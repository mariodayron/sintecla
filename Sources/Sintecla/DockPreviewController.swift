import AppKit
import Observation
import SinteclaCore

/// Módulo Dock (spec «Vistas del Dock» §3): al pasar el ratón por una app abierta del Dock, enseña sus ventanas para
/// saltar a una, cerrarla o minimizarla.
@MainActor
final class DockPreviewController {
  /// Cada cuánto se mira el ratón mientras la vista espera o está abierta (el Dock no avisa al salir de él).
  static let tickInterval = Duration.milliseconds(50)
  /// Tras cerrar o minimizar, las ventanas se vuelven a leer cada tanto hasta que macOS termina su animación.
  static let reloadStep = Duration.milliseconds(150)
  static let reloadSteps = 12

  private let settings: AppSettings
  private let watcher = DockWatcher()
  private let catalog = WindowCatalog()
  private lazy var panel: DockPreviewPanel = {
    let panel = DockPreviewPanel()
    panel.onClick = { [weak self] in self?.jump(to: $0) }
    panel.onClose = { [weak self] index in self?.act(on: index) { self?.catalog.close($0) } }
    panel.onMinimize = { [weak self] index in self?.act(on: index) { self?.catalog.toggleMinimized($0) } }
    panel.onQuit = { [weak self] in self?.quit(appOf: $0) }
    return panel
  }()
  private var timer = DockHoverTimer<pid_t>()
  /// El icono con el ratón encima: su elemento (para leer su sitio, que cambia con la lupa) y su app.
  private var hovered: (icon: AXUIElement, pid: pid_t)?
  private var ticker: Task<Void, Never>?
  private var thumbnailTask: Task<Void, Never>?
  private var clickMonitor: Any?
  private var moveMonitor: Any?
  /// El sitio del último icono: el Dock no avisa si el ratón sale y vuelve al mismo icono, así que se nota aquí.
  private var lastIconFrame: CGRect?
  /// Tras cerrar o minimizar, la vista cambia de tamaño y el ratón puede quedar fuera: su sitio anterior cuenta como
  /// dentro hasta que el ratón sale de él.
  private var previousPanelFrame: CGRect?

  init(settings: AppSettings) {
    self.settings = settings
  }

  /// Lo llama Sintecla al arrancar: desde ahí, escuchar el Dock sigue al interruptor del módulo.
  func start() {
    if settings.moduleDock {
      watcher.onHover = { [weak self] icon, item in self?.hover(icon: icon, item: item) }
      watcher.start()
      if moveMonitor == nil {
        moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
          MainActor.assumeIsolated { self?.mouseMoved() }
        }
      }
    } else {
      watcher.stop()
      if let moveMonitor { NSEvent.removeMonitor(moveMonitor) }
      moveMonitor = nil
      dismiss()
    }
    withObservationTracking { _ = settings.moduleDock } onChange: { [weak self] in
      Task { @MainActor in self?.start() }
    }
  }

  /// Lo llama el `EventTap` con cada pulsación que no usa nadie antes. Con la vista abierta, Esc la cierra.
  func keyDown(keyCode: Int64, modifiers: Set<ComboModifier>) -> Bool {
    guard panel.isVisible, keyCode == 53, modifiers.isEmpty else { return false }  // 53 = Esc
    dismiss()
    return true
  }

  /// Esc, un clic fuera de la vista o Alt-Tab: la vista se va.
  func dismiss() {
    timer.cancel()
    hidePanel()
  }

  private func hover(icon: AXUIElement, item: DockItem?) {
    // Carpetas, Papelera y apps cerradas no sacan nada: si el ratón sale del icono anterior, `tick` lo nota.
    guard let item, let app = Self.runningApp(at: item.appURL) else { return }
    hovered = (icon, app.processIdentifier)
    handle(timer.hover(app.processIdentifier, at: Date()))
    startTicking()
  }

  /// Solo con la vista quieta: si el ratón vuelve al último icono, es como si el Dock avisara otra vez.
  private func mouseMoved() {
    guard !timer.isActive, let hovered, let lastIconFrame,
          lastIconFrame.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) else { return }
    handle(timer.hover(hovered.pid, at: Date()))
    startTicking()
  }

  private func startTicking() {
    guard ticker == nil else { return }
    ticker = Task { [weak self] in
      while let self, self.timer.isActive, !Task.isCancelled {
        try? await Task.sleep(for: Self.tickInterval)
        self.tick()
      }
      self?.ticker = nil
    }
  }

  private func tick() {
    let mouse = NSEvent.mouseLocation
    let iconFrame = hovered.flatMap { watcher.frame(of: $0.icon) }
    if let iconFrame { lastIconFrame = iconFrame }
    let overIcon = iconFrame?.insetBy(dx: -2, dy: -2).contains(mouse) ?? false
    if let previous = previousPanelFrame, !previous.contains(mouse) { previousPanelFrame = nil }
    let overPanel = panel.isVisible && (panel.frame.contains(mouse) || previousPanelFrame != nil)
    handle(timer.tick(inside: overIcon || overPanel, at: Date()))
  }

  private func handle(_ action: DockHoverTimer<pid_t>.Action) {
    switch action {
    case .none: break
    case .show(let pid): show(pid, keepSelection: false)
    case .hide: hidePanel()
    }
  }

  /// Las ventanas de la app junto a su icono. Sin ventanas no sale nada.
  private func show(_ pid: pid_t, keepSelection: Bool) {
    guard let hovered, hovered.pid == pid, let icon = watcher.frame(of: hovered.icon),
          let screen = NSScreen.screens.first(where: { $0.frame.intersects(icon) }) ?? NSScreen.main else { return }
    catalog.refresh(only: pid)
    let windows = catalog.windows
    guard !windows.isEmpty else {
      hidePanel()
      return
    }
    let edge = DockEdge(icon: icon, screen: screen.frame)
    let selected = keepSelection ? panel.model.selected.map { min($0, windows.count - 1) } : nil
    panel.layout(count: windows.count, edge: edge, screen: screen.visibleFrame)
    panel.model.windows = windows
    panel.model.selected = selected
    panel.model.thumbnails = [:]
    panel.show(icon: icon, edge: edge, screen: screen.visibleFrame)
    thumbnailTask?.cancel()
    thumbnailTask = WindowThumbnails.capture(windows.filter { !$0.isMinimized }.map(\.id),
                                             maxSide: panel.model.cardWidth) { [weak self] id, image in
      self?.panel.model.thumbnails[id] = image
    }
    watchClicks()
  }

  private func hidePanel() {
    previousPanelFrame = nil
    thumbnailTask?.cancel()
    panel.hide()
    if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
    clickMonitor = nil
  }

  /// Un clic fuera de la vista (también en el Dock) la cierra. Los de dentro no llegan aquí.
  private func watchClicks() {
    guard clickMonitor == nil else { return }
    clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
      MainActor.assumeIsolated { self?.dismiss() }
    }
  }

  private func jump(to index: Int) {
    guard panel.model.windows.indices.contains(index) else { return }
    let window = panel.model.windows[index]
    dismiss()
    catalog.focus(window)
  }

  /// Salir de la app, como ⌘Q: si tiene algo sin guardar, la app pregunta. La vista se va.
  private func quit(appOf index: Int) {
    guard panel.model.windows.indices.contains(index) else { return }
    let pid = panel.model.windows[index].pid
    dismiss()
    NSRunningApplication(processIdentifier: pid)?.terminate()
  }

  /// Cerrar o minimizar: la vista sigue abierta y se vuelve a leer cuando macOS termina, es decir, cuando la lista ha
  /// cambiado y se queda igual en dos lecturas seguidas (durante la animación, una ventana puede salir dos veces).
  private func act(on index: Int, _ action: (SwitcherWindow) -> Void) {
    guard panel.model.windows.indices.contains(index), let pid = timer.shown else { return }
    action(panel.model.windows[index])
    let before = Self.signature(panel.model.windows)
    Task { [weak self] in
      var last = before
      for _ in 0..<Self.reloadSteps {
        try? await Task.sleep(for: Self.reloadStep)
        guard let self, self.timer.shown == pid else { return }
        self.catalog.refresh(only: pid)
        let now = Self.signature(self.catalog.windows)
        if now != before && now == last { break }
        last = now
      }
      guard let self, self.timer.shown == pid else { return }
      self.previousPanelFrame = self.panel.frame
      self.show(pid, keepSelection: true)
    }
  }

  private static func signature(_ windows: [SwitcherWindow]) -> [String] {
    windows.map { "\($0.id) \($0.isMinimized) \($0.title)" }
  }

  private static func runningApp(at url: URL) -> NSRunningApplication? {
    guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return nil }
    return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
  }
}
