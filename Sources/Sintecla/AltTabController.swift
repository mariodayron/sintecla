import AppKit
import Observation
import SinteclaCore

/// Módulo Alt-Tab (spec «Alt-Tab» §3): ⌘Tab abre el selector de ventanas, Tab, ⇧Tab y las flechas lo mueven, Esc lo
/// cierra y al soltar ⌘ se salta a la ventana marcada.
@MainActor
final class AltTabController {
  /// Si se suelta ⌘ antes, se salta sin enseñar el panel: el cambio rápido no parpadea.
  static let panelDelay = Duration.milliseconds(150)

  private let settings: AppSettings
  private let catalog = WindowCatalog()
  private lazy var panel: WindowSwitcherPanel = {
    let panel = WindowSwitcherPanel()
    panel.onHover = { [weak self] index in self?.mark(index) }
    panel.onClick = { [weak self] index in
      self?.mark(index)
      self?.commit()
    }
    return panel
  }()
  private var state: SwitcherState?
  private var showTask: Task<Void, Never>?
  private var thumbnailTask: Task<Void, Never>?
  /// Al abrirse el selector (la vista del Dock se cierra).
  var onOpen: (() -> Void)?

  init(settings: AppSettings) {
    self.settings = settings
  }

  private var isOpen: Bool { state != nil }

  /// Lo llama Sintecla cuando ya escucha el teclado: desde ahí, el ⌘Tab de macOS sigue al interruptor del módulo.
  func start() {
    NativeAppSwitcher.setEnabled(!settings.moduleAltTab)
    withObservationTracking { _ = settings.moduleAltTab } onChange: { [weak self] in
      Task { @MainActor in self?.start() }
    }
  }

  /// Lo llama el `EventTap` con cada pulsación que no usan el dictado, Finder ni Capturas. `true`: Sintecla se la queda.
  func keyDown(keyCode: Int64, modifiers: Set<ComboModifier>) -> Bool {
    guard settings.moduleAltTab, let key = AltTabShortcut.key(keyCode: keyCode, modifiers: modifiers, isOpen: isOpen)
    else { return false }
    switch key {
    case .open(let backward): open(backward: backward)
    case .next: move { $0.next() }
    case .previous: move { $0.previous() }
    case .cancel: close()
    }
    return true
  }

  /// Cada cambio de las teclas modificadoras: al soltar ⌘ se salta a la ventana marcada.
  func modifiersChanged(_ modifiers: Set<ComboModifier>) {
    guard isOpen, !modifiers.contains(.command) else { return }
    commit()
  }

  /// Sin ventanas que enseñar no se abre (y ⌘Tab no hace nada).
  private func open(backward: Bool) {
    catalog.refresh()
    let windows = catalog.windows
    guard !windows.isEmpty else { return }
    onOpen?()
    state = SwitcherState(count: windows.count, backward: backward)
    panel.layout(count: windows.count)
    panel.model.windows = windows
    panel.model.selected = state?.selected
    panel.model.thumbnails = [:]
    showTask = Task { [weak self] in
      try? await Task.sleep(for: Self.panelDelay)
      guard !Task.isCancelled, let self, self.isOpen else { return }
      self.panel.show()
    }
    thumbnailTask = WindowThumbnails.capture(windows.filter { !$0.isMinimized }.map(\.id),
                                             maxSide: panel.model.cardWidth) { [weak self] id, image in
      self?.panel.model.thumbnails[id] = image
    }
  }

  private func move(_ change: (inout SwitcherState) -> Void) {
    guard var state else { return }
    change(&state)
    self.state = state
    panel.model.selected = state.selected
  }

  private func mark(_ index: Int) {
    move { $0.mark(index) }
  }

  private func commit() {
    let target = state?.selected.map { catalog.windows[$0] }
    close()
    if let target { catalog.focus(target) }
  }

  private func close() {
    state = nil
    showTask?.cancel()
    thumbnailTask?.cancel()
    panel.hide()
  }
}

/// El ⌘Tab de macOS (sus atajos simbólicos 1 y 2: ⌘Tab y ⇧⌘Tab). Mientras Alt-Tab está encendido se apaga: aunque
/// Sintecla se quede la pulsación, macOS cambiaría de app igualmente. Es la misma llamada privada que usa AltTab.
/// Sintecla lo vuelve a encender al apagar el módulo y al salir.
enum NativeAppSwitcher {
  private typealias SetSymbolicHotKeyEnabled = @convention(c) (Int32, Bool) -> Int32
  private static let setSymbolicHotKeyEnabled: SetSymbolicHotKeyEnabled? = {
    dlsym(dlopen(nil, RTLD_NOW), "CGSSetSymbolicHotKeyEnabled").map { unsafeBitCast($0, to: SetSymbolicHotKeyEnabled.self) }
  }()

  static func setEnabled(_ enabled: Bool) {
    _ = setSymbolicHotKeyEnabled?(1, enabled)
    _ = setSymbolicHotKeyEnabled?(2, enabled)
  }
}
