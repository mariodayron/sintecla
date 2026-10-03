# Sintecla — Vistas del Dock (0.13.0) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** al pasar el ratón por el icono de una app abierta en el Dock, ver sus ventanas con una miniatura de cada una y saltar a una, cerrarla o minimizarla. Sustituye a DockDoor.

**Architecture:**
- **En el núcleo, con tests:** `DockItem` (qué icono es una app), `DockEdge` y `DockPreviewPlacement` (de qué lado está el Dock y dónde va la vista) y `DockHoverTimer` (cuándo aparece y cuándo se va).
- **En la app:**
  - `DockWatcher` escucha el Dock por Accesibilidad: el icono que tiene el ratón, su app y su sitio;
  - `WindowCatalog` (de Alt-Tab) da las ventanas de una sola app, y ahora también las cierra y las minimiza;
  - `WindowCard` es la tarjeta de Alt-Tab, compartida, con los botoncitos;
  - `DockPreviewPanel` es la vista de cristal y `DockPreviewController` lo une todo.

**Tech Stack:** Lo de siempre:
- Swift 6.4 de las Command Line Tools 27, en modo de lenguaje 5;
- SwiftPM, Swift Testing, SwiftUI y AppKit;
- además, Accesibilidad (`AXUIElement`, `AXObserver`), `CGWindowListCopyWindowInfo` y ScreenCaptureKit.

**Especificación:** `docs/superpowers/specs/2026-10-03-dock-vistas-design.md`.

**Punto de partida:** la rama `dock` (sale de `main` en la 0.12.0, con la especificación):

```bash
git checkout dock
```

## Global Constraints

- **Todo lo de antes sigue vigente:**
  - macOS 26.0 o superior, Apple Silicon.
  - Sin Xcode ni dependencias externas; modo de lenguaje 5.
  - Tests con `swift run sintecla-tests` (**nunca `swift test`**).
  - Textos visibles en español.
  - La release compila sin avisos.
- **Compilar la app con las Command Line Tools 27:** con el SDK de macOS 26, mediante `source scripts/sdk-env.sh` (lo hace `build-app.sh`). Los avisos `ld: warning: search path …` los pone SwiftPM y no cuentan.
- **Módulo «Dock»:** UserDefaults `moduleDock`, **apagado de fábrica**. Es el sexto en Módulos, con el símbolo `dock.rectangle`.
- **Tiempos:** la vista aparece a los **0,3 s**; con ella abierta, otro icono cambia al momento; fuera del icono y de la vista se va a los **0,25 s**.
- **Ventanas:** las mismas que Alt-Tab, solo las de esa app (escritorio actual y, al final, las minimizadas atenuadas).
- **Vista:** junto al icono, hacia dentro de la pantalla, a **36 puntos** (deja libre el nombre que pone el Dock), centrada y corrida si no cabe (8 puntos de margen). Tarjetas de **240 puntos**, en fila (Dock abajo) o en columna (Dock a un lado), más pequeñas si no caben en el 80 % de la pantalla.
- **Acciones:** clic salta (y la vista se va); en la tarjeta marcada, botones de 24 puntos para cerrar (la ventana), minimizar o restaurar (la vista sigue) y **salir de la app** como ⌘Q (la vista se va). Esc, un clic fuera o Alt-Tab la cierran.
- **Versión:** 0.13.0 (build 14).
- **Commits:** en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `dock`: compiló, pasó los tests en cada tarea y el árbol final quedó idéntico al del prototipo.

- **315 tests** (55 suites) en verde: los 300 de antes y 15 nuevos. La release compila sin avisos (aparte de los `ld: warning: search path` de SwiftPM).
- **El aviso del Dock en macOS 27.0.1,** probado en el Mac del usuario desde Sintecla, con el ratón movido por el programa:
  - el `AXList` del Dock avisa con `kAXSelectedChildrenChangedNotification` en cada icono, con su `AXSubrole`, su `AXURL` y su sitio;
  - el aviso se repite para el mismo icono mientras la lupa lo mueve;
  - **no avisa al salir del Dock, ni al volver al mismo icono.**
- **La vista de verdad,** con el módulo encendido y el ratón movido por el programa:
  - a los 0,15 s aún no sale; a los 1,25 s, sí (capa 101, encima del icono);
  - de Safari a Claude y a Finder cambia al momento; fuera del Dock, se va;
  - minimizar, restaurar, saltar con un clic, cerrar una ventana (la vista sigue con las que quedan) y Esc funcionan.

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| El Dock no avisa al salir el ratón | Mientras la vista espera o está abierta, se mira el ratón cada 50 ms (`tick`) |
| El Dock no avisa si el ratón vuelve al mismo icono | Un monitor de movimiento del ratón compara con el sitio del último icono (solo un rectángulo, sin Accesibilidad) |
| Tras Esc o un clic, el aviso repetido del Dock volvía a sacar la vista | `DockHoverTimer.cancel()` deja ese icono callado hasta que el ratón sale de él |
| A los 0,4 s de minimizar, macOS aún da la lista vieja y los botones actuaban sobre otra ventana | Se relee cada 150 ms hasta que la lista cambia y se queda igual dos veces seguidas (1,8 s como mucho) |
| Al cerrar una ventana la vista se encoge y el ratón queda fuera, así que se iba | El sitio anterior de la vista cuenta como dentro hasta que el ratón sale de él |
| Accesibilidad mide desde arriba y AppKit desde abajo | `DockPreviewPlacement.screenRect(fromAccessibility:primaryHeight:)` |
| Con la lupa, el sitio del icono cambia | Se lee en cada `tick` |
| Si el Dock se reinicia, el aviso se pierde | `DockWatcher` se vuelve a apuntar cuando el Dock arranca |

**Cambios que pidió el usuario al ver el prototipo (2026-10-03), ya en la spec:**
- Tarjetas más grandes: 240 puntos en lugar de 160, y botones de 24.
- Un botón para salir de la app (⏻, como ⌘Q). Quita «salir de la app» de los no-objetivos.
- La vista a 36 puntos del icono, para no tapar el nombre que pone el Dock.

**Decisiones de este plan que la spec no fijaba:**
- **El lado del Dock** sale del borde de la pantalla más cercano al icono, sin `AXOrientation`: funciona igual con la lupa.
- **Tras Esc o un clic,** la vista no vuelve a salir para ese icono hasta que el ratón sale de él.
- **Esc** solo se lo queda Sintecla con la vista abierta y sin modificadoras.

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/DockPreview.swift`, `Sources/SinteclaCoreTests/DockPreviewTests.swift` | Iconos, lado del Dock, sitio de la vista y tiempos | 1 |
| `Sources/SinteclaCore/Modules.swift`, `Sources/SinteclaCoreTests/ModulesTests.swift`, `Sources/Sintecla/AppSettings.swift`, `Sources/Sintecla/DockPage.swift`, `Sources/Sintecla/HomeView.swift`, `Sources/Sintecla/MainWindow.swift` | El módulo, su página y su tarjeta | 2 |
| `Sources/Sintecla/WindowCatalog.swift`, `Sources/Sintecla/WindowCard.swift`, `Sources/Sintecla/WindowSwitcherPanel.swift` | Ventanas de una app, cerrar, minimizar y la tarjeta compartida | 3 |
| `Sources/Sintecla/DockWatcher.swift`, `Sources/Sintecla/DockPreviewPanel.swift`, `Sources/Sintecla/DockPreviewController.swift`, `Sources/Sintecla/AltTabController.swift`, `Sources/Sintecla/DictationController.swift` | La vista del Dock | 4 |
| `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`, `Sources/SinteclaCoreTests/SmokeTests.swift`, `README.md`, `docs/superpowers/specs/2026-09-23-sintecla-design.md` | 0.13.0 | 5 |

---

### Task 1: Vistas del Dock en el núcleo: iconos, sitio y tiempos

**Files:**
- Create: `Sources/SinteclaCore/DockPreview.swift`
- Test: `Sources/SinteclaCoreTests/DockPreviewTests.swift`

**Interfaces:**
- Consumes: Nada de otras tareas.
- Produces: `DockPreview.summary` y `DockPreview.cardWidth`; `DockItem(subrole:url:)` (falla si no es una app) con `appURL`; `DockEdge(icon:screen:)` (`.bottom`, `.left`, `.right`); `DockPreviewPlacement.screenRect(fromAccessibility:primaryHeight:)` y `.frame(panel:icon:edge:screen:) -> CGRect`; `DockHoverTimer<Item>` con `hover(_:at:)`, `tick(inside:at:)` (devuelven `.none`, `.show(Item)` o `.hide`), `cancel()`, `shown: Item?` e `isActive`.

Todo lo que se puede probar sin el Dock de verdad: qué iconos son apps, de qué lado está el Dock, dónde va la vista y los tiempos de aparecer y desaparecer.

- [ ] **Step 1: Tests: iconos, coordenadas, lado del Dock, sitio de la vista y tiempos**

Crear `Sources/SinteclaCoreTests/DockPreviewTests.swift`:

```swift
import CoreGraphics
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct DockPreviewTests {
  // MARK: Iconos del Dock

  @Test func onlyApplicationItemsWithAnAppAreApps() {
    let safari = URL(fileURLWithPath: "/Applications/Safari.app")
    #expect(DockItem(subrole: "AXApplicationDockItem", url: safari)?.appURL == safari)
    #expect(DockItem(subrole: "AXFolderDockItem", url: URL(fileURLWithPath: "/Users/x/Downloads")) == nil)
    #expect(DockItem(subrole: "AXTrashDockItem", url: nil) == nil)
    #expect(DockItem(subrole: "AXSeparatorDockItem", url: nil) == nil)
    #expect(DockItem(subrole: "AXApplicationDockItem", url: nil) == nil)
    #expect(DockItem(subrole: "AXApplicationDockItem", url: URL(string: "https://example.com")) == nil)
  }

  // MARK: Coordenadas y lado del Dock

  @Test func accessibilityRectsAreFlippedToScreenCoordinates() {
    // Accesibilidad mide desde arriba a la izquierda de la pantalla principal; AppKit, desde abajo.
    let ax = CGRect(x: 1053, y: 1352, width: 67, height: 83)
    #expect(DockPreviewPlacement.screenRect(fromAccessibility: ax, primaryHeight: 1440)
              == CGRect(x: 1053, y: 5, width: 67, height: 83))
  }

  private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

  @Test func dockSideIsTheNearestScreenEdge() {
    #expect(DockEdge(icon: CGRect(x: 700, y: 4, width: 60, height: 60), screen: screen) == .bottom)
    #expect(DockEdge(icon: CGRect(x: 4, y: 400, width: 60, height: 60), screen: screen) == .left)
    #expect(DockEdge(icon: CGRect(x: 1376, y: 400, width: 60, height: 60), screen: screen) == .right)
    // Con la lupa el icono crece, pero sigue pegado a su borde.
    #expect(DockEdge(icon: CGRect(x: 700, y: 4, width: 120, height: 120), screen: screen) == .bottom)
  }

  // MARK: Dónde va la vista

  private let panel = CGSize(width: 400, height: 150)

  @Test func withTheDockAtTheBottomTheViewGoesAboveTheIconCentered() {
    // 36 puntos por encima del icono: el nombre que pone el Dock queda libre.
    let icon = CGRect(x: 700, y: 4, width: 60, height: 60)
    let frame = DockPreviewPlacement.frame(panel: panel, icon: icon, edge: .bottom, screen: screen)
    #expect(frame == CGRect(x: 530, y: 100, width: 400, height: 150))
  }

  @Test func withTheDockAtASideTheViewGoesInwards() {
    let left = CGRect(x: 4, y: 400, width: 60, height: 60)
    #expect(DockPreviewPlacement.frame(panel: panel, icon: left, edge: .left, screen: screen)
              == CGRect(x: 100, y: 355, width: 400, height: 150))
    let right = CGRect(x: 1376, y: 400, width: 60, height: 60)
    #expect(DockPreviewPlacement.frame(panel: panel, icon: right, edge: .right, screen: screen)
              == CGRect(x: 940, y: 355, width: 400, height: 150))
  }

  @Test func nearAScreenEdgeTheViewSlidesUntilItFits() {
    let first = CGRect(x: 10, y: 4, width: 60, height: 60)
    #expect(DockPreviewPlacement.frame(panel: panel, icon: first, edge: .bottom, screen: screen).minX == 8)
    let last = CGRect(x: 1370, y: 4, width: 60, height: 60)
    #expect(DockPreviewPlacement.frame(panel: panel, icon: last, edge: .bottom, screen: screen).maxX == 1432)
    let top = CGRect(x: 4, y: 830, width: 60, height: 60)
    #expect(DockPreviewPlacement.frame(panel: panel, icon: top, edge: .left, screen: screen).maxY == 892)
  }

  // MARK: Tiempos

  private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

  @Test func appearsOnlyAfterTheDelay() {
    var timer = DockHoverTimer<String>()
    #expect(timer.hover("Safari", at: t0) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.2) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.3) == .show("Safari"))
    #expect(timer.shown == "Safari")
    #expect(timer.tick(inside: true, at: t0 + 0.5) == .none)
  }

  @Test func leavingTheIconBeforeTheDelayShowsNothing() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    #expect(timer.tick(inside: false, at: t0 + 0.1) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.4) == .none)
    #expect(timer.shown == nil)
  }

  @Test func anotherIconWhilePendingStartsAgain() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    #expect(timer.hover("Notas", at: t0 + 0.2) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.4) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.5) == .show("Notas"))
  }

  @Test func withTheViewOpenAnotherIconSwitchesAtOnce() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    _ = timer.tick(inside: true, at: t0 + 0.3)
    #expect(timer.hover("Safari", at: t0 + 0.4) == .none)
    #expect(timer.hover("Notas", at: t0 + 0.5) == .show("Notas"))
    #expect(timer.shown == "Notas")
  }

  @Test func outsideTheIconAndTheViewItHidesAfterTheMargin() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    _ = timer.tick(inside: true, at: t0 + 0.3)
    #expect(timer.tick(inside: false, at: t0 + 1) == .none)
    #expect(timer.tick(inside: false, at: t0 + 1.2) == .none)
    #expect(timer.tick(inside: false, at: t0 + 1.25) == .hide)
    #expect(timer.shown == nil)
  }

  @Test func comingBackInTimeKeepsTheView() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    _ = timer.tick(inside: true, at: t0 + 0.3)
    _ = timer.tick(inside: false, at: t0 + 1)
    #expect(timer.tick(inside: true, at: t0 + 1.2) == .none)
    #expect(timer.tick(inside: false, at: t0 + 1.3) == .none)
    #expect(timer.tick(inside: false, at: t0 + 1.5) == .none)
    #expect(timer.shown == "Safari")
  }

  @Test func afterCancelTheSameIconWaitsUntilTheMouseLeaves() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    _ = timer.tick(inside: true, at: t0 + 0.3)
    timer.cancel()
    #expect(timer.shown == nil)
    #expect(timer.isActive)
    // El Dock repite el aviso del mismo icono: no vuelve a salir.
    #expect(timer.hover("Safari", at: t0 + 0.5) == .none)
    #expect(timer.tick(inside: true, at: t0 + 1) == .none)
    #expect(timer.shown == nil)
    // Al salir el ratón del icono, todo vuelve a empezar.
    #expect(timer.tick(inside: false, at: t0 + 1.1) == .none)
    #expect(!timer.isActive)
    _ = timer.hover("Safari", at: t0 + 2)
    #expect(timer.tick(inside: true, at: t0 + 2.2) == .none)
    #expect(timer.tick(inside: true, at: t0 + 2.3) == .show("Safari"))
  }

  @Test func afterCancelAnotherIconWaitsAsUsual() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    timer.cancel()
    #expect(timer.hover("Notas", at: t0 + 0.1) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.3) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.4) == .show("Notas"))
  }

  @Test func isActiveWhilePendingOrShown() {
    var timer = DockHoverTimer<String>()
    #expect(!timer.isActive)
    _ = timer.hover("Safari", at: t0)
    #expect(timer.isActive)
    _ = timer.tick(inside: true, at: t0 + 0.3)
    #expect(timer.isActive)
    _ = timer.tick(inside: false, at: t0 + 1)
    _ = timer.tick(inside: false, at: t0 + 1.25)
    #expect(!timer.isActive)
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find 'DockItem' in scope`.

- [ ] **Step 3: `DockItem`, `DockEdge`, `DockPreviewPlacement` y `DockHoverTimer`**

Crear `Sources/SinteclaCore/DockPreview.swift`:

```swift
import CoreGraphics
import Foundation

/// Vistas del Dock (spec «Vistas del Dock»): textos y medidas.
public enum DockPreview {
  /// Resumen para la tarjeta de Inicio.
  public static let summary = "Ventanas al pasar por el Dock"
  /// Ancho de cada tarjeta, en puntos (§5).
  public static let cardWidth: CGFloat = 240
}

/// Un icono de app del Dock (spec «Vistas del Dock» §6). Carpetas, Papelera y separadores no lo son.
public struct DockItem: Equatable, Sendable {
  public let appURL: URL

  /// `subrole` y `url`: los atributos `AXSubrole` y `AXURL` del icono.
  public init?(subrole: String?, url: URL?) {
    guard subrole == "AXApplicationDockItem", let url, url.isFileURL, url.pathExtension == "app" else { return nil }
    appURL = url
  }
}

/// El lado de la pantalla donde está el Dock.
public enum DockEdge: Equatable, Sendable {
  case bottom, left, right

  /// El borde de la pantalla más cerca del icono (con la lupa, el icono crece pero sigue pegado a su borde).
  public init(icon: CGRect, screen: CGRect) {
    let bottom = icon.minY - screen.minY
    let left = icon.minX - screen.minX
    let right = screen.maxX - icon.maxX
    if bottom <= left && bottom <= right {
      self = .bottom
    } else {
      self = left <= right ? .left : .right
    }
  }
}

/// Dónde va la vista (spec «Vistas del Dock» §5).
public enum DockPreviewPlacement {
  /// Hueco entre el icono y la vista: deja libre el nombre que el Dock pone junto al icono.
  static let iconGap: CGFloat = 36
  /// Margen con los bordes de la pantalla.
  static let margin: CGFloat = 8

  /// Accesibilidad mide desde arriba a la izquierda de la pantalla principal; AppKit, desde abajo a la izquierda.
  public static func screenRect(fromAccessibility rect: CGRect, primaryHeight: CGFloat) -> CGRect {
    CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
  }

  /// Junto al icono, hacia dentro de la pantalla y centrada en él; si se sale, se corre hasta caber.
  public static func frame(panel: CGSize, icon: CGRect, edge: DockEdge, screen: CGRect) -> CGRect {
    var origin: CGPoint
    switch edge {
    case .bottom: origin = CGPoint(x: icon.midX - panel.width / 2, y: icon.maxY + iconGap)
    case .left: origin = CGPoint(x: icon.maxX + iconGap, y: icon.midY - panel.height / 2)
    case .right: origin = CGPoint(x: icon.minX - iconGap - panel.width, y: icon.midY - panel.height / 2)
    }
    let bounds = screen.insetBy(dx: margin, dy: margin)
    origin.x = min(max(origin.x, bounds.minX), bounds.maxX - panel.width)
    origin.y = min(max(origin.y, bounds.minY), bounds.maxY - panel.height)
    return CGRect(origin: origin, size: panel)
  }
}

/// Los tiempos de la vista (spec «Vistas del Dock» §3). `Item` es el icono (la app) que tiene el ratón.
///
/// - `hover`: el Dock avisa de que el ratón está sobre otro icono de app.
/// - `tick`: cada poco, con `inside` a true si el ratón está sobre el icono (al esperar) o sobre el icono o la vista
///   (con la vista abierta).
public struct DockHoverTimer<Item: Equatable & Sendable>: Sendable {
  public static var showDelay: TimeInterval { 0.3 }
  public static var hideDelay: TimeInterval { 0.25 }
  /// Las fechas son grandes: sin este margen, 0,3 s podrían medir 0,2999999.
  static var epsilon: TimeInterval { 0.001 }

  public enum Action: Equatable, Sendable {
    case none
    case show(Item)
    case hide
  }

  private enum State: Sendable {
    case idle
    case pending(Item, since: Date)
    case shown(Item, outsideSince: Date?)
    /// Cerrada con Esc, un clic o Alt-Tab: ese icono no la vuelve a sacar hasta que el ratón salga de él.
    case dismissed(Item)
  }

  private var state = State.idle

  public init() {}

  /// El icono con la vista abierta.
  public var shown: Item? {
    if case .shown(let item, _) = state { return item }
    return nil
  }

  /// Esperando para enseñar la vista o con ella abierta: hay que seguir mirando el ratón.
  public var isActive: Bool {
    if case .idle = state { return false }
    return true
  }

  public mutating func hover(_ item: Item, at now: Date) -> Action {
    switch state {
    case .idle:
      state = .pending(item, since: now)
    case .pending(let current, _):
      if current != item { state = .pending(item, since: now) }
    case .shown(let current, _):
      // Con la vista abierta, otro icono cambia al momento.
      if current != item {
        state = .shown(item, outsideSince: nil)
        return .show(item)
      }
      state = .shown(item, outsideSince: nil)
    case .dismissed(let current):
      if current != item { state = .pending(item, since: now) }
    }
    return .none
  }

  public mutating func tick(inside: Bool, at now: Date) -> Action {
    switch state {
    case .idle:
      return .none
    case .pending(let item, let since):
      guard inside else {
        state = .idle
        return .none
      }
      guard now.timeIntervalSince(since) >= Self.showDelay - Self.epsilon else { return .none }
      state = .shown(item, outsideSince: nil)
      return .show(item)
    case .shown(let item, let outsideSince):
      if inside {
        state = .shown(item, outsideSince: nil)
        return .none
      }
      guard let outsideSince else {
        state = .shown(item, outsideSince: now)
        return .none
      }
      guard now.timeIntervalSince(outsideSince) >= Self.hideDelay - Self.epsilon else { return .none }
      state = .idle
      return .hide
    case .dismissed:
      if !inside { state = .idle }
      return .none
    }
  }

  /// Esc, un clic o Alt-Tab: la vista se va. El Dock repite su aviso aunque el ratón no cambie de icono: por eso ese
  /// icono no la vuelve a sacar hasta que el ratón sale de él (`tick` con `inside` a false).
  public mutating func cancel() {
    switch state {
    case .pending(let item, _), .shown(let item, _): state = .dismissed(item)
    case .idle, .dismissed: break
    }
  }
}
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 315 tests in 55 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/DockPreview.swift Sources/SinteclaCoreTests/DockPreviewTests.swift
git commit -m 'feat: iconos, sitio y tiempos de las vistas del Dock

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: El módulo Dock, su página y su tarjeta

**Files:**
- Modify: `Sources/SinteclaCore/Modules.swift` y Test: `Sources/SinteclaCoreTests/ModulesTests.swift`
- Modify: `Sources/Sintecla/AppSettings.swift` (`moduleDock`)
- Create: `Sources/Sintecla/DockPage.swift`
- Modify: `Sources/Sintecla/HomeView.swift` (tarjeta) y `Sources/Sintecla/MainWindow.swift` (página)

**Interfaces:**
- Consumes: `DockPreview.summary` (Tarea 1); `Permissions.accessibilityGranted`; `ScreenCapture.hasPermission` y `openPermissionSettings()`.
- Produces: `Module.dock`, `ModulePage.dock`, `ModuleSwitches.dock` (con `dock: Bool = false` en el `init`); `AppSettings.moduleDock` (UserDefaults `moduleDock`, `false`); `DockPage()`.

- [ ] **Step 1: Tests: el módulo Dock, apagado salvo que se diga**

En `Sources/SinteclaCoreTests/ModulesTests.swift`, cambiar:

```swift
  let allOn = ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true, altTab: true)
```

por:

```swift
  let allOn = ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true, altTab: true, dock: true)
```

Y cambiar:

```swift
    #expect(Module.altTab.pages == [.altTab])
```

por:

```swift
    #expect(Module.altTab.pages == [.altTab])
    #expect(Module.dock.pages == [.dock])
```

Y cambiar:

```swift
    #expect(Module.allCases.map(\.name) == ["Dictado", "Reuniones", "Finder", "Capturas", "Alt-Tab"])
```

por:

```swift
    #expect(Module.allCases.map(\.name) == ["Dictado", "Reuniones", "Finder", "Capturas", "Alt-Tab", "Dock"])
    #expect(ModulePage.dock.title == "Dock")
```

Y cambiar:

```swift
    #expect(allOn.enabled == [.dictation, .meetings, .finder, .captures, .altTab])
```

por:

```swift
    #expect(allOn.enabled == [.dictation, .meetings, .finder, .captures, .altTab, .dock])
```

Y cambiar:

```swift
    switches[.altTab] = false
    #expect(!switches.altTab)
  }
```

por:

```swift
    switches[.altTab] = false
    #expect(!switches.altTab)
    switches[.dock] = false
    #expect(!switches.dock)
  }
```

Y cambiar:

```swift
    #expect(!ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true).altTab)
```

por:

```swift
    #expect(!ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true).altTab)
    #expect(!ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true, altTab: true).dock)
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: extra argument 'dock' in call`.

- [ ] **Step 3: `Module.dock`, su página y su interruptor**

En `Sources/SinteclaCore/Modules.swift`, cambiar:

```swift
  case dictation, meetings, finder, captures, altTab
```

por:

```swift
  case dictation, meetings, finder, captures, altTab, dock
```

Y cambiar:

```swift
    case .altTab: "Alt-Tab"
    }
  }

  public var symbol: String {
    switch self {
    case .dictation: "waveform"
```

por:

```swift
    case .altTab: "Alt-Tab"
    case .dock: "Dock"
    }
  }

  public var symbol: String {
    switch self {
    case .dictation: "waveform"
```

Y cambiar:

```swift
    case .altTab: "rectangle.on.rectangle"
    }
  }

  /// Lo que hace, para la página Módulos.
```

por:

```swift
    case .altTab: "rectangle.on.rectangle"
    case .dock: "dock.rectangle"
    }
  }

  /// Lo que hace, para la página Módulos.
```

Y cambiar:

```swift
      + "necesitan el permiso de Grabación de pantalla."
    }
```

por:

```swift
      + "necesitan el permiso de Grabación de pantalla."
    case .dock: "Al pasar el ratón por una app del Dock, enseña sus ventanas para saltar a una, cerrarla o minimizarla. "
      + "Las miniaturas necesitan el permiso de Grabación de pantalla."
    }
```

Y cambiar:

```swift
  case altTab

  public var module: Module {
```

por:

```swift
  case altTab
  case dock

  public var module: Module {
```

Y cambiar:

```swift
    case .altTab: .altTab
    }
```

por:

```swift
    case .altTab: .altTab
    case .dock: .dock
    }
```

Y cambiar:

```swift
    case .altTab: "Alt-Tab"
    }
  }

  public var symbol: String {
    switch self {
    case .history:
```

por:

```swift
    case .altTab: "Alt-Tab"
    case .dock: "Dock"
    }
  }

  public var symbol: String {
    switch self {
    case .history:
```

Y cambiar:

```swift
    case .altTab: "rectangle.on.rectangle"
    }
  }
}

/// Qué módulos están encendidos.
```

por:

```swift
    case .altTab: "rectangle.on.rectangle"
    case .dock: "dock.rectangle"
    }
  }
}

/// Qué módulos están encendidos.
```

Y cambiar:

```swift
  public var altTab: Bool

  public init(dictation: Bool, meetings: Bool, finder: Bool, captures: Bool = false, altTab: Bool = false) {
```

por:

```swift
  public var altTab: Bool
  public var dock: Bool

  public init(dictation: Bool, meetings: Bool, finder: Bool, captures: Bool = false, altTab: Bool = false,
              dock: Bool = false) {
```

Y cambiar:

```swift
    self.altTab = altTab
```

por:

```swift
    self.altTab = altTab
    self.dock = dock
```

Y cambiar:

```swift
      case .altTab: altTab
```

por:

```swift
      case .altTab: altTab
      case .dock: dock
```

Y cambiar:

```swift
      case .altTab: altTab = newValue
```

por:

```swift
      case .altTab: altTab = newValue
      case .dock: dock = newValue
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 315 tests in 55 suites passed`.

- [ ] **Step 5: `AppSettings.moduleDock`**

En `Sources/Sintecla/AppSettings.swift`, cambiar:

```swift
  var moduleAltTab: Bool { didSet { defaults.set(moduleAltTab, forKey: "moduleAltTab") } }
```

por:

```swift
  var moduleAltTab: Bool { didSet { defaults.set(moduleAltTab, forKey: "moduleAltTab") } }
  /// Módulo Dock (spec «Vistas del Dock»), apagado por defecto.
  var moduleDock: Bool { didSet { defaults.set(moduleDock, forKey: "moduleDock") } }
```

Y cambiar:

```swift
      "moduleAltTab": false,
```

por:

```swift
      "moduleAltTab": false, "moduleDock": false,
```

Y cambiar:

```swift
    moduleAltTab = defaults.bool(forKey: "moduleAltTab")
```

por:

```swift
    moduleAltTab = defaults.bool(forKey: "moduleAltTab")
    moduleDock = defaults.bool(forKey: "moduleDock")
```

Y cambiar:

```swift
                     altTab: moduleAltTab)
```

por:

```swift
                     altTab: moduleAltTab, dock: moduleDock)
```

Y cambiar:

```swift
      if moduleAltTab != newValue.altTab { moduleAltTab = newValue.altTab }
```

por:

```swift
      if moduleAltTab != newValue.altTab { moduleAltTab = newValue.altTab }
      if moduleDock != newValue.dock { moduleDock = newValue.dock }
```

- [ ] **Step 6: La página Dock**

Crear `Sources/Sintecla/DockPage.swift`:

```swift
import Combine
import SinteclaCore
import SwiftUI

/// Dock → Dock (spec «Vistas del Dock» §2): cómo se usa, los dos permisos y el aviso de cerrar otras apps que hacen lo
/// mismo.
struct DockPage: View {
  @State private var accessibility = Permissions.accessibilityGranted
  @State private var screen = ScreenCapture.hasPermission
  private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

  var body: some View {
    Form {
      Section("Cómo se usa") {
        LabeledContent("Pasar el ratón", value: "Por una app abierta del Dock: salen sus ventanas")
        LabeledContent("Clic en una ventana", value: "La pone delante (y la restaura si estaba minimizada)")
        LabeledContent("Botones de la tarjeta", value: "Cerrar la ventana, o minimizarla y restaurarla")
        LabeledContent("Esc", value: "Cierra la vista")
        Text("Si usas DockDoor u otra app que enseña las ventanas al pasar por el Dock, ciérrala: si no, saldrán dos "
             + "vistas a la vez.")
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
          Text("Sin él, la vista funciona igual, con el icono de la app en lugar de la miniatura.")
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

- [ ] **Step 7: La tarjeta del Dock en Inicio**

En `Sources/Sintecla/HomeView.swift`, cambiar:

```swift
    case .altTab:
      Text(AltTabShortcut.summary).foregroundStyle(.secondary)
      if !ScreenCapture.hasPermission {
        Label("Sin miniaturas: falta el permiso de Grabación de pantalla", systemImage: "exclamationmark.triangle")
          .font(.callout)
      }
    }
```

por:

```swift
    case .altTab, .dock:
      Text(module == .altTab ? AltTabShortcut.summary : DockPreview.summary).foregroundStyle(.secondary)
      if !ScreenCapture.hasPermission {
        Label("Sin miniaturas: falta el permiso de Grabación de pantalla", systemImage: "exclamationmark.triangle")
          .font(.callout)
      }
    }
```

- [ ] **Step 8: La página en la ventana**

En `Sources/Sintecla/MainWindow.swift`, cambiar:

```swift
    case .altTab: AltTabPage()
```

por:

```swift
    case .altTab: AltTabPage()
    case .dock: DockPage()
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
git add Sources/SinteclaCore/Modules.swift Sources/SinteclaCoreTests/ModulesTests.swift Sources/Sintecla/AppSettings.swift Sources/Sintecla/DockPage.swift Sources/Sintecla/HomeView.swift Sources/Sintecla/MainWindow.swift
git commit -m 'feat: módulo Dock con su página y su tarjeta

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: Ventanas de una app, cerrar, minimizar y la tarjeta compartida

**Files:**
- Modify: `Sources/Sintecla/WindowCatalog.swift`
- Create: `Sources/Sintecla/WindowCard.swift`
- Modify: `Sources/Sintecla/WindowSwitcherPanel.swift` (usa `WindowCard`)

**Interfaces:**
- Consumes: `WindowCatalog` y `WindowSwitcherView` de Alt-Tab (0.12.0); `SwitcherWindow` (`Sources/SinteclaCore/AltTab.swift`).
- Produces: `WindowCatalog.refresh(only: pid_t? = nil)`, `close(_:)` y `toggleMinimized(_:)`; `WindowCard(window:thumbnail:width:chosen:onClose:onMinimize:onQuit:)` (los tres últimos, opcionales).

Aún no lo usa nadie más que Alt-Tab: la vista del Dock llega en la Tarea 4. La tarjeta sale tal cual del selector de Alt-Tab, que queda igual. Cerrar pulsa el botón de cerrar de la ventana por Accesibilidad (`kAXCloseButtonAttribute`), no sale de la app.

- [ ] **Step 1: `WindowCatalog`: las ventanas de una sola app, cerrar y minimizar o restaurar**

En `Sources/Sintecla/WindowCatalog.swift`, cambiar:

```swift
  /// Lee las ventanas en este momento.
  func refresh() {
```

por:

```swift
  /// Lee las ventanas en este momento: todas o, con `pid`, solo las de esa app (vistas del Dock).
  func refresh(only pid: pid_t? = nil) {
```

Y cambiar:

```swift
    for app in regular where app.processIdentifier != own {
```

por:

```swift
    for app in regular where app.processIdentifier != own && (pid == nil || app.processIdentifier == pid) {
```

Y cambiar:

```swift
    windows = WindowSwitcherOrder.arrange(visible: visible, minimized: minimized, ownPID: own, agentPIDs: agentPIDs)
```

por:

```swift
    windows = WindowSwitcherOrder.arrange(visible: visible, minimized: minimized, ownPID: own, agentPIDs: agentPIDs)
      .filter { pid == nil || $0.pid == pid }
```

Y cambiar:

```swift
      AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
    }
  }
```

por:

```swift
      AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
    }
  }

  /// La cierra con su botón de cerrar, como un clic en él: si tiene cambios sin guardar, la app saca su aviso.
  func close(_ window: SwitcherWindow) {
    guard let element = elements[window.id] ?? visibleElement(for: window),
          let button: AXUIElement = Self.value(element, kAXCloseButtonAttribute) else { return }
    AXUIElementPerformAction(button, kAXPressAction as CFString)
  }

  /// La minimiza o, si ya lo está, la restaura.
  func toggleMinimized(_ window: SwitcherWindow) {
    guard let element = elements[window.id] ?? visibleElement(for: window) else { return }
    AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString,
                                 window.isMinimized ? kCFBooleanFalse : kCFBooleanTrue)
  }
```

- [ ] **Step 2: `WindowCard`: la tarjeta, con los botoncitos opcionales**

Crear `Sources/Sintecla/WindowCard.swift`:

```swift
import AppKit
import SinteclaCore
import SwiftUI

/// La tarjeta de una ventana: la miniatura (o el icono grande de la app) y, debajo, el icono pequeño y el título. La
/// comparten el selector de Alt-Tab y las vistas del Dock.
struct WindowCard: View {
  let window: SwitcherWindow
  let thumbnail: CGImage?
  let width: CGFloat
  let chosen: Bool
  /// Con los dos, la tarjeta marcada enseña cerrar y minimizar (o restaurar) arriba a la izquierda (vistas del Dock).
  var onClose: (() -> Void)?
  var onMinimize: (() -> Void)?
  /// Con él, también salir de la app, como ⌘Q.
  var onQuit: (() -> Void)?

  var body: some View {
    let icon = NSRunningApplication(processIdentifier: window.pid)?.icon ?? NSImage(named: NSImage.applicationIconName)!
    VStack(alignment: .leading, spacing: 6) {
      ZStack {
        if let thumbnail {
          Image(decorative: thumbnail, scale: 2).resizable().aspectRatio(contentMode: .fit)
            .clipShape(.rect(cornerRadius: 6))
        } else {
          Image(nsImage: icon).resizable().frame(width: 64, height: 64)
        }
      }
      .frame(width: width - 16, height: (width - 16) * 0.66)
      HStack(spacing: 6) {
        Image(nsImage: icon).resizable().frame(width: 16, height: 16)
        Text(window.label).font(.callout).lineLimit(1).truncationMode(.tail)
      }
    }
    .padding(8)
    .frame(width: width)
    .background(chosen ? Color.accentColor.opacity(0.22) : .clear, in: .rect(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: chosen ? 2 : 0))
    .opacity(window.isMinimized ? 0.55 : 1)
    .overlay(alignment: .topLeading) {
      if chosen, let onClose, let onMinimize {
        HStack(spacing: 6) {
          button("xmark", help: "Cerrar la ventana", action: onClose)
          button(window.isMinimized ? "arrow.up.left.and.arrow.down.right" : "minus",
                 help: window.isMinimized ? "Restaurar" : "Minimizar", action: onMinimize)
          if let onQuit { button("power", help: "Salir de \(window.appName) (⌘Q)", action: onQuit) }
        }
        .padding(5)
      }
    }
    .contentShape(.rect)
  }

  private func button(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 11, weight: .bold)).frame(width: 24, height: 24)
        .background(.regularMaterial, in: .circle)
        .contentShape(.circle)
    }
    .buttonStyle(.plain)
    .help(help)
  }
}
```

- [ ] **Step 3: El selector de Alt-Tab usa `WindowCard`**

En `Sources/Sintecla/WindowSwitcherPanel.swift`, cambiar:

```swift
        card(window, chosen: model.selected == index)
```

por:

```swift
        WindowCard(window: window, thumbnail: model.thumbnails[window.id], width: model.cardWidth,
                   chosen: model.selected == index)
```

Y cambiar:

```swift
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
```

por:

```swift
    .padding(6)
  }
}
```

- [ ] **Step 4: Compilar la release (sin avisos)**

Run:

```bash
source scripts/sdk-env.sh && swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build complete' | grep -v 'ld: warning: search path' | tail -3
```

Esperado: `Build complete!`.

- [ ] **Step 5: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 315 tests in 55 suites passed`.

- [ ] **Step 6: Commit**

```bash
git add Sources/Sintecla/WindowCatalog.swift Sources/Sintecla/WindowCard.swift Sources/Sintecla/WindowSwitcherPanel.swift
git commit -m 'feat: ventanas de una app, cerrar y minimizar, y tarjeta compartida

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 4: La vista del Dock

**Files:**
- Create: `Sources/Sintecla/DockWatcher.swift`, `Sources/Sintecla/DockPreviewPanel.swift` y `Sources/Sintecla/DockPreviewController.swift`
- Modify: `Sources/Sintecla/AltTabController.swift` (`onOpen`)
- Modify: `Sources/Sintecla/DictationController.swift` (el Dock en la cadena de teclas y al arrancar)

**Interfaces:**
- Consumes: Tareas 1 a 3; `WindowThumbnails.capture` y `WindowCatalog.focus` (Alt-Tab); `FirstMouseHostingView` (Ask Anything).
- Produces: `DockWatcher` (`start()`, `stop()`, `onHover`, `frame(of:)`); `DockPreviewModel`, `DockPreviewView`, `DockPreviewPanel` (`layout(count:edge:screen:)`, `show(icon:edge:screen:)`, `hide()`, `onClick`, `onClose`, `onMinimize`, `onQuit`); `DockPreviewController(settings:)` con `start()`, `keyDown(keyCode:modifiers:) -> Bool` y `dismiss()`; `AltTabController.onOpen`.

El Dock avisa por Accesibilidad (`kAXSelectedChildrenChangedNotification` en su `AXList`) del icono que tiene el ratón, pero no de cuándo el ratón sale del Dock. Por eso, mientras la vista espera o está abierta, se mira el ratón cada 50 ms. Comprobado en macOS 27.0.1: el aviso llega en cada icono, repetido mientras la lupa lo mueve, con su `AXURL` y su sitio.

- [ ] **Step 1: `DockWatcher`: el icono bajo el ratón, por Accesibilidad**

Crear `Sources/Sintecla/DockWatcher.swift`:

```swift
import AppKit
import ApplicationServices
import SinteclaCore

/// Escucha el Dock por Accesibilidad (spec «Vistas del Dock» §6). El Dock marca como elegido el icono que tiene el ratón
/// y avisa cada vez que cambia (y también, repetido, mientras la lupa lo mueve). Si el Dock se reinicia, se vuelve a
/// apuntar.
@MainActor
final class DockWatcher {
  nonisolated static let dockBundleID = "com.apple.dock"

  /// El icono que tiene el ratón (su elemento, para leer su sitio) y, si es una app, cuál.
  var onHover: ((AXUIElement, DockItem?) -> Void)?
  private var observer: AXObserver?
  private var launchObserver: NSObjectProtocol?

  func start() {
    guard launchObserver == nil else { return }
    launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
    ) { [weak self] notification in
      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      guard app?.bundleIdentifier == Self.dockBundleID else { return }
      MainActor.assumeIsolated { self?.attachSoon() }
    }
    attach()
  }

  func stop() {
    if let launchObserver { NSWorkspace.shared.notificationCenter.removeObserver(launchObserver) }
    launchObserver = nil
    detach()
  }

  /// El sitio del icono en la pantalla, en coordenadas de AppKit. Se lee cada vez: la lupa lo cambia.
  func frame(of element: AXUIElement) -> CGRect? {
    var point = CGPoint.zero
    var size = CGSize.zero
    guard let position: AXValue = Self.value(element, kAXPositionAttribute),
          let extent: AXValue = Self.value(element, kAXSizeAttribute),
          AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(extent, .cgSize, &size),
          let primary = NSScreen.screens.first else { return nil }
    return DockPreviewPlacement.screenRect(fromAccessibility: CGRect(origin: point, size: size),
                                           primaryHeight: primary.frame.height)
  }

  /// El Dock recién abierto tarda un poco en tener su lista de iconos.
  private func attachSoon() {
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      self?.attach()
    }
  }

  private func attach() {
    detach()
    guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: Self.dockBundleID).first else { return }
    let app = AXUIElementCreateApplication(dock.processIdentifier)
    AXUIElementSetMessagingTimeout(app, WindowCatalog.accessibilityTimeout)
    let children: [AXUIElement] = Self.value(app, kAXChildrenAttribute) ?? []
    guard let list = children.first(where: { Self.value($0, kAXRoleAttribute) == kAXListRole as String }) else { return }
    let callback: AXObserverCallback = { _, element, _, refcon in
      guard let refcon else { return }
      let watcher = Unmanaged<DockWatcher>.fromOpaque(refcon).takeUnretainedValue()
      MainActor.assumeIsolated { watcher.selectionChanged(in: element) }
    }
    var observer: AXObserver?
    guard AXObserverCreate(dock.processIdentifier, callback, &observer) == .success, let observer else { return }
    // Sin retener: el vigilante vive lo que Sintecla.
    AXObserverAddNotification(observer, list, kAXSelectedChildrenChangedNotification as CFString,
                              Unmanaged.passUnretained(self).toOpaque())
    CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    self.observer = observer
  }

  private func detach() {
    if let observer {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
    observer = nil
  }

  private func selectionChanged(in list: AXUIElement) {
    let selected: [AXUIElement] = Self.value(list, kAXSelectedChildrenAttribute) ?? []
    guard let icon = selected.first else { return }
    onHover?(icon, DockItem(subrole: Self.value(icon, kAXSubroleAttribute), url: Self.value(icon, kAXURLAttribute)))
  }

  private static func value<T>(_ element: AXUIElement, _ attribute: String) -> T? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value as? T
  }
}
```

- [ ] **Step 2: La vista de cristal junto al icono**

Crear `Sources/Sintecla/DockPreviewPanel.swift`:

```swift
import AppKit
import Observation
import SinteclaCore
import SwiftUI

/// Lo que enseña la vista del Dock: las ventanas de la app, la marcada, las miniaturas que van llegando y cómo van las
/// tarjetas.
@MainActor @Observable
final class DockPreviewModel {
  var windows: [SwitcherWindow] = []
  var selected: Int?
  var thumbnails: [Int: CGImage] = [:]
  var cardWidth = DockPreview.cardWidth
  /// En columna si el Dock está a un lado; en fila si está abajo.
  var vertical = false
}

/// La vista de cristal con una tarjeta por ventana (spec «Vistas del Dock» §5).
struct DockPreviewView: View {
  let model: DockPreviewModel
  var onHover: (Int) -> Void
  var onClick: (Int) -> Void
  var onClose: (Int) -> Void
  var onMinimize: (Int) -> Void
  var onQuit: (Int) -> Void

  var body: some View {
    let layout = model.vertical ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
    layout {
      ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
        WindowCard(window: window, thumbnail: model.thumbnails[window.id], width: model.cardWidth,
                   chosen: model.selected == index, onClose: { onClose(index) }, onMinimize: { onMinimize(index) },
                   onQuit: { onQuit(index) })
          .onHover { if $0 { onHover(index) } }
          .onTapGesture { onClick(index) }
      }
    }
    .padding(12)
    .glassEffect(.regular, in: .rect(cornerRadius: 22))
    .padding(6)
  }
}

/// Panel por encima del Dock que no activa Sintecla: la app de delante sigue siendo la que era.
@MainActor
final class DockPreviewPanel {
  let model = DockPreviewModel()
  var onClick: ((Int) -> Void)?
  var onClose: ((Int) -> Void)?
  var onMinimize: ((Int) -> Void)?
  var onQuit: ((Int) -> Void)?
  private let panel: NSPanel
  private var hosting: FirstMouseHostingView<DockPreviewView>!

  init() {
    panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200), styleMask: [.nonactivatingPanel, .borderless],
                    backing: .buffered, defer: false)
    panel.level = .popUpMenu
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false  // el cristal ya lleva su sombra
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    hosting = FirstMouseHostingView(rootView: DockPreviewView(
      model: model,
      onHover: { [weak self] in self?.model.selected = $0 },
      onClick: { [weak self] in self?.onClick?($0) },
      onClose: { [weak self] in self?.onClose?($0) },
      onMinimize: { [weak self] in self?.onMinimize?($0) },
      onQuit: { [weak self] in self?.onQuit?($0) }))
    panel.contentView = hosting
  }

  var isVisible: Bool { panel.isVisible }
  var frame: CGRect { panel.frame }

  /// Tarjetas de 240 puntos; si no caben en el 80 % de la pantalla a lo largo del Dock, se encogen.
  func layout(count: Int, edge: DockEdge, screen: CGRect) {
    model.vertical = edge != .bottom
    let count = CGFloat(max(1, count))
    let free = (model.vertical ? screen.height : screen.width) * 0.8 - 36 - 10 * (count - 1)
    // En columna manda el alto de la tarjeta: la miniatura (0,66 del ancho) más el título, unos 32 puntos.
    let width = model.vertical ? (free / count - 32) / 0.66 : free / count
    model.cardWidth = max(80, min(DockPreview.cardWidth, width))
  }

  /// `screen`: la parte útil de la pantalla del icono (sin la barra de menús ni el Dock).
  func show(icon: CGRect, edge: DockEdge, screen: CGRect) {
    hosting.layoutSubtreeIfNeeded()
    let frame = DockPreviewPlacement.frame(panel: hosting.fittingSize, icon: icon, edge: edge, screen: screen)
    panel.setFrame(frame, display: true)
    panel.orderFrontRegardless()
  }

  func hide() {
    panel.orderOut(nil)
  }
}
```

- [ ] **Step 3: `DockPreviewController`: tiempos, ventanas y acciones**

Crear `Sources/Sintecla/DockPreviewController.swift`:

```swift
import AppKit
import Observation
import SinteclaCore

/// Módulo Dock (spec «Vistas del Dock» §3): al pasar el ratón por una app abierta del Dock, enseña sus ventanas para
/// saltar a una, cerrarla o minimizarla.
@MainActor
final class DockPreviewController {
  /// Cada cuánto se mira el ratón mientras la vista espera o está abierta (el Dock no avisa al salir de él).
  static let tickInterval = Duration.milliseconds(50)
  /// Tras cerrar o minimizar, las ventanas se vuelven a leer cada tanto hasta que macOS termina su animación.
  static let reloadStep = Duration.milliseconds(150)
  static let reloadSteps = 12

  private let settings: AppSettings
  private let watcher = DockWatcher()
  private let catalog = WindowCatalog()
  private lazy var panel: DockPreviewPanel = {
    let panel = DockPreviewPanel()
    panel.onClick = { [weak self] in self?.jump(to: $0) }
    panel.onClose = { [weak self] index in self?.act(on: index) { self?.catalog.close($0) } }
    panel.onMinimize = { [weak self] index in self?.act(on: index) { self?.catalog.toggleMinimized($0) } }
    panel.onQuit = { [weak self] in self?.quit(appOf: $0) }
    return panel
  }()
  private var timer = DockHoverTimer<pid_t>()
  /// El icono con el ratón encima: su elemento (para leer su sitio, que cambia con la lupa) y su app.
  private var hovered: (icon: AXUIElement, pid: pid_t)?
  private var ticker: Task<Void, Never>?
  private var thumbnailTask: Task<Void, Never>?
  private var clickMonitor: Any?
  private var moveMonitor: Any?
  /// El sitio del último icono: el Dock no avisa si el ratón sale y vuelve al mismo icono, así que se nota aquí.
  private var lastIconFrame: CGRect?
  /// Tras cerrar o minimizar, la vista cambia de tamaño y el ratón puede quedar fuera: su sitio anterior cuenta como
  /// dentro hasta que el ratón sale de él.
  private var previousPanelFrame: CGRect?

  init(settings: AppSettings) {
    self.settings = settings
  }

  /// Lo llama Sintecla al arrancar: desde ahí, escuchar el Dock sigue al interruptor del módulo.
  func start() {
    if settings.moduleDock {
      watcher.onHover = { [weak self] icon, item in self?.hover(icon: icon, item: item) }
      watcher.start()
      if moveMonitor == nil {
        moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
          MainActor.assumeIsolated { self?.mouseMoved() }
        }
      }
    } else {
      watcher.stop()
      if let moveMonitor { NSEvent.removeMonitor(moveMonitor) }
      moveMonitor = nil
      dismiss()
    }
    withObservationTracking { _ = settings.moduleDock } onChange: { [weak self] in
      Task { @MainActor in self?.start() }
    }
  }

  /// Lo llama el `EventTap` con cada pulsación que no usa nadie antes. Con la vista abierta, Esc la cierra.
  func keyDown(keyCode: Int64, modifiers: Set<ComboModifier>) -> Bool {
    guard panel.isVisible, keyCode == 53, modifiers.isEmpty else { return false }  // 53 = Esc
    dismiss()
    return true
  }

  /// Esc, un clic fuera de la vista o Alt-Tab: la vista se va.
  func dismiss() {
    timer.cancel()
    hidePanel()
  }

  private func hover(icon: AXUIElement, item: DockItem?) {
    // Carpetas, Papelera y apps cerradas no sacan nada: si el ratón sale del icono anterior, `tick` lo nota.
    guard let item, let app = Self.runningApp(at: item.appURL) else { return }
    hovered = (icon, app.processIdentifier)
    handle(timer.hover(app.processIdentifier, at: Date()))
    startTicking()
  }

  /// Solo con la vista quieta: si el ratón vuelve al último icono, es como si el Dock avisara otra vez.
  private func mouseMoved() {
    guard !timer.isActive, let hovered, let lastIconFrame,
          lastIconFrame.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) else { return }
    handle(timer.hover(hovered.pid, at: Date()))
    startTicking()
  }

  private func startTicking() {
    guard ticker == nil else { return }
    ticker = Task { [weak self] in
      while let self, self.timer.isActive, !Task.isCancelled {
        try? await Task.sleep(for: Self.tickInterval)
        self.tick()
      }
      self?.ticker = nil
    }
  }

  private func tick() {
    let mouse = NSEvent.mouseLocation
    let iconFrame = hovered.flatMap { watcher.frame(of: $0.icon) }
    if let iconFrame { lastIconFrame = iconFrame }
    let overIcon = iconFrame?.insetBy(dx: -2, dy: -2).contains(mouse) ?? false
    if let previous = previousPanelFrame, !previous.contains(mouse) { previousPanelFrame = nil }
    let overPanel = panel.isVisible && (panel.frame.contains(mouse) || previousPanelFrame != nil)
    handle(timer.tick(inside: overIcon || overPanel, at: Date()))
  }

  private func handle(_ action: DockHoverTimer<pid_t>.Action) {
    switch action {
    case .none: break
    case .show(let pid): show(pid, keepSelection: false)
    case .hide: hidePanel()
    }
  }

  /// Las ventanas de la app junto a su icono. Sin ventanas no sale nada.
  private func show(_ pid: pid_t, keepSelection: Bool) {
    guard let hovered, hovered.pid == pid, let icon = watcher.frame(of: hovered.icon),
          let screen = NSScreen.screens.first(where: { $0.frame.intersects(icon) }) ?? NSScreen.main else { return }
    catalog.refresh(only: pid)
    let windows = catalog.windows
    guard !windows.isEmpty else {
      hidePanel()
      return
    }
    let edge = DockEdge(icon: icon, screen: screen.frame)
    let selected = keepSelection ? panel.model.selected.map { min($0, windows.count - 1) } : nil
    panel.layout(count: windows.count, edge: edge, screen: screen.visibleFrame)
    panel.model.windows = windows
    panel.model.selected = selected
    panel.model.thumbnails = [:]
    panel.show(icon: icon, edge: edge, screen: screen.visibleFrame)
    thumbnailTask?.cancel()
    thumbnailTask = WindowThumbnails.capture(windows.filter { !$0.isMinimized }.map(\.id),
                                             maxSide: panel.model.cardWidth) { [weak self] id, image in
      self?.panel.model.thumbnails[id] = image
    }
    watchClicks()
  }

  private func hidePanel() {
    previousPanelFrame = nil
    thumbnailTask?.cancel()
    panel.hide()
    if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
    clickMonitor = nil
  }

  /// Un clic fuera de la vista (también en el Dock) la cierra. Los de dentro no llegan aquí.
  private func watchClicks() {
    guard clickMonitor == nil else { return }
    clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
      MainActor.assumeIsolated { self?.dismiss() }
    }
  }

  private func jump(to index: Int) {
    guard panel.model.windows.indices.contains(index) else { return }
    let window = panel.model.windows[index]
    dismiss()
    catalog.focus(window)
  }

  /// Salir de la app, como ⌘Q: si tiene algo sin guardar, la app pregunta. La vista se va.
  private func quit(appOf index: Int) {
    guard panel.model.windows.indices.contains(index) else { return }
    let pid = panel.model.windows[index].pid
    dismiss()
    NSRunningApplication(processIdentifier: pid)?.terminate()
  }

  /// Cerrar o minimizar: la vista sigue abierta y se vuelve a leer cuando macOS termina, es decir, cuando la lista ha
  /// cambiado y se queda igual en dos lecturas seguidas (durante la animación, una ventana puede salir dos veces).
  private func act(on index: Int, _ action: (SwitcherWindow) -> Void) {
    guard panel.model.windows.indices.contains(index), let pid = timer.shown else { return }
    action(panel.model.windows[index])
    let before = Self.signature(panel.model.windows)
    Task { [weak self] in
      var last = before
      for _ in 0..<Self.reloadSteps {
        try? await Task.sleep(for: Self.reloadStep)
        guard let self, self.timer.shown == pid else { return }
        self.catalog.refresh(only: pid)
        let now = Self.signature(self.catalog.windows)
        if now != before && now == last { break }
        last = now
      }
      guard let self, self.timer.shown == pid else { return }
      self.previousPanelFrame = self.panel.frame
      self.show(pid, keepSelection: true)
    }
  }

  private static func signature(_ windows: [SwitcherWindow]) -> [String] {
    windows.map { "\($0.id) \($0.isMinimized) \($0.title)" }
  }

  private static func runningApp(at url: URL) -> NSRunningApplication? {
    guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return nil }
    return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
  }
}
```

- [ ] **Step 4: `AltTabController`: avisar al abrirse**

En `Sources/Sintecla/AltTabController.swift`, cambiar:

```swift
  private var thumbnailTask: Task<Void, Never>?

  init(settings: AppSettings) {
```

por:

```swift
  private var thumbnailTask: Task<Void, Never>?
  /// Al abrirse el selector (la vista del Dock se cierra).
  var onOpen: (() -> Void)?

  init(settings: AppSettings) {
```

Y cambiar:

```swift
    guard !windows.isEmpty else { return }
    state = SwitcherState(count: windows.count, backward: backward)
```

por:

```swift
    guard !windows.isEmpty else { return }
    onOpen?()
    state = SwitcherState(count: windows.count, backward: backward)
```

- [ ] **Step 5: `DictationController`: arrancar el Dock y Esc en la cadena de teclas**

En `Sources/Sintecla/DictationController.swift`, cambiar:

```swift
  private lazy var altTab = AltTabController(settings: settings)
```

por:

```swift
  private lazy var altTab = AltTabController(settings: settings)
  /// Módulo Dock.
  private lazy var dock = DockPreviewController(settings: settings)
```

Y cambiar:

```swift
    // Después de los atajos de dictado: Finder, Capturas y Alt-Tab.
```

por:

```swift
    // Después de los atajos de dictado: Finder, Capturas, Alt-Tab y Esc de la vista del Dock.
```

Y cambiar:

```swift
          || self.altTab.keyDown(keyCode: keyCode, modifiers: modifiers)
```

por:

```swift
          || self.altTab.keyDown(keyCode: keyCode, modifiers: modifiers)
          || self.dock.keyDown(keyCode: keyCode, modifiers: modifiers)
```

Y cambiar:

```swift
    captures.onNeedsPermission = { [weak self] in self?.onShowCaptures?() }
```

por:

```swift
    captures.onNeedsPermission = { [weak self] in self?.onShowCaptures?() }
    altTab.onOpen = { [weak self] in self?.dock.dismiss() }
```

Y cambiar:

```swift
    altTab.start()
```

por:

```swift
    altTab.start()
    dock.start()
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

Esperado: `Test run with 315 tests in 55 suites passed`.

- [ ] **Step 8: Commit**

```bash
git add Sources/Sintecla/DockWatcher.swift Sources/Sintecla/DockPreviewPanel.swift Sources/Sintecla/DockPreviewController.swift Sources/Sintecla/AltTabController.swift Sources/Sintecla/DictationController.swift
git commit -m 'feat: ventanas de cada app al pasar por el Dock

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 5: Versión 0.13.0, README y spec principal

**Files:**
- Modify: `Sources/SinteclaCoreTests/SmokeTests.swift`, `Sources/SinteclaCore/AppInfo.swift` y `Resources/Info.plist`
- Modify: `README.md` y `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§7)

**Interfaces:**
- Consumes: Todo lo anterior.
- Produces: La versión 0.13.0 (build 14), instalada.

Comprobar el Dock a la izquierda o a la derecha cambia un ajuste del sistema: queda para el usuario, si quiere. Los tests de la Tarea 1 cubren los tres lados.

- [ ] **Step 1: El test de la versión**

En `Sources/SinteclaCoreTests/SmokeTests.swift`, cambiar:

```swift
#expect(AppInfo.version == "0.12.0")
```

por:

```swift
#expect(AppInfo.version == "0.13.0")
```

- [ ] **Step 2: Ver que falla**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA el test con `Expectation failed: AppInfo.version == "0.13.0"`.

- [ ] **Step 3: `AppInfo.version`**

En `Sources/SinteclaCore/AppInfo.swift`, cambiar:

```swift
public static let version = "0.12.0"
```

por:

```swift
public static let version = "0.13.0"
```

- [ ] **Step 4: `Info.plist`**

En `Resources/Info.plist`, cambiar:

```xml
  <key>CFBundleShortVersionString</key><string>0.12.0</string>
  <key>CFBundleVersion</key><string>13</string>
```

por:

```xml
  <key>CFBundleShortVersionString</key><string>0.13.0</string>
  <key>CFBundleVersion</key><string>14</string>
```

- [ ] **Step 5: Ver que pasa**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 315 tests in 55 suites passed`.

- [ ] **Step 6: README: el módulo Dock**

En `README.md`, cambiar:

```text
Sustituye al ⌘Tab de macOS mientras está encendido. |
| **Y además** |
```

por:

```text
Sustituye al ⌘Tab de macOS mientras está encendido. |
| **Dock** | Al pasar el ratón por una app abierta del Dock salen sus ventanas, con una miniatura de cada una: un clic salta a una, y la tarjeta marcada tiene botones para cerrarla o minimizarla. |
| **Y además** |
```

Y cambiar:

```text
Dictado, Reuniones, Finder, Capturas y Alt-Tab son **módulos**
```

por:

```text
Dictado, Reuniones, Finder, Capturas, Alt-Tab y Dock son **módulos**
```

Y cambiar:

```text
Finder, Capturas y Alt-Tab vienen apagados.
```

por:

```text
Finder, Capturas, Alt-Tab y Dock vienen apagados.
```

Y cambiar:

```text
y al soltar `⌘` salta a la ventana marcada.
```

por:

```text
y al soltar `⌘` salta a la ventana marcada.

Con el módulo Dock encendido: al pasar el ratón por una app del Dock salen sus ventanas, y `Esc` cierra la vista.
```

- [ ] **Step 7: Spec principal (§7): las vistas del Dock**

En `docs/superpowers/specs/2026-09-23-sintecla-design.md`, cambiar:

```text
Dictado, Reuniones, Finder, Capturas y Alt-Tab; los tres últimos, apagados de fábrica
```

por:

```text
Dictado, Reuniones, Finder, Capturas, Alt-Tab y Dock; los cuatro últimos, apagados de fábrica
```

Y cambiar:

```text
y **Alt-Tab** (cómo se usa y permisos, ver `2026-10-03-alt-tab-design.md`).
```

por:

```text
**Alt-Tab** (cómo se usa y permisos, ver `2026-10-03-alt-tab-design.md`) y **Dock** (cómo se usa y permisos, ver `2026-10-03-dock-vistas-design.md`).
```

Y cambiar:

```text
Sustituye al ⌘Tab de macOS mientras el módulo está encendido.
```

por:

```text
Sustituye al ⌘Tab de macOS mientras el módulo está encendido.
- **Vistas del Dock** (desde la 0.13.0, módulo Dock): al pasar el ratón por una app abierta del Dock, a los 0,3 s sale junto al icono una vista de cristal con sus ventanas (miniatura, icono y título; las minimizadas al final). Un clic salta a una, y la tarjeta marcada tiene botones para cerrarla o minimizarla.
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
git commit -m 'feat: versión 0.13.0 con las vistas del Dock

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
- Produces: Nada nuevo. Con todo ✓: DockDoor a la Papelera (lo pidió el usuario el 2026-10-03) y la 0.13.0 se cierra cuando el usuario lo pida.

La hace el usuario (spec §8.2), con DockDoor cerrado.

- [ ] **Step 1: Checklist. Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | Módulos → encender Dock; pasar por el icono de una app con una ventana | A los 0,3 s sale su vista con la miniatura, encima del icono |
| 2 | Safari (o Finder) con dos ventanas | Salen las dos; un clic en cada una la pone delante y la vista se va |
| 3 | Ir del icono a la vista; luego sacar el ratón | Con el ratón dentro sigue; al salir, se va enseguida |
| 4 | Con la vista abierta, pasar a otro icono | Cambia al momento |
| 5 | Botón de minimizar en una tarjeta; luego restaurar | La tarjeta pasa al final, atenuada; vuelve al restaurar. La vista sigue abierta |
| 6 | Botón de cerrar (en una ventana sin cambios y en una con cambios sin guardar) | Se cierra y su tarjeta desaparece; con cambios, sale el aviso de la app |
| 7 | Botón ⏻ de una app que se pueda cerrar sin miedo | La app se cierra como con ⌘Q y la vista se va |
| 8 | Una app sin ventanas, una carpeta, la Papelera y una app cerrada | No sale nada |
| 9 | Esc con la vista abierta; clic en el icono del Dock | Se cierra y no vuelve a salir hasta sacar el ratón del icono |
| 10 | Alt-Tab con la vista abierta | La vista se va y sale el selector |
| 11 | Dictado, Finder, Capturas y el resto | Como antes |

---
## Autorrevisión frente a la especificación

| Requisito (spec «Vistas del Dock») | Dónde |
|---|---|
| §2 Módulo apagado de fábrica; permisos; página con el uso, los permisos y el aviso de DockDoor; tarjeta de Inicio; sin bloque en el menú | Tarea 2 |
| §3 Aparecer a los 0,3 s; cambiar de icono al momento; clic salta; cerrar, minimizar o restaurar y salir de la app; actualizar sin irse; desaparecer a los 0,25 s, con Esc, un clic o Alt-Tab; sin vista para apps sin ventanas, cerradas, carpetas y Papelera | Tareas 1, 3 y 4 |
| §4 Las ventanas de Alt-Tab, solo las de esa app | Tarea 3 |
| §5 Junto al icono a 36 puntos, hacia dentro, centrada y corrida; cristal; tarjetas de 240 puntos en fila o columna; miniaturas después | Tareas 1 y 4 |
| §6 El aviso del Dock, el tipo, la app y el sitio del icono; reengancharse si el Dock se reinicia | Tarea 4 |
| §7 Piezas y 0.13.0 (build 14) | Tareas 1 a 5 |
| §8.1 Tests de iconos, sitio, tiempos y módulo | Tareas 1 y 2 |
| §8.2 Aceptación | Tarea 6 |
| §8.3 Riesgos: el aviso del Dock, la lupa, el Dock reiniciado, apps colgadas, DockDoor abierto | Tareas 2 y 4 |
| §9 DockDoor a la Papelera tras la aceptación | Tarea 6 |

**Consistencia de tipos revisada:**
- `DockItem(subrole:url:)` (Tarea 1) lo crea `DockWatcher` y lo lee `DockPreviewController` (Tarea 4).
- `DockPreviewPlacement.screenRect(fromAccessibility:primaryHeight:)` (Tarea 1) lo usa `DockWatcher.frame(of:)`, y `.frame(panel:icon:edge:screen:)` lo usa `DockPreviewPanel.show` (Tarea 4).
- `DockEdge(icon:screen:)` y `DockHoverTimer<pid_t>` (Tarea 1) los usa `DockPreviewController` (Tarea 4).
- `DockPreview.summary` (Tarea 1) lo usa la tarjeta de Inicio (Tarea 2), y `DockPreview.cardWidth` la vista (Tarea 4).
- `AppSettings.moduleDock` (Tarea 2) lo lee `DockPreviewController` (Tarea 4).
- `WindowCatalog.refresh(only:)`, `close(_:)`, `toggleMinimized(_:)` y `WindowCard` (Tarea 3) los usa la vista (Tarea 4).
