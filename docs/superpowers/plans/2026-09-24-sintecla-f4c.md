# Sintecla — F4c: Editor de atajos — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que en Ajustes → General se pueda elegir la tecla que acompaña a la tecla base en Traducir, Ask Anything, Notas y Reunión (⇧, ⌃, ⌥, ⌘ o Espacio), sin repetir.

**Architecture:** El núcleo `SinteclaCore` gana `HotkeyLayout`, una tabla modo → tecla acompañante (`HotkeyCompanion`) pura y con tests. La tabla sabe:
- intercambiar las teclas cuando se repite una;
- decidir el modo a partir de lo pulsado, con la regla de ⌥/⌘ para ⌥ derecha;
- dar el texto de cada atajo y su aviso;
- guardarse en JSON.

`HotkeyStateMachine` usa la tabla en vez de sus teclas fijas; si Espacio queda libre, base + Espacio cancela como cualquier otra tecla. La app guarda la tabla en las preferencias y la pestaña General enseña un selector por modo.

**Tech Stack:** Lo de siempre (Swift 6.3 de las Command Line Tools en modo de lenguaje 5, SwiftPM, AppKit, SwiftUI, Swift Testing, `UserDefaults`).

**Especificación:** `docs/superpowers/specs/2026-09-24-editor-de-atajos-design.md` (y la fila F4c de §12 de la spec principal).

**Punto de partida:** la rama `fase-4c`, que sale de `main` (`v0.5.1`) con la especificación de la F4c:

```bash
git checkout fase-4c
```

## Global Constraints

- Todo lo de la F1–F4b y el icono sigue vigente:
  - macOS 26.0 o superior, Apple Silicon.
  - Sin Xcode ni dependencias externas; todos los targets en `.swiftLanguageMode(.v5)`.
  - Tests con `swift run sintecla-tests` (**nunca `swift test`**).
  - Bundle id `local.sintecla.app`; textos visibles en español.
- **Modos configurables:** Traducir, Ask Anything, Notas y Reunión.
- **Teclas acompañantes:** ⇧, ⌃, ⌥, ⌘ y Espacio, sin repetir; si se repite una, se intercambian.
- **Valores por defecto:** Traducir ⇧, Ask Espacio, Notas ⌃, Reunión ⌥. Dictar (la base sola) y Cancelar (Esc) no cambian.
- **Orden al decidir:** Espacio, ⇧, ⌃, ⌥, ⌘; si nada coincide, Dictado.
- **Regla de ⌥:** con base ⌥ derecha, ⌥ nunca acompaña. Con base ⌥ derecha o «las dos», el modo de ⌥ también se activa con ⌘ si ⌘ está libre.
- **Datos:** `UserDefaults`, clave `hotkeys`, JSON `{"translation":"shift","ask":"space","notes":"control","meeting":"option"}`. Si falta o no vale, se usan los valores por defecto.
- Versión **0.6.0** (build 7).
- Commits: en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código de este plan se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `fase-4c`: compiló y pasó los tests en cada tarea, y el árbol final quedó idéntico al del prototipo.

- **185 tests** (37 suites) en verde: los 173 del icono y 12 nuevos. La release compila sin avisos.
- Con los valores por defecto, el modo sale igual que antes con las tres bases (test parametrizado), y los tests de la máquina de estados siguen en verde.

**Lo que no se pudo probar aquí** (queda para la aceptación, Tarea 4):
- **Las teclas de verdad.** La shell no tiene permiso de Accesibilidad para el `EventTap`, y no se toca.
- **El aspecto de la sección de atajos.**

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| `[HotkeyMode: HotkeyCompanion]` se codifica en JSON como lista, no como objeto | `Codable` propio a través de `[String: String]` (Tarea 1) |
| Con base ⌥ derecha, un test de siempre espera Dictado con `[.option]` | `mode(...)` quita ⌥ de lo pulsado si la base es ⌥ derecha (Tarea 1) |
| Con «las dos», la máquina no sabe si se pulsó 🌐 o ⌥ derecha | La regla de ⌥/⌘ no lo necesita: ⌘ libre vale por ⌥ con las dos bases (Tarea 1) |
| Si Espacio queda libre, base + Espacio no debe tragarse el espacio | `.space where layout.usesSpace`; si no, se trata como otra tecla (Tarea 2) |
| Asignar una tecla libre no debe quitársela a nadie | `assign` solo intercambia si otro modo la tenía (Tarea 1) |
| Tras mover la carpeta del proyecto, `swift build` falla con `missing required module 'SwiftShims'` | Caché de módulos con rutas viejas: `rm -rf .build` |

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/HotkeyLayout.swift` | `HotkeyCompanion`, `HotkeyMode.name`, `HotkeyLayout` | 1 |
| `Sources/SinteclaCoreTests/HotkeyLayoutTests.swift` | Tests de la tabla | 1 |
| `Sources/SinteclaCore/HotkeyStateMachine.swift` | Decidir el modo con la tabla; Espacio libre | 2 |
| `Sources/SinteclaCoreTests/HotkeyStateMachineTests.swift` | Tests de la máquina con la tabla | 2 |
| `Sources/Sintecla/AppSettings.swift` | `hotkeys` en las preferencias | 3 |
| `Sources/Sintecla/DictationController.swift` | Pasar la tabla a la máquina; aviso de la reunión | 3 |
| `Sources/Sintecla/Windows.swift` | Selectores, atajo resultante, avisos y «Restaurar atajos» | 3 |
| `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`, `Sources/SinteclaCoreTests/SmokeTests.swift` | Versión 0.6.0 | 3 |

---

### Task 1: La tabla de atajos

**Files:**
- Create: `Sources/SinteclaCore/HotkeyLayout.swift`
- Test: `Sources/SinteclaCoreTests/HotkeyLayoutTests.swift`

**Interfaces:**
- Consumes: `HotkeyMode`, `BaseKey`, `ComboModifier` (F1, `HotkeyTypes.swift`).
- Produces: `enum HotkeyCompanion: String, Codable, CaseIterable { shift, control, option, command, space; symbol; name }`; `HotkeyMode.name`; `struct HotkeyLayout: Equatable, Codable, Sendable { static configurableModes; static defaults; init?(companions:); companion(for:) -> HotkeyCompanion?; mode(for:) -> HotkeyMode?; mutating assign(_:to:); usesSpace: Bool; mode(modifiers:sawSpace:baseKey:) -> HotkeyMode; shortcut(for:baseKey:) -> String?; warning(for:baseKey:) -> String?; static decoded(_ data: Data?) -> HotkeyLayout }`.

Todo puro. `mode(modifiers:sawSpace:baseKey:)` sustituye a `HotkeyStateMachine.mode` (que se quita en la Tarea 2); con los valores por defecto da lo mismo con las tres bases.

- [ ] **Step 1: Escribir los tests**

Crear `Sources/SinteclaCoreTests/HotkeyLayoutTests.swift`:

```swift
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct HotkeyLayoutTests {
  let layout = HotkeyLayout.defaults

  @Test func theDefaultsAreTheShortcutsOfAlways() {
    #expect(layout.companion(for: .translation) == .shift)
    #expect(layout.companion(for: .ask) == .space)
    #expect(layout.companion(for: .notes) == .control)
    #expect(layout.companion(for: .meeting) == .option)
    #expect(layout.companion(for: .dictation) == nil)
  }

  /// Con los valores por defecto, el modo sale igual que antes de la F4c con las tres bases.
  @Test(arguments: BaseKey.allCases)
  func theDefaultsDecideLikeBefore(_ base: BaseKey) {
    #expect(layout.mode(modifiers: [], sawSpace: false, baseKey: base) == .dictation)
    #expect(layout.mode(modifiers: [.shift], sawSpace: false, baseKey: base) == .translation)
    #expect(layout.mode(modifiers: [], sawSpace: true, baseKey: base) == .ask)
    #expect(layout.mode(modifiers: [.control], sawSpace: false, baseKey: base) == .notes)
    #expect(layout.mode(modifiers: [.option], sawSpace: false, baseKey: base) == (base == .rightOption ? .dictation : .meeting))
    #expect(layout.mode(modifiers: [.command], sawSpace: false, baseKey: base) == (base == .fn ? .dictation : .meeting))
  }

  @Test func spaceFirstThenShiftControlOptionCommand() {
    #expect(layout.mode(modifiers: [.shift, .control], sawSpace: true, baseKey: .fn) == .ask)
    #expect(layout.mode(modifiers: [.shift, .control, .option], sawSpace: false, baseKey: .fn) == .translation)
    #expect(layout.mode(modifiers: [.control, .option], sawSpace: false, baseKey: .fn) == .notes)
  }

  @Test func aTakenKeyIsSwapped() {
    var layout = layout
    layout.assign(.option, to: .notes)
    #expect(layout.companion(for: .notes) == .option)
    #expect(layout.companion(for: .meeting) == .control)
    layout.assign(.space, to: .translation)
    #expect(layout.companion(for: .translation) == .space)
    #expect(layout.companion(for: .ask) == .shift)
    // Una tecla libre no quita nada a nadie.
    layout.assign(.command, to: .notes)
    #expect(layout.companion(for: .notes) == .command)
    #expect(layout.mode(for: .option) == nil)
  }

  @Test func commandStandsInForOptionWithRightOption() {
    var layout = layout
    layout.assign(.option, to: .notes)
    #expect(layout.mode(modifiers: [.command], sawSpace: false, baseKey: .rightOption) == .notes)
    #expect(layout.mode(modifiers: [.command], sawSpace: false, baseKey: .both) == .notes)
    #expect(layout.mode(modifiers: [.command], sawSpace: false, baseKey: .fn) == .dictation)
    // Si ⌘ es de otro modo, ⌘ es de ese modo.
    layout.assign(.command, to: .ask)
    #expect(layout.mode(modifiers: [.command], sawSpace: false, baseKey: .both) == .ask)
    #expect(layout.mode(modifiers: [.option], sawSpace: false, baseKey: .both) == .notes)
  }

  @Test func aFreeKeyDoesNothing() {
    var layout = layout
    layout.assign(.command, to: .ask)
    #expect(!layout.usesSpace)
    #expect(layout.mode(modifiers: [], sawSpace: true, baseKey: .fn) == .dictation)
    #expect(HotkeyLayout.defaults.usesSpace)
  }

  @Test func shortcutsWithEachBaseKey() {
    #expect(layout.shortcut(for: .dictation, baseKey: .fn) == "🌐")
    #expect(layout.shortcut(for: .dictation, baseKey: .rightOption) == "⌥ der")
    #expect(layout.shortcut(for: .dictation, baseKey: .both) == "🌐 o ⌥ der")
    #expect(layout.shortcut(for: .translation, baseKey: .fn) == "🌐 + ⇧")
    #expect(layout.shortcut(for: .ask, baseKey: .rightOption) == "⌥ der + Espacio")
    #expect(layout.shortcut(for: .notes, baseKey: .both) == "🌐 o ⌥ der + ⌃")
    #expect(layout.shortcut(for: .meeting, baseKey: .fn) == "🌐 + ⌥")
    #expect(layout.shortcut(for: .meeting, baseKey: .rightOption) == "⌥ der + ⌘")
    #expect(layout.shortcut(for: .meeting, baseKey: .both) == "🌐 + ⌥ o ⌥ der + ⌘")
  }

  @Test func theOptionModeLosesItsShortcutWhenCommandIsTaken() {
    var layout = layout
    layout.assign(.command, to: .notes)
    #expect(layout.shortcut(for: .meeting, baseKey: .rightOption) == nil)
    #expect(layout.shortcut(for: .meeting, baseKey: .both) == "🌐 + ⌥")
    #expect(layout.warning(for: .meeting, baseKey: .rightOption)
      == "Con ⌥ derecha, Reunión no tiene atajo: ⌥ es la propia tecla base. Ponle otra tecla o deja ⌘ libre.")
    #expect(layout.warning(for: .meeting, baseKey: .both)
      == "Reunión solo funciona con 🌐: con ⌥ derecha, ⌥ es la propia tecla base. Ponle otra tecla o deja ⌘ libre.")
    #expect(layout.warning(for: .meeting, baseKey: .fn) == nil)
    #expect(layout.warning(for: .notes, baseKey: .rightOption) == nil)
    #expect(HotkeyLayout.defaults.warning(for: .meeting, baseKey: .rightOption) == nil)
  }

  @Test func savesAndReadsBack() throws {
    var layout = layout
    layout.assign(.option, to: .notes)
    #expect(HotkeyLayout.decoded(try JSONEncoder().encode(layout)) == layout)
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    #expect(String(decoding: try encoder.encode(HotkeyLayout.defaults), as: UTF8.self)
      == #"{"ask":"space","meeting":"option","notes":"control","translation":"shift"}"#)
  }

  @Test(arguments: [
    nil,
    "no es json",
    #"{"translation":"shift","ask":"space","notes":"control"}"#,
    #"{"translation":"shift","ask":"shift","notes":"control","meeting":"option"}"#,
    #"{"translation":"shift","ask":"space","notes":"control","meeting":"tecla"}"#,
    #"{"translation":"shift","ask":"space","notes":"control","meeting":"option","dictation":"command"}"#,
  ] as [String?])
  func badDataGivesTheDefaults(_ json: String?) {
    #expect(HotkeyLayout.decoded(json.map { Data($0.utf8) }) == .defaults)
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find 'HotkeyLayout' in scope`.

- [ ] **Step 3: La tabla, el intercambio, la decisión, los textos y el JSON**

Crear `Sources/SinteclaCore/HotkeyLayout.swift`:

```swift
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
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 183 tests in 37 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/HotkeyLayout.swift Sources/SinteclaCoreTests/HotkeyLayoutTests.swift
git commit -m 'feat: tabla de atajos por modo con intercambio y regla de ⌥/⌘

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: La máquina de estados usa la tabla

**Files:**
- Modify: `Sources/SinteclaCore/HotkeyStateMachine.swift`
- Test: `Sources/SinteclaCoreTests/HotkeyStateMachineTests.swift`

**Interfaces:**
- Consumes: `HotkeyLayout` (Tarea 1).
- Produces: `HotkeyStateMachine(baseKey: BaseKey = .fn, layout: HotkeyLayout = .defaults)` y `var layout: HotkeyLayout`; desaparece `static func mode(modifiers:sawSpace:baseKey:)`.

- [ ] **Step 1: Los tests usan la tabla y prueban una tabla cambiada y Espacio libre**

En `Sources/SinteclaCoreTests/HotkeyStateMachineTests.swift`, cambiar:

```swift
    #expect(HotkeyStateMachine.mode(modifiers: [.option], sawSpace: false, baseKey: .rightOption) == .dictation)
```

por:

```swift
    #expect(HotkeyLayout.defaults.mode(modifiers: [.option], sawSpace: false, baseKey: .rightOption) == .dictation)
```

Y cambiar:

```swift
    #expect(HotkeyStateMachine.mode(modifiers: [.option], sawSpace: false, baseKey: .both) == .meeting)
    #expect(HotkeyStateMachine.mode(modifiers: [.command], sawSpace: false, baseKey: .both) == .meeting)
    #expect(HotkeyStateMachine.mode(modifiers: [.shift], sawSpace: false, baseKey: .both) == .translation)
    #expect(HotkeyStateMachine.mode(modifiers: [], sawSpace: false, baseKey: .both) == .dictation)
```

por:

```swift
    #expect(HotkeyLayout.defaults.mode(modifiers: [.option], sawSpace: false, baseKey: .both) == .meeting)
    #expect(HotkeyLayout.defaults.mode(modifiers: [.command], sawSpace: false, baseKey: .both) == .meeting)
    #expect(HotkeyLayout.defaults.mode(modifiers: [.shift], sawSpace: false, baseKey: .both) == .translation)
    #expect(HotkeyLayout.defaults.mode(modifiers: [], sawSpace: false, baseKey: .both) == .dictation)
```

Y cambiar:

```swift
  @Test func busyGivesFeedback() {
```

por:

```swift
  @Test func theMachineUsesTheLayout() {
    var layout = HotkeyLayout.defaults
    layout.assign(.option, to: .notes)  // la reunión pasa a ⌃
    var m = HotkeyStateMachine(layout: layout)
    _ = m.handle(.modifiers([.control], at: 0))
    _ = m.handle(.baseDown(at: 0))
    #expect(m.handle(.baseUp(at: 0.1)) == [.cancel, .toggleMeeting])
  }

  /// Si Espacio no es de ningún modo, base + Espacio es otra tecla: cancela y el Espacio llega a la app.
  @Test func aFreeSpaceCancelsAndPassesThrough() {
    var layout = HotkeyLayout.defaults
    layout.assign(.command, to: .ask)
    var armed = HotkeyStateMachine(layout: layout)
    _ = armed.handle(.baseDown(at: 0))
    #expect(armed.handle(.space(at: 0.1)) == [.cancel])
    #expect(armed.state == .idle)
    var holding = HotkeyStateMachine(layout: layout)
    _ = holding.handle(.baseDown(at: 0))
    _ = holding.handle(.tick(at: 0.4))
    #expect(holding.handle(.space(at: 0.5)) == [.cancel])
    #expect(holding.state == .idle)
  }

  @Test func busyGivesFeedback() {
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: extra argument 'layout' in call`.

- [ ] **Step 3: Decidir el modo con la tabla; Espacio libre es otra tecla**

En `Sources/SinteclaCore/HotkeyStateMachine.swift`, cambiar:

```swift
  public private(set) var state: State = .idle
  public var baseKey: BaseKey
  private var modifiers: Set<ComboModifier> = []

  public init(baseKey: BaseKey = .fn) {
    self.baseKey = baseKey
  }

  /// Modo según los modificadores y si se pulsó Space con la base abajo.
  public static func mode(modifiers: Set<ComboModifier>, sawSpace: Bool, baseKey: BaseKey) -> HotkeyMode {
    if sawSpace { return .ask }
    if modifiers.contains(.shift) { return .translation }
    if modifiers.contains(.control) { return .notes }
    let meetingModifiers: Set<ComboModifier> = switch baseKey {
    case .fn: [.option]
    case .rightOption: [.command]
    case .both: [.option, .command]  // 🌐 + ⌥ o ⌥ derecha + ⌘
    }
    if !modifiers.isDisjoint(with: meetingModifiers) { return .meeting }
    return .dictation
  }
```

por:

```swift
  public private(set) var state: State = .idle
  public var baseKey: BaseKey
  /// Qué tecla acompaña a la base en cada modo (Ajustes → General).
  public var layout: HotkeyLayout
  private var modifiers: Set<ComboModifier> = []

  public init(baseKey: BaseKey = .fn, layout: HotkeyLayout = .defaults) {
    self.baseKey = baseKey
    self.layout = layout
  }
```

Y cambiar:

```swift
    switch event {
    case .space:
      state = .armed(since: since, sawSpace: true)
      return [.swallowKey]
    case .escape, .otherKey:
```

por:

```swift
    switch event {
    case .space where layout.usesSpace:
      state = .armed(since: since, sawSpace: true)
      return [.swallowKey]
    case .escape, .otherKey, .space:
```

Y cambiar:

```swift
      let mode = Self.mode(modifiers: modifiers, sawSpace: sawSpace, baseKey: baseKey)
      if mode == .meeting { return [] }  // la reunión actúa al soltar
```

por:

```swift
      let mode = layout.mode(modifiers: modifiers, sawSpace: sawSpace, baseKey: baseKey)
      if mode == .meeting { return [] }  // la reunión actúa al soltar
```

Y cambiar:

```swift
    case .baseUp(let t):
      let mode = Self.mode(modifiers: modifiers, sawSpace: sawSpace, baseKey: baseKey)
```

por:

```swift
    case .baseUp(let t):
      let mode = layout.mode(modifiers: modifiers, sawSpace: sawSpace, baseKey: baseKey)
```

Y cambiar:

```swift
    case (.hold, .space):
      return [.swallowKey]
    case (.hold, .otherKey):
```

por:

```swift
    case (.hold, .space) where layout.usesSpace:
      return [.swallowKey]
    case (.hold, .otherKey), (.hold, .space):
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 185 tests in 37 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/HotkeyStateMachine.swift Sources/SinteclaCoreTests/HotkeyStateMachineTests.swift
git commit -m 'feat: la máquina de atajos decide el modo con la tabla

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: Selectores en Ajustes → General y versión 0.6.0

**Files:**
- Modify: `Sources/Sintecla/AppSettings.swift`
- Modify: `Sources/Sintecla/DictationController.swift` (`applySettings`, aviso de la reunión)
- Modify: `Sources/Sintecla/Windows.swift` (`GeneralTab`)
- Modify: `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`
- Test: `Sources/SinteclaCoreTests/SmokeTests.swift`

**Interfaces:**
- Consumes: `HotkeyLayout` y `HotkeyCompanion` (Tarea 1); `HotkeyStateMachine.layout` (Tarea 2).
- Produces: `AppSettings.hotkeys: HotkeyLayout` (clave `hotkeys`); la sección de atajos editable; versión 0.6.0 (build 7).

La parte de la app no tiene tests automáticos (sin permiso de Accesibilidad no hay teclas): se compila y se prueba a mano en la Tarea 4.

- [ ] **Step 1: Test de la versión nueva**

En `Sources/SinteclaCoreTests/SmokeTests.swift`, cambiar:

```swift
#expect(AppInfo.version == "0.5.1")
```

por:

```swift
#expect(AppInfo.version == "0.6.0")
```

- [ ] **Step 2: Ver que falla**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA el test con `Expectation failed: (AppInfo.version → "0.5.1") == "0.6.0"`.

- [ ] **Step 3: Versión 0.6.0**

En `Sources/SinteclaCore/AppInfo.swift`, cambiar:

```swift
public static let version = "0.5.1"
```

por:

```swift
public static let version = "0.6.0"
```

- [ ] **Step 4: Versión 0.6.0 (build 7) en el Info.plist**

En `Resources/Info.plist`, cambiar:

```xml
<key>CFBundleShortVersionString</key><string>0.5.1</string>
```

por:

```xml
<key>CFBundleShortVersionString</key><string>0.6.0</string>
```

Y cambiar:

```xml
<key>CFBundleVersion</key><string>6</string>
```

por:

```xml
<key>CFBundleVersion</key><string>7</string>
```

- [ ] **Step 5: Ver que pasa**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 185 tests in 37 suites passed`.

- [ ] **Step 6: Guardar la tabla en las preferencias**

En `Sources/Sintecla/AppSettings.swift`, cambiar:

```swift
  var baseKey: BaseKey { didSet { defaults.set(baseKey.rawValue, forKey: "baseKey") } }
```

por:

```swift
  var baseKey: BaseKey { didSet { defaults.set(baseKey.rawValue, forKey: "baseKey") } }
  /// Qué tecla acompaña a la base en cada modo (F4c).
  var hotkeys: HotkeyLayout { didSet { defaults.set(try? JSONEncoder().encode(hotkeys), forKey: "hotkeys") } }
```

Y cambiar:

```swift
    baseKey = BaseKey(rawValue: defaults.string(forKey: "baseKey") ?? "") ?? .fn
```

por:

```swift
    baseKey = BaseKey(rawValue: defaults.string(forKey: "baseKey") ?? "") ?? .fn
    hotkeys = HotkeyLayout.decoded(defaults.data(forKey: "hotkeys"))
```

- [ ] **Step 7: La máquina recibe la tabla; el aviso de la reunión dice su atajo**

En `Sources/Sintecla/DictationController.swift`, cambiar:

```swift
  /// Relee idioma, tecla base y ganancia (tras cambiar Ajustes o el menú).
  func applySettings() {
    machine.baseKey = settings.baseKey
```

por:

```swift
  /// Relee idioma, tecla base, atajos y ganancia (tras cambiar Ajustes o el menú).
  func applySettings() {
    machine.baseKey = settings.baseKey
    machine.layout = settings.hotkeys
```

Y cambiar:

```swift
      show(.message("Reunión en curso: termínala con \(meetingShortcut)"))
```

por:

```swift
      let shortcut = settings.hotkeys.shortcut(for: .meeting, baseKey: settings.baseKey)
      show(.message(shortcut.map { "Reunión en curso: termínala con \($0)" } ?? "Reunión en curso: termínala desde el menú"))
```

Y cambiar:

```swift
  private var meetingShortcut: String {
    switch settings.baseKey {
    case .fn: "🌐 + ⌥"
    case .rightOption: "⌥ der + ⌘"
    case .both: "🌐 + ⌥"
    }
  }
```

por:

```swift

```

- [ ] **Step 8: Pestaña General: un selector por modo, el atajo resultante, avisos y «Restaurar atajos»**

En `Sources/Sintecla/Windows.swift`, cambiar:

```swift
      Section("Atajos (mantener, o pulsar para manos libres)") {
        LabeledContent("Dictar", value: baseSymbol)
        LabeledContent("Traducir", value: "\(baseSymbol) + ⇧")
        LabeledContent("Ask Anything", value: "\(baseSymbol) + Espacio")
        LabeledContent("Notas", value: "\(baseSymbol) + ⌃")
        LabeledContent("Reunión (empieza o termina)", value: meetingCombo)
        LabeledContent("Cancelar / cerrar tarjeta", value: "Esc")
      }
    }
    .formStyle(.grouped)
    .onChange(of: settings.launchAtLogin) { onChange() }
    .onChange(of: settings.soundsEnabled) { onChange() }
    .onChange(of: settings.language) { onChange() }
    .onChange(of: settings.baseKey) { onChange() }
  }

  private var meetingCombo: String {
    switch settings.baseKey {
    case .fn: "🌐 + ⌥"
    case .rightOption: "⌥ der + ⌘"
    case .both: "🌐 + ⌥ o ⌥ der + ⌘"
    }
  }

  private var baseSymbol: String {
    switch settings.baseKey {
    case .fn: "🌐"
    case .rightOption: "⌥ der"
    case .both: "🌐 o ⌥ der"
    }
  }
}
```

por:

```swift
      Section("Atajos (mantener, o pulsar para manos libres)") {
        LabeledContent("Dictar", value: settings.hotkeys.shortcut(for: .dictation, baseKey: settings.baseKey) ?? "")
        ForEach(HotkeyLayout.configurableModes, id: \.self) { mode in
          VStack(alignment: .leading, spacing: 2) {
            Picker(mode == .meeting ? "Reunión (empieza o termina)" : mode.name, selection: companion(for: mode)) {
              ForEach(HotkeyCompanion.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            Text(settings.hotkeys.shortcut(for: mode, baseKey: settings.baseKey) ?? "Sin atajo")
              .font(.caption).foregroundStyle(.secondary)
            if let warning = settings.hotkeys.warning(for: mode, baseKey: settings.baseKey) {
              Text(warning).font(.caption).foregroundStyle(.secondary)
            }
          }
        }
        LabeledContent("Cancelar / cerrar tarjeta", value: "Esc")
        Button("Restaurar atajos") { settings.hotkeys = .defaults }
          .disabled(settings.hotkeys == .defaults)
      }
    }
    .formStyle(.grouped)
    .onChange(of: settings.launchAtLogin) { onChange() }
    .onChange(of: settings.soundsEnabled) { onChange() }
    .onChange(of: settings.language) { onChange() }
    .onChange(of: settings.baseKey) { onChange() }
    .onChange(of: settings.hotkeys) { onChange() }
  }

  /// Elegir una tecla que ya tiene otro modo las intercambia.
  private func companion(for mode: HotkeyMode) -> Binding<HotkeyCompanion> {
    Binding(get: { settings.hotkeys.companion(for: mode) ?? .shift },
            set: { settings.hotkeys.assign($0, to: mode) })
  }
}
```

- [ ] **Step 9: Compilar**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | tail -1
```

Esperado: `Build of product 'Sintecla' complete!`.

- [ ] **Step 10: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 185 tests in 37 suites passed`.

- [ ] **Step 11: Commit**

```bash
git add Sources/Sintecla/AppSettings.swift Sources/Sintecla/DictationController.swift Sources/Sintecla/Windows.swift Sources/SinteclaCore/AppInfo.swift Resources/Info.plist Sources/SinteclaCoreTests/SmokeTests.swift
git commit -m 'feat: elegir en Ajustes la tecla de cada modo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

- [ ] **Step 12: Instalar la versión nueva**

Run:

```bash
scripts/build-app.sh
```

Esperado: `✅ Instalada en /Applications/Sintecla.app`. Los permisos se conservan.

---
### Task 4: Aceptación de la F4c

**Files:**
- Modify: `docs/superpowers/specs/2026-09-23-sintecla-design.md` (estado)

**Interfaces:**
- Consumes: La app instalada (Tarea 3), con permiso de Accesibilidad.
- Produces: Etiqueta `v0.6.0` y la rama `fase-4c` integrada en `main`.

Lo hace el usuario: las teclas de verdad no se pueden probar sin permisos (spec F4c §8).

- [ ] **Step 1: Checklist manual F4c. Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | Ajustes → General → Atajos: poner ⌥ en Notas | Reunión pasa a ⌃ (se intercambian); los atajos de debajo cambian al momento |
| 2 | `🌐 + ⌥` mantenido y `🌐 + ⌃` pulsado | El primero graba notas; el segundo inicia la reunión (y otra vez, la termina) |
| 3 | Con la base en «Las dos», desde el Logitech: `⌥ der + ⌘` y `⌥ der + ⌃` | Notas y reunión |
| 4 | Poner Espacio en Traducir | Ask pasa a ⇧; `🌐 + Espacio` traduce |
| 5 | Poner ⌘ en Ask con la base en ⌥ derecha | Notas (con ⌥) sale «Sin atajo» y el aviso «Con ⌥ derecha, Notas no tiene atajo…» |
| 6 | «Restaurar atajos» | Vuelven ⇧ / Espacio / ⌃ / ⌥ y el botón se desactiva |
| 7 | Con una reunión en marcha, otro atajo | «Reunión en curso: termínala con …» con la combinación actual |
| 8 | Salir de Sintecla y volver a abrirla | Los atajos elegidos se conservan |
| 9 | Dictado, traducción, Ask, notas y reuniones con los atajos de siempre | Igual que en la 0.5.1 |

- [ ] **Step 2: Marcar la F4c como entregada en la spec**

En `docs/superpowers/specs/2026-09-23-sintecla-design.md`, cambiar:

```text
Icono entregado (`v0.5.1`).
```

por:

```text
Icono entregado (`v0.5.1`). F4c entregada (`v0.6.0`).
```

- [ ] **Step 3: Cerrar la fase**

```bash
git add docs/superpowers/specs/2026-09-23-sintecla-design.md
git commit -m 'docs: F4c entregada

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
swift run sintecla-tests
git tag -a v0.6.0 -m 'F4c: editor de atajos'
```

Después, integrar `fase-4c` en `main` con superpowers:finishing-a-development-branch.

---
## Autorrevisión frente a la especificación (F4c)

| Requisito (spec F4c) | Dónde |
|---|---|
| §2 Modos configurables, 5 teclas, intercambio, valores por defecto, «Restaurar» | Tareas 1 y 3 |
| §3 Espacio y luego ⇧ ⌃ ⌥ ⌘; regla de ⌥/⌘; modificador libre = Dictado; Espacio libre = otra tecla | Tareas 1 y 2 |
| §4 Textos de los atajos | Tarea 1 (`shortcut`), usados en la Tarea 3 |
| §5 Selectores, atajo resultante, avisos, Dictar y Esc fijos, «Restaurar atajos», cambios al momento | Tarea 3 |
| §6 `UserDefaults` `hotkeys` en JSON; si no vale, valores por defecto | Tareas 1 (`Codable`, `decoded`) y 3 |
| §7 Versión 0.6.0 | Tarea 3 |
| §8 Tests y aceptación a mano | Tareas 1, 2 y 4 |

**Consistencia de tipos revisada:**
- `HotkeyLayout.mode(modifiers:sawSpace:baseKey:)` (Tarea 1) la usan `HotkeyStateMachine` (Tarea 2) y los tests de siempre en lugar de `HotkeyStateMachine.mode`.
- `HotkeyLayout.usesSpace` (Tarea 1) decide si la máquina se traga el Espacio (Tarea 2).
- `shortcut(for:baseKey:)` y `warning(for:baseKey:)` (Tarea 1) salen en `GeneralTab` y en el aviso de la reunión (Tarea 3).
