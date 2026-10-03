import AppKit
import Observation
import SinteclaCore

/// Módulo Isla (spec «La isla»): une lo que suena, lo que hace Sintecla (el mismo `OverlayModel` de la pastilla), el
/// ratón y la pantalla completa, y decide la forma de la isla. También pausa la música al dictar (§3.4).
@MainActor
final class IslandController {
  private let settings: AppSettings
  private let overlay: OverlayModel
  private let music = NowPlayingClient.shared
  private let model = IslandModel()
  private lazy var panel = IslandPanel(view: IslandView(
    model: model, overlay: overlay, music: music,
    onOpenApp: { [weak self] in self?.openPlayingApp() },
    onCommand: { [weak self] in self?.music.send($0) },
    onSeek: { [weak self] in self?.seek(to: $0) }))
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

  /// Lo llama Sintecla al arrancar: desde ahí, la isla sigue al interruptor del módulo.
  func start() {
    apply()
    withObservationTracking { _ = settings.moduleIsland } onChange: { [weak self] in
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
      screensChanged()
    } else {
      music.onChange = nil
      music.stop()
      uninstall()
      takesActivity = false
      screen = nil
      notch = nil
      panel.hide()
    }
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
      return
    }
    let activity = takesActivity ? Self.activity(for: overlay.phase) : nil
    let showsMusic = presence.isShown(music.track, at: Date())
    if !showsMusic { hover.reset() }
    let form = IslandLayout.form(activity: activity, music: showsMusic, hovering: hover.isExpanded,
                                 fullScreen: fullScreen, hasNotch: hasNotch)
    model.notch = notch.size
    model.hasNotch = hasNotch
    if model.form != form { model.form = form }
    panel.show(on: screen, notch: notch)
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

  /// Con música, el ratón dentro de la isla la despliega (y fuera la recoge); solo entonces el panel recibe clics.
  private func updateMouse() {
    let inside = islandRect?.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) ?? false
    panel.acceptsMouse = inside && (model.form == .compact || model.form == .expanded)
    let musicForm = model.form == .compact || model.form == .expanded
    if hover.update(inside: inside && musicForm, at: Date()) { refresh() }
    // El ratón puede quedarse quieto: se vuelve a mirar cuando se cumple la espera.
    recheckTask?.cancel()
    let waiting = musicForm && inside != hover.isExpanded
    guard waiting else { return }
    let delay = inside ? IslandHover.expandDelay : IslandHover.collapseDelay
    recheckTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay + 0.02))
      guard !Task.isCancelled else { return }
      self?.updateMouse()
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
