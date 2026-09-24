import AppKit
import ApplicationServices
import SinteclaCore

/// Lee el texto seleccionado en la app activa (Ask Anything).
@MainActor
enum ContextReader {
  static let editableRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

  /// Primero por Accesibilidad; si no hay nada (apps Electron, algunas webs), copiando con ⌘C
  /// y dejando el portapapeles como estaba. nil si no hay selección.
  static func selection() async -> Selection? {
    let focused = focusedElement()
    if let focused, let text = string(of: focused, kAXSelectedTextAttribute) {
      if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return Selection(text: text, editable: isEditable(focused))
      }
      // En un cuadro de texto, "vacía" es fiable: sin ⌘C, que sin selección suena a error.
      if let role = string(of: focused, kAXRoleAttribute), editableRoles.contains(role) { return nil }
    }
    guard let copied = await copySelection() else { return nil }
    // Si no se puede saber si es editable, se asume que sí.
    return Selection(text: copied, editable: focused.map(isEditable) ?? true)
  }

  static func focusedElement() -> AXUIElement? {
    var value: CFTypeRef?
    let system = AXUIElementCreateSystemWide()
    // Una app colgada haría esperar 6 s por defecto.
    AXUIElementSetMessagingTimeout(system, 0.5)
    guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
          let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    let element = value as! AXUIElement
    AXUIElementSetMessagingTimeout(element, 0.5)
    return element
  }

  static func isEditable(_ element: AXUIElement) -> Bool {
    if let role = string(of: element, kAXRoleAttribute), editableRoles.contains(role) { return true }
    var settable: DarwinBoolean = false
    guard AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success else { return true }
    return settable.boolValue
  }

  static func string(of element: AXUIElement, _ attribute: String) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value as? String
  }

  /// ⌘C y espera hasta 250 ms a que cambie el portapapeles; luego lo restaura.
  static func copySelection() async -> String? {
    let pasteboard = NSPasteboard.general
    let saved = Paster.snapshot(pasteboard)
    let before = pasteboard.changeCount
    Paster.postCommand(key: 8)  // 8 = C
    for _ in 0..<10 where pasteboard.changeCount == before {
      try? await Task.sleep(for: .milliseconds(25))
    }
    guard pasteboard.changeCount != before else { return nil }
    let text = pasteboard.string(forType: .string)
    Paster.restore(saved, to: pasteboard)
    guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return text
  }
}
