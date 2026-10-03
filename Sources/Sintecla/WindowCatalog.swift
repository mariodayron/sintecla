import AppKit
import ApplicationServices
import ScreenCaptureKit
import SinteclaCore

/// Las ventanas del selector (spec «Alt-Tab» §4 y §6): la lista de macOS, las minimizadas por Accesibilidad y cómo
/// poner una delante.
@MainActor
final class WindowCatalog {
  /// Tiempo máximo de cada llamada de Accesibilidad: una app colgada no bloquea el selector.
  static let accessibilityTimeout: Float = 0.1

  private(set) var windows: [SwitcherWindow] = []
  /// El elemento de Accesibilidad de las minimizadas (las visibles se buscan al saltar, por su sitio).
  private var elements: [Int: AXUIElement] = [:]
  private var frames: [Int: CGRect] = [:]

  /// Lee las ventanas en este momento.
  func refresh() {
    elements = [:]
    frames = [:]
    let own = ProcessInfo.processInfo.processIdentifier
    let regular = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
    let regularPIDs = Set(regular.map(\.processIdentifier))
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
      as? [[String: Any]] ?? []
    var visible: [SwitcherWindow] = []
    var agentPIDs: Set<Int32> = []
    for entry in info {
      guard let number = entry[kCGWindowNumber as String] as? Int, let pid = entry[kCGWindowOwnerPID as String] as? Int32,
            (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0 else { continue }
      if !regularPIDs.contains(pid) { agentPIDs.insert(pid) }
      let frame = (entry[kCGWindowBounds as String] as? NSDictionary)
        .flatMap { CGRect(dictionaryRepresentation: $0 as CFDictionary) } ?? .zero
      frames[number] = frame
      visible.append(SwitcherWindow(id: number, pid: pid, appName: entry[kCGWindowOwnerName as String] as? String ?? "",
                                    title: entry[kCGWindowName as String] as? String ?? "", isMinimized: false,
                                    layer: entry[kCGWindowLayer as String] as? Int ?? 0, size: frame.size))
    }
    var minimized: [SwitcherWindow] = []
    for app in regular where app.processIdentifier != own {
      for element in Self.windows(of: app.processIdentifier) where Self.value(element, kAXMinimizedAttribute) == true {
        let id = -(minimized.count + 1)
        elements[id] = element
        minimized.append(SwitcherWindow(id: id, pid: app.processIdentifier, appName: app.localizedName ?? "",
                                        title: Self.value(element, kAXTitleAttribute) ?? "", isMinimized: true, layer: 0,
                                        size: Self.size(of: element) ?? .zero))
      }
    }
    windows = WindowSwitcherOrder.arrange(visible: visible, minimized: minimized, ownPID: own, agentPIDs: agentPIDs)
  }

  /// La pone delante: si estaba minimizada, la restaura; luego activa su app y la sube por encima de las demás.
  /// `activate()` a veces no basta desde Sintecla (activación cooperativa de macOS): por eso también se pide con
  /// Accesibilidad, que sí lo consigue.
  func focus(_ window: SwitcherWindow) {
    let element = elements[window.id] ?? visibleElement(for: window)
    if window.isMinimized, let element {
      AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
    }
    NSRunningApplication(processIdentifier: window.pid)?.activate()
    let app = AXUIElementCreateApplication(window.pid)
    AXUIElementSetMessagingTimeout(app, Self.accessibilityTimeout)
    AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    if let element {
      AXUIElementPerformAction(element, kAXRaiseAction as CFString)
      AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
    }
  }

  /// La ventana de Accesibilidad que ocupa el mismo sitio (Accesibilidad no da el número de ventana de macOS); si no,
  /// la del mismo título.
  private func visibleElement(for window: SwitcherWindow) -> AXUIElement? {
    let candidates = Self.windows(of: window.pid)
    if let frame = frames[window.id], let match = candidates.first(where: {
      Self.position(of: $0) == frame.origin && Self.size(of: $0) == frame.size
    }) {
      return match
    }
    return candidates.first { Self.value($0, kAXTitleAttribute) == window.title }
  }

  private static func windows(of pid: pid_t) -> [AXUIElement] {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, accessibilityTimeout)
    return value(app, kAXWindowsAttribute) ?? []
  }

  private static func value<T>(_ element: AXUIElement, _ attribute: String) -> T? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value as? T
  }

  private static func position(of element: AXUIElement) -> CGPoint? {
    guard let value: AXValue = value(element, kAXPositionAttribute) else { return nil }
    var point = CGPoint.zero
    return AXValueGetValue(value, .cgPoint, &point) ? point : nil
  }

  private static func size(of element: AXUIElement) -> CGSize? {
    guard let value: AXValue = value(element, kAXSizeAttribute) else { return nil }
    var size = CGSize.zero
    return AXValueGetValue(value, .cgSize, &size) ? size : nil
  }
}

/// Miniaturas de las ventanas con ScreenCaptureKit (spec «Alt-Tab» §5), en segundo plano y una a una. Sin el permiso
/// de Grabación de pantalla no hace nada: el selector se queda con los iconos.
enum WindowThumbnails {
  /// `maxSide`: el lado mayor de la miniatura, en píxeles.
  static func capture(_ ids: [Int], maxSide: CGFloat, each: @escaping @MainActor (Int, CGImage) -> Void) -> Task<Void, Never>? {
    guard CGPreflightScreenCaptureAccess(), !ids.isEmpty else { return nil }
    return Task.detached(priority: .userInitiated) {
      guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true) else {
        return
      }
      for id in ids {
        guard !Task.isCancelled else { return }
        guard let window = content.windows.first(where: { Int($0.windowID) == id }) else { continue }
        let configuration = SCStreamConfiguration()
        let scale = min(1, maxSide / max(window.frame.width, window.frame.height, 1)) * 2
        configuration.width = max(1, Int(window.frame.width * scale))
        configuration.height = max(1, Int(window.frame.height * scale))
        configuration.showsCursor = false
        let filter = SCContentFilter(desktopIndependentWindow: window)
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        else { continue }
        await each(id, image)
      }
    }
  }
}
