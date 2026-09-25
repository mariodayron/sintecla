# Sintecla — Herramientas: cortar y pegar en Finder — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Una sección «Herramientas» en la ventana de Sintecla y su primera herramienta: en Finder, ⌘X corta los archivos seleccionados y ⌘V los mueve a la carpeta abierta, como en Windows.

**Architecture:**
- **`FinderCut` (núcleo, puro y con tests)** decide qué hacer con cada ⌘X y ⌘V según el interruptor, la app activa, si se está escribiendo y el `changeCount` del portapapeles. También recuerda el corte.
- **La app** hace el resto:
  - `EventTap` pasa las pulsaciones que no usan los atajos de dictado a `FinderCutter`;
  - `FinderCutter` envía ⌘C (cortar) o ⌥⌘V («Mover aquí» de Finder) con `Paster.postCommand` y avisa en la pastilla;
  - `ToolsTab` pone el interruptor.

**Tech Stack:** Lo de siempre:
- Swift 6.3 de las Command Line Tools, en modo de lenguaje 5;
- SwiftPM y Swift Testing;
- AppKit (`NSPasteboard`, `NSWorkspace`), Accesibilidad (`AXUIElement`), `CGEvent` y SwiftUI.

**Especificación:** `docs/superpowers/specs/2026-09-25-herramientas-finder-design.md`.

**Punto de partida:** la rama `herramientas` (sale de `main` en `v0.8.0` y lleva la especificación):

```bash
git checkout herramientas
```

## Global Constraints

- **Todo lo de antes sigue vigente:**
  - macOS 26.0 o superior, Apple Silicon.
  - Sin Xcode ni dependencias externas; todos los targets en `.swiftLanguageMode(.v5)`.
  - Tests con `swift run sintecla-tests` (**nunca `swift test`**).
  - Textos visibles en español.
  - La release compila sin avisos.
- **Herramientas:** cada una con su interruptor, **todas apagadas por defecto** (UserDefaults `finderCut`, `false`). Se aplican al momento, sin reiniciar.
- **Cortar y pegar solo actúa si se cumplen las tres condiciones:**
  - el interruptor está encendido;
  - Finder (`com.apple.finder`) es la app activa;
  - el elemento enfocado no es un campo de texto (roles `AXTextField`, `AXTextArea`, `AXSearchField` y `AXComboBox`).

  Si alguna falla, ⌘X y ⌘V hacen lo de siempre.
- **Teclas:**
  - solo ⌘X y ⌘V, con ⌘ y ninguna otra modificadora (códigos de tecla 7 y 9);
  - Sintecla envía ⌘C (código 8) y ⌥⌘V, con la marca `EventTap.syntheticMarker`.
- **Portapapeles:** tras el ⌘C se mira hasta **3 veces en 600 ms**. El corte vale mientras el portapapeles tenga el mismo `changeCount`.
- **Aviso:** «Cortado: 3 elementos · ⌘V para mover» (en singular, «1 elemento»), con el símbolo `scissors`. Al pegar no hay aviso.
- **Prioridad:** el dictado va primero.
  - Lo que usan los atajos de dictado no llega a Finder.
  - Con la pastilla grabando o procesando, el aviso no sale.
- **Permisos:** solo el de Accesibilidad, que Sintecla ya tiene.
- **Interfaz:**
  - la sección «Herramientas» (icono `wrench.and.screwdriver`) va detrás de IA, dentro de Ajustes;
  - dentro, la sección «Finder» con el interruptor «Cortar y pegar archivos (⌘X, ⌘V)».
- **Versión 0.9.0** (build 10).
- **Commits:** en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código de este plan se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `herramientas`: compiló, pasó los tests en cada tarea y el árbol final quedó idéntico al del prototipo.

- **236 tests** (43 suites) en verde: los 226 de antes y 10 nuevos (`FinderCutTests`). La release compila sin avisos.
- **De Finder, sin probar en el prototipo:** ⌥⌘V es su «Mover aquí» (el menú Edición con ⌥ pulsada) y mueve lo que se copió con ⌘C, también a otro disco. Lo comprueban las pruebas 1 y 2 de la aceptación (Tarea 4).
- **`ContextReader`** ya tiene lo necesario para saber si se escribe: `focusedElement()`, `string(of:_:)` y `editableRoles`, con los cuatro roles de la especificación.
- **Precedente:** `ContextReader.copySelection()` (Ask Anything) ya envía ⌘C con `Paster.postCommand` y espera a que cambie el portapapeles.
- **La app no tiene tests propios:** toda la lógica que se puede probar está en `FinderCut` (Tarea 1). Lo demás se comprueba compilando y con la aceptación a mano (Tarea 4).

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| Con la ⌥ derecha como tecla base, `EventTap.comboModifiers` no cuenta la ⌥, así que ⌥⌘X parecería ⌘X | `EventTap.modifiers(from:)` da todas las modificadoras tal cual para las herramientas (Tarea 2) |
| Preguntar por Accesibilidad con cada ⌘X o ⌘V, en cualquier app, haría más lento el callback del `EventTap` | `isEditingText` es un cierre que `FinderCut` solo llama con la herramienta encendida y Finder activo (Tarea 1) |
| Enviar ⌘C dentro del callback del `EventTap` lo alarga mientras se espera a Finder | `FinderCutter` responde enseguida y hace el ⌘C y la espera en un `Task` (Tarea 2) |
| ⌘X sin nada seleccionado olvidaría un corte anterior | El corte solo se sustituye cuando Finder copia otros archivos (Tarea 1, test `cutWithNothingSelectedKeepsThePreviousCut`) |
| El aviso taparía la pastilla del dictado | `showToolNotice` solo avisa con la máquina en reposo y sin grabación (Tarea 2) |

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/FinderCut.swift`, `Sources/SinteclaCoreTests/FinderCutTests.swift` | Decidir qué hacer con ⌘X y ⌘V, recordar el corte y el texto del aviso | 1 |
| `Sources/Sintecla/EventTap.swift` | `onKeyDown` y `modifiers(from:)` para las herramientas | 2 |
| `Sources/Sintecla/Paster.swift` | `postCommand(key:extra:)` para ⌥⌘V | 2 |
| `Sources/Sintecla/FinderCutter.swift` | Une `FinderCut` con Finder, el portapapeles y la pastilla | 2 |
| `Sources/Sintecla/AppSettings.swift` | Interruptor `finderCut` | 2 |
| `Sources/Sintecla/DictationController.swift` | Engancha `FinderCutter` al `EventTap` y a la pastilla | 2 |
| `Sources/Sintecla/ToolsTab.swift`, `Sources/Sintecla/MainWindow.swift` | La sección Herramientas | 3 |
| `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`, `Sources/SinteclaCoreTests/SmokeTests.swift` | Versión 0.9.0 (build 10) | 3 |
| `README.md`, `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§7) | Fila «Herramientas» y ventana Sintecla en la spec principal | 3 |

---

### Task 1: `FinderCut`: cuándo ⌘X corta y ⌘V mueve

**Files:**
- Create: `Sources/SinteclaCore/FinderCut.swift`
- Test: `Sources/SinteclaCoreTests/FinderCutTests.swift`

**Interfaces:**
- Consumes: `ComboModifier` (`Sources/SinteclaCore/HotkeyTypes.swift`: `shift`, `control`, `option`, `command`).
- Produces: `FinderCut` (struct, `init()`); `FinderCut.finderBundleID`; `FinderCut.Key` (`.cut`, `.paste`); `FinderCut.Decision` (`.pass`, `.copyAsCut`, `.move`); `static func key(keyCode: Int64, modifiers: Set<ComboModifier>) -> Key?`; `mutating func keyDown(_ key: Key, enabled: Bool, app: String?, changeCount: Int, isEditingText: () -> Bool) -> Decision`; `mutating func copied(changeCount: Int, files: Int) -> String?` (devuelve el aviso o nil); `static func notice(files: Int) -> String`.

Toda la lógica que se puede probar, sin AppKit.

- **Qué entra:** la tecla, el interruptor, la app activa, si se escribe (un cierre, para no preguntar por Accesibilidad sin necesidad) y el `changeCount` del portapapeles.
- **Qué sale:** pasar, copiar como corte o mover.

- [ ] **Step 1: Tests de `FinderCut`**

Crear `Sources/SinteclaCoreTests/FinderCutTests.swift`:

```swift
import Testing
@testable import SinteclaCore

@Suite struct FinderCutTests {
  let finder = FinderCut.finderBundleID

  /// ⌘X o ⌘V en Finder, sin escribir, con el interruptor encendido.
  private func press(_ key: FinderCut.Key, _ cut: inout FinderCut, changeCount: Int, app: String? = FinderCut.finderBundleID) -> FinderCut.Decision {
    cut.keyDown(key, enabled: true, app: app, changeCount: changeCount, isEditingText: { false })
  }

  @Test func onlyCommandXAndCommandVCount() {
    #expect(FinderCut.key(keyCode: 7, modifiers: [.command]) == .cut)
    #expect(FinderCut.key(keyCode: 9, modifiers: [.command]) == .paste)
    #expect(FinderCut.key(keyCode: 7, modifiers: [.command, .shift]) == nil)
    #expect(FinderCut.key(keyCode: 9, modifiers: [.command, .option]) == nil)
    #expect(FinderCut.key(keyCode: 7, modifiers: []) == nil)
    #expect(FinderCut.key(keyCode: 8, modifiers: [.command]) == nil)
  }

  @Test func passesWhenOffOutsideFinderOrWriting() {
    var cut = FinderCut()
    #expect(cut.keyDown(.cut, enabled: false, app: finder, changeCount: 1, isEditingText: { false }) == .pass)
    #expect(cut.keyDown(.cut, enabled: true, app: "com.apple.Notes", changeCount: 1, isEditingText: { false }) == .pass)
    #expect(cut.keyDown(.cut, enabled: true, app: nil, changeCount: 1, isEditingText: { false }) == .pass)
    #expect(cut.keyDown(.cut, enabled: true, app: finder, changeCount: 1, isEditingText: { true }) == .pass)
    #expect(cut.keyDown(.paste, enabled: true, app: finder, changeCount: 1, isEditingText: { true }) == .pass)
  }

  @Test func asksWhetherWritingOnlyInFinderWithTheToolOn() {
    var cut = FinderCut()
    var asked = 0
    _ = cut.keyDown(.cut, enabled: false, app: finder, changeCount: 1, isEditingText: { asked += 1; return false })
    _ = cut.keyDown(.cut, enabled: true, app: "com.apple.Notes", changeCount: 1, isEditingText: { asked += 1; return false })
    #expect(asked == 0)
    _ = cut.keyDown(.cut, enabled: true, app: finder, changeCount: 1, isEditingText: { asked += 1; return false })
    #expect(asked == 1)
  }

  @Test func cutThenPasteMovesOnce() {
    var cut = FinderCut()
    #expect(press(.cut, &cut, changeCount: 4) == .copyAsCut)
    #expect(cut.copied(changeCount: 5, files: 3) == "Cortado: 3 elementos · ⌘V para mover")
    #expect(press(.paste, &cut, changeCount: 5) == .move)
    // El corte se olvida: el siguiente ⌘V pega como siempre.
    #expect(press(.paste, &cut, changeCount: 5) == .pass)
  }

  @Test func nothingIsCutWithoutChangeOrFiles() {
    var cut = FinderCut()
    _ = press(.cut, &cut, changeCount: 4)
    #expect(cut.copied(changeCount: 4, files: 0) == nil)  // no había nada seleccionado
    #expect(press(.paste, &cut, changeCount: 4) == .pass)
    _ = press(.cut, &cut, changeCount: 4)
    #expect(cut.copied(changeCount: 5, files: 0) == nil)  // cambió, pero sin archivos
    #expect(press(.paste, &cut, changeCount: 5) == .pass)
  }

  @Test func copyingSomethingElseForgetsTheCut() {
    var cut = FinderCut()
    _ = press(.cut, &cut, changeCount: 4)
    _ = cut.copied(changeCount: 5, files: 2)
    #expect(press(.paste, &cut, changeCount: 6) == .pass)
    #expect(press(.paste, &cut, changeCount: 5) == .pass)
  }

  @Test func cutWithNothingSelectedKeepsThePreviousCut() {
    var cut = FinderCut()
    _ = press(.cut, &cut, changeCount: 4)
    _ = cut.copied(changeCount: 5, files: 2)
    _ = press(.cut, &cut, changeCount: 5)
    #expect(cut.copied(changeCount: 5, files: 2) == nil)
    #expect(press(.paste, &cut, changeCount: 5) == .move)
  }

  @Test func pasteOutsideFinderKeepsTheCut() {
    var cut = FinderCut()
    _ = press(.cut, &cut, changeCount: 4)
    _ = cut.copied(changeCount: 5, files: 2)
    #expect(press(.paste, &cut, changeCount: 5, app: "com.apple.Notes") == .pass)
    #expect(press(.paste, &cut, changeCount: 5) == .move)
  }

  @Test func copiedWithoutCutDoesNothing() {
    var cut = FinderCut()
    #expect(cut.copied(changeCount: 5, files: 2) == nil)
    #expect(press(.paste, &cut, changeCount: 5) == .pass)
  }

  @Test func noticeInSingularAndPlural() {
    #expect(FinderCut.notice(files: 1) == "Cortado: 1 elemento · ⌘V para mover")
    #expect(FinderCut.notice(files: 3) == "Cortado: 3 elementos · ⌘V para mover")
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find 'FinderCut' in scope`.

- [ ] **Step 3: `FinderCut`**

Crear `Sources/SinteclaCore/FinderCut.swift`:

```swift
/// Cortar y pegar archivos en Finder con ⌘X y ⌘V, como en Windows (spec «Herramientas» §2).
/// Puro: la app le da la tecla, el interruptor, la app activa, si se escribe y el `changeCount` del portapapeles.
public struct FinderCut {
  public static let finderBundleID = "com.apple.finder"

  public enum Key: Equatable, Sendable { case cut, paste }

  public enum Decision: Equatable, Sendable {
    /// La pulsación sigue su camino, como siempre.
    case pass
    /// Tragarse ⌘X, enviar ⌘C y, cuando Finder haya copiado, llamar a `copied(changeCount:files:)`.
    case copyAsCut
    /// Tragarse ⌘V y enviar ⌥⌘V: Finder mueve los archivos a la carpeta abierta.
    case move
  }

  /// `changeCount` del portapapeles al pulsar ⌘X, hasta que se sabe si Finder copió.
  private var copyingFrom: Int?
  /// `changeCount` del portapapeles con los archivos cortados; nil si no hay corte.
  private var cutAt: Int?

  public init() {}

  /// ⌘X o ⌘V (códigos de tecla 7 y 9) con ⌘ y ninguna otra modificadora; nil con cualquier otra pulsación.
  public static func key(keyCode: Int64, modifiers: Set<ComboModifier>) -> Key? {
    guard modifiers == [.command] else { return nil }
    switch keyCode {
    case 7: return .cut
    case 9: return .paste
    default: return nil
    }
  }

  /// `isEditingText` (se pregunta por Accesibilidad) solo se mira en Finder y con la herramienta encendida.
  public mutating func keyDown(_ key: Key, enabled: Bool, app: String?, changeCount: Int,
                               isEditingText: () -> Bool) -> Decision {
    guard enabled, app == Self.finderBundleID, !isEditingText() else { return .pass }
    switch key {
    case .cut:
      // El corte anterior sigue hasta que Finder copie otros archivos: sin nada seleccionado, no copia.
      copyingFrom = changeCount
      return .copyAsCut
    case .paste:
      defer { cutAt = nil }
      return cutAt == changeCount ? .move : .pass
    }
  }

  /// Tras el ⌘C: si el portapapeles cambió y tiene archivos, apunta el corte y devuelve el aviso de la pastilla.
  public mutating func copied(changeCount: Int, files: Int) -> String? {
    guard let from = copyingFrom else { return nil }
    copyingFrom = nil
    guard changeCount != from, files > 0 else { return nil }
    cutAt = changeCount
    return Self.notice(files: files)
  }

  public static func notice(files: Int) -> String {
    "Cortado: \(files) \(files == 1 ? "elemento" : "elementos") · ⌘V para mover"
  }
}
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 236 tests in 43 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/FinderCut.swift Sources/SinteclaCoreTests/FinderCutTests.swift
git commit -m 'feat: FinderCut decide cuándo ⌘X corta y ⌘V mueve archivos en Finder

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: La app corta y pega en Finder

**Files:**
- Modify: `Sources/Sintecla/EventTap.swift` (`onKeyDown`, `modifiers(from:)`)
- Modify: `Sources/Sintecla/Paster.swift` (`postCommand(key:extra:)`)
- Modify: `Sources/Sintecla/AppSettings.swift` (`finderCut`)
- Create: `Sources/Sintecla/FinderCutter.swift`
- Modify: `Sources/Sintecla/DictationController.swift` (`start()`, `showToolNotice`)

**Interfaces:**
- Consumes: `FinderCut` (Tarea 1). `ContextReader.focusedElement()`, `string(of:_:)` y `editableRoles`, `Paster.postCommand` y `DictationController.show(_:)` (ya existen).
- Produces: `EventTap.onKeyDown: ((Int64, Set<ComboModifier>) -> Bool)?`; `EventTap.modifiers(from: CGEventFlags) -> Set<ComboModifier>`; `Paster.postCommand(key: CGKeyCode, extra: CGEventFlags = [])`; `AppSettings.finderCut: Bool`; `FinderCutter(settings:)`, con `keyDown(keyCode:modifiers:) -> Bool`, `onNotice: ((String) -> Void)?` y `FinderCutter.symbol`.

El target de la app no tiene tests: esta tarea se comprueba compilando la release sin avisos y con los tests del núcleo en verde. Hasta la Tarea 3 no hay interruptor en la ventana, así que la herramienta sigue apagada.

- [ ] **Step 1: `EventTap`: las pulsaciones que no usan los atajos van a `onKeyDown`, con todas sus modificadoras**

En `Sources/Sintecla/EventTap.swift`, cambiar:

```swift
  /// Devuelve `true` si el evento debe tragarse (no llega a la app activa).
  var onEvent: ((HotkeyEvent) -> Bool)?
```

por:

```swift
  /// Devuelve `true` si el evento debe tragarse (no llega a la app activa).
  var onEvent: ((HotkeyEvent) -> Bool)?
  /// Cada pulsación que no usan los atajos, con su código y sus modificadores, para las herramientas (cortar y pegar
  /// en Finder). Devuelve `true` si hay que tragársela.
  var onKeyDown: ((_ keyCode: Int64, _ modifiers: Set<ComboModifier>) -> Bool)?
```

Y cambiar:

```swift
      if onEvent?(hotkeyEvent) == true {
        swallowedKeyUps.insert(keyCode)
        return nil
      }
```

por:

```swift
      // Los atajos de dictado van primero: lo que usan no llega a las herramientas.
      if onEvent?(hotkeyEvent) == true || onKeyDown?(keyCode, Self.modifiers(from: event.flags)) == true {
        swallowedKeyUps.insert(keyCode)
        return nil
      }
```

Y cambiar:

```swift
  private func comboModifiers(from flags: CGEventFlags) -> Set<ComboModifier> {
    var set: Set<ComboModifier> = []
    if flags.contains(.maskShift) { set.insert(.shift) }
    if flags.contains(.maskControl) { set.insert(.control) }
    if flags.contains(.maskAlternate) && base.optionIsModifier { set.insert(.option) }
    if flags.contains(.maskCommand) { set.insert(.command) }
    return set
  }
```

por:

```swift
  private func comboModifiers(from flags: CGEventFlags) -> Set<ComboModifier> {
    var set = Self.modifiers(from: flags)
    if !base.optionIsModifier { set.remove(.option) }
    return set
  }

  /// Las teclas modificadoras pulsadas, todas (también la ⌥ cuando es la tecla base).
  static func modifiers(from flags: CGEventFlags) -> Set<ComboModifier> {
    var set: Set<ComboModifier> = []
    if flags.contains(.maskShift) { set.insert(.shift) }
    if flags.contains(.maskControl) { set.insert(.control) }
    if flags.contains(.maskAlternate) { set.insert(.option) }
    if flags.contains(.maskCommand) { set.insert(.command) }
    return set
  }
```

- [ ] **Step 2: `Paster.postCommand` admite modificadoras extra (⌥ para ⌥⌘V)**

En `Sources/Sintecla/Paster.swift`, cambiar:

```swift
  /// ⌘ + tecla, marcado para que nuestro EventTap lo ignore.
  static func postCommand(key: CGKeyCode) {
    let source = CGEventSource(stateID: .combinedSessionState)
    for isDown in [true, false] {
      guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown) else { continue }
      event.flags = .maskCommand
```

por:

```swift
  /// ⌘ + tecla (con `extra`, otras modificadoras: ⌥ para ⌥⌘V), marcado para que nuestro EventTap lo ignore.
  static func postCommand(key: CGKeyCode, extra: CGEventFlags = []) {
    let source = CGEventSource(stateID: .combinedSessionState)
    for isDown in [true, false] {
      guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown) else { continue }
      event.flags = CGEventFlags.maskCommand.union(extra)
```

Las llamadas de antes (`postCommand(key: 9)`, `postCommand(key: 8)`) no cambian: `extra` vale `[]` por defecto.

- [ ] **Step 3: El interruptor `finderCut`, apagado por defecto**

En `Sources/Sintecla/AppSettings.swift`, cambiar:

```swift
  var meetingNoticeShown: Bool { didSet { defaults.set(meetingNoticeShown, forKey: "meetingNoticeShown") } }
```

por:

```swift
  var meetingNoticeShown: Bool { didSet { defaults.set(meetingNoticeShown, forKey: "meetingNoticeShown") } }
  /// Herramientas: cortar y pegar archivos en Finder con ⌘X y ⌘V. Apagada por defecto, como todas las herramientas.
  var finderCut: Bool { didSet { defaults.set(finderCut, forKey: "finderCut") } }
```

Y cambiar:

```swift
      "saveMeetingAudio": true, "meetingNoticeShown": false,
    ])
```

por:

```swift
      "saveMeetingAudio": true, "meetingNoticeShown": false,
      "finderCut": false,
    ])
```

Y cambiar:

```swift
    meetingNoticeShown = defaults.bool(forKey: "meetingNoticeShown")
```

por:

```swift
    meetingNoticeShown = defaults.bool(forKey: "meetingNoticeShown")
    finderCut = defaults.bool(forKey: "finderCut")
```

- [ ] **Step 4: `FinderCutter`: Finder, el portapapeles y el aviso**

Crear `Sources/Sintecla/FinderCutter.swift`:

```swift
import AppKit
import SinteclaCore

/// Cortar y pegar archivos en Finder (spec «Herramientas» §2): une `FinderCut` con la app activa, el elemento enfocado,
/// el portapapeles y la pastilla.
@MainActor
final class FinderCutter {
  static let symbol = "scissors"
  /// Aviso para la pastilla («Cortado: 3 elementos · ⌘V para mover»).
  var onNotice: ((String) -> Void)?

  private let settings: AppSettings
  private var cut = FinderCut()

  init(settings: AppSettings) {
    self.settings = settings
  }

  /// Lo llama `EventTap` con cada pulsación que no usan los atajos de dictado. `true`: Sintecla se la queda.
  func keyDown(keyCode: Int64, modifiers: Set<ComboModifier>) -> Bool {
    guard let key = FinderCut.key(keyCode: keyCode, modifiers: modifiers) else { return false }
    let changeCount = NSPasteboard.general.changeCount
    let decision = cut.keyDown(key, enabled: settings.finderCut,
                               app: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                               changeCount: changeCount, isEditingText: Self.isEditingText)
    switch decision {
    case .pass:
      return false
    case .copyAsCut:
      // Fuera del callback del EventTap, que tiene que volver enseguida.
      Task { await copyAsCut(from: changeCount) }
      return true
    case .move:
      Task { Paster.postCommand(key: 9, extra: .maskAlternate) }  // ⌥⌘V: «Mover aquí» de Finder
      return true
    }
  }

  /// Renombrando, en el buscador o en «Ir a la carpeta», ⌘X y ⌘V son de texto.
  private static func isEditingText() -> Bool {
    guard let focused = ContextReader.focusedElement(),
          let role = ContextReader.string(of: focused, kAXRoleAttribute) else { return false }
    return ContextReader.editableRoles.contains(role)
  }

  /// ⌘C y, en cuanto Finder copia (se mira hasta 3 veces en 600 ms), apunta el corte si hay archivos.
  private func copyAsCut(from changeCount: Int) async {
    let pasteboard = NSPasteboard.general
    Paster.postCommand(key: 8)  // 8 = C
    for _ in 0..<3 {
      try? await Task.sleep(for: .milliseconds(200))
      if pasteboard.changeCount != changeCount { break }
    }
    let files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])?.count ?? 0
    if let notice = cut.copied(changeCount: pasteboard.changeCount, files: files) { onNotice?(notice) }
  }
}
```

- [ ] **Step 5: `DictationController` engancha el `FinderCutter` después de los atajos de dictado**

En `Sources/Sintecla/DictationController.swift`, cambiar:

```swift
  private let meetings: MeetingLibrary
  private lazy var recorder = MeetingRecorder(settings: settings, library: meetings)
```

por:

```swift
  private let meetings: MeetingLibrary
  private lazy var recorder = MeetingRecorder(settings: settings, library: meetings)
  /// Herramientas: cortar y pegar archivos en Finder.
  private lazy var finderCutter = FinderCutter(settings: settings)
```

Y cambiar:

```swift
    eventTap.onEvent = { [weak self] event in
      MainActor.assumeIsolated { self?.handle(event) ?? false }
    }
```

por:

```swift
    eventTap.onEvent = { [weak self] event in
      MainActor.assumeIsolated { self?.handle(event) ?? false }
    }
    eventTap.onKeyDown = { [weak self] keyCode, modifiers in
      MainActor.assumeIsolated { self?.finderCutter.keyDown(keyCode: keyCode, modifiers: modifiers) ?? false }
    }
    finderCutter.onNotice = { [weak self] text in self?.showToolNotice(text) }
```

Y cambiar:

```swift
  // MARK: - Pastilla
```

por:

```swift
  // MARK: - Pastilla

  /// Aviso de una herramienta. El dictado va primero: si se está grabando o procesando, no sale.
  private func showToolNotice(_ text: String) {
    guard machine.state == .idle, session == nil else { return }
    show(.notice(text, symbol: FinderCutter.symbol))
  }
```

- [ ] **Step 6: Compilar la release (sin avisos)**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build of product' | tail -3
```

Esperado: `Build of product 'Sintecla' complete!`.

Si sale alguna línea `warning:`, corrígela antes de seguir.

- [ ] **Step 7: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 236 tests in 43 suites passed`.

- [ ] **Step 8: Commit**

```bash
git add Sources/Sintecla/EventTap.swift Sources/Sintecla/Paster.swift Sources/Sintecla/AppSettings.swift Sources/Sintecla/FinderCutter.swift Sources/Sintecla/DictationController.swift
git commit -m 'feat: cortar y pegar archivos en Finder con ⌘X y ⌘V

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: La sección Herramientas y la versión 0.9.0

**Files:**
- Create: `Sources/Sintecla/ToolsTab.swift`
- Modify: `Sources/Sintecla/MainWindow.swift` (`MainSection`, barra lateral, `detail`)
- Modify: `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`
- Test: `Sources/SinteclaCoreTests/SmokeTests.swift`
- Modify: `README.md`, `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§7, ventana Sintecla)

**Interfaces:**
- Consumes: `AppSettings.finderCut` (Tarea 2).
- Produces: `MainSection.tools`; `ToolsTab(settings:)`; `AppInfo.version == "0.9.0"` (build 10).

`ToolsTab` va en su propio archivo: ahí irán las próximas herramientas (Alt-Tab, copiar texto de la pantalla, batería).

- [ ] **Step 1: El test de humo pide la 0.9.0**

En `Sources/SinteclaCoreTests/SmokeTests.swift`, cambiar:

```swift
#expect(AppInfo.version == "0.8.0")
```

por:

```swift
#expect(AppInfo.version == "0.9.0")
```

- [ ] **Step 2: Ver que falla**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA el test con `Test appInfoIsSet() recorded an issue at SmokeTests.swift:6:5: Expectation failed`.

- [ ] **Step 3: Versión 0.9.0**

En `Sources/SinteclaCore/AppInfo.swift`, cambiar:

```swift
public static let version = "0.8.0"
```

por:

```swift
public static let version = "0.9.0"
```

- [ ] **Step 4: Versión 0.9.0 (build 10) en el Info.plist**

En `Resources/Info.plist`, cambiar:

```xml
<key>CFBundleShortVersionString</key><string>0.8.0</string>
```

por:

```xml
<key>CFBundleShortVersionString</key><string>0.9.0</string>
```

Y cambiar:

```xml
<key>CFBundleVersion</key><string>9</string>
```

por:

```xml
<key>CFBundleVersion</key><string>10</string>
```

- [ ] **Step 5: Ver que pasa**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 236 tests in 43 suites passed`.

- [ ] **Step 6: `ToolsTab`: la sección Finder con su interruptor**

Crear `Sources/Sintecla/ToolsTab.swift`:

```swift
import SwiftUI

/// Herramientas (spec «Herramientas» §3): utilidades de Windows o de apps de pago, cada una con su interruptor
/// y todas apagadas por defecto.
struct ToolsTab: View {
  @Bindable var settings: AppSettings

  var body: some View {
    Form {
      Section("Finder") {
        Toggle("Cortar y pegar archivos (⌘X, ⌘V)", isOn: $settings.finderCut)
        Text("⌘X corta los archivos seleccionados y ⌘V los mueve a la carpeta abierta, como en Windows. "
             + "Al renombrar, ⌘X corta texto como siempre.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}
```

- [ ] **Step 7: La entrada «Herramientas» en la barra lateral, detrás de IA**

En `Sources/Sintecla/MainWindow.swift`, cambiar:

```swift
  case meetings, history, stats, general, dictionary, tones, ai
```

por:

```swift
  case meetings, history, stats, general, dictionary, tones, ai, tools
```

Y cambiar:

```swift
          Label("IA", systemImage: "sparkles").tag(MainSection.ai)
```

por:

```swift
          Label("IA", systemImage: "sparkles").tag(MainSection.ai)
          Label("Herramientas", systemImage: "wrench.and.screwdriver").tag(MainSection.tools)
```

Y cambiar:

```swift
    case .ai: AITab(settings: settings, history: history).navigationTitle("IA")
```

por:

```swift
    case .ai: AITab(settings: settings, history: history).navigationTitle("IA")
    case .tools: ToolsTab(settings: settings).navigationTitle("Herramientas")
```

- [ ] **Step 8: README: la fila «Herramientas»**

En `README.md`, cambiar:

```text
| **Y además** | Historial, estadísticas, atajos configurables, modo susurro y tecla ⌥ derecha para teclados sin 🌐. |
```

por:

```text
| **Herramientas** | Utilidades de Windows o de apps de pago, cada una con su interruptor y apagadas de fábrica. Por ahora, cortar y pegar archivos en Finder con ⌘X y ⌘V. Si ya usas otra app que cambia ⌘X en Finder, deja esta apagada. |
| **Y además** | Historial, estadísticas, atajos configurables, modo susurro y tecla ⌥ derecha para teclados sin 🌐. |
```

- [ ] **Step 9: Spec principal §7: la sección nueva de la ventana**

En `docs/superpowers/specs/2026-09-23-sintecla-design.md`, cambiar:

```text
"Probar conexión", "Mi estilo"). Con la ventana abierta
```

por:

```text
"Probar conexión", "Mi estilo") · Herramientas (desde la 0.9.0; cortar y pegar archivos en Finder, ver `2026-09-25-herramientas-finder-design.md`). Con la ventana abierta
```

- [ ] **Step 10: Compilar la release (sin avisos)**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build of product' | tail -3
```

Esperado: `Build of product 'Sintecla' complete!`.

- [ ] **Step 11: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 236 tests in 43 suites passed`.

- [ ] **Step 12: Commit**

```bash
git add Sources/Sintecla/ToolsTab.swift Sources/Sintecla/MainWindow.swift Sources/SinteclaCore/AppInfo.swift Resources/Info.plist Sources/SinteclaCoreTests/SmokeTests.swift README.md docs/superpowers/specs/2026-09-23-sintecla-design.md
git commit -m 'feat: sección Herramientas en la ventana; versión 0.9.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

- [ ] **Step 13: Instalar la versión nueva**

Run:

```bash
scripts/build-app.sh
```

Esperado: `✅ Instalada en /Applications/Sintecla.app`. La herramienta viene apagada: se enciende en Sintecla → Herramientas.

---
### Task 4: Aceptación a mano

**Files:**
- —

**Interfaces:**
- Consumes: La app instalada (Tarea 3).
- Produces: Nada nuevo: con todo ✓, la 0.9.0 se cierra (etiqueta `v0.9.0`, integración en `main` y el estado en la spec principal).

La hace el usuario: hay que pulsar teclas en Finder con archivos de verdad. Para las pruebas, mejor una carpeta con archivos de prueba.

- [ ] **Step 1: Checklist de la especificación (§5). Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | Encender Sintecla → Herramientas → «Cortar y pegar archivos». En Finder, seleccionar 2 archivos, pulsar ⌘X, ir a otra carpeta y pulsar ⌘V | Tras ⌘X, la pastilla dice «Cortado: 2 elementos · ⌘V para mover». Con ⌘V, los archivos se mueven: ya no están en la carpeta de origen |
| 2 | Lo mismo hacia otro disco o un USB | Se mueven, no se copian |
| 3 | Renombrar un archivo, seleccionar parte del nombre y pulsar ⌘X. Lo mismo en el buscador de Finder y en «Ir a la carpeta» (⇧⌘G) | Se corta el texto, sin aviso |
| 4 | Cortar archivos con ⌘X, copiar otra cosa con ⌘C (texto u otro archivo) y pulsar ⌘V en Finder | Se pega lo copiado; los archivos cortados no se mueven |
| 5 | En Notas, ⌘X y ⌘V | Cortan y pegan texto como siempre |
| 6 | Con el interruptor apagado, ⌘X en Finder | No hace nada, como en macOS |
| 7 | Dictar, traducir, Ask Anything y pegar el último resultado | Todo funciona como en la 0.8.0 |

---
## Autorrevisión frente a la especificación

| Requisito (spec Herramientas) | Dónde |
|---|---|
| §1 Sección «Herramientas», todas apagadas por defecto; primera herramienta, cortar y pegar en Finder | Tareas 2 y 3 |
| §2 Las tres condiciones (interruptor, Finder, no escribir) | Tarea 1 (`keyDown`) y Tarea 2 (`FinderCutter.isEditingText`) |
| §2 ⌘X: se queda la pulsación, ⌘C, mira el portapapeles hasta 3 veces en 600 ms, aviso en singular o plural | Tarea 1 (`copied`, `notice`) y Tarea 2 (`copyAsCut`) |
| §2 ⌘V: mismo `changeCount` → ⌥⌘V y se olvida; si no, pega como siempre y se olvida; sin aviso | Tarea 1 y Tarea 2 (`.move`) |
| §2 Pulsaciones marcadas con `syntheticMarker`; el dictado va primero | Tarea 2 (`Paster.postCommand`, `EventTap`, `showToolNotice`) |
| §3 Entrada «Herramientas» (`wrench.and.screwdriver`) detrás de IA, sección «Finder» con su texto, al momento y sin permisos nuevos | Tarea 3 (y Tarea 2: `settings.finderCut` se lee con cada pulsación) |
| §4 Piezas: `FinderCut`, `EventTap.onKeyDown`, `Paster.postCommand`, `FinderCutter`, `DictationController`, `AppSettings.finderCut`, `MainSection.tools`, `ToolsTab`, versión 0.9.0 (build 10), README | Tareas 1–3 |
| §5 Tests automáticos y aceptación a mano | Tareas 1 y 4 |
| §6 Riesgos: Finder lento (3 intentos), campos de texto de Finder (aceptación 3), otras apps (apagada por defecto y aviso en el README) | Tareas 2–4 |

**Consistencia de tipos revisada:**
- `FinderCut.key(keyCode:modifiers:)`, `keyDown(_:enabled:app:changeCount:isEditingText:)` y `copied(changeCount:files:)` (Tarea 1) los usa `FinderCutter` (Tarea 2) con esos mismos nombres.
- `EventTap.onKeyDown` recibe `(Int64, Set<ComboModifier>)`, igual que `FinderCutter.keyDown(keyCode:modifiers:)`.
- `AppSettings.finderCut` (Tarea 2) lo usan `FinderCutter` (Tarea 2) y `ToolsTab` (Tarea 3).
- `FinderCutter.symbol` (Tarea 2) lo usa `DictationController.showToolNotice`.
