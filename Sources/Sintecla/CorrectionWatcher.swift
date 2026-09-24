import AppKit
import ApplicationServices
import SinteclaCore

/// Tras pegar, relee cada 2 s el campo donde se pegó para ver si el usuario corrige alguna palabra. Termina al cambiar
/// el foco, si el campo ya no contiene lo pegado (se envió el mensaje), al empezar otra grabación o a los 90 s, y
/// entrega la última lectura que aún lo contenía. Lo leído solo vive en memoria.
@MainActor
final class CorrectionWatcher {
  static let interval: Duration = .seconds(2)
  static let maxDuration: TimeInterval = 90
  /// Campos más largos (documentos) no se vigilan.
  nonisolated static let maxLength = 50_000

  /// Lo pegado y la última lectura del campo que aún lo contenía.
  var onFinish: ((_ pasted: String, _ field: String) -> Void)?
  private var task: Task<Void, Never>?
  private var pasted = ""
  private var lastGood: String?

  /// AXUIElement no es Sendable; solo se usa para leer.
  private struct Field: @unchecked Sendable {
    let element: AXUIElement
  }

  private enum Reading: Sendable {
    case keep(String)
    case stop
  }

  /// Empieza a vigilar el campo con el foco (termina antes la vigilancia anterior).
  func watch(pasted text: String) {
    finish()
    guard let element = Self.focusedElement(), !Self.isSecure(element) else { return }
    pasted = text
    let field = Field(element: element)
    let start = Date()
    task = Task { [weak self] in
      while Date().timeIntervalSince(start) < Self.maxDuration {
        try? await Task.sleep(for: Self.interval)
        if Task.isCancelled { return }
        let reading = await Task.detached { Self.read(field, pasted: text) }.value
        if Task.isCancelled { return }
        guard case .keep(let value) = reading else { break }
        self?.lastGood = value
      }
      if Task.isCancelled { return }
      self?.finish()
    }
  }

  /// Termina la vigilancia y entrega la última lectura buena, si la hubo.
  func finish() {
    task?.cancel()
    task = nil
    guard let field = lastGood else { return }
    lastGood = nil
    onFinish?(pasted, field)
  }

  /// Sigue con el foco, se puede leer, no es un documento largo y aún contiene lo pegado.
  nonisolated private static func read(_ field: Field, pasted: String) -> Reading {
    guard let focused = focusedElement(), CFEqual(focused, field.element),
          let value = string(of: field.element, kAXValueAttribute), value.count <= maxLength,
          CorrectionLearner.contains(pasted, in: value) else { return .stop }
    return .keep(value)
  }

  nonisolated private static func focusedElement() -> AXUIElement? {
    let system = AXUIElementCreateSystemWide()
    AXUIElementSetMessagingTimeout(system, 0.5)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
          let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    let element = value as! AXUIElement
    AXUIElementSetMessagingTimeout(element, 0.5)
    return element
  }

  nonisolated private static func isSecure(_ element: AXUIElement) -> Bool {
    [kAXRoleAttribute, kAXSubroleAttribute].contains { string(of: element, $0) == (kAXSecureTextFieldSubrole as String) }
  }

  nonisolated private static func string(of element: AXUIElement, _ attribute: String) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value as? String
  }
}
