import AppKit
import ApplicationServices
import SinteclaCore

/// Dominio de la pestaña de Safari (tono por web), por Accesibilidad: sin permisos nuevos. Solo se queda el dominio,
/// nunca la dirección completa, y no se guarda en ningún sitio.
enum SafariSite {
  /// La lectura se abandona pasado este tiempo (cada llamada de Accesibilidad tiene además su tope de 0,5 s).
  static let maxDuration: TimeInterval = 0.5
  /// Niveles que se sube desde el foco buscando la página.
  static let maxClimb = 40
  /// Búsqueda en la ventana cuando el foco no está en la página.
  static let maxDepth = 10
  static let maxElements = 500

  /// Empieza a leer el dominio en segundo plano si `app` es Safari; nil si no lo es.
  static func read(_ app: NSRunningApplication?) -> Task<String?, Never>? {
    guard let app, let id = app.bundleIdentifier, SiteRules.browsers.contains(id) else { return nil }
    let pid = app.processIdentifier
    return Task.detached { host(pid: pid) }
  }

  /// Dominio de la pestaña de delante de Safari aunque no sea la app activa (Ajustes → Tonos).
  @MainActor
  static func frontTab() async -> String? {
    let safari = NSWorkspace.shared.runningApplications.first { SiteRules.browsers.contains($0.bundleIdentifier ?? "") }
    return await read(safari)?.value
  }

  /// Sube desde el elemento con el foco hasta la página (`AXWebArea`) más externa; si el foco no está en la página
  /// (p. ej., en la barra de direcciones), la busca en la ventana de delante.
  static func host(pid: pid_t) -> String? {
    let reader = Reader(deadline: Date().addingTimeInterval(maxDuration))
    // Con el objeto de todo el sistema, el tope de 0,5 s por llamada vale para todos los elementos.
    AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.5)
    let app = AXUIElementCreateApplication(pid)
    if let focused = reader.element(app, kAXFocusedUIElementAttribute),
       let page = reader.outermostWebArea(from: focused), let host = reader.host(of: page) {
      return host
    }
    guard let window = reader.element(app, kAXFocusedWindowAttribute) ?? reader.element(app, kAXMainWindowAttribute),
          let page = reader.firstWebArea(in: window) else { return nil }
    return reader.host(of: page)
  }

  /// Llamadas de Accesibilidad con fecha límite: pasada, todas devuelven nil.
  private struct Reader {
    let deadline: Date

    func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
      guard Date() < deadline else { return nil }
      var value: CFTypeRef?
      guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
      return value
    }

    func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
      guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
      return (value as! AXUIElement)
    }

    func role(_ element: AXUIElement) -> String? {
      attribute(element, kAXRoleAttribute) as? String
    }

    func outermostWebArea(from start: AXUIElement) -> AXUIElement? {
      var current: AXUIElement? = start
      var outermost: AXUIElement?
      for _ in 0..<SafariSite.maxClimb {
        guard let element = current, let kind = role(element),
              kind != kAXWindowRole, kind != kAXApplicationRole else { break }
        if kind == "AXWebArea" { outermost = element }
        current = self.element(element, kAXParentAttribute)
      }
      return outermost
    }

    /// Recorrido en anchura: la primera página es la de la pestaña visible.
    func firstWebArea(in window: AXUIElement) -> AXUIElement? {
      var level = [window]
      var visited = 0
      for _ in 0..<SafariSite.maxDepth where !level.isEmpty {
        var next: [AXUIElement] = []
        for element in level {
          if role(element) == "AXWebArea" { return element }
          visited += 1
          guard visited < SafariSite.maxElements, Date() < deadline else { return nil }
          next += (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
        }
        level = next
      }
      return nil
    }

    /// Solo páginas `http`/`https`, y solo el dominio.
    func host(of page: AXUIElement) -> String? {
      guard let value = attribute(page, kAXURLAttribute) else { return nil }
      let url = CFGetTypeID(value) == CFURLGetTypeID() ? (value as! URL) : (value as? String).flatMap(URL.init(string:))
      guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""), let host = url.host() else { return nil }
      return SiteRules.normalize(host)
    }
  }
}
