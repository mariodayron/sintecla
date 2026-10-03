# Sintecla — Módulo Alt-Tab (0.12.0) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ⌘Tab cambia de **ventana**, no de app, con una miniatura de cada una, como en Windows. Sustituye al selector de macOS mientras el módulo esté encendido.

**Architecture:**
- **En el núcleo, con tests:** `AltTabShortcut` (teclas), `WindowSwitcherOrder` (qué ventanas y en qué orden) y `SwitcherState` (la marcada).
- **En la app:**
  - `WindowCatalog` lista las ventanas (la lista de macOS y, por Accesibilidad, las minimizadas) y salta a una;
  - `WindowThumbnails` saca las miniaturas con ScreenCaptureKit;
  - `WindowSwitcherPanel` es el panel de cristal;
  - `AltTabController` va el último en la cadena de teclas del `EventTap`, salta al soltar ⌘ y apaga el ⌘Tab de macOS mientras el módulo está encendido.

**Tech Stack:** Lo de siempre:
- Swift 6.4 de las Command Line Tools 27, en modo de lenguaje 5;
- SwiftPM, Swift Testing, SwiftUI y AppKit;
- además, Accesibilidad (`AXUIElement`), `CGWindowListCopyWindowInfo` y ScreenCaptureKit.

**Especificación:** `docs/superpowers/specs/2026-10-03-alt-tab-design.md`.

**Punto de partida:** la rama `alt-tab` (sale de `main` en la 0.11.0, con la especificación y los dos arreglos para compilar con las Command Line Tools 27):

```bash
git checkout alt-tab
```

## Global Constraints

- **Todo lo de antes sigue vigente:**
  - macOS 26.0 o superior, Apple Silicon.
  - Sin Xcode ni dependencias externas; modo de lenguaje 5.
  - Tests con `swift run sintecla-tests` (**nunca `swift test`**).
  - Textos visibles en español.
  - La release compila sin avisos.
- **Compilar la app con las Command Line Tools 27:** con el SDK de macOS 26, mediante `source scripts/sdk-env.sh` (lo hace `build-app.sh`).
  - Los avisos `ld: warning: search path …` los pone SwiftPM y no cuentan.
  - SwiftPM ahora escribe «Build complete!».
- **Módulo «Alt-Tab»:** UserDefaults `moduleAltTab`, **apagado de fábrica**. Es el quinto en Módulos.
- **Teclas:**
  - ⌘Tab abre con la segunda ventana marcada y ⇧⌘Tab con la última; solo con ⌘ (y ⇧).
  - Con ⌘ pulsado: Tab y → avanzan, ⇧Tab y ← retroceden, Esc cierra.
  - Al soltar ⌘ se salta a la marcada.
  - El resto de teclas sigue llegando a la app.
- **Panel:** aparece a los **150 ms**; si ⌘ se suelta antes, se salta sin enseñarlo.
- **Ventanas:**
  - las del escritorio actual en el orden de macOS y, al final, las minimizadas;
  - fuera: las de Sintecla, las de capa distinta de 0, las de menos de 50 × 50 puntos y las de apps que no son normales;
  - sin título, el nombre de la app.
- **Tarjetas:** hasta 6 por fila, de 200 puntos de ancho, más pequeñas si no caben en el 80 % de la pantalla.
- **Versión:** 0.12.0 (build 13).
- **Commits:** en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `alt-tab`: compiló, pasó los tests en cada tarea y el árbol final quedó idéntico al del prototipo.

- **300 tests** (54 suites) en verde: los 293 de antes y 7 nuevos. La release compila sin avisos (aparte de los `ld: warning: search path` de SwiftPM).
- **El ⌘Tab de macOS,** probado en el Mac del usuario con Sintecla y ⌘Tab sintéticos:
  - sin interceptor, macOS cambia de app (control);
  - con el `EventTap` quedándose ⌘Tab, **macOS cambia de app igualmente**;
  - con el `EventTap` y `CGSSetSymbolicHotKeyEnabled(1 y 2, false)`, macOS ya no hace nada.
- **Activar otra app desde Sintecla:**
  - `NSRunningApplication.activate()` falló una de dos veces;
  - Accesibilidad (`kAXFrontmostAttribute`) funcionó siempre.
- **El selector de verdad,** con el módulo encendido:
  - el catálogo leyó 4 ventanas en 56 ms;
  - un toque rápido de ⌘Tab saltó a la segunda ventana sin enseñar el panel;
  - manteniendo ⌘, el panel salió encima de todo (capa 101, 880 × 204 puntos con 4 tarjetas);
  - Esc lo cerró sin cambiar nada.
- **Sin probar** (lo comprueba la Tarea 6): el ratón en las tarjetas, las minimizadas y las miniaturas en pantalla.

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| El `EventTap` se queda ⌘Tab, pero macOS cambia de app igualmente | Mientras el módulo está encendido, `NativeAppSwitcher` apaga los atajos simbólicos 1 y 2 de macOS |
| Apagar el ⌘Tab de macOS sin que Sintecla escuche el teclado (sin permisos) dejaría sin ninguno | `AltTabController.start()` se llama solo cuando el `EventTap` ya ha arrancado |
| Si Sintecla se cierra a la fuerza con el módulo encendido, el ⌘Tab de macOS se queda apagado | Al arrancar con el módulo apagado se vuelve a encender, y `applicationWillTerminate` también lo enciende |
| `NSRunningApplication.activate()` no siempre trae otra app al frente desde Sintecla | `WindowCatalog.focus` también pone la app delante con Accesibilidad |
| Accesibilidad no da el número de ventana de macOS | Al saltar, la ventana visible se busca por su sitio y su tamaño (y si no, por el título) |
| Una app colgada bloquearía la lista con Accesibilidad | `AXUIElementSetMessagingTimeout` de 0,1 s |
| Con el SDK de macOS 27, `@State` y las macros de Swift Testing no compilan con las Command Line Tools | Ya resuelto en la rama: `scripts/sdk-env.sh` para la app y `-plugin-path` para los tests |

**Decisiones de este plan que la spec no fijaba:**
- Con el selector abierto, **las demás teclas siguen llegando a la app** (⌘Q, por ejemplo); solo se quedan Tab, ⇧Tab, las flechas y Esc.
- **Se quitan las ventanas transparentes** (alfa 0), que algunas apps dejan abiertas.

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/AltTab.swift`, `Sources/SinteclaCoreTests/AltTabTests.swift` | Teclas, orden y ventana marcada | 1 |
| `Sources/SinteclaCore/Modules.swift`, `Sources/SinteclaCoreTests/ModulesTests.swift`, `Sources/Sintecla/AppSettings.swift`, `Sources/Sintecla/AltTabPage.swift`, `Sources/Sintecla/HomeView.swift`, `Sources/Sintecla/MainWindow.swift` | El módulo, su página y su tarjeta | 2 |
| `Sources/Sintecla/WindowCatalog.swift` | Lista de ventanas, salto y miniaturas | 3 |
| `Sources/Sintecla/WindowSwitcherPanel.swift`, `Sources/Sintecla/AltTabController.swift`, `Sources/Sintecla/EventTap.swift`, `Sources/Sintecla/DictationController.swift`, `Sources/Sintecla/AppDelegate.swift` | El selector con ⌘Tab | 4 |
| `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`, `Sources/SinteclaCoreTests/SmokeTests.swift`, `README.md`, `docs/superpowers/specs/2026-09-23-sintecla-design.md` | 0.12.0 | 5 |

---

### Task 1: Alt-Tab en el núcleo: teclas, orden y ventana marcada

**Files:**
- Create: `Sources/SinteclaCore/AltTab.swift`
- Test: `Sources/SinteclaCoreTests/AltTabTests.swift`

**Interfaces:**
- Consumes: `ComboModifier` (`Sources/SinteclaCore/HotkeyTypes.swift`).
- Produces: `AltTabKey` (`.open(backward:)`, `.next`, `.previous`, `.cancel`); `AltTabShortcut.key(keyCode:modifiers:isOpen:) -> AltTabKey?` y `AltTabShortcut.summary`; `SwitcherWindow(id:pid:appName:title:isMinimized:layer:size:)` con `label`; `WindowSwitcherOrder.arrange(visible:minimized:ownPID:agentPIDs:) -> [SwitcherWindow]`; `SwitcherState(count:backward:)` con `selected: Int?`, `next()`, `previous()` y `mark(_:)`.

Todo lo que se puede probar sin ventanas: qué teclas hacen qué, qué ventanas salen y cuál queda marcada.

- [ ] **Step 1: Tests: teclas, orden, filtros y ventana marcada**

Crear `Sources/SinteclaCoreTests/AltTabTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import SinteclaCore

@Suite struct AltTabTests {
  @Test func commandTabOpensAndShiftGoesBackwards() {
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.command], isOpen: false) == .open(backward: false))
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.command, .shift], isOpen: false) == .open(backward: true))
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.option], isOpen: false) == nil)
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.command, .option], isOpen: false) == nil)
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.command, .control], isOpen: false) == nil)
    #expect(AltTabShortcut.key(keyCode: 49, modifiers: [.command], isOpen: false) == nil)  // ⌘Espacio no
  }

  @Test func whileOpenTabArrowsAndEscape() {
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.command], isOpen: true) == .next)
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.command, .shift], isOpen: true) == .previous)
    #expect(AltTabShortcut.key(keyCode: 124, modifiers: [.command], isOpen: true) == .next)  // →
    #expect(AltTabShortcut.key(keyCode: 123, modifiers: [.command], isOpen: true) == .previous)  // ←
    #expect(AltTabShortcut.key(keyCode: 53, modifiers: [.command], isOpen: true) == .cancel)  // Esc
    #expect(AltTabShortcut.key(keyCode: 12, modifiers: [.command], isOpen: true) == nil)  // ⌘Q sigue siendo de la app
  }

  private func window(_ id: Int, pid: Int32 = 10, app: String = "Safari", title: String = "Ventana", minimized: Bool = false,
                      layer: Int = 0, size: CGSize = CGSize(width: 800, height: 600)) -> SwitcherWindow {
    SwitcherWindow(id: id, pid: pid, appName: app, title: title, isMinimized: minimized, layer: layer, size: size)
  }

  @Test func keepsMacOSOrderAndPutsMinimizedLast() {
    let visible = [window(1), window(2, pid: 11, app: "Notas"), window(3)]
    let minimized = [window(-1, pid: 11, app: "Notas", minimized: true)]
    let arranged = WindowSwitcherOrder.arrange(visible: visible, minimized: minimized, ownPID: 99, agentPIDs: [])
    #expect(arranged.map(\.id) == [1, 2, 3, -1])
  }

  @Test func leavesOutSinteclaMenusTinyWindowsAndAgents() {
    let visible = [
      window(1),
      window(2, pid: 99, app: "Sintecla"),  // la propia app
      window(3, layer: 25),  // barra de menú, Dock, paneles
      window(4, size: CGSize(width: 40, height: 300)),  // menos de 50 puntos
      window(5, pid: 12, app: "Ayudante"),  // app de fondo
    ]
    let arranged = WindowSwitcherOrder.arrange(visible: visible, minimized: [window(6, pid: 99, minimized: true)],
                                               ownPID: 99, agentPIDs: [12])
    #expect(arranged.map(\.id) == [1])
  }

  @Test func untitledWindowsShowTheAppName() {
    #expect(window(1, app: "Finder", title: "  ").label == "Finder")
    #expect(window(1, app: "Safari", title: "Inicio").label == "Inicio")
  }

  @Test func startsOnTheSecondOrTheLastBackwards() {
    #expect(SwitcherState(count: 4, backward: false).selected == 1)
    #expect(SwitcherState(count: 4, backward: true).selected == 3)
    #expect(SwitcherState(count: 1, backward: false).selected == 0)
    #expect(SwitcherState(count: 0, backward: false).selected == nil)
  }

  @Test func movesAroundAndTheMouseMarks() {
    var state = SwitcherState(count: 3, backward: false)
    state.next()
    #expect(state.selected == 2)
    state.next()
    #expect(state.selected == 0)  // da la vuelta
    state.previous()
    #expect(state.selected == 2)
    state.mark(1)
    #expect(state.selected == 1)
    state.mark(7)  // fuera de la lista: no cambia
    #expect(state.selected == 1)
    var empty = SwitcherState(count: 0, backward: false)
    empty.next()
    #expect(empty.selected == nil)
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find type 'SwitcherWindow' in scope`.

- [ ] **Step 3: `AltTabShortcut`, `SwitcherWindow`, `WindowSwitcherOrder` y `SwitcherState`**

Crear `Sources/SinteclaCore/AltTab.swift`:

```swift
import CoreGraphics

/// Lo que hace una pulsación con el selector de ventanas (spec «Alt-Tab» §3).
public enum AltTabKey: Equatable, Sendable {
  /// ⌘Tab (o ⇧⌘Tab, hacia atrás) con el selector cerrado.
  case open(backward: Bool)
  case next
  case previous
  case cancel
}

public enum AltTabShortcut {
  /// Resumen para la tarjeta de Inicio.
  public static let summary = "⌘Tab por ventanas"

  /// Con el selector cerrado, solo ⌘Tab y ⇧⌘Tab. Abierto (⌘ pulsado): Tab, ⇧Tab, ← y → lo mueven y Esc lo cierra; el
  /// resto de teclas sigue llegando a la app (nil).
  public static func key(keyCode: Int64, modifiers: Set<ComboModifier>, isOpen: Bool) -> AltTabKey? {
    guard isOpen else {
      guard keyCode == 48 else { return nil }  // 48 = Tab
      if modifiers == [.command] { return .open(backward: false) }
      if modifiers == [.command, .shift] { return .open(backward: true) }
      return nil
    }
    switch keyCode {
    case 48: return modifiers.contains(.shift) ? .previous : .next
    case 124: return .next  // →
    case 123: return .previous  // ←
    case 53: return .cancel  // Esc
    default: return nil
    }
  }
}

/// Una ventana del selector. `id` es el número de ventana de macOS; las minimizadas, que no lo dan, llevan uno negativo.
public struct SwitcherWindow: Equatable, Sendable {
  public let id: Int
  public let pid: Int32
  public let appName: String
  public let title: String
  public let isMinimized: Bool
  /// Capa de macOS: 0 son las ventanas normales.
  public let layer: Int
  public let size: CGSize

  public init(id: Int, pid: Int32, appName: String, title: String, isMinimized: Bool, layer: Int, size: CGSize) {
    self.id = id
    self.pid = pid
    self.appName = appName
    self.title = title
    self.isMinimized = isMinimized
    self.layer = layer
    self.size = size
  }

  /// El título o, si no tiene, el nombre de la app.
  public var label: String {
    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? appName : title
  }
}

/// Qué ventanas salen y en qué orden (spec «Alt-Tab» §4).
public enum WindowSwitcherOrder {
  /// Lado mínimo, en puntos.
  static let minimumSide: CGFloat = 50

  /// `visible`: las del escritorio actual en el orden de macOS (de delante a atrás). `minimized`: van al final.
  public static func arrange(visible: [SwitcherWindow], minimized: [SwitcherWindow], ownPID: Int32,
                             agentPIDs: Set<Int32>) -> [SwitcherWindow] {
    (visible + minimized).filter {
      $0.pid != ownPID && !agentPIDs.contains($0.pid) && $0.layer == 0
        && $0.size.width >= minimumSide && $0.size.height >= minimumSide
    }
  }
}

/// La ventana marcada (spec «Alt-Tab» §3).
public struct SwitcherState: Equatable, Sendable {
  public let count: Int
  public private(set) var selected: Int?

  /// Empieza en la segunda (la anterior que se usó) o, hacia atrás, en la última. Con una sola, en ella.
  public init(count: Int, backward: Bool) {
    self.count = count
    switch count {
    case 0: selected = nil
    case 1: selected = 0
    default: selected = backward ? count - 1 : 1
    }
  }

  public mutating func next() {
    guard let selected else { return }
    self.selected = (selected + 1) % count
  }

  public mutating func previous() {
    guard let selected else { return }
    self.selected = (selected - 1 + count) % count
  }

  /// El ratón sobre una tarjeta.
  public mutating func mark(_ index: Int) {
    guard (0..<count).contains(index) else { return }
    selected = index
  }
}
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 300 tests in 54 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/AltTab.swift Sources/SinteclaCoreTests/AltTabTests.swift
git commit -m 'feat: teclas, orden y ventana marcada del selector Alt-Tab

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: El módulo Alt-Tab, su página y su tarjeta

**Files:**
- Modify: `Sources/SinteclaCore/Modules.swift` y Test: `Sources/SinteclaCoreTests/ModulesTests.swift`
- Modify: `Sources/Sintecla/AppSettings.swift` (`moduleAltTab`)
- Create: `Sources/Sintecla/AltTabPage.swift`
- Modify: `Sources/Sintecla/HomeView.swift` (tarjeta) y `Sources/Sintecla/MainWindow.swift` (página)

**Interfaces:**
- Consumes: `AltTabShortcut.summary` (Tarea 1); `Permissions.accessibilityGranted`; `ScreenCapture.hasPermission` y `openPermissionSettings()`.
- Produces: `Module.altTab`, `ModulePage.altTab`, `ModuleSwitches.altTab` (con `altTab: Bool = false` en el `init`); `AppSettings.moduleAltTab` (UserDefaults `moduleAltTab`, `false`); `AltTabPage()`.

- [ ] **Step 1: Tests: el módulo Alt-Tab, apagado salvo que se diga**

En `Sources/SinteclaCoreTests/ModulesTests.swift`, cambiar:

```swift
  let allOn = ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true)
```

por:

```swift
  let allOn = ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true, altTab: true)
```

Y cambiar:

```swift
    #expect(Module.captures.pages == [.captures])
```

por:

```swift
    #expect(Module.captures.pages == [.captures])
    #expect(Module.altTab.pages == [.altTab])
```

Y cambiar:

```swift
    #expect(Module.allCases.map(\.name) == ["Dictado", "Reuniones", "Finder", "Capturas"])
```

por:

```swift
    #expect(Module.allCases.map(\.name) == ["Dictado", "Reuniones", "Finder", "Capturas", "Alt-Tab"])
    #expect(ModulePage.altTab.title == "Alt-Tab")
```

Y cambiar:

```swift
    #expect(allOn.enabled == [.dictation, .meetings, .finder, .captures])
```

por:

```swift
    #expect(allOn.enabled == [.dictation, .meetings, .finder, .captures, .altTab])
```

Y cambiar:

```swift
    switches[.captures] = false
    #expect(!switches.captures)
  }
```

por:

```swift
    switches[.captures] = false
    #expect(!switches.captures)
    switches[.altTab] = false
    #expect(!switches.altTab)
  }
```

Y cambiar:

```swift
    #expect(!ModuleSwitches(dictation: true, meetings: true, finder: true).captures)
```

por:

```swift
    #expect(!ModuleSwitches(dictation: true, meetings: true, finder: true).captures)
    #expect(!ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true).altTab)
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar: `ModuleSwitches`, `Module` y `ModulePage` aún no tienen `altTab`.

- [ ] **Step 3: `Module.altTab`, su página y su interruptor**

En `Sources/SinteclaCore/Modules.swift`, cambiar:

```swift
  case dictation, meetings, finder, captures
```

por:

```swift
  case dictation, meetings, finder, captures, altTab
```

Y cambiar:

```swift
    case .captures: "Capturas"
    }
  }

  public var symbol: String {
    switch self {
    case .dictation: "waveform"
```

por:

```swift
    case .captures: "Capturas"
    case .altTab: "Alt-Tab"
    }
  }

  public var symbol: String {
    switch self {
    case .dictation: "waveform"
```

Y cambiar:

```swift
    case .captures: "camera.viewfinder"
    }
  }

  /// Lo que hace, para la página Módulos.
```

por:

```swift
    case .captures: "camera.viewfinder"
    case .altTab: "rectangle.on.rectangle"
    }
  }

  /// Lo que hace, para la página Módulos.
```

Y cambiar:

```swift
      + "Grabación de pantalla."
    }
```

por:

```swift
      + "Grabación de pantalla."
    case .altTab: "⌘Tab cambia de ventana, no de app, con una miniatura de cada una, como en Windows. Las miniaturas "
      + "necesitan el permiso de Grabación de pantalla."
    }
```

Y cambiar:

```swift
  case captures

  public var module: Module {
```

por:

```swift
  case captures
  case altTab

  public var module: Module {
```

Y cambiar:

```swift
    case .captures: .captures
    }
```

por:

```swift
    case .captures: .captures
    case .altTab: .altTab
    }
```

Y cambiar:

```swift
    case .captures: "Capturas"
    }
  }

  public var symbol: String {
    switch self {
    case .history:
```

por:

```swift
    case .captures: "Capturas"
    case .altTab: "Alt-Tab"
    }
  }

  public var symbol: String {
    switch self {
    case .history:
```

Y cambiar:

```swift
    case .captures: "camera.viewfinder"
    }
  }
}

/// Qué módulos están encendidos.
```

por:

```swift
    case .captures: "camera.viewfinder"
    case .altTab: "rectangle.on.rectangle"
    }
  }
}

/// Qué módulos están encendidos.
```

Y cambiar:

```swift
  public var captures: Bool

  public init(dictation: Bool, meetings: Bool, finder: Bool, captures: Bool = false) {
```

por:

```swift
  public var captures: Bool
  public var altTab: Bool

  public init(dictation: Bool, meetings: Bool, finder: Bool, captures: Bool = false, altTab: Bool = false) {
```

Y cambiar:

```swift
    self.captures = captures
```

por:

```swift
    self.captures = captures
    self.altTab = altTab
```

Y cambiar:

```swift
      case .captures: captures
```

por:

```swift
      case .captures: captures
      case .altTab: altTab
```

Y cambiar:

```swift
      case .captures: captures = newValue
```

por:

```swift
      case .captures: captures = newValue
      case .altTab: altTab = newValue
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 300 tests in 54 suites passed`.

- [ ] **Step 5: `AppSettings.moduleAltTab`**

En `Sources/Sintecla/AppSettings.swift`, cambiar:

```swift
  var moduleCaptures: Bool { didSet { defaults.set(moduleCaptures, forKey: "moduleCaptures") } }
```

por:

```swift
  var moduleCaptures: Bool { didSet { defaults.set(moduleCaptures, forKey: "moduleCaptures") } }
  /// Módulo Alt-Tab (spec «Alt-Tab»), apagado por defecto.
  var moduleAltTab: Bool { didSet { defaults.set(moduleAltTab, forKey: "moduleAltTab") } }
```

Y cambiar:

```swift
"moduleCaptures": false,
```

por:

```swift
"moduleCaptures": false,
      "moduleAltTab": false,
```

Y cambiar:

```swift
    moduleCaptures = defaults.bool(forKey: "moduleCaptures")
```

por:

```swift
    moduleCaptures = defaults.bool(forKey: "moduleCaptures")
    moduleAltTab = defaults.bool(forKey: "moduleAltTab")
```

Y cambiar:

```swift
    get { ModuleSwitches(dictation: moduleDictation, meetings: moduleMeetings, finder: finderCut, captures: moduleCaptures) }
```

por:

```swift
    get {
      ModuleSwitches(dictation: moduleDictation, meetings: moduleMeetings, finder: finderCut, captures: moduleCaptures,
                     altTab: moduleAltTab)
    }
```

Y cambiar:

```swift
      if moduleCaptures != newValue.captures { moduleCaptures = newValue.captures }
```

por:

```swift
      if moduleCaptures != newValue.captures { moduleCaptures = newValue.captures }
      if moduleAltTab != newValue.altTab { moduleAltTab = newValue.altTab }
```

- [ ] **Step 6: La página Alt-Tab**

Crear `Sources/Sintecla/AltTabPage.swift`:

```swift
import Combine
import SinteclaCore
import SwiftUI

/// Alt-Tab → Alt-Tab (spec «Alt-Tab» §2): cómo se usa, los dos permisos y el aviso de que ⌘Tab ya es de Sintecla.
struct AltTabPage: View {
  @State private var accessibility = Permissions.accessibilityGranted
  @State private var screen = ScreenCapture.hasPermission
  private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

  var body: some View {
    Form {
      Section("Cómo se usa") {
        LabeledContent("⌘Tab", value: "Abre el selector con la ventana anterior marcada")
        LabeledContent("Tab, ⇧Tab, ← →", value: "Con ⌘ pulsado, mueven la marca")
        LabeledContent("Soltar ⌘", value: "Salta a la ventana marcada")
        LabeledContent("Esc", value: "Cierra sin cambiar nada")
        Text("También con el ratón: pasar por encima marca una ventana y un clic salta a ella. Mientras el módulo está "
             + "encendido, ⌘Tab abre el selector de Sintecla en lugar del de macOS; al apagarlo vuelve el de macOS.")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("Permisos") {
        LabeledContent("Accesibilidad") {
          Label(accessibility ? "Dado" : "Falta", systemImage: accessibility ? "checkmark.circle.fill" : "xmark.circle")
        }
        LabeledContent("Grabación de pantalla") {
          Label(screen ? "Dado" : "Falta: sin miniaturas", systemImage: screen ? "checkmark.circle.fill" : "xmark.circle")
        }
        if !screen {
          Button("Abrir Ajustes") { ScreenCapture.openPermissionSettings() }
          Text("Sin él, el selector funciona igual, con el icono de cada app en lugar de la miniatura.")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .onReceive(timer) { _ in
      accessibility = Permissions.accessibilityGranted
      screen = ScreenCapture.hasPermission
    }
  }
}
```

- [ ] **Step 7: La tarjeta de Alt-Tab en Inicio**

En `Sources/Sintecla/HomeView.swift`, cambiar:

```swift
      if !ScreenCapture.hasPermission {
        Label(CaptureNotice.noPermission, systemImage: "exclamationmark.triangle").font(.callout)
      }
    }
```

por:

```swift
      if !ScreenCapture.hasPermission {
        Label(CaptureNotice.noPermission, systemImage: "exclamationmark.triangle").font(.callout)
      }
    case .altTab:
      Text(AltTabShortcut.summary).foregroundStyle(.secondary)
      if !ScreenCapture.hasPermission {
        Label("Sin miniaturas: falta el permiso de Grabación de pantalla", systemImage: "exclamationmark.triangle")
          .font(.callout)
      }
    }
```

- [ ] **Step 8: La página en la ventana**

En `Sources/Sintecla/MainWindow.swift`, cambiar:

```swift
    case .captures: CapturesPage(settings: settings)
```

por:

```swift
    case .captures: CapturesPage(settings: settings)
    case .altTab: AltTabPage()
```

- [ ] **Step 9: Compilar la release (sin avisos)**

Run:

```bash
source scripts/sdk-env.sh && swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build complete' | grep -v 'ld: warning: search path' | tail -3
```

Esperado: `Build complete!`.

Si sale alguna línea `warning:` (aparte de las de `ld: warning: search path`, que se filtran), corrígela antes de seguir.

- [ ] **Step 10: Commit**

```bash
git add Sources/SinteclaCore/Modules.swift Sources/SinteclaCoreTests/ModulesTests.swift Sources/Sintecla/AppSettings.swift Sources/Sintecla/AltTabPage.swift Sources/Sintecla/HomeView.swift Sources/Sintecla/MainWindow.swift
git commit -m 'feat: módulo Alt-Tab con su página y su tarjeta

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: Las ventanas: lista, salto y miniaturas

**Files:**
- Create: `Sources/Sintecla/WindowCatalog.swift`

**Interfaces:**
- Consumes: `SwitcherWindow` y `WindowSwitcherOrder.arrange` (Tarea 1).
- Produces: `WindowCatalog()` con `refresh()`, `windows: [SwitcherWindow]` y `focus(_:)`; `WindowThumbnails.capture(_ ids: [Int], maxSide: CGFloat, each: @MainActor (Int, CGImage) -> Void) -> Task<Void, Never>?`.

Aún no lo usa nadie: el selector llega en la Tarea 4. Accesibilidad no da el número de ventana de macOS: las visibles se encuentran por su sitio y su tamaño al saltar. `activate()` a veces no basta desde Sintecla (activación cooperativa), así que también se pide con Accesibilidad (`kAXFrontmostAttribute`), que sí lo consigue.

- [ ] **Step 1: `WindowCatalog` y `WindowThumbnails`**

Crear `Sources/Sintecla/WindowCatalog.swift`:

```swift
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
```

- [ ] **Step 2: Compilar la release (sin avisos)**

Run:

```bash
source scripts/sdk-env.sh && swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build complete' | grep -v 'ld: warning: search path' | tail -3
```

Esperado: `Build complete!`.

- [ ] **Step 3: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 300 tests in 54 suites passed`.

- [ ] **Step 4: Commit**

```bash
git add Sources/Sintecla/WindowCatalog.swift
git commit -m 'feat: lista de ventanas, salto y miniaturas para Alt-Tab

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 4: El selector con ⌘Tab

**Files:**
- Create: `Sources/Sintecla/WindowSwitcherPanel.swift` y `Sources/Sintecla/AltTabController.swift`
- Modify: `Sources/Sintecla/EventTap.swift` (`onModifiersChanged`)
- Modify: `Sources/Sintecla/DictationController.swift` (Alt-Tab en la cadena de teclas) y `Sources/Sintecla/AppDelegate.swift` (⌘Tab de macOS al salir)

**Interfaces:**
- Consumes: Las Tareas 1 a 3; `FirstMouseHostingView` (Ask Anything); `EventTap.onKeyDown`.
- Produces: `SwitcherModel`, `WindowSwitcherView`, `WindowSwitcherPanel` (`layout(count:)`, `show()`, `hide()`, `onHover`, `onClick`); `AltTabController(settings:)` con `start()`, `keyDown(keyCode:modifiers:) -> Bool` y `modifiersChanged(_:)`; `NativeAppSwitcher.setEnabled(_:)`; `EventTap.onModifiersChanged`.

Sintecla se queda ⌘Tab con su `EventTap`, pero eso no basta: macOS cambia de app igualmente. Por eso, mientras el módulo está encendido, se apaga el ⌘Tab de macOS (`CGSSetSymbolicHotKeyEnabled`, la llamada privada que usa AltTab). Se vuelve a encender al apagar el módulo, al salir y, si el módulo está apagado, al arrancar.

- [ ] **Step 1: El panel de cristal con las tarjetas**

Crear `Sources/Sintecla/WindowSwitcherPanel.swift`:

```swift
import AppKit
import Observation
import SinteclaCore
import SwiftUI

/// Lo que enseña el selector: las ventanas, la marcada, las miniaturas que van llegando y el tamaño de las tarjetas.
@MainActor @Observable
final class SwitcherModel {
  var windows: [SwitcherWindow] = []
  var selected: Int?
  var thumbnails: [Int: CGImage] = [:]
  /// Ancho de cada tarjeta, en puntos: 200, o menos si no caben (spec «Alt-Tab» §5).
  var cardWidth: CGFloat = 200
  /// Tarjetas por fila: hasta 6.
  var columns = 1
}

/// El panel de cristal con una tarjeta por ventana (spec «Alt-Tab» §5).
struct WindowSwitcherView: View {
  let model: SwitcherModel
  var onHover: (Int) -> Void
  var onClick: (Int) -> Void

  var body: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(model.cardWidth), spacing: 12), count: model.columns),
              spacing: 12) {
      ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
        card(window, chosen: model.selected == index)
          .onHover { if $0 { onHover(index) } }
          .onTapGesture { onClick(index) }
      }
    }
    .padding(16)
    .glassEffect(.regular, in: .rect(cornerRadius: 28))
    .padding(6)
  }

  private func card(_ window: SwitcherWindow, chosen: Bool) -> some View {
    let icon = NSRunningApplication(processIdentifier: window.pid)?.icon ?? NSImage(named: NSImage.applicationIconName)!
    return VStack(alignment: .leading, spacing: 6) {
      ZStack {
        if let thumbnail = model.thumbnails[window.id] {
          Image(decorative: thumbnail, scale: 2).resizable().aspectRatio(contentMode: .fit)
            .clipShape(.rect(cornerRadius: 6))
        } else {
          Image(nsImage: icon).resizable().frame(width: 64, height: 64)
        }
      }
      .frame(width: model.cardWidth - 16, height: (model.cardWidth - 16) * 0.66)
      HStack(spacing: 6) {
        Image(nsImage: icon).resizable().frame(width: 16, height: 16)
        Text(window.label).font(.callout).lineLimit(1).truncationMode(.tail)
      }
    }
    .padding(8)
    .frame(width: model.cardWidth)
    .background(chosen ? Color.accentColor.opacity(0.22) : .clear, in: .rect(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: chosen ? 2 : 0))
    .opacity(window.isMinimized ? 0.55 : 1)
    .contentShape(.rect)
  }
}

/// Panel por encima de todo que no activa Sintecla: la app de delante sigue siendo la que era hasta que se salta.
@MainActor
final class WindowSwitcherPanel {
  let model = SwitcherModel()
  var onHover: ((Int) -> Void)?
  var onClick: ((Int) -> Void)?
  private let panel: NSPanel
  private var hosting: FirstMouseHostingView<WindowSwitcherView>!

  init() {
    panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200), styleMask: [.nonactivatingPanel, .borderless],
                    backing: .buffered, defer: false)
    panel.level = .popUpMenu
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false  // el cristal ya lleva su sombra
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    hosting = FirstMouseHostingView(rootView: WindowSwitcherView(
      model: model, onHover: { [weak self] in self?.onHover?($0) }, onClick: { [weak self] in self?.onClick?($0) }))
    panel.contentView = hosting
  }

  /// Hasta 6 tarjetas por fila de 200 puntos; si no caben en el 80 % de la pantalla del ratón, se encogen.
  func layout(count: Int) {
    let visible = screenUnderMouse()?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
    let columns = max(1, min(6, count))
    let rows = CGFloat((count + columns - 1) / columns)
    let byWidth = (visible.width * 0.8 - 44 - 12 * CGFloat(columns - 1)) / CGFloat(columns)
    // Alto de una tarjeta: la miniatura (0,66 del ancho) y la línea del título.
    let byHeight = ((visible.height * 0.8 - 44 - 12 * (rows - 1)) / rows - 40) / 0.66
    model.columns = columns
    model.cardWidth = max(80, min(200, byWidth, byHeight))
  }

  func show() {
    hosting.layoutSubtreeIfNeeded()
    let size = hosting.fittingSize
    guard let visible = screenUnderMouse()?.visibleFrame else { return }
    panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2, width: size.width,
                          height: size.height), display: true)
    panel.orderFrontRegardless()
  }

  func hide() {
    panel.orderOut(nil)
  }

  private func screenUnderMouse() -> NSScreen? {
    let mouse = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
  }
}
```

- [ ] **Step 2: `AltTabController` y el ⌘Tab de macOS**

Crear `Sources/Sintecla/AltTabController.swift`:

```swift
import AppKit
import Observation
import SinteclaCore

/// Módulo Alt-Tab (spec «Alt-Tab» §3): ⌘Tab abre el selector de ventanas, Tab, ⇧Tab y las flechas lo mueven, Esc lo
/// cierra y al soltar ⌘ se salta a la ventana marcada.
@MainActor
final class AltTabController {
  /// Si se suelta ⌘ antes, se salta sin enseñar el panel: el cambio rápido no parpadea.
  static let panelDelay = Duration.milliseconds(150)

  private let settings: AppSettings
  private let catalog = WindowCatalog()
  private lazy var panel: WindowSwitcherPanel = {
    let panel = WindowSwitcherPanel()
    panel.onHover = { [weak self] index in self?.mark(index) }
    panel.onClick = { [weak self] index in
      self?.mark(index)
      self?.commit()
    }
    return panel
  }()
  private var state: SwitcherState?
  private var showTask: Task<Void, Never>?
  private var thumbnailTask: Task<Void, Never>?

  init(settings: AppSettings) {
    self.settings = settings
  }

  private var isOpen: Bool { state != nil }

  /// Lo llama Sintecla cuando ya escucha el teclado: desde ahí, el ⌘Tab de macOS sigue al interruptor del módulo.
  func start() {
    NativeAppSwitcher.setEnabled(!settings.moduleAltTab)
    withObservationTracking { _ = settings.moduleAltTab } onChange: { [weak self] in
      Task { @MainActor in self?.start() }
    }
  }

  /// Lo llama el `EventTap` con cada pulsación que no usan el dictado, Finder ni Capturas. `true`: Sintecla se la queda.
  func keyDown(keyCode: Int64, modifiers: Set<ComboModifier>) -> Bool {
    guard settings.moduleAltTab, let key = AltTabShortcut.key(keyCode: keyCode, modifiers: modifiers, isOpen: isOpen)
    else { return false }
    switch key {
    case .open(let backward): open(backward: backward)
    case .next: move { $0.next() }
    case .previous: move { $0.previous() }
    case .cancel: close()
    }
    return true
  }

  /// Cada cambio de las teclas modificadoras: al soltar ⌘ se salta a la ventana marcada.
  func modifiersChanged(_ modifiers: Set<ComboModifier>) {
    guard isOpen, !modifiers.contains(.command) else { return }
    commit()
  }

  /// Sin ventanas que enseñar no se abre (y ⌘Tab no hace nada).
  private func open(backward: Bool) {
    catalog.refresh()
    let windows = catalog.windows
    guard !windows.isEmpty else { return }
    state = SwitcherState(count: windows.count, backward: backward)
    panel.layout(count: windows.count)
    panel.model.windows = windows
    panel.model.selected = state?.selected
    panel.model.thumbnails = [:]
    showTask = Task { [weak self] in
      try? await Task.sleep(for: Self.panelDelay)
      guard !Task.isCancelled, let self, self.isOpen else { return }
      self.panel.show()
    }
    thumbnailTask = WindowThumbnails.capture(windows.filter { !$0.isMinimized }.map(\.id),
                                             maxSide: panel.model.cardWidth) { [weak self] id, image in
      self?.panel.model.thumbnails[id] = image
    }
  }

  private func move(_ change: (inout SwitcherState) -> Void) {
    guard var state else { return }
    change(&state)
    self.state = state
    panel.model.selected = state.selected
  }

  private func mark(_ index: Int) {
    move { $0.mark(index) }
  }

  private func commit() {
    let target = state?.selected.map { catalog.windows[$0] }
    close()
    if let target { catalog.focus(target) }
  }

  private func close() {
    state = nil
    showTask?.cancel()
    thumbnailTask?.cancel()
    panel.hide()
  }
}

/// El ⌘Tab de macOS (sus atajos simbólicos 1 y 2: ⌘Tab y ⇧⌘Tab). Mientras Alt-Tab está encendido se apaga: aunque
/// Sintecla se quede la pulsación, macOS cambiaría de app igualmente. Es la misma llamada privada que usa AltTab.
/// Sintecla lo vuelve a encender al apagar el módulo y al salir.
enum NativeAppSwitcher {
  private typealias SetSymbolicHotKeyEnabled = @convention(c) (Int32, Bool) -> Int32
  private static let setSymbolicHotKeyEnabled: SetSymbolicHotKeyEnabled? = {
    dlsym(dlopen(nil, RTLD_NOW), "CGSSetSymbolicHotKeyEnabled").map { unsafeBitCast($0, to: SetSymbolicHotKeyEnabled.self) }
  }()

  static func setEnabled(_ enabled: Bool) {
    _ = setSymbolicHotKeyEnabled?(1, enabled)
    _ = setSymbolicHotKeyEnabled?(2, enabled)
  }
}
```

- [ ] **Step 3: `EventTap`: avisar de cada cambio de las modificadoras**

En `Sources/Sintecla/EventTap.swift`, cambiar:

```swift
  var onKeyDown: ((_ keyCode: Int64, _ modifiers: Set<ComboModifier>) -> Bool)?
```

por:

```swift
  var onKeyDown: ((_ keyCode: Int64, _ modifiers: Set<ComboModifier>) -> Bool)?
  /// Cada cambio de las teclas modificadoras, todas (también la ⌥ cuando es la tecla base): Alt-Tab salta al soltar ⌘.
  var onModifiersChanged: ((Set<ComboModifier>) -> Void)?
```

Y cambiar:

```swift
        _ = onEvent?(.modifiers(modifiers, at: now))
      }
      return Unmanaged.passUnretained(event)  // los modificadores nunca se tragan
```

por:

```swift
        _ = onEvent?(.modifiers(modifiers, at: now))
      }
      onModifiersChanged?(Self.modifiers(from: flags))
      return Unmanaged.passUnretained(event)  // los modificadores nunca se tragan
```

- [ ] **Step 4: `DictationController`: Alt-Tab el último en la cadena de teclas**

En `Sources/Sintecla/DictationController.swift`, cambiar:

```swift
  private lazy var captures = CaptureController(settings: settings, appleModel: appleModel)
```

por:

```swift
  private lazy var captures = CaptureController(settings: settings, appleModel: appleModel)
  /// Módulo Alt-Tab.
  private lazy var altTab = AltTabController(settings: settings)
```

Y cambiar:

```swift
    // Después de los atajos de dictado: primero Finder y luego Capturas.
    eventTap.onKeyDown = { [weak self] keyCode, modifiers in
      MainActor.assumeIsolated {
        guard let self else { return false }
        return self.finderCutter.keyDown(keyCode: keyCode, modifiers: modifiers)
          || self.captures.keyDown(keyCode: keyCode, modifiers: modifiers)
      }
    }
```

por:

```swift
    // Después de los atajos de dictado: Finder, Capturas y Alt-Tab.
    eventTap.onKeyDown = { [weak self] keyCode, modifiers in
      MainActor.assumeIsolated {
        guard let self else { return false }
        return self.finderCutter.keyDown(keyCode: keyCode, modifiers: modifiers)
          || self.captures.keyDown(keyCode: keyCode, modifiers: modifiers)
          || self.altTab.keyDown(keyCode: keyCode, modifiers: modifiers)
      }
    }
    eventTap.onModifiersChanged = { [weak self] modifiers in
      MainActor.assumeIsolated { self?.altTab.modifiersChanged(modifiers) }
    }
```

Y cambiar:

```swift
    guard eventTap.start() else { return false }
```

por:

```swift
    guard eventTap.start() else { return false }
    // Solo con el teclado escuchándose: si no, apagar el ⌘Tab de macOS dejaría sin ninguno.
    altTab.start()
```

- [ ] **Step 5: `AppDelegate`: el ⌘Tab de macOS vuelve al salir**

En `Sources/Sintecla/AppDelegate.swift`, cambiar:

```swift
  private func showOnboarding() {
```

por:

```swift
  /// El ⌘Tab de macOS vuelve siempre al salir, aunque Alt-Tab estuviera encendido.
  func applicationWillTerminate(_ notification: Notification) {
    NativeAppSwitcher.setEnabled(true)
  }

  private func showOnboarding() {
```

- [ ] **Step 6: Compilar la release (sin avisos)**

Run:

```bash
source scripts/sdk-env.sh && swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build complete' | grep -v 'ld: warning: search path' | tail -3
```

Esperado: `Build complete!`.

- [ ] **Step 7: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 300 tests in 54 suites passed`.

- [ ] **Step 8: Commit**

```bash
git add Sources/Sintecla/WindowSwitcherPanel.swift Sources/Sintecla/AltTabController.swift Sources/Sintecla/EventTap.swift Sources/Sintecla/DictationController.swift Sources/Sintecla/AppDelegate.swift
git commit -m 'feat: selector de ventanas con ⌘Tab

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 5: Versión 0.12.0, README y spec principal

**Files:**
- Modify: `Sources/SinteclaCoreTests/SmokeTests.swift`, `Sources/SinteclaCore/AppInfo.swift` y `Resources/Info.plist`
- Modify: `README.md` y `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§7)

**Interfaces:**
- Consumes: Todo lo anterior.
- Produces: La versión 0.12.0 (build 13), instalada.

La línea «Estado» de la spec principal y la etiqueta `v0.12.0` se ponen al cerrar la versión, cuando el usuario lo pida.

- [ ] **Step 1: El test de la versión**

En `Sources/SinteclaCoreTests/SmokeTests.swift`, cambiar:

```swift
#expect(AppInfo.version == "0.11.0")
```

por:

```swift
#expect(AppInfo.version == "0.12.0")
```

- [ ] **Step 2: Ver que falla**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA el test con `Expectation failed: AppInfo.version == "0.12.0"`.

- [ ] **Step 3: `AppInfo.version`**

En `Sources/SinteclaCore/AppInfo.swift`, cambiar:

```swift
public static let version = "0.11.0"
```

por:

```swift
public static let version = "0.12.0"
```

- [ ] **Step 4: `Info.plist`**

En `Resources/Info.plist`, cambiar:

```xml
  <key>CFBundleShortVersionString</key><string>0.11.0</string>
  <key>CFBundleVersion</key><string>12</string>
```

por:

```xml
  <key>CFBundleShortVersionString</key><string>0.12.0</string>
  <key>CFBundleVersion</key><string>13</string>
```

- [ ] **Step 5: Ver que pasa**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 300 tests in 54 suites passed`.

- [ ] **Step 6: README: el módulo Alt-Tab**

En `README.md`, cambiar:

```text
| **Y además** |
```

por:

```text
| **Alt-Tab** | ⌘Tab cambia de ventana, no de app, como en Windows: un panel con una miniatura de cada ventana del escritorio, por uso reciente (las minimizadas al final). Con ⌘ pulsado, Tab y las flechas eligen; al soltar, salta. Sustituye al ⌘Tab de macOS mientras está encendido. |
| **Y además** |
```

Y cambiar:

```text
Dictado, Reuniones, Finder y Capturas son **módulos**: se encienden y se apagan en la página **Módulos** de la ventana de Sintecla, y uno apagado desaparece del menú y deja de funcionar. Finder y Capturas vienen apagados.
```

por:

```text
Dictado, Reuniones, Finder, Capturas y Alt-Tab son **módulos**: se encienden y se apagan en la página **Módulos** de la ventana de Sintecla, y uno apagado desaparece del menú y deja de funcionar. Finder, Capturas y Alt-Tab vienen apagados.
```

Y cambiar:

```text
`⌘S` guarda (`⇧⌘S`, Guardar como…) y `⌘P` fija la captura en pantalla.
```

por:

```text
`⌘S` guarda (`⇧⌘S`, Guardar como…) y `⌘P` fija la captura en pantalla.

Con el módulo Alt-Tab encendido: `⌘Tab` abre el selector de ventanas (`⇧⌘Tab`, hacia atrás); con `⌘` pulsado, `Tab`, `⇧Tab` y las flechas mueven la marca, `Esc` cierra y al soltar `⌘` salta a la ventana marcada.
```

- [ ] **Step 7: Spec principal (§7): el selector de ventanas**

En `docs/superpowers/specs/2026-09-23-sintecla-design.md`, cambiar:

```text
Módulos** (un interruptor por módulo: Dictado, Reuniones, Finder y Capturas; los dos últimos, apagados de fábrica)
```

por:

```text
Módulos** (un interruptor por módulo: Dictado, Reuniones, Finder, Capturas y Alt-Tab; los tres últimos, apagados de fábrica)
```

Y cambiar:

```text
`) y **Capturas** (permiso de Grabación de pantalla y atajos, ver `2026-09-25-capturas-design.md`)
```

por:

```text
`), **Capturas** (permiso de Grabación de pantalla y atajos, ver `2026-09-25-capturas-design.md`) y **Alt-Tab** (cómo se usa y permisos, ver `2026-10-03-alt-tab-design.md`)
```

Y cambiar:

```text
- **Editor de capturas** (desde la 0.10.0
```

por:

```text
- **Selector de ventanas** (desde la 0.12.0, módulo Alt-Tab, ⌘Tab): panel de cristal en el centro de la pantalla del ratón con una tarjeta por ventana (miniatura, icono y título), por uso reciente y con las minimizadas al final. Sustituye al ⌘Tab de macOS mientras el módulo está encendido.
- **Editor de capturas** (desde la 0.10.0
```

- [ ] **Step 8: Compilar la release (sin avisos)**

Run:

```bash
source scripts/sdk-env.sh && swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build complete' | grep -v 'ld: warning: search path' | tail -3
```

Esperado: `Build complete!`.

- [ ] **Step 9: Commit**

```bash
git add Sources/SinteclaCoreTests/SmokeTests.swift Sources/SinteclaCore/AppInfo.swift Resources/Info.plist README.md docs/superpowers/specs/2026-09-23-sintecla-design.md
git commit -m 'feat: versión 0.12.0 con el módulo Alt-Tab

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

- [ ] **Step 10: Instalar la versión nueva**

Run:

```bash
scripts/build-app.sh
```

Esperado: `✅ Instalada en /Applications/Sintecla.app`. El módulo viene apagado: se enciende en Módulos.

---
### Task 6: Aceptación a mano

**Files:**
- —

**Interfaces:**
- Consumes: La app instalada (Tarea 5).
- Produces: Nada nuevo. Con todo ✓: DockDoor a la Papelera (lo pidió el usuario el 2026-10-03) y la 0.12.0 se cierra cuando el usuario lo pida.

La hace el usuario (spec §8.2).

- [ ] **Step 1: Checklist. Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | Módulos → encender Alt-Tab; ⌘Tab manteniendo ⌘ | Sale el selector de Sintecla (no el de macOS), con la ventana anterior marcada |
| 2 | Un toque rápido de ⌘Tab, varias veces | Alterna entre las dos últimas ventanas, sin parpadeo |
| 3 | Dos ventanas de la misma app (por ejemplo, Safari) | Salen las dos y se salta a la elegida |
| 4 | Con ⌘ pulsado: Tab, ⇧Tab, ← →, Esc | Mueven la marca dando la vuelta; Esc cierra sin cambiar nada |
| 5 | Pasar el ratón por las tarjetas y hacer clic | Marca y salta |
| 6 | Minimizar una ventana y abrir el selector | Sale al final, atenuada; al elegirla, se restaura |
| 7 | Miniaturas | Todas las ventanas visibles tienen la suya |
| 8 | Saltar a una ventana de otra app y escribir | Queda delante y con el teclado |
| 9 | Apagar Alt-Tab y pulsar ⌘Tab | Vuelve el selector de macOS |
| 10 | Dictado, Finder, Capturas y el resto | Como antes |

---
## Autorrevisión frente a la especificación

| Requisito (spec «Alt-Tab») | Dónde |
|---|---|
| §2 Módulo apagado de fábrica; permisos; página con el uso, los permisos y el aviso de ⌘Tab; tarjeta de Inicio; sin bloque en el menú | Tarea 2 |
| §3 ⌘Tab y ⇧⌘Tab; Tab, ⇧Tab, flechas, Esc y ratón; soltar ⌘; cambio rápido de 150 ms; sin ventanas, nada | Tareas 1 y 4 |
| §4 Escritorio actual por uso, minimizadas al final, filtros, título o app | Tareas 1 y 3 |
| §5 Panel de cristal, tarjetas de 200 puntos y hasta 6 por fila, marcada resaltada, minimizadas atenuadas, iconos y luego miniaturas | Tareas 3 y 4 |
| §6 Restaurar, activar la app y subir la ventana | Tarea 3 |
| §7 Piezas y 0.12.0 (build 13) | Tareas 1 a 5 |
| §8.1 Tests de teclas, orden, ventana marcada y módulo | Tareas 1 y 2 |
| §8.2 Aceptación | Tarea 6 |
| §8.3 Riesgos: ⌘Tab de macOS, activación cooperativa, miniaturas lentas, apps colgadas | Tareas 3 y 4 |
| §9 DockDoor a la Papelera tras la aceptación | Tarea 6 |

**Consistencia de tipos revisada:**
- `AltTabShortcut.key(keyCode:modifiers:isOpen:)` y `AltTabKey` (Tarea 1) los usa `AltTabController.keyDown` (Tarea 4).
- `SwitcherWindow` y `WindowSwitcherOrder.arrange` (Tarea 1) los usa `WindowCatalog.refresh` (Tarea 3).
- `SwitcherState` (Tarea 1) lo usa `AltTabController` (Tarea 4).
- `AppSettings.moduleAltTab` (Tarea 2) lo lee `AltTabController` (Tarea 4).
- `WindowCatalog.focus(_:)` y `WindowThumbnails.capture(_:maxSide:each:)` (Tarea 3) los usa `AltTabController` (Tarea 4).
