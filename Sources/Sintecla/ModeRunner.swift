import AppKit
import SinteclaCore

/// Lo que se sabe de una grabación al terminarla.
struct Recording {
  var mode: HotkeyMode
  var raw: String
  var audioSeconds: Double
  var target: (bundleID: String?, name: String?)
  /// Dominio de la pestaña si se dictó en Safari (tono por web).
  var site: String? = nil
  var language: String
  /// Solo en Ask Anything.
  var selection: Selection?
  /// Cuándo se soltó la tecla (para medir la latencia).
  var releasedAt: Date
}

/// Qué hacer con el resultado de un modo.
enum ModeOutput: Equatable {
  /// Pegar en el cursor. `keepInClipboard`: notas. `notice`: aviso en la pastilla en vez de "Listo".
  case paste(String, keepInClipboard: Bool, notice: String?)
  case card(String, local: Bool, isError: Bool)
  case open(URL)
  case message(String)
  case notice(String, symbol: String)
}

/// Procesa cada modo con las piezas del núcleo y prepara la entrada del historial.
@MainActor
struct ModeRunner {
  let settings: AppSettings
  let appleModel: AppleTextModel?

  func run(_ recording: Recording) async -> (ModeOutput, HistoryEntry?) {
    let tone = settings.tones.tone(for: recording.target.bundleID, host: recording.site)
    switch recording.mode {
    case .dictation: return await dictation(recording, tone: tone)
    case .translation: return await translation(recording, tone: tone)
    case .ask: return await ask(recording)
    case .notes: return await notes(recording, tone: tone)
    case .meeting: return (.message("Las reuniones llegan en la Fase 3"), nil)
    }
  }

  private func cleaner() -> DictationCleaner {
    DictationCleaner(model: appleModel, dictionary: settings.dictionary, isKnownWord: { SpellChecker.isKnownWord($0) })
  }

  private func dictation(_ r: Recording, tone: Tone) async -> (ModeOutput, HistoryEntry?) {
    let result = await cleaner().clean(r.raw, tone: tone)
    guard !result.text.isEmpty else { return (.message("No te he oído"), nil) }
    return (.paste(result.text, keepInClipboard: false, notice: nil), entry(r, result.text, engine: result.engine.rawValue))
  }

  private func translation(_ r: Recording, tone: Tone) async -> (ModeOutput, HistoryEntry?) {
    let pipeline = TranslationPipeline(cleaner: cleaner(), primary: AppleTranslator(),
                                       fallback: settings.cloudModel().map { ModelTranslator(model: $0) })
    let result = await pipeline.run(r.raw, source: .of(locale: r.language), target: settings.translationTarget, tone: tone)
    guard !result.text.isEmpty else { return (.message("No te he oído"), nil) }
    let notice = result.engine == .untranslated ? "No se pudo traducir: pegado sin traducir" : nil
    return (.paste(result.text, keepInClipboard: false, notice: notice), entry(r, result.text, engine: result.engine.rawValue))
  }

  private func ask(_ r: Recording) async -> (ModeOutput, HistoryEntry?) {
    // "Añádelo al diccionario": la selección pasa a ser un término.
    if DictionaryCommand.matches(r.raw) {
      guard let text = r.selection?.text else { return (.message(DictionaryCommand.noSelection), nil) }
      let added = settings.dictionary.addTerm(fromSelection: text)
      return (added.isError ? .message(added.message) : .notice(added.message, symbol: OverlayView.dictionarySymbol), nil)
    }
    let pipeline = AskPipeline(apple: appleModel, localAnswers: appleModel == nil ? nil : AppleTextModel(temperature: 0.4),
                               cloud: settings.cloudModel(), translator: AppleTranslator(), style: settings.myStyle)
    switch await pipeline.run(command: r.raw, selection: r.selection) {
    case .replace(let text, let engine):
      return (.paste(text, keepInClipboard: false, notice: nil), entry(r, text, engine: engine))
    case .answer(let text, let local, let engine):
      return (.card(text, local: local, isError: false), entry(r, text, engine: engine))
    case .open(let url):
      return (.open(url), entry(r, url.absoluteString, engine: "web"))
    case .failure(let message):
      return (.card(message, local: false, isError: true), nil)
    case .silence:
      return (.message("No te he oído"), nil)
    }
  }

  private func notes(_ r: Recording, tone: Tone) async -> (ModeOutput, HistoryEntry?) {
    let organizer = NotesOrganizer(cloud: settings.cloudModel(timeout: 120), apple: appleModel,
                                   dictionary: settings.dictionary, isKnownWord: { SpellChecker.isKnownWord($0) },
                                   style: settings.myStyle)
    let result = await organizer.organize(r.raw, format: NotesFormat.forApp(bundleID: r.target.bundleID, tone: tone))
    guard !result.text.isEmpty else { return (.message("No te he oído"), nil) }
    let notice: String? = switch result.engine {
    case .gemini: nil
    case .apple: "Resumen local · " + (result.cloudError?.userMessage ?? "sin clave de Gemini")
    case .rules: "Sin IA: pegada la transcripción"
    }
    return (.paste(result.text, keepInClipboard: true, notice: notice), entry(r, result.text, engine: result.engine.rawValue))
  }

  private func entry(_ r: Recording, _ text: String, engine: String) -> HistoryEntry {
    HistoryEntry(mode: r.mode, appBundleID: r.target.bundleID, appName: r.target.name, language: r.language,
                 audioSeconds: r.audioSeconds, rawText: r.raw, finalText: text, engine: engine,
                 latencyMs: Int(Date().timeIntervalSince(r.releasedAt) * 1000))
  }
}
