/// Lo que hace cada atajo del módulo Capturas (spec «Capturas» §2.2).
public enum CaptureAction: String, CaseIterable, Sendable {
  case screen, area, text, textCard

  /// La tecla que acompaña a ⇧⌘.
  public var key: String {
    switch self {
    case .screen: "3"
    case .area: "4"
    case .text: "2"
    case .textCard: "1"
    }
  }

  public var shortcut: String { "⇧⌘" + key }

  public var title: String {
    switch self {
    case .screen: "Capturar pantalla"
    case .area: "Capturar zona o ventana"
    case .text: "Copiar texto"
    case .textCard: "Texto con traducir y preguntar"
    }
  }
}

public enum CaptureShortcut {
  /// ⇧⌘1 a ⇧⌘4 (códigos de tecla 18 a 21), con ⇧⌘ y ninguna otra modificadora; nil con cualquier otra pulsación.
  public static func action(keyCode: Int64, modifiers: Set<ComboModifier>) -> CaptureAction? {
    guard modifiers == [.shift, .command] else { return nil }
    switch keyCode {
    case 18: return .textCard
    case 19: return .text
    case 20: return .screen
    case 21: return .area
    default: return nil
    }
  }

  /// Resumen para la tarjeta de Inicio.
  public static let summary = "⇧⌘4 zona · ⇧⌘2 texto"
}
