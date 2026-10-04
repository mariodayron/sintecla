import AppKit
import Observation
import SinteclaCore

/// Módulo Isla (spec «La isla»): une lo que suena, lo que hace Sintecla (el mismo `OverlayModel` de la pastilla), el
/// ratón y la pantalla completa, y decide la forma de la isla. También pausa la música al dictar (§3.4). Desde la
/// 0.15.0, el estante de archivos y los avisos de carga y AirPods (spec «Estante y avisos»).
@MainActor
final class IslandController {
  private let settings: AppSettings
  private let overlay: OverlayModel
  private let music = NowPlayingClient.shared
  private let model = IslandModel()
  private let shelf = ShelfStore()
  private let drag = ShelfDragSource()
  private lazy var panel = IslandPanel(view: IslandView(
    model: model, overlay: overlay, music: music, shelf: shelf, drag: drag,
    onOpenApp: { [weak self] in self?.openPlayingApp() },
    onShelfDrag: { [weak self] in self?.draggingOut = true },
    onCommand: { [weak self] in self?.music.send($0) },
    onSeek: { [weak self] in self?.seek(to: $0) }))
  private let dropWindow = ShelfDropWindow()
  private let fileDrag = FileDragWatcher()
  private let power = PowerMonitor()
  private let airPods = AirPodsMonitor()
  private var powerNotices = PowerNotices()
  private var airPodsNotices = AirPodsNotices()
  private var notices = NoticeQueue()
  private var noticeTask: Task<Void, Never>?
  /// La bandeja: se abre al acercar archivos a la muesca y se recoge al alejarse (como la desplegada).
  private var trayHover = IslandHover()
  private var trayTask: Task<Void, Never>?
  /// Sacando un archivo del estante: la isla no se recoge hasta soltarlo.
  private var draggingOut = false
  private var hover = IslandHover()
  private var presence = MusicPresence()
  private var pauser = MusicPauser()
  private var screen: NSScreen?
  private var notch: CGRect?
  private var fullScreen = false
  /// Sin muesca (tapa cerrada): isla virtual en la pantalla principal, solo con lo de Sintecla.
  private var hasNotch = true
  /// Lo de Sintecla sale en la isla, y no en la pastilla (lo pide `DictationController` con `claimActivity()`).
  private var takesActivity = false
  /// El modo que se estaba escuchando, para saber cuándo empieza y cuándo termina.
  private var listening: HotkeyMode?
  private var monitors: [Any] = []
  private var observers: [NSObjectProtocol] = []
  private var observingPhase = false
  private var lingerTask: Task<Void, Never>?
  private var recheckTask: Task<Void, Never>?

  init(settings: AppSettings, overlay: OverlayModel) {
    self.settings = settings
    self.overlay = overlay
  }

  /// Encendido y con una pantalla: la del MacBook o, con la tapa cerrada, la principal (isla virtual).
  var isActive: Bool { settings.moduleIsland && screen != nil }

  /// Lo llama Sintecla al arrancar: desde ahí, la isla sigue al interruptor del módulo y a los del estante y los avisos.
  func start() {
    apply()
    withObservationTracking {
      _ = settings.moduleIsland
      _ = settings.islandShelf
      _ = settings.islandDeviceNotices
    } onChange: { [weak self] in
      Task { @MainActor in self?.start() }
    }
  }

  /// Antes de enseñar un estado de Sintecla: true si lo enseña la isla (encendida, aunque se esté trabajando en otra
  /// pantalla); si no, va a la pastilla de abajo.
  func claimActivity() -> Bool {
    takesActivity = isActive
    refresh()
    return takesActivity
  }

  private func apply() {
    if settings.moduleIsland {
      music.onChange = { [weak self] in self?.musicChanged($0) }
      music.start()
      install()
      watchPhase()
      applyShelf()
      applyDeviceNotices()
      screensChanged()
    } else {
      music.onChange = nil
      music.stop()
      uninstall()
      stopShelf()
      stopDeviceNotices()
      takesActivity = false
      screen = nil
      notch = nil
      panel.hide()
    }
  }

  private var shelfOn: Bool { settings.moduleIsland && settings.islandShelf }

  private func applyShelf() {
    guard settings.islandShelf else { return stopShelf() }
    fileDrag.onChange = { [weak self] in self?.fileDragMoved($0) }
    fileDrag.start()
    panel.dropView.onDrop = { [weak self] in self?.dropped($0) }
    dropWindow.view.onEnter = { [weak self] in self?.openTray() }
    dropWindow.view.onDrop = { [weak self] in self?.dropped($0) }
    drag.onEnd = { [weak self] id, dropped, keep in self?.draggedOut(id, dropped: dropped, keep: keep) }
    shelf.refresh()
    watchShelf()
  }

  /// Al cambiar el estante (soltar, ✕, Vaciar, sacar), la forma puede cambiar.
  private var observingShelf = false
  private func watchShelf() {
    guard !observingShelf else { return }
    observingShelf = true
    withObservationTracking { _ = shelf.items } onChange: { [weak self] in
      Task { @MainActor in
        self?.observingShelf = false
        self?.refresh()
        self?.watchShelf()
      }
    }
  }

  private func stopShelf() {
    fileDrag.stop()
    dropWindow.hide()
    trayHover.reset()
  }

  private func applyDeviceNotices() {
    guard settings.islandDeviceNotices else { return stopDeviceNotices() }
    power.onChange = { [weak self] in self?.push(self?.powerNotices.update($0) ?? []) }
    airPods.onKnown = { [weak self] in self?.airPodsNotices.known($0) }
    airPods.onConnect = { [weak self] in self?.push(self?.airPodsNotices.connected($0) ?? []) }
    airPods.onBattery = { [weak self] in self?.push(self?.airPodsNotices.batteryChanged($0) ?? []) }
    airPods.onDisconnect = { [weak self] in self?.airPodsNotices.disconnected(address: $0) }
    power.start()
    airPods.start()
  }

  private func stopDeviceNotices() {
    power.stop()
    airPods.stop()
    powerNotices = PowerNotices()
    airPodsNotices = AirPodsNotices()
    notices = NoticeQueue()
    noticeTask?.cancel()
    model.device = nil
  }

  // MARK: Avisos

  private func install() {
    guard monitors.isEmpty else { return }
    let moved: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
    if let global = NSEvent.addGlobalMonitorForEvents(matching: moved, handler: { [weak self] _ in
      MainActor.assumeIsolated { self?.mouseMoved() }
    }) {
      monitors.append(global)
    }
    if let local = NSEvent.addLocalMonitorForEvents(matching: moved, handler: { [weak self] event in
      MainActor.assumeIsolated { self?.mouseMoved() }
      return event
    }) {
      monitors.append(local)
    }
    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                        queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.screensChanged() }
    })
    let workspace = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
      observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.spaceChanged() }
      })
    }
  }

  private func uninstall() {
    monitors.forEach(NSEvent.removeMonitor)
    monitors.removeAll()
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    observers.removeAll()
  }

  /// Cada cambio de estado de Sintecla: la forma y, al empezar y terminar de escuchar, la pausa de la música.
  private func watchPhase() {
    guard !observingPhase else { return }
    observingPhase = true
    withObservationTracking { _ = overlay.phase } onChange: { [weak self] in
      Task { @MainActor in
        self?.observingPhase = false
        self?.phaseChanged()
        self?.watchPhase()
      }
    }
  }

  private func phaseChanged() {
    guard settings.moduleIsland else { return }
    var mode: HotkeyMode?
    if case .listening(let current) = overlay.phase { mode = current }
    if let mode, listening == nil,
       let command = pauser.listeningStarted(mode: mode, musicPlaying: music.track?.isPlaying ?? false) {
      send(command)
    }
    if mode == nil, listening != nil, let command = pauser.listeningEnded() {
      send(command)
    }
    listening = mode
    tickNotices()
    refresh()
  }

  private func send(_ command: MusicPauser.Command) {
    music.send(command == .pause ? .pause : .play)
  }

  private func musicChanged(_ track: NowPlaying?) {
    pauser.musicChanged(isPlaying: track?.isPlaying ?? false)
    presence.update(track, at: Date())
    // En pausa, la música se va de la isla a los 5 minutos.
    lingerTask?.cancel()
    if let track, !track.isPlaying {
      lingerTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(MusicPresence.pausedLinger + 0.5))
        guard !Task.isCancelled else { return }
        self?.refresh()
      }
    }
    refresh()
  }

  private func screensChanged() {
    if let real = NotchScreen.current, let rect = NotchScreen.notchRect(on: real) {
      screen = real
      notch = rect
      hasNotch = true
    } else {
      // La pantalla principal es la de la barra de menús.
      screen = NSScreen.screens.first
      notch = screen.map(NotchScreen.virtualNotch(on:))
      hasNotch = false
    }
    hover.reset()
    checkFullScreen()
    refresh()
  }

  /// Al cambiar de escritorio o de app; la animación de macOS tarda un poco en dejar la ventana en su sitio.
  private func spaceChanged() {
    checkFullScreen()
    refresh()
    Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(700))
      self?.checkFullScreen()
      self?.refresh()
    }
  }

  /// A pantalla completa: la app de delante tiene una ventana normal del tamaño de la pantalla de la muesca.
  private func checkFullScreen() {
    guard let screen, let app = NSWorkspace.shared.frontmostApplication,
          let primary = NSScreen.screens.first?.frame else {
      fullScreen = false
      return
    }
    // La lista de ventanas mide desde arriba a la izquierda de la pantalla principal.
    let target = CGRect(x: screen.frame.minX, y: primary.maxY - screen.frame.maxY, width: screen.frame.width,
                        height: screen.frame.height)
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
      as? [[String: Any]] ?? []
    fullScreen = windows.contains { window in
      guard (window[kCGWindowOwnerPID as String] as? Int32) == app.processIdentifier,
            (window[kCGWindowLayer as String] as? Int) == 0,
            let bounds = window[kCGWindowBounds as String] as? NSDictionary,
            let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
      return rect == target
    }
  }

  // MARK: Forma y ratón

  private func refresh() {
    guard isActive, let screen, let notch else {
      panel.hide()
      dropWindow.hide()
      return
    }
    let activity = (takesActivity ? Self.activity(for: overlay.phase) : nil) ?? (model.device == nil ? nil : .device)
    let showsMusic = presence.isShown(music.track, at: Date())
    // Al desplegarse, se quitan del estante los archivos que ya no están.
    if shelfOn, hover.isExpanded, !Self.isExpanded(model.form) { shelf.refresh() }
    let files = shelfOn ? shelf.items.count : 0
    if !showsMusic, files == 0 { hover.reset() }
    let form = IslandLayout.form(activity: activity, music: showsMusic, hovering: hover.isExpanded || draggingOut,
                                 fullScreen: fullScreen, hasNotch: hasNotch, shelf: files,
                                 dragging: shelfOn && trayHover.isExpanded)
    model.notch = notch.size
    model.hasNotch = hasNotch
    if model.form != form { model.form = form }
    panel.dropView.accepting = form == .tray
    panel.show(on: screen, notch: notch)
    if shelfOn, hasNotch { dropWindow.show(over: notch) } else { dropWindow.hide() }
    updateMouse()
  }

  private static func activity(for phase: OverlayModel.Phase) -> IslandActivity? {
    switch phase {
    case .hidden: nil
    case .listening(.meeting): .meeting
    case .listening: .listening
    case .processing: .processing
    case .done: .done
    case .message, .notice: .notice
    }
  }

  private static func isExpanded(_ form: IslandForm) -> Bool {
    if case .expanded = form { return true }
    return false
  }

  /// Sintecla ocupa la isla: los avisos esperan (spec «Estante y avisos» §4.2).
  private var sinteclaBusy: Bool {
    takesActivity && Self.activity(for: overlay.phase) != nil
  }

  /// El sitio de la isla en la pantalla, con las curvas de arriba.
  private var islandRect: CGRect? {
    guard let screen, let notch else { return nil }
    let size = IslandLayout.size(of: model.form, notch: notch.size, hasNotch: hasNotch)
    guard size != .zero else { return nil }
    let width = size.width + 2 * IslandView.flare
    return CGRect(x: notch.midX - width / 2, y: screen.frame.maxY - size.height, width: width, height: size.height)
  }

  private func mouseMoved() {
    guard isActive else { return }
    updateMouse()
  }

  /// Con música o archivos, el ratón dentro de la isla la despliega (y fuera la recoge); solo entonces el panel recibe
  /// clics. La bandeja recibe el arrastre en toda su forma.
  private func updateMouse() {
    let inside = islandRect?.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) ?? false
    let hoverable = IslandLayout.isHoverable(model.form)
    panel.acceptsMouse = model.form == .tray || draggingOut || (inside && hoverable)
    if hover.update(inside: inside && hoverable, at: Date()) { refresh() }
    // El ratón puede quedarse quieto: se vuelve a mirar cuando se cumple la espera.
    recheckTask?.cancel()
    let waiting = hoverable && inside != hover.isExpanded
    guard waiting else { return }
    let delay = inside ? IslandHover.expandDelay : IslandHover.collapseDelay
    recheckTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay + 0.02))
      guard !Task.isCancelled else { return }
      self?.updateMouse()
    }
  }

  // MARK: Estante

  /// Cada movimiento de un arrastre de archivos desde otra app (nil al soltar el botón).
  private func fileDragMoved(_ location: NSPoint?) {
    guard shelfOn, hasNotch, let notch else { return }
    guard let location else {
      // Al soltar, la bandeja espera un poco para no perder la entrega.
      trayTask?.cancel()
      trayTask = Task { [weak self] in
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        self?.closeTray()
      }
      return
    }
    let inZone = IslandLayout.dropZone(around: notch).contains(location)
    if trayHover.update(inside: inZone, at: Date()) { refresh() }
    recheckTray(inZone)
  }

  /// El ratón puede quedarse quieto en la zona o fuera de ella: se vuelve a mirar al cumplirse la espera.
  private func recheckTray(_ inZone: Bool) {
    trayTask?.cancel()
    guard inZone != trayHover.isExpanded else { return }
    let delay = inZone ? IslandHover.expandDelay : IslandHover.collapseDelay
    trayTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay + 0.02))
      guard !Task.isCancelled, let self else { return }
      if self.trayHover.update(inside: inZone, at: Date()) { self.refresh() }
    }
  }

  /// El arrastre llegó a la ventana de la muesca antes que a la zona.
  private func openTray() {
    guard !trayHover.isExpanded else { return }
    trayHover.update(inside: true, at: Date())
    trayHover.update(inside: true, at: Date() + IslandHover.expandDelay)
    refresh()
  }

  private func closeTray() {
    trayTask?.cancel()
    guard trayHover.isExpanded else { return }
    trayHover.reset()
    refresh()
  }

  private func dropped(_ urls: [URL]) {
    shelf.add(urls)
    fileDrag.finish()
    closeTray()
  }

  private func draggedOut(_ id: UUID, dropped: Bool, keep: Bool) {
    shelf.dragEnded(id, dropped: dropped, keep: keep)
    draggingOut = false
    refresh()
  }

  // MARK: Avisos de carga y AirPods

  private func push(_ new: [DeviceNotice]) {
    guard !new.isEmpty else { return }
    notices.push(new, at: Date())
    tickNotices()
  }

  /// Enseña el siguiente aviso cuando toca y programa el final del de ahora.
  private func tickNotices() {
    if notices.tick(at: Date(), busy: sinteclaBusy) {
      model.device = notices.current
      refresh()
    }
    noticeTask?.cancel()
    guard let next = notices.nextTick else { return }
    noticeTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(max(0, next.timeIntervalSinceNow) + 0.02))
      guard !Task.isCancelled else { return }
      self?.tickNotices()
    }
  }

  // MARK: Acciones

  private func openPlayingApp() {
    guard let pid = music.track?.pid, let url = NSRunningApplication(processIdentifier: pid)?.bundleURL else { return }
    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
  }

  /// La barra se queda donde se soltó hasta que la app confirma el salto.
  private func seek(to fraction: Double) {
    guard let track = music.track, track.duration > 0 else { return }
    music.seek(to: fraction * track.duration)
    Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(900))
      self?.model.scrub = nil
    }
  }
}
