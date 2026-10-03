import AppKit
import ApplicationServices
import SinteclaCore

/// Escucha el Dock por Accesibilidad (spec «Vistas del Dock» §6). El Dock marca como elegido el icono que tiene el ratón
/// y avisa cada vez que cambia (y también, repetido, mientras la lupa lo mueve). Si el Dock se reinicia, se vuelve a
/// apuntar.
@MainActor
final class DockWatcher {
  nonisolated static let dockBundleID = "com.apple.dock"

  /// El icono que tiene el ratón (su elemento, para leer su sitio) y, si es una app, cuál.
  var onHover: ((AXUIElement, DockItem?) -> Void)?
  private var observer: AXObserver?
  private var launchObserver: NSObjectProtocol?

  func start() {
    guard launchObserver == nil else { return }
    launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
    ) { [weak self] notification in
      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      guard app?.bundleIdentifier == Self.dockBundleID else { return }
      MainActor.assumeIsolated { self?.attachSoon() }
    }
    attach()
  }

  func stop() {
    if let launchObserver { NSWorkspace.shared.notificationCenter.removeObserver(launchObserver) }
    launchObserver = nil
    detach()
  }

  /// El sitio del icono en la pantalla, en coordenadas de AppKit. Se lee cada vez: la lupa lo cambia.
  func frame(of element: AXUIElement) -> CGRect? {
    var point = CGPoint.zero
    var size = CGSize.zero
    guard let position: AXValue = Self.value(element, kAXPositionAttribute),
          let extent: AXValue = Self.value(element, kAXSizeAttribute),
          AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(extent, .cgSize, &size),
          let primary = NSScreen.screens.first else { return nil }
    return DockPreviewPlacement.screenRect(fromAccessibility: CGRect(origin: point, size: size),
                                           primaryHeight: primary.frame.height)
  }

  /// El Dock recién abierto tarda un poco en tener su lista de iconos.
  private func attachSoon() {
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      self?.attach()
    }
  }

  private func attach() {
    detach()
    guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: Self.dockBundleID).first else { return }
    let app = AXUIElementCreateApplication(dock.processIdentifier)
    AXUIElementSetMessagingTimeout(app, WindowCatalog.accessibilityTimeout)
    let children: [AXUIElement] = Self.value(app, kAXChildrenAttribute) ?? []
    guard let list = children.first(where: { Self.value($0, kAXRoleAttribute) == kAXListRole as String }) else { return }
    let callback: AXObserverCallback = { _, element, _, refcon in
      guard let refcon else { return }
      let watcher = Unmanaged<DockWatcher>.fromOpaque(refcon).takeUnretainedValue()
      MainActor.assumeIsolated { watcher.selectionChanged(in: element) }
    }
    var observer: AXObserver?
    guard AXObserverCreate(dock.processIdentifier, callback, &observer) == .success, let observer else { return }
    // Sin retener: el vigilante vive lo que Sintecla.
    AXObserverAddNotification(observer, list, kAXSelectedChildrenChangedNotification as CFString,
                              Unmanaged.passUnretained(self).toOpaque())
    CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    self.observer = observer
  }

  private func detach() {
    if let observer {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
    observer = nil
  }

  private func selectionChanged(in list: AXUIElement) {
    let selected: [AXUIElement] = Self.value(list, kAXSelectedChildrenAttribute) ?? []
    guard let icon = selected.first else { return }
    onHover?(icon, DockItem(subrole: Self.value(icon, kAXSubroleAttribute), url: Self.value(icon, kAXURLAttribute)))
  }

  private static func value<T>(_ element: AXUIElement, _ attribute: String) -> T? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value as? T
  }
}
