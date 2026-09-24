import Foundation

/// Sigue qué tecla base está abajo a partir de los cambios de modificadores (lógica pura, sin CGEvent).
/// Con `.both` manda la primera que se pulsa; mientras sigue abajo, la otra no hace de base
/// (la ⌥ derecha vuelve a ser el modificador ⌥).
public struct BaseKeyTracker: Sendable {
  public let baseKey: BaseKey
  /// Tecla física que hace ahora de base (`.fn` o `.rightOption`), o nil si no hay ninguna abajo.
  public private(set) var active: BaseKey?

  public init(baseKey: BaseKey = .fn) {
    self.baseKey = baseKey
  }

  /// `keyCode`: la tecla que ha cambiado (63 = 🌐/Fn, 61 = ⌥ derecha); los estados son los de ahora.
  /// Devuelve `true` si la base acaba de bajar, `false` si acaba de subir y nil si no cambia.
  public mutating func update(keyCode: Int64, fnDown: Bool, rightOptionDown: Bool) -> Bool? {
    let isDown: (BaseKey) -> Bool = { $0 == .fn ? fnDown : rightOptionDown }
    if let active {
      guard keyCode == Self.keyCode(of: active), !isDown(active) else { return nil }
      self.active = nil
      return false
    }
    let candidates: [BaseKey] = baseKey == .both ? [.fn, .rightOption] : [baseKey]
    guard let pressed = candidates.first(where: { keyCode == Self.keyCode(of: $0) && isDown($0) }) else { return nil }
    active = pressed
    return true
  }

  /// La ⌥ cuenta como modificador salvo cuando la base es la ⌥ derecha.
  public var optionIsModifier: Bool {
    baseKey == .rightOption ? false : active != .rightOption
  }

  private static func keyCode(of key: BaseKey) -> Int64 { key == .fn ? 63 : 61 }
}
