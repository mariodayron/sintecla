# Sintecla — Módulos y menú por bloques (0.10.0, plan 1) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Organizar Sintecla por módulos (Dictado, Reuniones y Finder), todavía sin batería:
- la ventana abre en un Inicio con una tarjeta por módulo;
- dentro de cada módulo, la barra lateral enseña solo sus páginas;
- una página Módulos enciende y apaga cada uno;
- el menú de la barra se ordena por bloques.

**Architecture:**
- **En el núcleo (`SinteclaCore`), puro y con tests:**
  - `Module` y `ModulePage`: qué módulos hay y qué páginas tiene cada uno;
  - `ModuleSwitches`: cuáles están encendidos;
  - `WindowPlace`: dónde está la ventana; una página de un módulo apagado vuelve a Inicio;
  - `HomeSummary`: los textos de las tarjetas.
- **En la app:**
  - `MainView` pasa de una barra lateral fija a Inicio → módulo;
  - las páginas de ahora se mueven, no se rehacen;
  - `MenuBar` pone una cabecera por módulo encendido;
  - `DictationController` deja de atender los atajos con Dictado apagado y no empieza reuniones con Reuniones apagado.

**Tech Stack:** Lo de siempre:
- Swift 6.3 de las Command Line Tools, en modo de lenguaje 5;
- SwiftPM, Swift Testing, SwiftUI (Liquid Glass de macOS 26) y AppKit (`NSMenu`).

**Especificación:** `docs/superpowers/specs/2026-09-25-bateria-modulos-design.md` (§2, §3, §8, §9.3 y §10, plan 1).

**Punto de partida:** la rama `bateria` (sale de `main` en `v0.9.0` y lleva la especificación):

```bash
git checkout bateria
```

## Global Constraints

- **Todo lo de antes sigue vigente:**
  - macOS 26.0 o superior, Apple Silicon.
  - Sin Xcode ni dependencias externas; todos los targets en `.swiftLanguageMode(.v5)`.
  - Tests con `swift run sintecla-tests` (**nunca `swift test`**).
  - Textos visibles en español.
  - La release compila sin avisos.
- **Módulos del plan 1:** Dictado, Reuniones y Finder, en ese orden. Batería llega con el plan 2 y no aparece en este.
- **De fábrica y al actualizar desde la 0.9.0:**
  - Dictado y Reuniones, encendidos (UserDefaults `moduleDictation` y `moduleMeetings`, `true`);
  - Finder, como estuviera `finderCut`, que pasa a ser su interruptor.
- **Módulo apagado:** desaparecen su tarjeta, sus páginas y su bloque del menú, y deja de funcionar.
  - **Dictado:** no funciona ningún atajo de la tecla base, tampoco el de reunión.
  - **Reuniones:** no se empieza ninguna; la que esté en curso se puede terminar.
  - **Finder:** ⌘X y ⌘V, como siempre.
- **Páginas:**
  - Dictado: Historial · Estadísticas · Diccionario · Tonos · IA · Atajos e idioma;
  - Reuniones: Reuniones (con «Guardar también el audio»);
  - Finder: Cortar y pegar.
- **General:** abrir al iniciar sesión, sonidos y «Revisar permisos…». Susurro, idioma, «Traducir a», tecla base y atajos pasan a Dictado → Atajos e idioma.
- **Menú de la barra:** sigue siendo un menú de macOS (spec §3.2, cambio del plan 1):
  - arriba, «Sintecla: lista · Micrófono: X» o «faltan permisos», con «Revisar permisos…»;
  - un bloque con cabecera por módulo encendido (Dictado, Reuniones);
  - pie: Abrir Sintecla… (⌘O) · Ajustes… (⌘,) · Salir (⌘Q).
- **Versión:** sigue en 0.9.0. La 0.10.0 se pone en el plan 3.
- **Commits:** en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código de este plan se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `bateria`: compiló, pasó los tests en cada tarea y el árbol final quedó idéntico al del prototipo.

- **245 tests** (44 suites) en verde: los 236 de antes y 9 nuevos (`ModulesTests`). La release compila sin avisos.
- **La interfaz no tiene tests propios.** La ventana y el menú se comprueban compilando y en la aceptación a mano (Tarea 4).
- **`UsageStats.uses(on:)` ya existía, pero era privada.** Inicio la necesita para «N dictados hoy» y se hace pública.

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| Un panel propio (NSPanel) tendría que activar Sintecla para recibir el teclado, y «Pegar último resultado» pegaría en Sintecla | El menú sigue siendo `NSMenu`, con `NSMenuItem.sectionHeader` por bloque. La spec se corrige en la Tarea 3 |
| Si se apaga el módulo de la página que está a la vista, la ventana quedaría en una página que ya no existe | `WindowPlace.resolved(with:)` la manda a Inicio (Tarea 1, test `pageOfATurnedOffModuleGoesHome`) |
| En la tarjeta de Reuniones, un botón dentro de otro botón no funciona | La tarjeta usa `onTapGesture` y el botón «Grabar reunión» va dentro (Tarea 2) |
| `settings.modules[x] = …` reescribiría los tres interruptores | El `set` de `AppSettings.modules` solo toca los que cambian (Tarea 2) |
| Con Dictado apagado a media grabación, la máquina de atajos se quedaría a medias | El atajo solo se ignora en reposo: lo que se está grabando termina (Tarea 3) |

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/Modules.swift`, `Sources/SinteclaCoreTests/ModulesTests.swift` | Módulos, páginas, interruptores, dónde está la ventana y textos de Inicio | 1 |
| `Sources/SinteclaCore/UsageStats.swift` | `uses(on:)` pública | 1 |
| `Sources/Sintecla/AppSettings.swift` | `moduleDictation`, `moduleMeetings` y `modules` | 2 |
| `Sources/Sintecla/MainWindow.swift` | `MainNavigation` con `WindowPlace`, `MainView` (Inicio → módulo) y `MeetingsPage` | 2 |
| `Sources/Sintecla/HomeView.swift` | Inicio con tarjetas y la página Módulos | 2 |
| `Sources/Sintecla/DictationSettingsTab.swift` | Dictado → Atajos e idioma (lo que sale de General) | 2 |
| `Sources/Sintecla/Windows.swift` | `GeneralTab`, más corta | 2 |
| `Sources/Sintecla/FinderCutPage.swift` (antes `ToolsTab.swift`) | Finder → Cortar y pegar | 2 |
| `Sources/Sintecla/AppDelegate.swift` | Enlaces a las páginas nuevas y «Revisar permisos…» | 2 |
| `Sources/Sintecla/MenuBar.swift` | Menú por bloques | 3 |
| `Sources/Sintecla/DictationController.swift` | Dictado y Reuniones apagados de verdad | 3 |
| `docs/superpowers/specs/2026-09-25-bateria-modulos-design.md` | §3.2: menú por bloques en vez de panel | 3 |

---

### Task 1: Los módulos en el núcleo

**Files:**
- Create: `Sources/SinteclaCore/Modules.swift`
- Modify: `Sources/SinteclaCore/UsageStats.swift` (`uses(on:calendar:)` pública)
- Test: `Sources/SinteclaCoreTests/ModulesTests.swift`

**Interfaces:**
- Consumes: `MeetingRecord` (`Sources/SinteclaCore/MeetingStore.swift`); `UsageStats`, `HistoryEntry`.
- Produces: `Module` (`.dictation`, `.meetings`, `.finder`; `name`, `symbol`, `detail`, `pages`); `ModulePage` (`.history`, `.stats`, `.dictionary`, `.tones`, `.ai`, `.hotkeys`, `.meetings`, `.finderCut`; `module`, `title`, `symbol`); `ModuleSwitches(dictation:meetings:finder:)`, con `subscript(Module) -> Bool` y `enabled: [Module]`; `WindowPlace` (`.home`, `.general`, `.modules`, `.page(ModulePage)`; `module: Module?`, `resolved(with: ModuleSwitches) -> WindowPlace`); `HomeSummary.dictation(uses:words:) -> String`, `HomeSummary.meetings(_:now:) -> String`; `UsageStats.uses(on: Date, calendar: Calendar = .current) -> Int`.

Todo lo que decide qué se ve, sin SwiftUI. La app (Tareas 2 y 3) solo lo pinta.

- [ ] **Step 1: Tests de los módulos**

Crear `Sources/SinteclaCoreTests/ModulesTests.swift`:

```swift
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct ModulesTests {
  let allOn = ModuleSwitches(dictation: true, meetings: true, finder: true)

  @Test func eachPageBelongsToItsModule() {
    #expect(Module.dictation.pages == [.history, .stats, .dictionary, .tones, .ai, .hotkeys])
    #expect(Module.meetings.pages == [.meetings])
    #expect(Module.finder.pages == [.finderCut])
    for module in Module.allCases {
      #expect(module.pages.allSatisfy { $0.module == module })
    }
    #expect(ModulePage.allCases.count == Module.allCases.map(\.pages.count).reduce(0, +))
  }

  @Test func namesInSpanish() {
    #expect(Module.allCases.map(\.name) == ["Dictado", "Reuniones", "Finder"])
    #expect(ModulePage.hotkeys.title == "Atajos e idioma")
    #expect(ModulePage.finderCut.title == "Cortar y pegar")
  }

  @Test func enabledModulesKeepTheirOrder() {
    #expect(allOn.enabled == [.dictation, .meetings, .finder])
    #expect(ModuleSwitches(dictation: false, meetings: true, finder: true).enabled == [.meetings, .finder])
    #expect(ModuleSwitches(dictation: false, meetings: false, finder: false).enabled == [])
  }

  @Test func switchesCanBeReadAndChangedByModule() {
    var switches = allOn
    switches[.meetings] = false
    #expect(!switches[.meetings])
    #expect(switches[.dictation] && switches[.finder])
  }

  @Test func pageOfATurnedOffModuleGoesHome() {
    let noDictation = ModuleSwitches(dictation: false, meetings: true, finder: false)
    #expect(WindowPlace.page(.history).resolved(with: noDictation) == .home)
    #expect(WindowPlace.page(.finderCut).resolved(with: noDictation) == .home)
    #expect(WindowPlace.page(.meetings).resolved(with: noDictation) == .page(.meetings))
    #expect(WindowPlace.general.resolved(with: noDictation) == .general)
    #expect(WindowPlace.modules.resolved(with: noDictation) == .modules)
  }

  @Test func placeKnowsItsModule() {
    #expect(WindowPlace.page(.tones).module == .dictation)
    #expect(WindowPlace.home.module == nil)
    #expect(WindowPlace.general.module == nil)
  }

  @Test func dictationSummary() {
    #expect(HomeSummary.dictation(uses: 0, words: 0) == "Aún no has dictado hoy")
    #expect(HomeSummary.dictation(uses: 1, words: 1) == "1 dictado · 1 palabra hoy")
    #expect(HomeSummary.dictation(uses: 12, words: 840) == "12 dictados · 840 palabras hoy")
  }

  @Test func meetingsSummaryCountsThisWeekAndPending() {
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let day: TimeInterval = 86_400
    let records = [
      MeetingRecord(id: "a", startedAt: now - 1 * day, status: .ready),
      MeetingRecord(id: "b", startedAt: now - 6 * day, status: .ready),
      MeetingRecord(id: "c", startedAt: now - 8 * day, status: .ready),  // hace más de 7 días
      MeetingRecord(id: "d", startedAt: now - 2 * day, status: .pending),
      MeetingRecord(id: "e", startedAt: now - 20 * day, status: .pending),  // pendiente: cuenta aunque sea antigua
      MeetingRecord(id: "f", startedAt: now, status: .recording),
    ]
    #expect(HomeSummary.meetings(records, now: now) == "2 actas esta semana · 2 pendientes")
    #expect(HomeSummary.meetings([records[0]], now: now) == "1 acta esta semana")
    #expect(HomeSummary.meetings([], now: now) == "Sin actas esta semana")
    #expect(HomeSummary.meetings([records[3]], now: now) == "Sin actas esta semana · 1 pendiente")
  }

  @Test func usesOnADay() {
    let calendar = Calendar(identifier: .gregorian)
    let date = Date(timeIntervalSince1970: 1_790_000_000)
    var stats = UsageStats()
    for text in ["hola qué tal", "otra cosa"] {
      stats.add(HistoryEntry(date: date, mode: .dictation, appBundleID: nil, appName: nil, language: "es_ES",
                             audioSeconds: 2, rawText: text, finalText: text, engine: "rules", latencyMs: 10),
                calendar: calendar)
    }
    #expect(stats.uses(on: date, calendar: calendar) == 2)
    #expect(stats.uses(on: date + 86_400 * 2, calendar: calendar) == 0)
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find 'ModuleSwitches' in scope`.

- [ ] **Step 3: Módulos, páginas, interruptores, dónde está la ventana y textos de Inicio**

Crear `Sources/SinteclaCore/Modules.swift`:

```swift
import Foundation

/// Los módulos de Sintecla (spec «Módulos y batería» §2). Cada uno se enciende o se apaga en la página Módulos.
public enum Module: String, CaseIterable, Sendable {
  case dictation, meetings, finder

  public var name: String {
    switch self {
    case .dictation: "Dictado"
    case .meetings: "Reuniones"
    case .finder: "Finder"
    }
  }

  public var symbol: String {
    switch self {
    case .dictation: "waveform"
    case .meetings: "person.2.wave.2"
    case .finder: "folder"
    }
  }

  /// Lo que hace, para la página Módulos.
  public var detail: String {
    switch self {
    case .dictation: "Dictado, traducción, Ask Anything y notas con la tecla base."
    case .meetings: "Graba videollamadas y te deja el acta en PDF."
    case .finder: "⌘X corta los archivos seleccionados y ⌘V los mueve a la carpeta abierta, como en Windows."
    }
  }

  /// Las páginas del módulo en la barra lateral, en orden.
  public var pages: [ModulePage] { ModulePage.allCases.filter { $0.module == self } }
}

public enum ModulePage: String, CaseIterable, Hashable, Sendable {
  case history, stats, dictionary, tones, ai, hotkeys
  case meetings
  case finderCut

  public var module: Module {
    switch self {
    case .history, .stats, .dictionary, .tones, .ai, .hotkeys: .dictation
    case .meetings: .meetings
    case .finderCut: .finder
    }
  }

  public var title: String {
    switch self {
    case .history: "Historial"
    case .stats: "Estadísticas"
    case .dictionary: "Diccionario"
    case .tones: "Tonos"
    case .ai: "IA"
    case .hotkeys: "Atajos e idioma"
    case .meetings: "Reuniones"
    case .finderCut: "Cortar y pegar"
    }
  }

  public var symbol: String {
    switch self {
    case .history: "clock.arrow.circlepath"
    case .stats: "chart.bar"
    case .dictionary: "book"
    case .tones: "textformat"
    case .ai: "sparkles"
    case .hotkeys: "keyboard"
    case .meetings: "person.2.wave.2"
    case .finderCut: "scissors"
    }
  }
}

/// Qué módulos están encendidos.
public struct ModuleSwitches: Equatable, Sendable {
  public var dictation: Bool
  public var meetings: Bool
  public var finder: Bool

  public init(dictation: Bool, meetings: Bool, finder: Bool) {
    self.dictation = dictation
    self.meetings = meetings
    self.finder = finder
  }

  public subscript(module: Module) -> Bool {
    get {
      switch module {
      case .dictation: dictation
      case .meetings: meetings
      case .finder: finder
      }
    }
    set {
      switch module {
      case .dictation: dictation = newValue
      case .meetings: meetings = newValue
      case .finder: finder = newValue
      }
    }
  }

  /// Los módulos encendidos, en el orden de `Module.allCases`.
  public var enabled: [Module] { Module.allCases.filter { self[$0] } }
}

/// Dónde está la ventana de Sintecla: Inicio, General, Módulos o una página de un módulo.
public enum WindowPlace: Hashable, Sendable {
  case home, general, modules
  case page(ModulePage)

  public var module: Module? {
    if case .page(let page) = self { return page.module }
    return nil
  }

  /// Una página de un módulo apagado no se puede ver: vuelve a Inicio.
  public func resolved(with switches: ModuleSwitches) -> WindowPlace {
    if let module, !switches[module] { return .home }
    return self
  }
}

/// Los resúmenes de las tarjetas de Inicio.
public enum HomeSummary {
  public static func dictation(uses: Int, words: Int) -> String {
    guard uses > 0 else { return "Aún no has dictado hoy" }
    return "\(uses) \(uses == 1 ? "dictado" : "dictados") · \(words) \(words == 1 ? "palabra" : "palabras") hoy"
  }

  /// Actas listas de los últimos 7 días y reuniones pendientes (de cuando sean).
  public static func meetings(_ records: [MeetingRecord], now: Date = Date()) -> String {
    let weekAgo = now.addingTimeInterval(-7 * 86_400)
    let ready = records.filter { $0.status == .ready && $0.startedAt > weekAgo && $0.startedAt <= now }.count
    let pending = records.filter { $0.status == .pending }.count
    var text = ready == 0 ? "Sin actas esta semana" : "\(ready) \(ready == 1 ? "acta" : "actas") esta semana"
    if pending > 0 { text += " · \(pending) \(pending == 1 ? "pendiente" : "pendientes")" }
    return text
  }
}
```

- [ ] **Step 4: Ver que falla solo lo de `uses(on:)`**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: 'uses' is inaccessible due to 'private' protection level`.

- [ ] **Step 5: `UsageStats.uses(on:)` pública**

En `Sources/SinteclaCore/UsageStats.swift`, cambiar:

```swift
  private func uses(on day: Date, calendar: Calendar) -> Int {
```

por:

```swift
  /// Usos de un día (tarjeta de Dictado en Inicio y rachas).
  public func uses(on day: Date, calendar: Calendar = .current) -> Int {
```

- [ ] **Step 6: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 245 tests in 44 suites passed`.

- [ ] **Step 7: Commit**

```bash
git add Sources/SinteclaCore/Modules.swift Sources/SinteclaCoreTests/ModulesTests.swift Sources/SinteclaCore/UsageStats.swift
git commit -m 'feat: módulos, páginas y textos de Inicio en el núcleo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: La ventana por módulos

**Files:**
- Modify: `Sources/Sintecla/AppSettings.swift`
- Modify: `Sources/Sintecla/MainWindow.swift` (`MainSection` y `MainNavigation` → `WindowPlace`; `MainView`; `MeetingsPage`; `show(_:)`)
- Create: `Sources/Sintecla/HomeView.swift`
- Create: `Sources/Sintecla/DictationSettingsTab.swift`
- Modify: `Sources/Sintecla/Windows.swift` (`GeneralTab`)
- Rename + Modify: `Sources/Sintecla/ToolsTab.swift` → `Sources/Sintecla/FinderCutPage.swift`
- Modify: `Sources/Sintecla/AppDelegate.swift`

**Interfaces:**
- Consumes: Todo lo de la Tarea 1. Las páginas que ya existen: `HistoryView`, `StatsView`, `DictionaryTab`, `TonesTab`, `AITab`, `MeetingsView`; `MeetingActions`, `MeetingLibrary`, `.usageChanged`.
- Produces: `AppSettings.moduleDictation`, `moduleMeetings` y `modules: ModuleSwitches` (con `set`); `MainNavigation.place: WindowPlace`; `MainWindowController.show(_ place: WindowPlace? = nil)`; `MainView(…, showPermissions:, onSettingsChange:)`; `HomeView`, `ModulesView`, `DictationSettingsTab`, `MeetingsPage`, `FinderCutPage`; `GeneralTab(settings:showPermissions:onChange:)`.

La ventana abre en Inicio. Al pulsar una tarjeta se entra en el módulo, con `NavigationSplitView` y solo sus páginas. Inicio, General y Módulos van en un `NavigationStack` sin barra lateral. Las páginas de antes no cambian por dentro.

- [ ] **Step 1: Los interruptores de módulo en `AppSettings`**

En `Sources/Sintecla/AppSettings.swift`, cambiar:

```swift
  /// Herramientas: cortar y pegar archivos en Finder con ⌘X y ⌘V. Apagada por defecto, como todas las herramientas.
  var finderCut: Bool { didSet { defaults.set(finderCut, forKey: "finderCut") } }
```

por:

```swift
  /// Módulo Finder: cortar y pegar archivos con ⌘X y ⌘V. Apagado por defecto.
  var finderCut: Bool { didSet { defaults.set(finderCut, forKey: "finderCut") } }
  /// Módulos Dictado y Reuniones (spec «Módulos y batería» §2), encendidos por defecto.
  var moduleDictation: Bool { didSet { defaults.set(moduleDictation, forKey: "moduleDictation") } }
  var moduleMeetings: Bool { didSet { defaults.set(moduleMeetings, forKey: "moduleMeetings") } }
```

Y cambiar:

```swift
      "finderCut": false,
    ])
```

por:

```swift
      "finderCut": false, "moduleDictation": true, "moduleMeetings": true,
    ])
```

Y cambiar:

```swift
    finderCut = defaults.bool(forKey: "finderCut")
```

por:

```swift
    finderCut = defaults.bool(forKey: "finderCut")
    moduleDictation = defaults.bool(forKey: "moduleDictation")
    moduleMeetings = defaults.bool(forKey: "moduleMeetings")
```

Y cambiar:

```swift
  /// Guarda la clave en el Llavero (o la borra si llega vacía). Devuelve false si no se pudo guardar.
```

por:

```swift
  /// Qué módulos están encendidos. Finder es el interruptor `finderCut` de la 0.9.0.
  var modules: ModuleSwitches {
    get { ModuleSwitches(dictation: moduleDictation, meetings: moduleMeetings, finder: finderCut) }
    set {
      if moduleDictation != newValue.dictation { moduleDictation = newValue.dictation }
      if moduleMeetings != newValue.meetings { moduleMeetings = newValue.meetings }
      if finderCut != newValue.finder { finderCut = newValue.finder }
    }
  }

  /// Guarda la clave en el Llavero (o la borra si llega vacía). Devuelve false si no se pudo guardar.
```

- [ ] **Step 2: `MainView`: Inicio → módulo, con `WindowPlace`**

En `Sources/Sintecla/MainWindow.swift`, cambiar:

```swift
enum MainSection: String, Hashable {
  case meetings, history, stats, general, dictionary, tones, ai, tools
}

@MainActor @Observable
final class MainNavigation {
  var section: MainSection? = .meetings
}
```

por:

```swift
@MainActor @Observable
final class MainNavigation {
  var place: WindowPlace = .home
}
```

Y cambiar:

```swift
/// Ventana principal: barra lateral de Liquid Glass (nativa en macOS 26) con Reuniones, Historial, Estadísticas y Ajustes.
struct MainView: View {
  @Bindable var navigation: MainNavigation
  @Bindable var settings: AppSettings
  let history: HistoryStore
  let usage: UsageStatsStore
  let meetings: MeetingLibrary
  let meetingActions: MeetingActions
  var onSettingsChange: () -> Void

  var body: some View {
    NavigationSplitView {
      List(selection: $navigation.section) {
        Label("Reuniones", systemImage: "person.2.wave.2").tag(MainSection.meetings)
        Label("Historial", systemImage: "clock.arrow.circlepath").tag(MainSection.history)
        Label("Estadísticas", systemImage: "chart.bar").tag(MainSection.stats)
        Section("Ajustes") {
          Label("General", systemImage: "gearshape").tag(MainSection.general)
          Label("Diccionario", systemImage: "book").tag(MainSection.dictionary)
          Label("Tonos", systemImage: "textformat").tag(MainSection.tones)
          Label("IA", systemImage: "sparkles").tag(MainSection.ai)
          Label("Herramientas", systemImage: "wrench.and.screwdriver").tag(MainSection.tools)
        }
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
    } detail: {
      detail
    }
    .frame(minWidth: 820, minHeight: 560)
    .tint(.gray)  // sin colores: selección, interruptores y botones en gris neutro
  }

  @ViewBuilder private var detail: some View {
    switch navigation.section ?? .meetings {
    case .meetings: MeetingsView(library: meetings, actions: meetingActions).navigationTitle("Reuniones")
    case .history: HistoryView(store: history).navigationTitle("Historial")
    case .stats: StatsView(store: usage).navigationTitle("Estadísticas")
    case .general: GeneralTab(settings: settings, onChange: onSettingsChange).navigationTitle("General")
    case .dictionary: DictionaryTab(settings: settings).navigationTitle("Diccionario")
    case .tones: TonesTab(settings: settings).navigationTitle("Tonos")
    case .ai: AITab(settings: settings, history: history).navigationTitle("IA")
    case .tools: ToolsTab(settings: settings).navigationTitle("Herramientas")
    }
  }
}
```

por:

```swift
/// Ventana principal (spec «Módulos y batería» §3.1): Inicio con una tarjeta por módulo; dentro de un módulo, barra
/// lateral de Liquid Glass (nativa en macOS 26) solo con sus páginas.
struct MainView: View {
  @Bindable var navigation: MainNavigation
  @Bindable var settings: AppSettings
  let history: HistoryStore
  let usage: UsageStatsStore
  let meetings: MeetingLibrary
  let meetingActions: MeetingActions
  var showPermissions: () -> Void
  var onSettingsChange: () -> Void

  var body: some View {
    let place = navigation.place.resolved(with: settings.modules)
    Group {
      if let module = place.module {
        NavigationSplitView {
          sidebar(module)
        } detail: {
          detail(place)
        }
      } else {
        NavigationStack { detail(place) }
      }
    }
    .frame(minWidth: 820, minHeight: 560)
    .tint(.gray)  // sin colores: selección, interruptores y botones en gris neutro
  }

  private func sidebar(_ module: Module) -> some View {
    List(selection: pageSelection) {
      Button { navigation.place = .home } label: { Label("Inicio", systemImage: "chevron.backward") }
        .buttonStyle(.plain)
      Section(module.name) {
        ForEach(module.pages, id: \.self) { page in
          Label(page.title, systemImage: page.symbol).tag(page)
        }
      }
    }
    .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
  }

  private var pageSelection: Binding<ModulePage?> {
    Binding(get: { if case .page(let page) = navigation.place { page } else { nil } },
            set: { if let page = $0 { navigation.place = .page(page) } })
  }

  @ViewBuilder private func detail(_ place: WindowPlace) -> some View {
    switch place {
    case .home:
      HomeView(settings: settings, usage: usage, meetings: meetings, meetingActions: meetingActions, navigation: navigation)
        .navigationTitle("Sintecla")
    case .general:
      GeneralTab(settings: settings, showPermissions: showPermissions, onChange: onSettingsChange)
        .navigationTitle("General")
        .toolbar { backHome }
    case .modules:
      ModulesView(settings: settings)
        .navigationTitle("Módulos")
        .toolbar { backHome }
    case .page(let page):
      pageView(page).navigationTitle(page.title)
    }
  }

  private var backHome: some ToolbarContent {
    ToolbarItem(placement: .navigation) {
      Button { navigation.place = .home } label: { Label("Inicio", systemImage: "chevron.backward") }
    }
  }

  @ViewBuilder private func pageView(_ page: ModulePage) -> some View {
    switch page {
    case .history: HistoryView(store: history)
    case .stats: StatsView(store: usage)
    case .dictionary: DictionaryTab(settings: settings)
    case .tones: TonesTab(settings: settings)
    case .ai: AITab(settings: settings, history: history)
    case .hotkeys: DictationSettingsTab(settings: settings, onChange: onSettingsChange)
    case .meetings: MeetingsPage(library: meetings, actions: meetingActions, settings: settings)
    case .finderCut: FinderCutPage()
    }
  }
}

/// Reuniones → Reuniones: la lista y, abajo, dónde se guardan y si se guarda también el audio.
struct MeetingsPage: View {
  let library: MeetingLibrary
  let actions: MeetingActions
  @Bindable var settings: AppSettings

  var body: some View {
    VStack(spacing: 0) {
      MeetingsView(library: library, actions: actions)
      Divider()
      HStack {
        Toggle("Guardar también el audio de las reuniones", isOn: $settings.saveMeetingAudio)
        Spacer()
        Text("Actas en Documentos › Sintecla › Reuniones").font(.caption).foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16).padding(.vertical, 10)
    }
  }
}
```

Y cambiar:

```swift
  func show(_ section: MainSection? = nil) {
    if let section { navigation.section = section }
```

por:

```swift
  func show(_ place: WindowPlace? = nil) {
    if let place { navigation.place = place }
```

- [ ] **Step 3: Inicio con tarjetas y la página Módulos**

Crear `Sources/Sintecla/HomeView.swift`:

```swift
import SinteclaCore
import SwiftUI

/// Inicio (spec «Módulos y batería» §3.1): una tarjeta por módulo encendido con su resumen; al pulsarla se entra en
/// el módulo. Abajo, General y Módulos.
struct HomeView: View {
  @Bindable var settings: AppSettings
  let usage: UsageStatsStore
  let meetings: MeetingLibrary
  let meetingActions: MeetingActions
  let navigation: MainNavigation
  @State private var stats = UsageStats()

  var body: some View {
    let modules = settings.modules.enabled
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if modules.isEmpty {
          ContentUnavailableView {
            Label("Sin módulos", systemImage: "square.grid.2x2")
          } description: {
            Text("Enciende algún módulo para empezar.")
          }
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
            ForEach(modules, id: \.self) { card($0) }
          }
        }
        HStack {
          Spacer()
          Button { navigation.place = .general } label: { Label("General", systemImage: "gearshape") }
          Button { navigation.place = .modules } label: { Label("Módulos", systemImage: "square.grid.2x2") }
        }
        .buttonStyle(.glass)
      }
      .padding(24)
    }
    .onAppear { stats = usage.current }
    .onReceive(NotificationCenter.default.publisher(for: .usageChanged)) { _ in stats = usage.current }
  }

  private func card(_ module: Module) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(module.name, systemImage: module.symbol).font(.title3.weight(.semibold))
      summary(module)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
    .padding(16)
    .contentShape(RoundedRectangle(cornerRadius: 18))
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
    .onTapGesture { if let first = module.pages.first { navigation.place = .page(first) } }
  }

  @ViewBuilder private func summary(_ module: Module) -> some View {
    let now = Date()
    switch module {
    case .dictation:
      Text(HomeSummary.dictation(uses: stats.uses(on: now), words: stats.words(on: now))).foregroundStyle(.secondary)
    case .meetings:
      Text(HomeSummary.meetings(meetings.records, now: now)).foregroundStyle(.secondary)
      Button(action: meetingActions.toggle) {
        Label(meetings.recordingSince == nil ? "Grabar reunión" : "Detener",
              systemImage: meetings.recordingSince == nil ? "record.circle" : "stop.circle.fill")
      }
      .buttonStyle(.glass)
    case .finder:
      Text("⌘X corta y ⌘V mueve archivos en Finder").foregroundStyle(.secondary)
    }
  }
}

/// Módulos: un interruptor por módulo. Uno apagado desaparece de Inicio y del menú, y deja de funcionar.
struct ModulesView: View {
  @Bindable var settings: AppSettings

  var body: some View {
    Form {
      Section {
        ForEach(Module.allCases, id: \.self) { module in
          Toggle(isOn: Binding(get: { settings.modules[module] }, set: { settings.modules[module] = $0 })) {
            Label {
              VStack(alignment: .leading, spacing: 2) {
                Text(module.name)
                Text(module.detail).font(.caption).foregroundStyle(.secondary)
              }
            } icon: {
              Image(systemName: module.symbol)
            }
          }
        }
      } footer: {
        Text("Un módulo apagado desaparece de Inicio y del menú, y deja de funcionar. Con Dictado apagado no funciona "
             + "ningún atajo de la tecla base, tampoco el de reunión: las reuniones se graban desde el menú o Inicio.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}
```

- [ ] **Step 4: Dictado → Atajos e idioma: lo que sale de General**

Crear `Sources/Sintecla/DictationSettingsTab.swift`:

```swift
import SinteclaCore
import SwiftUI

/// Dictado → Atajos e idioma: lo que era del dictado en General hasta la 0.9.0.
struct DictationSettingsTab: View {
  @Bindable var settings: AppSettings
  var onChange: () -> Void

  var body: some View {
    Form {
      Toggle("Modo susurro (más ganancia de micrófono)", isOn: $settings.whisperMode)
      Picker("Idioma de dictado", selection: $settings.language) {
        Text("Español (España)").tag("es_ES")
        Text("English (US)").tag("en_US")
      }
      Picker("Traducir a", selection: $settings.translationTarget) {
        ForEach(TranslationLanguage.allCases, id: \.self) { Text($0.name).tag($0) }
      }
      Picker("Tecla base", selection: $settings.baseKey) {
        Text("🌐 Fn").tag(BaseKey.fn)
        Text("⌥ derecha").tag(BaseKey.rightOption)
        Text("Las dos (🌐 o ⌥ derecha)").tag(BaseKey.both)
      }
      Text("Algunos teclados externos (p. ej. Logitech) no envían su tecla Fn al Mac: con ellos usa ⌥ derecha.")
        .font(.caption).foregroundStyle(.secondary)
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

- [ ] **Step 5: General se queda con lo común**

En `Sources/Sintecla/Windows.swift`, cambiar:

```swift
struct GeneralTab: View {
  @Bindable var settings: AppSettings
  var onChange: () -> Void

  var body: some View {
    Form {
      Toggle("Abrir Sintecla al iniciar sesión", isOn: $settings.launchAtLogin)
      Toggle("Sonidos", isOn: $settings.soundsEnabled)
      Toggle("Modo susurro (más ganancia de micrófono)", isOn: $settings.whisperMode)
      Picker("Idioma de dictado", selection: $settings.language) {
        Text("Español (España)").tag("es_ES")
        Text("English (US)").tag("en_US")
      }
      Picker("Traducir a", selection: $settings.translationTarget) {
        ForEach(TranslationLanguage.allCases, id: \.self) { Text($0.name).tag($0) }
      }
      Picker("Tecla base", selection: $settings.baseKey) {
        Text("🌐 Fn").tag(BaseKey.fn)
        Text("⌥ derecha").tag(BaseKey.rightOption)
        Text("Las dos (🌐 o ⌥ derecha)").tag(BaseKey.both)
      }
      Text("Algunos teclados externos (p. ej. Logitech) no envían su tecla Fn al Mac: con ellos usa ⌥ derecha.")
        .font(.caption).foregroundStyle(.secondary)
      Section("Reuniones") {
        Toggle("Guardar también el audio de las reuniones", isOn: $settings.saveMeetingAudio)
        LabeledContent("Actas", value: "Documentos › Sintecla › Reuniones")
      }
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

por:

```swift
/// General (spec «Módulos y batería» §2): lo común a todos los módulos.
struct GeneralTab: View {
  @Bindable var settings: AppSettings
  var showPermissions: () -> Void
  var onChange: () -> Void

  var body: some View {
    Form {
      Toggle("Abrir Sintecla al iniciar sesión", isOn: $settings.launchAtLogin)
      Toggle("Sonidos", isOn: $settings.soundsEnabled)
      Section("Permisos") {
        Button("Revisar permisos…", action: showPermissions)
        Text("Micrófono, Accesibilidad y Monitorización de entrada.").font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .onChange(of: settings.launchAtLogin) { onChange() }
    .onChange(of: settings.soundsEnabled) { onChange() }
  }
}
```

- [ ] **Step 6: `ToolsTab.swift` pasa a ser la página de Finder**

Run:

```bash
git mv Sources/Sintecla/ToolsTab.swift Sources/Sintecla/FinderCutPage.swift
```

- [ ] **Step 7: Finder → Cortar y pegar (el interruptor ya está en Módulos)**

Sustituir todo el contenido de `Sources/Sintecla/FinderCutPage.swift`:

```swift
import SwiftUI

/// Finder → Cortar y pegar (spec «Herramientas» §2). Se enciende y se apaga en Módulos; aquí se explica cómo va.
struct FinderCutPage: View {
  var body: some View {
    Form {
      Section("Cómo funciona") {
        LabeledContent("⌘X", value: "Corta los archivos seleccionados")
        LabeledContent("⌘V", value: "Los mueve a la carpeta abierta, también a otro disco")
        Text("Al renombrar, en el buscador o en «Ir a la carpeta», ⌘X y ⌘V cortan y pegan texto como siempre. "
             + "Si copias otra cosa después de cortar, ⌘V pega lo copiado y los archivos no se mueven.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}
```

- [ ] **Step 8: `AppDelegate`: «Revisar permisos…» y los enlaces a Historial y Reuniones**

En `Sources/Sintecla/AppDelegate.swift`, cambiar:

```swift
                                                    retry: { [unowned self] in controller.retryMeeting($0) }),
                     onSettingsChange: { [unowned self] in
```

por:

```swift
                                                    retry: { [unowned self] in controller.retryMeeting($0) }),
                     showPermissions: { [unowned self] in showOnboarding() },
                     onSettingsChange: { [unowned self] in
```

Y cambiar:

```swift
      showMeetings: { [weak self] in self?.mainWindow.show(.meetings) },
      showHistory: { [weak self] in self?.mainWindow.show(.history) },
```

por:

```swift
      showMeetings: { [weak self] in self?.mainWindow.show(.page(.meetings)) },
      showHistory: { [weak self] in self?.mainWindow.show(.page(.history)) },
```

- [ ] **Step 9: Compilar la release (sin avisos)**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build of product' | tail -3
```

Esperado: `Build of product 'Sintecla' complete!`.

Si sale alguna línea `warning:`, corrígela antes de seguir.

- [ ] **Step 10: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 245 tests in 44 suites passed`.

- [ ] **Step 11: Commit**

```bash
git add Sources/Sintecla/AppSettings.swift Sources/Sintecla/MainWindow.swift Sources/Sintecla/HomeView.swift Sources/Sintecla/DictationSettingsTab.swift Sources/Sintecla/Windows.swift Sources/Sintecla/FinderCutPage.swift Sources/Sintecla/AppDelegate.swift
git commit -m 'feat: ventana por módulos con Inicio, Módulos y General

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: Menú por bloques y módulos apagados de verdad

**Files:**
- Modify: `Sources/Sintecla/MenuBar.swift` (`MenuBarController`)
- Modify: `Sources/Sintecla/DictationController.swift` (`handle(_:)`, `toggleMeeting()`)
- Modify: `docs/superpowers/specs/2026-09-25-bateria-modulos-design.md` (§1, §2, §3.2, §4.1, §5.1, §8, §9.3, §10)

**Interfaces:**
- Consumes: `AppSettings.modules`, `moduleDictation` y `moduleMeetings` (Tarea 2); `MenuActions` y `ClosureMenuItem` (ya existen).
- Produces: El menú con una cabecera por módulo encendido. Con Dictado apagado no hay atajos de la tecla base; con Reuniones apagado no se empieza ninguna.

El menú sigue siendo un `NSMenu`, no un panel: así «Pegar último resultado» pega en la app de delante. La especificación decía «panel» y se corrige aquí, con el porqué.

- [ ] **Step 1: El menú por bloques, uno por módulo encendido**

En `Sources/Sintecla/MenuBar.swift`, cambiar:

```swift
/// Icono de la barra de menú y su menú (se reconstruye cada vez que se abre).
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let settings: AppSettings
  private let actions: MenuActions
  var isReady = false

  init(settings: AppSettings, actions: MenuActions) {
    self.settings = settings
    self.actions = actions
    super.init()
    setRecording(false)
    let menu = NSMenu()
    menu.delegate = self
    statusItem.menu = menu
  }

  func setRecording(_ recording: Bool) {
    statusItem.button?.image = BrandMarkRenderer.menuImage(recording: recording)
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()
    let status = NSMenuItem(title: isReady ? "Sintecla: lista" : "Sintecla: faltan permisos", action: nil, keyEquivalent: "")
    status.isEnabled = false
    menu.addItem(status)
    // El micrófono lo elige macOS (Ajustes del Sistema → Sonido → Entrada); Sintecla usa ese.
    let microphone = NSMenuItem(title: "Micrófono: \(AudioDevices.defaultInputName() ?? "ninguno")",
                                action: nil, keyEquivalent: "")
    microphone.isEnabled = false
    menu.addItem(microphone)
    menu.addItem(.separator())

    let languageItem = NSMenuItem(title: "Idioma de dictado", action: nil, keyEquivalent: "")
    let languageMenu = NSMenu()
    for (code, name) in [("es_ES", "Español (España)"), ("en_US", "English (US)")] {
      languageMenu.addItem(ClosureMenuItem(name, checked: settings.language == code) { [weak self] in
        self?.settings.language = code
        self?.actions.settingsChanged()
      })
    }
    languageItem.submenu = languageMenu
    menu.addItem(languageItem)
    menu.addItem(ClosureMenuItem("Modo susurro", checked: settings.whisperMode) { [weak self] in
      guard let self else { return }
      self.settings.whisperMode.toggle()
      self.actions.settingsChanged()
    })
    let targetItem = NSMenuItem(title: "Traducir a", action: nil, keyEquivalent: "")
    let targetMenu = NSMenu()
    for target in TranslationLanguage.allCases {
      targetMenu.addItem(ClosureMenuItem(target.name, checked: settings.translationTarget == target) { [weak self] in
        self?.settings.translationTarget = target
      })
    }
    targetItem.submenu = targetMenu
    menu.addItem(targetItem)
    menu.addItem(.separator())
    if let since = actions.meetingSince() {
      let minutes = Int(Date().timeIntervalSince(since) / 60)
      menu.addItem(ClosureMenuItem("■ Detener reunión (\(minutes) min)", handler: actions.toggleMeeting))
    } else {
      menu.addItem(ClosureMenuItem("● Grabar reunión", handler: actions.toggleMeeting))
    }
    let pendingMeetings = actions.pendingMeetings()
    if pendingMeetings > 0 {
      menu.addItem(ClosureMenuItem("Reuniones pendientes (\(pendingMeetings))…", handler: actions.showMeetings))
    }
    menu.addItem(.separator())
    menu.addItem(ClosureMenuItem("Pegar último resultado", handler: actions.pasteLast))
    menu.addItem(ClosureMenuItem("Añadir selección al diccionario", handler: actions.addToDictionary))
    let pending = actions.pendingNotes()
    if pending > 0 {
      menu.addItem(ClosureMenuItem("Notas sin procesar (\(pending))…", handler: actions.showPendingNotes))
    }
    menu.addItem(ClosureMenuItem("Abrir Sintecla…", key: "o", handler: actions.showMain))
    menu.addItem(ClosureMenuItem("Historial…", handler: actions.showHistory))
    menu.addItem(ClosureMenuItem("Ajustes…", key: ",", handler: actions.showSettings))
    menu.addItem(ClosureMenuItem("Permisos…", handler: actions.showPermissions))
    menu.addItem(.separator())
    menu.addItem(ClosureMenuItem("Salir de Sintecla", key: "q") { NSApp.terminate(nil) })
  }
}
```

por:

```swift
/// Icono de la barra de menú y su menú, por bloques: uno por módulo encendido (spec «Módulos y batería» §3.2).
/// Es un menú de macOS (se reconstruye cada vez que se abre): «Pegar último resultado» pega en la app de delante,
/// y Esc, los atajos y cerrar al pulsar fuera son los de siempre.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let settings: AppSettings
  private let actions: MenuActions
  var isReady = false

  init(settings: AppSettings, actions: MenuActions) {
    self.settings = settings
    self.actions = actions
    super.init()
    setRecording(false)
    let menu = NSMenu()
    menu.delegate = self
    statusItem.menu = menu
  }

  func setRecording(_ recording: Bool) {
    statusItem.button?.image = BrandMarkRenderer.menuImage(recording: recording)
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()
    // El micrófono lo elige macOS (Ajustes del Sistema → Sonido → Entrada); Sintecla usa ese.
    let microphone = AudioDevices.defaultInputName() ?? "ninguno"
    let status = NSMenuItem(title: isReady ? "Sintecla: lista · Micrófono: \(microphone)" : "Sintecla: faltan permisos",
                            action: nil, keyEquivalent: "")
    status.isEnabled = false
    menu.addItem(status)
    if !isReady { menu.addItem(ClosureMenuItem("Revisar permisos…", handler: actions.showPermissions)) }

    let modules = settings.modules
    if modules.dictation { addDictation(to: menu) }
    if modules.meetings { addMeetings(to: menu) }

    menu.addItem(.separator())
    menu.addItem(ClosureMenuItem("Abrir Sintecla…", key: "o", handler: actions.showMain))
    menu.addItem(ClosureMenuItem("Ajustes…", key: ",", handler: actions.showSettings))
    menu.addItem(ClosureMenuItem("Salir de Sintecla", key: "q") { NSApp.terminate(nil) })
  }

  private func addDictation(to menu: NSMenu) {
    menu.addItem(.separator())
    menu.addItem(.sectionHeader(title: "Dictado"))
    let languageItem = NSMenuItem(title: "Idioma de dictado", action: nil, keyEquivalent: "")
    let languageMenu = NSMenu()
    for (code, name) in [("es_ES", "Español (España)"), ("en_US", "English (US)")] {
      languageMenu.addItem(ClosureMenuItem(name, checked: settings.language == code) { [weak self] in
        self?.settings.language = code
        self?.actions.settingsChanged()
      })
    }
    languageItem.submenu = languageMenu
    menu.addItem(languageItem)
    let targetItem = NSMenuItem(title: "Traducir a", action: nil, keyEquivalent: "")
    let targetMenu = NSMenu()
    for target in TranslationLanguage.allCases {
      targetMenu.addItem(ClosureMenuItem(target.name, checked: settings.translationTarget == target) { [weak self] in
        self?.settings.translationTarget = target
      })
    }
    targetItem.submenu = targetMenu
    menu.addItem(targetItem)
    menu.addItem(ClosureMenuItem("Modo susurro", checked: settings.whisperMode) { [weak self] in
      guard let self else { return }
      self.settings.whisperMode.toggle()
      self.actions.settingsChanged()
    })
    menu.addItem(ClosureMenuItem("Pegar último resultado", handler: actions.pasteLast))
    menu.addItem(ClosureMenuItem("Añadir selección al diccionario", handler: actions.addToDictionary))
    let pending = actions.pendingNotes()
    if pending > 0 {
      menu.addItem(ClosureMenuItem("Notas sin procesar (\(pending))…", handler: actions.showPendingNotes))
    }
    menu.addItem(ClosureMenuItem("Historial…", handler: actions.showHistory))
  }

  private func addMeetings(to menu: NSMenu) {
    menu.addItem(.separator())
    menu.addItem(.sectionHeader(title: "Reuniones"))
    if let since = actions.meetingSince() {
      let minutes = Int(Date().timeIntervalSince(since) / 60)
      menu.addItem(ClosureMenuItem("■ Detener reunión (\(minutes) min)", handler: actions.toggleMeeting))
    } else {
      menu.addItem(ClosureMenuItem("● Grabar reunión", handler: actions.toggleMeeting))
    }
    let pendingMeetings = actions.pendingMeetings()
    if pendingMeetings > 0 {
      menu.addItem(ClosureMenuItem("Reuniones pendientes (\(pendingMeetings))…", handler: actions.showMeetings))
    }
  }
}
```

- [ ] **Step 2: Dictado y Reuniones apagados dejan de funcionar**

En `Sources/Sintecla/DictationController.swift`, cambiar:

```swift
    if case .escape = event, card.isVisible, machine.state == .idle {
      card.close()
      return true
    }
```

por:

```swift
    if case .escape = event, card.isVisible, machine.state == .idle {
      card.close()
      return true
    }
    // Con el módulo Dictado apagado no hay atajos de la tecla base (tampoco el de reunión). Lo que se esté grabando
    // termina con normalidad.
    if !settings.moduleDictation, machine.state == .idle { return false }
```

Y cambiar:

```swift
  func toggleMeeting() {
    if recorder.isRecording { stopMeeting() } else { startMeeting() }
  }
```

por:

```swift
  /// Con el módulo Reuniones apagado no se empieza ninguna; la que esté en curso sí se puede terminar.
  func toggleMeeting() {
    if recorder.isRecording { stopMeeting() } else if settings.moduleMeetings { startMeeting() }
  }
```

- [ ] **Step 3: La especificación: menú por bloques en lugar de panel**

En `docs/superpowers/specs/2026-09-25-bateria-modulos-design.md`, cambiar:

```text
   - El menú de la barra pasa a ser un panel con un bloque por módulo.
```

por:

```text
   - El menú de la barra se ordena por bloques, uno por módulo.
```

Y cambiar:

```text
  - desaparecen su tarjeta, sus páginas y su bloque del panel;
```

por:

```text
  - desaparecen su tarjeta, sus páginas y su bloque del menú;
```

Y cambiar:

```text
## 3. Ventana y panel del menú
```

por:

```text
## 3. Ventana y menú de la barra
```

Y cambiar:

```text
### 3.2 Panel del menú

El icono de Sintecla en la barra de menú abre un **panel** en lugar del menú de ahora. El icono sigue igual: en reposo o grabando.

- **Arriba:** una línea con el estado («Sintecla: lista» o «faltan permisos») y el micrófono.
```

por:

```text
### 3.2 Menú de la barra

El icono de Sintecla abre su menú, **ordenado por bloques**: una cabecera por módulo encendido. El icono sigue igual: en reposo o grabando.

- **Cambio respecto al diseño aprobado (plan 1):** es un menú de macOS, no un panel propio.
  - Un panel tendría que activar Sintecla para recibir el teclado, y entonces «Pegar último resultado» pegaría en Sintecla y no en la app de delante.
  - Con el menú, Esc, los atajos y cerrar al pulsar fuera son los de macOS.
  - El bloque de Batería (plan 2) lleva una vista propia dentro del menú para el deslizador y los botones.
- **Arriba:** una línea con el estado («Sintecla: lista» o «faltan permisos») y el micrófono. Si faltan permisos, debajo, «Revisar permisos…».
```

Y cambiar:

```text
    - «Notas sin procesar (N)…», si hay.
  - **Reuniones:**
```

por:

```text
    - «Notas sin procesar (N)…», si hay;
    - «Historial…».
  - **Reuniones:**
```

Y cambiar:

```text
- **Pie:** Abrir Sintecla… (⌘O) · Ajustes… (⌘,) · Salir (⌘Q). Los atajos funcionan con el panel abierto.
- **Cerrar:** el panel se cierra al pulsar fuera o con Esc.
```

por:

```text
- **Pie:** Abrir Sintecla… (⌘O) · Ajustes… (⌘,) · Salir (⌘Q).
```

Y cambiar:

```text
módulo apagado, sin ayudante, AlDente funcionando o Mac no compatible. El panel dice el motivo |
```

por:

```text
módulo apagado, sin ayudante, AlDente funcionando o Mac no compatible. El menú dice el motivo |
```

Y cambiar:

```text
| App | `Sintecla` | Cliente del socket, instalador, páginas de Batería, bloque del panel, enlaces
```

por:

```text
| App | `Sintecla` | Cliente del socket, instalador, páginas de Batería, bloque del menú, enlaces
```

Y cambiar:

```text
| Panel del menú | App | Sustituye el `NSMenu` de `MenuBar.swift`: SwiftUI en un panel anclado al icono |
```

por:

```text
| Menú por bloques | App | `MenuBar.swift`: una cabecera por módulo encendido (`NSMenuItem.sectionHeader`). El bloque de Batería (plan 2) lleva una vista propia para el deslizador y los botones |
```

Y cambiar:

```text
- El panel del menú hace todo lo del menú de antes.
```

por:

```text
- El menú por bloques hace todo lo del menú de antes.
```

Y cambiar:

```text
1. **Ventana por módulos y panel del menú** (§2, §3).
```

por:

```text
1. **Ventana por módulos y menú por bloques** (§2, §3).
```

Y cambiar:

```text
las páginas Estado, Carga y Ajustes, y el bloque del panel.
```

por:

```text
las páginas Estado, Carga y Ajustes, y el bloque del menú.
```

- [ ] **Step 4: Compilar la release (sin avisos)**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build of product' | tail -3
```

Esperado: `Build of product 'Sintecla' complete!`.

- [ ] **Step 5: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 245 tests in 44 suites passed`.

- [ ] **Step 6: Commit**

```bash
git add Sources/Sintecla/MenuBar.swift Sources/Sintecla/DictationController.swift docs/superpowers/specs/2026-09-25-bateria-modulos-design.md
git commit -m 'feat: menú por bloques y módulos que se apagan de verdad

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

- [ ] **Step 7: Instalar la versión nueva**

Run:

```bash
scripts/build-app.sh
```

Esperado: `✅ Instalada en /Applications/Sintecla.app`. Sigue diciendo 0.9.0: la versión cambia en el plan 3.

---
### Task 4: Aceptación a mano

**Files:**
- —

**Interfaces:**
- Consumes: La app instalada (Tarea 3).
- Produces: Nada nuevo. Con todo ✓, se sigue con el plan 2 (batería básica) en la misma rama.

La hace el usuario (spec §9.3, plan 1).

- [ ] **Step 1: Checklist. Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | Abrir Sintecla (menú → Abrir Sintecla…) | Inicio con las tarjetas Dictado (dictados y palabras de hoy), Reuniones (actas de la semana y el botón de grabar) y Finder si está encendido. Abajo, General y Módulos |
| 2 | Pulsar cada tarjeta | Se entra en el módulo: la barra lateral enseña solo sus páginas y, arriba, «Inicio» para volver |
| 3 | Recorrer las páginas de Dictado | Historial, Estadísticas, Diccionario, Tonos e IA como antes; Atajos e idioma con susurro, idioma, «Traducir a», tecla base y atajos |
| 4 | Reuniones → Reuniones | La lista y, abajo, «Guardar también el audio» |
| 5 | General | Abrir al iniciar sesión, Sonidos y «Revisar permisos…», que abre la ventana de permisos |
| 6 | Módulos: apagar Finder | Desaparece su tarjeta, y ⌘X en Finder no hace nada, como en macOS. Volver a encenderlo |
| 7 | Módulos: apagar Reuniones | Desaparecen la tarjeta y el bloque del menú, y el atajo de reunión no hace nada. Volver a encenderlo |
| 8 | Módulos: apagar Dictado | Desaparecen la tarjeta y el bloque del menú, y la tecla base no dicta. Volver a encenderlo: dicta otra vez |
| 9 | Abrir el menú de la barra | Arriba, «Sintecla: lista · Micrófono: …». Bloques Dictado y Reuniones con cabecera. Pie: Abrir Sintecla… (⌘O), Ajustes… (⌘,), Salir (⌘Q) |
| 10 | En una app de texto: menú → «Pegar último resultado» | Pega en esa app, como antes |
| 11 | Menú → Historial… y Ajustes… | Abren Dictado → Historial y General |
| 12 | Dictar, traducir, Ask Anything y grabar una reunión corta | Todo como en la 0.9.0 |

---
## Autorrevisión frente a la especificación (plan 1)

| Requisito (spec «Módulos y batería») | Dónde |
|---|---|
| §2 Módulos Dictado, Reuniones y Finder, con sus páginas; Batería queda para el plan 2 | Tarea 1 (`Module`, `ModulePage`) |
| §2 Página Módulos; un módulo apagado no se ve ni funciona | Tarea 2 (`ModulesView`, `MainView`) y Tarea 3 (`DictationController`, menú) |
| §2 Al actualizar: Dictado y Reuniones encendidos, Finder = `finderCut` | Tarea 2 (`AppSettings`) |
| §2 General con lo común; el dictado pasa a Atajos e idioma | Tarea 2 (`GeneralTab`, `DictationSettingsTab`) |
| §3.1 Inicio con tarjetas y resúmenes; General y Módulos; dentro de un módulo, solo sus páginas y «Inicio» | Tareas 1 (`HomeSummary`, `WindowPlace`) y 2 (`HomeView`, `MainView`) |
| §3.1 Del menú a la ventana: Historial…, Ajustes…, Reuniones pendientes | Tarea 2 (`AppDelegate`) |
| §3.2 Menú por bloques (cambio: menú de macOS, no panel) | Tarea 3 |
| §9.3 Aceptación del plan 1 | Tarea 4 |

**Consistencia de tipos revisada:**
- `ModuleSwitches` y `WindowPlace` (Tarea 1) los usan `AppSettings.modules`, `MainView`, `HomeView`, `ModulesView` (Tarea 2) y `MenuBarController` (Tarea 3).
- `HomeSummary.dictation(uses:words:)` usa `UsageStats.uses(on:)` y `words(on:)`. `HomeSummary.meetings(_:now:)` usa `MeetingLibrary.records`.
- `MainWindowController.show(_:)` recibe `WindowPlace`: `.general` (`MainMenu`, Ajustes…), `.page(.history)` y `.page(.meetings)`.
