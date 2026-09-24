import Foundation

/// Tecla que acompaña a la tecla base en un modo.
public enum HotkeyCompanion: String, Codable, CaseIterable, Sendable {
  case shift, control, option, command, space

  public var symbol: String {
    switch self {
    case .shift: "⇧"
    case .control: "⌃"
    case .option: "⌥"
    case .command: "⌘"
    case .space: "Espacio"
    }
  }

  /// Nombre en el selector de Ajustes.
  public var name: String {
    switch self {
    case .shift: "⇧ Mayúsculas"
    case .control: "⌃ Control"
    case .option: "⌥ Opción"
    case .command: "⌘ Comando"
    case .space: "Espacio"
    }
  }

  var modifier: ComboModifier? {
    switch self {
    case .shift: .shift
    case .control: .control
    case .option: .option
    case .command: .command
    case .space: nil
    }
  }
}

extension HotkeyMode {
  public var name: String {
    switch self {
    case .dictation: "Dictar"
    case .translation: "Traducir"
    case .ask: "Ask Anything"
    case .notes: "Notas"
    case .meeting: "Reunión"
    }
  }
}

/// Qué tecla acompaña a la base en cada modo (Ajustes → General). Dictar es la base sola y Cancelar, Esc.
public struct HotkeyLayout: Equatable, Sendable {
  public static let configurableModes: [HotkeyMode] = [.translation, .ask, .notes, .meeting]
  /// Los atajos de siempre.
  public static let defaults = HotkeyLayout(companions: [.translation: .shift, .ask: .space, .notes: .control, .meeting: .option])!
  /// Orden en que se miran los modificadores si hay varios pulsados (Espacio va antes que todos).
  static let modifierOrder: [HotkeyCompanion] = [.shift, .control, .option, .command]

  public private(set) var companions: [HotkeyMode: HotkeyCompanion]

  /// nil si no asigna los 4 modos configurables a teclas distintas.
  public init?(companions: [HotkeyMode: HotkeyCompanion]) {
    guard Set(companions.keys) == Set(Self.configurableModes), Set(companions.values).count == companions.count else { return nil }
    self.companions = companions
  }

  public func companion(for mode: HotkeyMode) -> HotkeyCompanion? {
    companions[mode]
  }

  public func mode(for companion: HotkeyCompanion) -> HotkeyMode? {
    companions.first { $0.value == companion }?.key
  }

  /// Pone `companion` en `mode`; si otro modo la tenía, ese se queda con la que tenía `mode`.
  public mutating func assign(_ companion: HotkeyCompanion, to mode: HotkeyMode) {
    guard let previous = companions[mode], previous != companion else { return }
    if let other = self.mode(for: companion) { companions[other] = previous }
    companions[mode] = companion
  }

  public var usesSpace: Bool { mode(for: .space) != nil }

  /// Con ⌥ derecha o las dos, ⌥ no puede acompañar a la ⌥ derecha: si ⌘ está libre, hace de ⌥.
  func commandStandsInForOption(_ baseKey: BaseKey) -> Bool {
    baseKey != .fn && mode(for: .command) == nil
  }

  /// Modo según lo pulsado con la base: Espacio y luego ⇧, ⌃, ⌥, ⌘. Dictado si nada coincide.
  public func mode(modifiers: Set<ComboModifier>, sawSpace: Bool, baseKey: BaseKey) -> HotkeyMode {
    if sawSpace, let mode = mode(for: .space) { return mode }
    // Con base ⌥ derecha, ⌥ es la propia base y nunca acompaña.
    let held = baseKey == .rightOption ? modifiers.subtracting([.option]) : modifiers
    for companion in Self.modifierOrder {
      guard let modifier = companion.modifier, held.contains(modifier) else { continue }
      if let mode = mode(for: companion) { return mode }
      if companion == .command, commandStandsInForOption(baseKey), let mode = mode(for: .option) { return mode }
    }
    return .dictation
  }

  /// Texto del atajo con esa tecla base (p. ej. «🌐 + ⌥ o ⌥ der + ⌘»); nil si con ella no tiene.
  public func shortcut(for mode: HotkeyMode, baseKey: BaseKey) -> String? {
    guard let companion = companions[mode] else {
      return switch baseKey {
      case .fn: "🌐"
      case .rightOption: "⌥ der"
      case .both: "🌐 o ⌥ der"
      }
    }
    let key = companion.symbol
    guard companion == .option else {
      return switch baseKey {
      case .fn: "🌐 + \(key)"
      case .rightOption: "⌥ der + \(key)"
      case .both: "🌐 o ⌥ der + \(key)"
      }
    }
    let command = commandStandsInForOption(baseKey)
    return switch baseKey {
    case .fn: "🌐 + ⌥"
    case .rightOption: command ? "⌥ der + ⌘" : nil
    case .both: command ? "🌐 + ⌥ o ⌥ der + ⌘" : "🌐 + ⌥"
    }
  }

  /// Aviso para Ajustes si con esa base el modo se queda sin atajo (o solo con 🌐).
  public func warning(for mode: HotkeyMode, baseKey: BaseKey) -> String? {
    guard companions[mode] == .option, baseKey != .fn, !commandStandsInForOption(baseKey) else { return nil }
    let fix = "⌥ es la propia tecla base. Ponle otra tecla o deja ⌘ libre."
    return baseKey == .rightOption
      ? "Con ⌥ derecha, \(mode.name) no tiene atajo: \(fix)"
      : "\(mode.name) solo funciona con 🌐: con ⌥ derecha, \(fix)"
  }

  /// Lo guardado en las preferencias; si falta o no vale, los atajos de siempre.
  public static func decoded(_ data: Data?) -> HotkeyLayout {
    data.flatMap { try? JSONDecoder().decode(HotkeyLayout.self, from: $0) } ?? .defaults
  }
}

/// Se guarda como `{"translation":"shift","ask":"space","notes":"control","meeting":"option"}`.
extension HotkeyLayout: Codable {
  public init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode([String: String].self)
    var companions: [HotkeyMode: HotkeyCompanion] = [:]
    for (mode, companion) in raw {
      guard let mode = HotkeyMode(rawValue: mode), let companion = HotkeyCompanion(rawValue: companion) else {
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Atajo desconocido: \(mode) → \(companion)"))
      }
      companions[mode] = companion
    }
    guard let layout = HotkeyLayout(companions: companions) else {
      throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Atajos incompletos o repetidos"))
    }
    self = layout
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(Dictionary(uniqueKeysWithValues: companions.map { ($0.key.rawValue, $0.value.rawValue) }))
  }
}
