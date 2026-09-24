import AppKit
import AVFoundation
import SinteclaCore

/// Orquesta los modos: atajo → micro → transcripción → modo (ModeRunner) → pegar/tarjeta/web → historial.
@MainActor
final class DictationController {
  let history = HistoryStore(fileURL: AppPaths.historyURL)
  /// Resumen por día para Estadísticas: a diferencia del historial, no se recorta.
  let usage = UsageStatsStore(fileURL: AppPaths.statsURL)
  let drafts = DraftStore(directory: AppPaths.draftsDirectory)
  var onRecordingChange: ((Bool) -> Void)?

  private let settings: AppSettings
  private let overlayModel = OverlayModel()
  private lazy var overlay = OverlayPanel(model: overlayModel)
  private let card = AskCardPanel()
  private let eventTap = EventTap()
  private let audio = AudioCapture()
  private let appleModel: AppleTextModel? = AppleTextModel.isAvailable ? AppleTextModel() : nil
  private var machine = HotkeyStateMachine()
  private var session: TranscriptionSession?
  private var audioFormat: AVAudioFormat?
  private var target: (bundleID: String?, name: String?) = (nil, nil)
  /// Dominio de la pestaña de Safari donde se dicta (tono por web), leído en segundo plano.
  private var siteTask: Task<String?, Never>?
  private var mode: HotkeyMode = .dictation
  private var selectionTask: Task<Selection?, Never>?
  private var draft: URL?
  private var hideTask: Task<Void, Never>?
  private let watcher = CorrectionWatcher()
  /// Aviso de "Aprendido…" que espera a que la pastilla quede libre.
  private var pendingNotice: String?

  private let meetings: MeetingLibrary
  private lazy var recorder = MeetingRecorder(settings: settings, library: meetings)

  init(settings: AppSettings, meetings: MeetingLibrary) {
    self.settings = settings
    self.meetings = meetings
    card.onInsert = { text in Task { await Paster.paste(text) } }
    // Antes de que `start()` recorte el historial: la primera vez, el resumen se rellena con todo lo que hay.
    usage.prepare(history: history.load())
    watcher.onFinish = { [weak self] pasted, field in self?.learn(pasted: pasted, field: field) }
  }

  /// Arranca la escucha del teclado. Devuelve false si macOS no da permiso.
  @discardableResult
  func start() -> Bool {
    eventTap.onEvent = { [weak self] event in
      MainActor.assumeIsolated { self?.handle(event) ?? false }
    }
    applySettings()
    guard eventTap.start() else { return false }
    try? history.compact()
    if Permissions.typelessRunning {
      show(.message("Typeless está abierto: ciérralo (también usa 🌐)"))
    } else if appleModel == nil {
      show(.message("Apple Intelligence no disponible: limpieza solo con reglas"))
    }
    return true
  }

  /// Relee idioma, tecla base, atajos y ganancia (tras cambiar Ajustes o el menú).
  func applySettings() {
    machine.baseKey = settings.baseKey
    machine.layout = settings.hotkeys
    eventTap.baseKey = settings.baseKey
    Sounds.enabled = settings.soundsEnabled
    audioFormat = nil
    let locale = Locale(identifier: settings.language)
    Task { [weak self] in
      do {
        try await TranscriptionSession.ensureAssets(for: locale)
        let format = await TranscriptionSession.audioFormat(for: locale)
        self?.audioFormat = format
      } catch {
        self?.show(.message("No se pudo preparar el dictado en \(locale.identifier)"))
      }
    }
  }

  func pasteLastResult() {
    guard let last = history.latest() else { return }
    Task { await Paster.paste(last.finalText) }
  }

  // MARK: - Atajos

  private func handle(_ event: HotkeyEvent) -> Bool {
    // Esc cierra la tarjeta de Ask Anything si no se está grabando.
    if case .escape = event, card.isVisible, machine.state == .idle {
      card.close()
      return true
    }
    let actions = machine.handle(event)
    actions.forEach(perform)
    return actions.contains(.swallowKey)
  }

  private func perform(_ action: HotkeyAction) {
    switch action {
    case .arm: arm()
    case .startRecording(let mode, _): startRecording(mode)
    case .finishRecording: finish()
    case .cancel: cancel()
    case .toggleMeeting: toggleMeeting()
    case .swallowKey: break
    case .busyFeedback: Sounds.error()
    }
  }

  /// Tecla base pulsada: abre el micro ya (pre-roll) sin mostrar nada. Durante una reunión el micro es suyo:
  /// no se abre (la tecla base solo sirve para terminarla).
  private func arm() {
    // Empieza otra grabación: se cierra la vigilancia de correcciones del pegado anterior.
    watcher.finish()
    if recorder.isRecording { return }
    guard let format = audioFormat else {
      machine.reset()
      show(.message("El dictado aún se está preparando…"))
      return
    }
    card.close()
    let app = NSWorkspace.shared.frontmostApplication
    target = (app?.bundleIdentifier, app?.localizedName)
    siteTask = SafariSite.read(app)
    let session = TranscriptionSession(locale: Locale(identifier: settings.language),
                                       contextualStrings: settings.dictionary.terms)
    self.session = session
    audio.gain = settings.whisperMode ? 3.2 : 1
    audio.onBuffer = { buffer in session.append(buffer) }
    audio.onLevel = { [weak self] level in
      DispatchQueue.main.async { self?.overlayModel.level = level }
    }
    audio.start(format: format) { [weak self] in
      DispatchQueue.main.async { self?.microphoneFailed(session) }
    }
    session.begin()
    // El modelo local se prepara con el tono ya resuelto (en Safari, el de la web).
    let tones = settings.tones, bundleID = target.bundleID, siteTask = self.siteTask
    Task { [weak self] in
      let site = await siteTask?.value
      self?.appleModel?.prewarm(instructions: PromptLibrary.dictationInstructions(tone: tones.tone(for: bundleID, host: site)))
    }
    // Decide "mantener" sin esperar a que se suelte la tecla.
    DispatchQueue.main.asyncAfter(deadline: .now() + HotkeyStateMachine.tapThreshold + 0.01) { [weak self] in
      guard let self else { return }
      self.machine.handle(.tick(at: ProcessInfo.processInfo.systemUptime)).forEach(self.perform)
    }
  }

  /// El micrófono no se pudo abrir (se abre en segundo plano): se cancela esa grabación.
  private func microphoneFailed(_ failed: TranscriptionSession) {
    guard session === failed else { return }
    cancel()
    machine.reset()
    show(.message("No se pudo abrir el micrófono"))
  }

  private func startRecording(_ mode: HotkeyMode) {
    if recorder.isRecording {
      machine.reset()
      let shortcut = settings.hotkeys.shortcut(for: .meeting, baseKey: settings.baseKey)
      show(.message(shortcut.map { "Reunión en curso: termínala con \($0)" } ?? "Reunión en curso: termínala desde el menú"))
      return
    }
    self.mode = mode
    switch mode {
    case .ask:
      selectionTask = Task { await ContextReader.selection() }
    case .notes:
      startDraft()
    default:
      break
    }
    Sounds.start()
    onRecordingChange?(true)
    show(.listening(mode))
  }

  /// Notas: cada frase reconocida va al borrador en disco y a la pastilla.
  private func startDraft() {
    let drafts = self.drafts
    let draft = drafts.create()
    self.draft = draft
    overlayModel.startedAt = Date()
    overlayModel.liveText = ""
    session?.observeFinals { [weak self] piece in
      drafts.append(piece, to: draft)
      DispatchQueue.main.async {
        guard let self else { return }
        let text = (self.overlayModel.liveText + " " + piece).trimmingCharacters(in: .whitespaces)
        self.overlayModel.liveText = String(text.suffix(80))
      }
    }
  }

  private func cancel() {
    audio.stop()
    let session = self.session
    self.session = nil
    Task { await session?.cancel() }
    selectionTask?.cancel()
    selectionTask = nil
    // Un borrador con texto se conserva (menú "Notas sin procesar") por si el Esc fue sin querer.
    if let draft, drafts.read(draft).isEmpty { drafts.delete(draft) }
    draft = nil
    onRecordingChange?(false)
    hideOverlay()
  }

  private func finish() {
    guard let session else {
      machine.processingFinished()
      return
    }
    self.session = nil
    audio.stop()
    onRecordingChange?(false)
    let mode = self.mode
    show(.processing(mode))

    let releasedAt = Date()
    // Las notas se pegan donde estés al terminar (puedes cambiar de app mientras hablas).
    let app = NSWorkspace.shared.frontmostApplication
    let target = mode == .notes ? (app?.bundleIdentifier, app?.localizedName) : self.target
    let siteTask = mode == .notes ? SafariSite.read(app) : self.siteTask
    let language = settings.language
    let selectionTask = self.selectionTask
    self.selectionTask = nil
    let draft = self.draft
    self.draft = nil
    let runner = ModeRunner(settings: settings, appleModel: appleModel)
    Task { [weak self] in
      let raw = (try? await session.finish()) ?? ""
      let selection = await selectionTask?.value
      let site = await siteTask?.value
      let recording = Recording(mode: mode, raw: raw, audioSeconds: session.audioSeconds, target: target, site: site,
                                language: language, selection: selection, releasedAt: releasedAt)
      let (output, entry) = await runner.run(recording)
      guard let self else { return }
      defer { self.machine.processingFinished() }
      if let entry {
        try? self.history.append(entry)
        try? self.usage.add(entry)
        NotificationCenter.default.post(name: .usageChanged, object: nil)
      }
      await self.deliver(output, question: raw)
      if case .paste(let text, _, _) = output, mode != .ask, self.settings.learnCorrections {
        self.watcher.watch(pasted: text)
      }
      // El borrador se borra cuando las notas ya están pegadas y en el historial.
      if let draft, entry != nil || self.drafts.read(draft).isEmpty { self.drafts.delete(draft) }
    }
  }

  private func deliver(_ output: ModeOutput, question: String = "") async {
    switch output {
    case .paste(let text, let keepInClipboard, let notice):
      await Paster.paste(text, restoreClipboard: !keepInClipboard)
      Sounds.done()
      show(notice.map { .message($0) } ?? .done)
    case .card(let text, let local, let isError):
      hideOverlay()
      if isError { Sounds.error() } else { Sounds.done() }
      card.show(text, question: question, local: local, isError: isError)
    case .open(let url):
      NSWorkspace.shared.open(url)
      Sounds.done()
      show(.done)
    case .message(let text):
      show(.message(text))
    case .notice(let text, let symbol):
      show(.notice(text, symbol: symbol))
    }
  }

  // MARK: - Diccionario que aprende

  /// Menú "Añadir selección al diccionario".
  func addSelectionToDictionary() {
    Task {
      guard let selection = await ContextReader.selection() else {
        show(.message(DictionaryCommand.noSelection))
        return
      }
      let added = settings.dictionary.addTerm(fromSelection: selection.text)
      show(added.isError ? .message(added.message) : .notice(added.message, symbol: OverlayView.dictionarySymbol))
    }
  }

  private func learn(pasted: String, field: String) {
    let notices = CorrectionLearner.corrections(pasted: pasted, field: field).compactMap {
      settings.dictionary.learn($0, isKnownWord: { SpellChecker.isKnownWord($0) }).notice
    }
    guard let first = notices.first else { return }
    let notice = notices.count > 1 ? first + " (+\(notices.count - 1))" : first
    // Si la vigilancia terminó porque empieza otra grabación (la máquina ya no está en reposo), el dictado taparía el
    // aviso enseguida: espera a que la pastilla quede libre.
    if overlayModel.phase == .hidden, machine.state == .idle {
      show(.notice(notice, symbol: OverlayView.dictionarySymbol))
    } else {
      pendingNotice = notice
    }
  }

  // MARK: - Reuniones

  func toggleMeeting() {
    if recorder.isRecording { stopMeeting() } else { startMeeting() }
  }

  func retryMeeting(_ record: MeetingRecord) {
    Task { handle(await recorder.process(record)) }
  }

  private func startMeeting() {
    guard machine.state == .idle, session == nil else {
      show(.message("Termina antes lo que estás dictando"))
      return
    }
    guard let format = audioFormat else {
      show(.message("El dictado aún se está preparando…"))
      return
    }
    if !settings.meetingNoticeShown {
      let alert = NSAlert()
      alert.messageText = "Avisa de que grabas la reunión"
      alert.informativeText = "Informa a los participantes antes de grabar. Sintecla guarda la transcripción en tu Mac "
        + "y envía el texto a Gemini para redactar el acta."
      alert.addButton(withTitle: "Entendido, grabar")
      alert.addButton(withTitle: "Cancelar")
      NSApp.activate()
      guard alert.runModal() == .alertFirstButtonReturn else { return }
      settings.meetingNoticeShown = true
    }
    card.close()
    recorder.onLevel = { [weak self] level in self?.overlayModel.level = level }
    recorder.onLiveText = { [weak self] text in self?.overlayModel.liveText = String(text.suffix(60)) }
    do {
      try recorder.start(format: format)
    } catch {
      show(.message("No se pudo empezar la reunión"))
      return
    }
    overlayModel.startedAt = meetings.recordingSince
    overlayModel.liveText = ""
    Sounds.start()
    onRecordingChange?(true)
    show(.listening(.meeting))
  }

  private func stopMeeting() {
    onRecordingChange?(false)
    overlayModel.liveText = ""
    show(.processing(.meeting))
    Task { handle(await recorder.stop()) }
  }

  private func handle(_ outcome: MeetingOutcome) {
    switch outcome {
    case .ready(let record, let markdown):
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(markdown, forType: .string)
      if let pdf = record.pdfPath { NSWorkspace.shared.open(URL(fileURLWithPath: pdf)) }
      Sounds.done()
      show(.done)
      Notifier.post(title: "Acta lista", body: "\(record.title ?? "Reunión") · \(record.tasks) tareas. Resumen copiado.")
    case .pending(let record):
      Sounds.error()
      show(.message("Acta pendiente: \(record.problem ?? "reinténtalo")"))
      Notifier.post(title: "Acta pendiente", body: record.problem ?? "Reinténtalo desde Sintecla › Reuniones.")
    case .empty:
      show(.message("No se oyó nada: no hay acta"))
    }
  }

  // MARK: - Pastilla

  private func show(_ phase: OverlayModel.Phase) {
    hideTask?.cancel()
    overlayModel.phase = phase
    overlay.show()
    switch phase {
    case .done: scheduleHide(after: 0.7)
    case .message, .notice: scheduleHide(after: 2.5)
    default: break
    }
  }

  private func scheduleHide(after seconds: Double) {
    hideTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(seconds))
      guard !Task.isCancelled else { return }
      self?.hideOverlay()
    }
  }

  private func hideOverlay() {
    hideTask?.cancel()
    // Durante una reunión, la pastilla vuelve a la reunión en lugar de desaparecer.
    if recorder.isRecording {
      overlayModel.startedAt = meetings.recordingSince
      overlayModel.phase = .listening(.meeting)
      overlay.show()
      return
    }
    if let notice = pendingNotice {
      pendingNotice = nil
      show(.notice(notice, symbol: OverlayView.dictionarySymbol))
      return
    }
    overlayModel.phase = .hidden
    overlayModel.level = 0
    overlayModel.startedAt = nil
    overlayModel.liveText = ""
    overlay.hide()
  }
}
