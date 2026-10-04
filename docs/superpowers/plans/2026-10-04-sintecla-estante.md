# Sintecla — Estante y avisos en la isla (0.16.0) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un estante de archivos en la muesca (soltar y sacar archivos) y avisos de carga y AirPods en la isla.

**Architecture:** La lógica (lista del estante, qué aviso toca, la cola y las formas de la isla) va en `SinteclaCore` con tests. En la app, piezas sueltas (guardado, arrastres, monitores de energía y de audio) que une `IslandController`. Sin permisos nuevos.

**Tech Stack:** Swift 6, SwiftUI y AppKit (`NSDraggingSource`, `NSDraggingDestination`, monitores globales), IOKit (energía), Core Audio (dispositivos), `system_profiler` (batería de los AirPods), QuickLookThumbnailing, Swift Testing.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-10-03-estante-design.md`.
- **Solo con el módulo Isla encendido.** Dos interruptores nuevos en la página Isla, **encendidos de fábrica**: `islandShelf` y `islandDeviceNotices`.
- **Permisos:** ninguno nuevo.
- **Bandeja:** se abre al acercar archivos a la zona de la muesca (120 puntos por cada lado y 110 por debajo), tras 0,15 s; se recoge a los 0,3 s fuera de la zona y 0,5 s después de soltar el botón. Ventana invisible del tamaño de la muesca, por si acaso.
- **Estante:** al final y sin repetir; guarda marcadores a los originales en `~/Library/Application Support/Sintecla/estante.json`; sacar arrastrando lo quita salvo con ⌥ o si no se soltó; los que faltan se quitan solos. No sale con la tapa cerrada.
- **Avisos:** 3 s cada uno, en fila; esperan a Sintecla y a los 10 s se descartan, salvo los de batería baja. Umbrales del Mac: 20 % y 10 % sin cargador, una vez cada uno, rearmados al enchufar. AirPods: un auricular al 10 % o menos, una vez por conexión. El primer estado no avisa.
- **Colores:** blanco sobre negro; verde al cargar y rojo en batería baja.
- **Medidas** (muesca de 208 × 37,5): compacta del estante como la de la música; desplegada solo con estante, 6 + 78 por debajo; con música y estante, 148 + 78; bandeja, 420 de ancho y 96 por debajo. Panel de 760 × 300.
- **Versión:** 0.16.0 (build 18).
- **Compilar la app con las Command Line Tools 27:** con el SDK de macOS 26, mediante `source scripts/sdk-env.sh`. Los avisos `ld: warning: search path …` los pone SwiftPM y no cuentan.
- **Commits:** en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `estante`: compiló, pasó los tests en cada tarea y el árbol final quedó idéntico al del prototipo.

- **381 tests** (60 suites) en verde: los 353 de antes y 28 nuevos. La release compila sin avisos (aparte de los `ld: warning: search path` de SwiftPM).
- **Arrastres a la muesca** (el usuario los probó en el prototipo, con una ventana de prueba):
  - una ventana sobre la muesca recibe un archivo arrastrado desde Finder;
  - llevarlo hasta el borde de arriba abre Mission Control;
  - abrir la bandeja al entrar en la zona (con el monitor global de ratón, que sí ve el arrastre de Finder) lo evita, y el archivo se recibe;
  - si la bandeja se cierra justo al soltar, la entrega se pierde: por eso espera 0,5 s.
- **Energía:** la API avisa al desenchufar («Battery Power», tiempo −1 mientras calcula) y al enchufar («AC Power»), comprobado por el usuario.
- **AirPods:** `system_profiler SPBluetoothDataType -json` da izquierdo, derecho y estuche en unos 60 ms; los AirPods aparecen como dispositivo de audio Bluetooth en Core Audio. `IOBluetooth` cierra el programa sin el permiso de Bluetooth.
- **La vista, pintada con `ImageRenderer`:** compacta del estante con 🗂 y el número; bandeja con el borde discontinuo; desplegada con la fila y «Vaciar»; avisos de carga y de AirPods con sus anillos, también sin muesca. (`ImageRenderer` no pinta las `ScrollView` ni las vistas de AppKit: la fila se comprobó sin desplazamiento).
- **Sin probar** (lo comprueba la Tarea 6): sacar arrastrando, ⌥, doble clic, reinicio y la cola con un dictado.

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| Llegar arriba con un archivo abre Mission Control | La bandeja se abre al entrar en la zona de la muesca |
| La bandeja se cerraba antes de recibir el archivo | Espera 0,5 s tras soltar el botón |
| `IOBluetooth` pide un permiso nuevo y cierra el programa | Core Audio para saber cuándo se conectan y `system_profiler` para la batería |
| Recién conectados, los AirPods aún no dan batería | Reintentos a los 1, 3 y 6 s |
| La isla puede recogerse mientras se saca un archivo | El origen del arrastre vive en el controlador, y la isla no se recoge hasta soltar |
| El panel con `ignoresMouseEvents` no recibe arrastres | Recibe el ratón mientras es la bandeja o se saca un archivo |
| Los arrastres que salen del estante abrirían la bandeja | `FileDragWatcher` usa solo el monitor global, que no ve los de Sintecla |
| `#expect` no acepta llamadas que cambian el valor | Se guardan antes en una variable |

**Decisiones de este plan que la spec no fijaba:**
- La bandeja manda también sobre lo de Sintecla (si arrastras un archivo mientras dictas, ves la bandeja).
- Con «Enchufado» sale el símbolo del enchufe; con «Cargando», el rayo en verde.
- Los anillos de los AirPods van en verde, y en rojo el que está al 10 % o menos.

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/Shelf.swift` y sus tests | La lista del estante | 1 |
| `Sources/SinteclaCore/DeviceNotices.swift` y sus tests | Qué aviso toca y la cola | 2 |
| `Sources/SinteclaCore/Storage.swift`, `Sources/Sintecla/AppSettings.swift`, `ShelfStore.swift`, `ShelfDrop.swift`, `ShelfRow.swift`, `PowerMonitor.swift`, `AirPodsMonitor.swift` | Guardado, arrastres y monitores | 3 |
| `Sources/SinteclaCore/Island.swift` y sus tests, `IslandView.swift`, `IslandPanel.swift`, `IslandController.swift`, `IslandPage.swift`, `MainWindow.swift` | La isla con todo junto | 4 |
| `AppInfo.swift`, `Info.plist`, `SmokeTests.swift`, `README.md`, spec principal | 0.16.0 | 5 |

---

### Task 1: El estante en el núcleo

**Files:**
- Create: `Sources/SinteclaCore/Shelf.swift`
- Test: `Sources/SinteclaCoreTests/ShelfTests.swift`

**Interfaces:**
- Consumes: Nada.
- Produces: `ShelfItem(id:path:name:bookmark:)` (`Codable`, `Identifiable`); `Shelf` (`Codable`) con `items`, `count`, `isEmpty`, `add(_:) -> Int` (sin repetir rutas), `remove(_:)`, `clear()`, `dragEnded(_:dropped:keep:)` y `refresh(_:) -> Bool` (un cierre que da la ruta y el nombre de ahora, o nil).

La lista del estante, sin nada de AppKit: guardar enlaces (marcadores) a los originales, no copias.

- [ ] **Step 1: Tests: añadir sin repetir, quitar, vaciar, sacar arrastrando, seguir a los movidos y guardar**

Crear `Sources/SinteclaCoreTests/ShelfTests.swift`:

```swift
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct ShelfTests {
  private func item(_ path: String) -> ShelfItem {
    ShelfItem(path: path, name: (path as NSString).lastPathComponent, bookmark: Data(path.utf8))
  }

  @Test func addsAtTheEndWithoutRepeating() {
    var shelf = Shelf()
    var added = shelf.add([item("/tmp/a.pdf"), item("/tmp/b.png")])
    #expect(added == 2)
    added = shelf.add([item("/tmp/c.zip"), item("/tmp/a.pdf")])
    #expect(added == 1)
    #expect(shelf.items.map(\.name) == ["a.pdf", "b.png", "c.zip"])
    #expect(shelf.count == 3)
  }

  @Test func removesOneAndClears() {
    var shelf = Shelf()
    shelf.add([item("/tmp/a.pdf"), item("/tmp/b.png")])
    shelf.remove(shelf.items[0].id)
    #expect(shelf.items.map(\.name) == ["b.png"])
    shelf.clear()
    #expect(shelf.isEmpty)
  }

  @Test func draggingOutRemovesUnlessOptionOrNotDropped() {
    var shelf = Shelf()
    shelf.add([item("/tmp/a.pdf"), item("/tmp/b.png"), item("/tmp/c.zip")])
    let (a, b, c) = (shelf.items[0].id, shelf.items[1].id, shelf.items[2].id)
    shelf.dragEnded(a, dropped: true, keep: false)
    shelf.dragEnded(b, dropped: true, keep: true)
    shelf.dragEnded(c, dropped: false, keep: false)
    #expect(shelf.items.map(\.name) == ["b.png", "c.zip"])
  }

  @Test func refreshDropsMissingAndFollowsMovedFiles() {
    var shelf = Shelf()
    shelf.add([item("/tmp/a.pdf"), item("/tmp/b.png"), item("/tmp/c.zip")])
    let changed = shelf.refresh { item in
      switch item.name {
      case "a.pdf": nil
      case "b.png": (path: "/tmp/fotos/foto.png", name: "foto.png")
      default: (path: item.path, name: item.name)
      }
    }
    #expect(changed)
    #expect(shelf.items.map(\.path) == ["/tmp/fotos/foto.png", "/tmp/c.zip"])
    let again = shelf.refresh { (path: $0.path, name: $0.name) }
    #expect(!again)
  }

  @Test func savesAndLoadsTheSameList() throws {
    var shelf = Shelf()
    shelf.add([item("/tmp/a.pdf"), item("/tmp/b.png")])
    let data = try JSONEncoder().encode(shelf)
    #expect(try JSONDecoder().decode(Shelf.self, from: data) == shelf)
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find type 'ShelfItem' in scope`.

- [ ] **Step 3: `ShelfItem` y `Shelf`**

Crear `Sources/SinteclaCore/Shelf.swift`:

```swift
import Foundation

/// Un archivo del estante (spec «Estante y avisos» §3.4): el marcador para encontrarlo aunque se mueva, y la última
/// ruta y el nombre conocidos.
public struct ShelfItem: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public var path: String
  public var name: String
  public var bookmark: Data

  public init(id: UUID = UUID(), path: String, name: String, bookmark: Data) {
    self.id = id
    self.path = path
    self.name = name
    self.bookmark = bookmark
  }
}

/// La lista del estante (spec «Estante y avisos» §3). Guarda enlaces a los originales, no copias.
public struct Shelf: Codable, Equatable, Sendable {
  public private(set) var items: [ShelfItem] = []

  public init(items: [ShelfItem] = []) {
    self.items = items
  }

  public var isEmpty: Bool { items.isEmpty }
  public var count: Int { items.count }

  /// Al final y sin repetir (misma ruta). Devuelve cuántos entraron.
  @discardableResult
  public mutating func add(_ new: [ShelfItem]) -> Int {
    var added = 0
    for item in new where !items.contains(where: { $0.path == item.path }) {
      items.append(item)
      added += 1
    }
    return added
  }

  public mutating func remove(_ id: UUID) {
    items.removeAll { $0.id == id }
  }

  public mutating func clear() {
    items.removeAll()
  }

  /// Al acabar de arrastrarlo fuera: si se soltó en algún sitio se quita, salvo que se mantuviera ⌥.
  public mutating func dragEnded(_ id: UUID, dropped: Bool, keep: Bool) {
    guard dropped, !keep else { return }
    remove(id)
  }

  /// Vuelve a buscar cada archivo (`locate` da su ruta y nombre de ahora, o nil si ya no está): quita los que faltan y
  /// pone al día los que se movieron o se renombraron. Devuelve si cambió algo.
  @discardableResult
  public mutating func refresh(_ locate: (ShelfItem) -> (path: String, name: String)?) -> Bool {
    let before = items
    items = items.compactMap { item in
      guard let found = locate(item) else { return nil }
      var item = item
      item.path = found.path
      item.name = found.name
      return item
    }
    return items != before
  }
}
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 358 tests in 59 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/Shelf.swift Sources/SinteclaCoreTests/ShelfTests.swift
git commit -m 'feat: el estante de la isla en el núcleo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: Los avisos de carga y AirPods en el núcleo

**Files:**
- Create: `Sources/SinteclaCore/DeviceNotices.swift`
- Test: `Sources/SinteclaCoreTests/DeviceNoticesTests.swift`

**Interfaces:**
- Consumes: Nada.
- Produces: `AirPodsBattery(left:right:case:)` (`isEmpty`, `isLow`); `AirPodsDevice(name:address:battery:)` y `AirPodsDevice.parse(systemProfiler:)`; `PowerState(percent:pluggedIn:charging:minutesLeft:)`; `DeviceNotice` (`.pluggedIn`, `.unplugged`, `.lowBattery`, `.airPods`, `.airPodsLow`; `isUrgent`, `symbol`, `tint` (`.plain`, `.green`, `.red`), `text`, `airPods`, `duration(_:)`); `PowerNotices.update(_:) -> [DeviceNotice]`; `AirPodsNotices` (`lowLevel`, `known(_:)`, `connected(_:)`, `batteryChanged(_:)`, `disconnected(address:)`, `isConnected(address:)`); `NoticeQueue` (`push(_:at:)`, `tick(at:busy:) -> Bool`, `current`, `nextTick`, `isEmpty`).

Qué aviso toca con cada cambio (umbrales del 20 y el 10 %, una vez por conexión en los AirPods) y la cola: 3 s cada uno, esperan a Sintecla y a los 10 s se descartan, salvo los de batería baja. La batería de los AirPods sale del JSON de `system_profiler` (comprobado en el Mac del usuario; la vía Bluetooth pide permiso).

- [ ] **Step 1: Tests: carga, umbrales, textos, AirPods y la cola**

Crear `Sources/SinteclaCoreTests/DeviceNoticesTests.swift`:

```swift
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct DeviceNoticesTests {
  // MARK: Carga

  private func battery(_ percent: Int, minutes: Int? = nil) -> PowerState {
    PowerState(percent: percent, pluggedIn: false, charging: false, minutesLeft: minutes)
  }

  private func plugged(_ percent: Int, charging: Bool = true) -> PowerState {
    PowerState(percent: percent, pluggedIn: true, charging: charging)
  }

  @Test func theFirstStateDoesNotNotify() {
    var power = PowerNotices()
    let notices = power.update(battery(80))
    #expect(notices.isEmpty)
  }

  @Test func pluggingInSaysChargingOrPluggedIn() {
    var power = PowerNotices()
    _ = power.update(battery(80))
    var notices = power.update(plugged(80))
    #expect(notices == [.pluggedIn(percent: 80, charging: true)])
    notices = power.update(plugged(81))
    #expect(notices.isEmpty)
    _ = power.update(battery(81))
    notices = power.update(plugged(81, charging: false))
    #expect(notices == [.pluggedIn(percent: 81, charging: false)])
  }

  @Test func unpluggingGivesPercentAndTimeLeft() {
    var power = PowerNotices()
    _ = power.update(plugged(80))
    var notices = power.update(battery(80, minutes: 380))
    #expect(notices == [.unplugged(percent: 80, minutesLeft: 380)])
    _ = power.update(plugged(80))
    notices = power.update(battery(80))
    #expect(notices == [.unplugged(percent: 80, minutesLeft: nil)])
  }

  @Test func lowBatteryWarnsOncePerThreshold() {
    var power = PowerNotices()
    _ = power.update(battery(25))
    var notices = power.update(battery(21))
    #expect(notices.isEmpty)
    notices = power.update(battery(20))
    #expect(notices == [.lowBattery(percent: 20)])
    notices = power.update(battery(15))
    #expect(notices.isEmpty)
    notices = power.update(battery(10))
    #expect(notices == [.lowBattery(percent: 10)])
    notices = power.update(battery(5))
    #expect(notices.isEmpty)
  }

  @Test func pluggingInRearmsTheThresholds() {
    var power = PowerNotices()
    _ = power.update(battery(21))
    _ = power.update(battery(20))
    _ = power.update(plugged(20))
    _ = power.update(plugged(25))
    _ = power.update(battery(25))
    let notices = power.update(battery(20))
    #expect(notices == [.lowBattery(percent: 20)])
  }

  @Test func startingOrUnpluggingBelowAThresholdDoesNotWarnForIt() {
    var power = PowerNotices()
    _ = power.update(battery(15))
    var notices = power.update(battery(14))
    #expect(notices.isEmpty)
    notices = power.update(battery(10))
    #expect(notices == [.lowBattery(percent: 10)])
  }

  @Test func aJumpAcrossBothThresholdsWarnsOnce() {
    var power = PowerNotices()
    _ = power.update(battery(30))
    var notices = power.update(battery(9))
    #expect(notices == [.lowBattery(percent: 9)])
    notices = power.update(battery(8))
    #expect(notices.isEmpty)
  }

  @Test func textsAndSymbols() {
    #expect(DeviceNotice.pluggedIn(percent: 80, charging: true).text == "Cargando · 80 %")
    #expect(DeviceNotice.pluggedIn(percent: 80, charging: false).text == "Enchufado · 80 %")
    #expect(DeviceNotice.unplugged(percent: 80, minutesLeft: 380).text == "80 % · 6 h 20 min")
    #expect(DeviceNotice.unplugged(percent: 80, minutesLeft: nil).text == "80 %")
    #expect(DeviceNotice.lowBattery(percent: 10).text == "Batería baja · 10 %")
    #expect(DeviceNotice.duration(45) == "45 min")
    #expect(DeviceNotice.duration(120) == "2 h")
    #expect(DeviceNotice.pluggedIn(percent: 80, charging: true).tint == .green)
    #expect(DeviceNotice.lowBattery(percent: 10).tint == .red)
    #expect(DeviceNotice.unplugged(percent: 80, minutesLeft: nil).tint == .plain)
    #expect(DeviceNotice.lowBattery(percent: 10).isUrgent)
    #expect(!DeviceNotice.pluggedIn(percent: 80, charging: true).isUrgent)
  }

  // MARK: AirPods

  private let json = Data("""
  {"SPBluetoothDataType":[{"device_connected":[
    {"AirPods de prueba":{"device_address":"00:11:22:33:44:55","device_batteryLevelCase":"52\\u00a0%",
      "device_batteryLevelLeft":"64\\u00a0%","device_batteryLevelRight":"65 %","device_minorType":"Headphones",
      "device_vendorID":"0x004C"}},
    {"Teclado":{"device_address":"AA:BB:CC:DD:EE:FF","device_minorType":"Keyboard","device_vendorID":"0x046D"}},
    {"Otros cascos":{"device_address":"11:11:11:11:11:11","device_minorType":"Headphones","device_vendorID":"0x0A12"}}
  ]}]}
  """.utf8)

  @Test func readsTheAppleHeadphonesFromSystemProfiler() {
    let devices = AirPodsDevice.parse(systemProfiler: json)
    #expect(devices == [AirPodsDevice(name: "AirPods de prueba", address: "00:11:22:33:44:55",
                                      battery: AirPodsBattery(left: 64, right: 65, case: 52))])
    #expect(AirPodsDevice.parse(systemProfiler: Data("no".utf8)).isEmpty)
  }

  @Test func missingBatteriesStayNil() {
    let data = Data("""
    {"SPBluetoothDataType":[{"device_connected":[{"AirPods de prueba":{"device_address":"00:11","device_batteryLevelLeft":"40 %",
      "device_minorType":"Headphones","device_vendorID":"0x004c"}}]}]}
    """.utf8)
    #expect(AirPodsDevice.parse(systemProfiler: data).first?.battery == AirPodsBattery(left: 40))
  }

  private func pods(_ left: Int?, _ right: Int?, case box: Int? = nil) -> AirPodsDevice {
    AirPodsDevice(name: "AirPods de prueba", address: "00:11", battery: AirPodsBattery(left: left, right: right, case: box))
  }

  @Test func connectingNotifiesWithTheBatteries() {
    var notices = AirPodsNotices()
    let device = pods(64, 65, case: 52)
    #expect(notices.connected(device) == [.airPods(name: "AirPods de prueba", battery: device.battery)])
    #expect(notices.isConnected(address: "00:11"))
    #expect(DeviceNotice.airPods(name: "AirPods de prueba", battery: device.battery).airPods == device.battery)
  }

  @Test func lowAirPodsWarnOncePerConnection() {
    var notices = AirPodsNotices()
    _ = notices.connected(pods(30, 30))
    var result = notices.batteryChanged(pods(11, 30))
    #expect(result.isEmpty)
    result = notices.batteryChanged(pods(10, 30))
    #expect(result == [.airPodsLow(name: "AirPods de prueba", battery: AirPodsBattery(left: 10, right: 30))])
    result = notices.batteryChanged(pods(8, 30))
    #expect(result.isEmpty)
    notices.disconnected(address: "00:11")
    #expect(!notices.isConnected(address: "00:11"))
    result = notices.connected(pods(8, 30))
    #expect(result == [.airPodsLow(name: "AirPods de prueba", battery: AirPodsBattery(left: 8, right: 30))])
  }

  @Test func theCaseDoesNotCountAsLow() {
    #expect(!AirPodsBattery(left: 50, right: 50, case: 5).isLow)
    #expect(AirPodsBattery(left: 50, right: 9).isLow)
    #expect(AirPodsBattery().isEmpty)
  }

  @Test func alreadyConnectedAtStartDoesNotNotify() {
    var notices = AirPodsNotices()
    notices.known(pods(30, 30))
    let result = notices.batteryChanged(pods(9, 30))
    #expect(result.count == 1)
    #expect(notices.batteryChanged(pods(64, 64)).isEmpty)
  }

  // MARK: Cola

  private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

  @Test func oneAfterAnotherThreeSecondsEach() {
    var queue = NoticeQueue()
    queue.push([.lowBattery(percent: 10), .pluggedIn(percent: 10, charging: true)], at: t0)
    var changed = queue.tick(at: t0, busy: false)
    #expect(changed)
    #expect(queue.current == .lowBattery(percent: 10))
    #expect(queue.nextTick == t0 + 3)
    changed = queue.tick(at: t0 + 2, busy: false)
    #expect(!changed)
    changed = queue.tick(at: t0 + 3, busy: false)
    #expect(changed)
    #expect(queue.current == .pluggedIn(percent: 10, charging: true))
    queue.tick(at: t0 + 6, busy: false)
    #expect(queue.current == nil)
    #expect(queue.isEmpty)
  }

  @Test func waitsWhileSinteclaIsBusyAndDropsStaleOnes() {
    var queue = NoticeQueue()
    queue.push([.pluggedIn(percent: 50, charging: true), .lowBattery(percent: 9)], at: t0)
    queue.tick(at: t0, busy: true)
    #expect(queue.current == nil)
    queue.tick(at: t0 + 5, busy: false)
    #expect(queue.current == .pluggedIn(percent: 50, charging: true))

    var late = NoticeQueue()
    late.push([.pluggedIn(percent: 50, charging: true), .lowBattery(percent: 9)], at: t0)
    late.tick(at: t0 + 11, busy: false)
    #expect(late.current == .lowBattery(percent: 9))
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find type 'PowerState' in scope`.

- [ ] **Step 3: `DeviceNotice`, `PowerNotices`, `AirPodsNotices` y `NoticeQueue`**

Crear `Sources/SinteclaCore/DeviceNotices.swift`:

```swift
import Foundation

/// La batería de unos AirPods; lo que no da dato (el estuche cerrado) va a nil.
public struct AirPodsBattery: Equatable, Sendable {
  public var left: Int?
  public var right: Int?
  public var `case`: Int?

  public init(left: Int? = nil, right: Int? = nil, case: Int? = nil) {
    self.left = left
    self.right = right
    self.case = `case`
  }

  public var isEmpty: Bool { left == nil && right == nil && self.case == nil }

  /// Un auricular (no el estuche) al 10 % o menos.
  public var isLow: Bool { [left, right].contains { ($0 ?? 100) <= AirPodsNotices.lowLevel } }
}

/// Unos AirPods conectados, según `system_profiler SPBluetoothDataType -json` (spec «Estante y avisos» §4.3).
public struct AirPodsDevice: Equatable, Sendable {
  public var name: String
  public var address: String
  public var battery: AirPodsBattery

  public init(name: String, address: String, battery: AirPodsBattery) {
    self.name = name
    self.address = address
    self.battery = battery
  }

  /// Los auriculares de Apple conectados (fabricante 0x004C y tipo auriculares), con lo que haya de batería.
  public static func parse(systemProfiler data: Data) -> [AirPodsDevice] {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let sections = root["SPBluetoothDataType"] as? [[String: Any]] else { return [] }
    var devices: [AirPodsDevice] = []
    for section in sections {
      for entry in section["device_connected"] as? [[String: Any]] ?? [] {
        for (name, value) in entry {
          guard let info = value as? [String: Any],
                (info["device_vendorID"] as? String)?.lowercased() == "0x004c",
                info["device_minorType"] as? String == "Headphones" else { continue }
          let battery = AirPodsBattery(left: level(info["device_batteryLevelLeft"]),
                                       right: level(info["device_batteryLevelRight"]),
                                       case: level(info["device_batteryLevelCase"]))
          devices.append(AirPodsDevice(name: name, address: info["device_address"] as? String ?? "",
                                       battery: battery))
        }
      }
    }
    return devices.sorted { $0.name < $1.name }
  }

  /// «64 %» (con espacio duro o sin él) → 64.
  private static func level(_ value: Any?) -> Int? {
    guard let text = value as? String else { return nil }
    return Int(text.prefix { $0.isNumber })
  }
}

/// El estado de la carga del Mac (spec «Estante y avisos» §4.3).
public struct PowerState: Equatable, Sendable {
  public var percent: Int
  public var pluggedIn: Bool
  public var charging: Bool
  /// Lo que queda con la batería; nil mientras macOS lo calcula.
  public var minutesLeft: Int?

  public init(percent: Int, pluggedIn: Bool, charging: Bool, minutesLeft: Int? = nil) {
    self.percent = percent
    self.pluggedIn = pluggedIn
    self.charging = charging
    self.minutesLeft = minutesLeft
  }
}

/// Un aviso de la isla que no es de Sintecla (spec «Estante y avisos» §4.1).
public enum DeviceNotice: Equatable, Sendable {
  /// Al enchufar; `charging` a false si macOS no carga (Optimizar carga o al 100 %).
  case pluggedIn(percent: Int, charging: Bool)
  case unplugged(percent: Int, minutesLeft: Int?)
  case lowBattery(percent: Int)
  case airPods(name: String, battery: AirPodsBattery)
  case airPodsLow(name: String, battery: AirPodsBattery)

  public enum Tint: Sendable { case plain, green, red }

  /// Los de batería baja no se descartan aunque esperen (§4.2).
  public var isUrgent: Bool {
    switch self {
    case .lowBattery, .airPodsLow: true
    default: false
    }
  }

  public var symbol: String {
    switch self {
    case .pluggedIn(_, let charging): charging ? "bolt.fill" : "powerplug.fill"
    case .unplugged(let percent, _): Self.batterySymbol(percent)
    case .lowBattery: "battery.0percent"
    case .airPods, .airPodsLow: "airpods.pro"
    }
  }

  public var tint: Tint {
    switch self {
    case .pluggedIn(_, true): .green
    case .lowBattery, .airPodsLow: .red
    default: .plain
    }
  }

  public var text: String {
    switch self {
    case .pluggedIn(let percent, let charging): "\(charging ? "Cargando" : "Enchufado") · \(percent) %"
    case .unplugged(let percent, let minutes):
      minutes.map { "\(percent) % · \(Self.duration($0))" } ?? "\(percent) %"
    case .lowBattery(let percent): "Batería baja · \(percent) %"
    case .airPods(let name, _): name
    case .airPodsLow(let name, _): "\(name) · batería baja"
    }
  }

  /// La batería de los AirPods, para los anillos; nil en los avisos del Mac.
  public var airPods: AirPodsBattery? {
    switch self {
    case .airPods(_, let battery), .airPodsLow(_, let battery): battery
    default: nil
    }
  }

  /// 380 → «6 h 20 min»; 45 → «45 min»; 120 → «2 h».
  public static func duration(_ minutes: Int) -> String {
    let hours = minutes / 60, rest = minutes % 60
    if hours == 0 { return "\(rest) min" }
    return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
  }

  private static func batterySymbol(_ percent: Int) -> String {
    switch percent {
    case ..<13: "battery.0percent"
    case ..<38: "battery.25percent"
    case ..<63: "battery.50percent"
    case ..<88: "battery.75percent"
    default: "battery.100percent"
    }
  }
}

/// Qué aviso toca con cada cambio de la carga (spec «Estante y avisos» §4.1).
public struct PowerNotices: Sendable {
  /// Avisos de batería baja, sin cargador.
  public static let thresholds = [20, 10]
  private var last: PowerState?
  private var warned: Set<Int> = []

  public init() {}

  /// El primer estado no avisa: es el punto de partida.
  public mutating func update(_ state: PowerState) -> [DeviceNotice] {
    defer { last = state }
    guard let last else {
      if !state.pluggedIn { markWarned(below: state.percent) }
      return []
    }
    if state.pluggedIn {
      warned.removeAll()
      return last.pluggedIn ? [] : [.pluggedIn(percent: state.percent, charging: state.charging)]
    }
    if last.pluggedIn {
      markWarned(below: state.percent)
      return [.unplugged(percent: state.percent, minutesLeft: state.minutesLeft)]
    }
    let crossed = Self.thresholds.filter { state.percent <= $0 && !warned.contains($0) }
    guard !crossed.isEmpty else { return [] }
    markWarned(below: state.percent)
    return [.lowBattery(percent: state.percent)]
  }

  private mutating func markWarned(below percent: Int) {
    for threshold in Self.thresholds where percent <= threshold { warned.insert(threshold) }
  }
}

/// Avisos de los AirPods (spec «Estante y avisos» §4.1): al conectarlos y con batería baja, una vez por conexión.
public struct AirPodsNotices: Sendable {
  public static let lowLevel = 10
  /// Las direcciones conectadas y si ya avisaron de batería baja.
  private var connected: [String: Bool] = [:]

  public init() {}

  /// Los que ya estaban al arrancar: sin aviso.
  public mutating func known(_ device: AirPodsDevice) {
    connected[device.address] = device.battery.isLow
  }

  public mutating func connected(_ device: AirPodsDevice) -> [DeviceNotice] {
    connected[device.address] = device.battery.isLow
    return [device.battery.isLow ? .airPodsLow(name: device.name, battery: device.battery)
                                 : .airPods(name: device.name, battery: device.battery)]
  }

  /// Cada minuto, mientras siguen conectados.
  public mutating func batteryChanged(_ device: AirPodsDevice) -> [DeviceNotice] {
    guard let warned = connected[device.address], !warned, device.battery.isLow else { return [] }
    connected[device.address] = true
    return [.airPodsLow(name: device.name, battery: device.battery)]
  }

  public mutating func disconnected(address: String) {
    connected[address] = nil
  }

  public func isConnected(address: String) -> Bool { connected[address] != nil }
}

/// La cola de avisos (spec «Estante y avisos» §4.2): uno detrás de otro, 3 s cada uno; si Sintecla está ocupada,
/// esperan, y pasados 10 s se descartan salvo los de batería baja.
public struct NoticeQueue: Sendable {
  public static let duration: TimeInterval = 3
  public static let maxWait: TimeInterval = 10

  private var pending: [(notice: DeviceNotice, at: Date)] = []
  public private(set) var current: DeviceNotice?
  private var until: Date?

  public init() {}

  public var isEmpty: Bool { current == nil && pending.isEmpty }

  public mutating func push(_ notices: [DeviceNotice], at now: Date) {
    pending += notices.map { ($0, now) }
  }

  /// Al llegar un aviso, al acabar uno y al cambiar Sintecla. Devuelve si cambió `current`.
  @discardableResult
  public mutating func tick(at now: Date, busy: Bool) -> Bool {
    let before = current
    if let until, now >= until {
      current = nil
      self.until = nil
    }
    if current == nil, !busy {
      pending.removeAll { !$0.notice.isUrgent && now.timeIntervalSince($0.at) > Self.maxWait }
      if !pending.isEmpty {
        current = pending.removeFirst().notice
        until = now + Self.duration
      }
    }
    return current != before
  }

  /// Cuándo hay que volver a mirar (cuando acaba el aviso de ahora).
  public var nextTick: Date? { until }
}
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 374 tests in 60 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/DeviceNotices.swift Sources/SinteclaCoreTests/DeviceNoticesTests.swift
git commit -m 'feat: los avisos de carga y AirPods en el núcleo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: El estante y los monitores en la app

**Files:**
- Modify: `Sources/SinteclaCore/Storage.swift`, `Sources/Sintecla/AppSettings.swift`
- Create: `Sources/Sintecla/ShelfStore.swift`, `Sources/Sintecla/ShelfDrop.swift`, `Sources/Sintecla/ShelfRow.swift`, `Sources/Sintecla/PowerMonitor.swift` y `Sources/Sintecla/AirPodsMonitor.swift`

**Interfaces:**
- Consumes: `Shelf` y `ShelfItem` (Tarea 1); `PowerState`, `AirPodsDevice` y `AirPodsNotices.lowLevel` (Tarea 2); `JSONFileStore` y `AppPaths` (`Storage.swift`).
- Produces: `AppPaths.shelfURL`; `AppSettings.islandShelf` e `islandDeviceNotices` (encendidos de fábrica); `ShelfStore(url:)` (`@Observable`: `items`, `thumbnails`, `add(_:)`, `remove(_:)`, `clear()`, `dragEnded(_:dropped:keep:)`, `url(of:)`, `open(_:)`, `refresh()`); `FileDragWatcher` (`onChange: (NSPoint?) -> Void`, `start()`, `stop()`, `finish()`); `FileDropView` (`accepting`, `onEnter`, `onDrop`); `ShelfDropWindow` (`view`, `show(over:)`, `hide()`); `ShelfRow(store:drag:onDragStart:)`; `ShelfDragSource` (`onEnd: (UUID, Bool, Bool) -> Void`, `begin(item:url:image:event:from:)`); `PowerMonitor` (`onChange`, `start()`, `stop()`, `current()`); `AirPodsMonitor` (`onConnect`, `onDisconnect`, `onBattery`, `onKnown`, `start()`, `stop()`).

Piezas sueltas que aún no usa nadie (las une la isla en la Tarea 4). Comprobado en un prototipo: un arrastre desde Finder sí llega a una ventana sobre la muesca, pero llegar al borde de arriba abre Mission Control; por eso `FileDragWatcher` mira el arrastre con un monitor global (que sí lo ve aunque lo lleve Finder) para abrir la bandeja antes, y la bandeja espera 0,5 s al soltar para no perder la entrega.

- [ ] **Step 1: `AppPaths.shelfURL`**

En `Sources/SinteclaCore/Storage.swift`, cambiar:

```swift
  public static var tonesURL: URL { supportDirectory.appendingPathComponent("tones.json") }
```

por:

```swift
  public static var tonesURL: URL { supportDirectory.appendingPathComponent("tones.json") }
  /// El estante de la isla (spec «Estante y avisos» §3.4).
  public static var shelfURL: URL { supportDirectory.appendingPathComponent("estante.json") }
```

- [ ] **Step 2: Los dos interruptores, encendidos de fábrica**

En `Sources/Sintecla/AppSettings.swift`, cambiar:

```swift
  var moduleIsland: Bool { didSet { defaults.set(moduleIsland, forKey: "moduleIsland") } }
```

por:

```swift
  var moduleIsland: Bool { didSet { defaults.set(moduleIsland, forKey: "moduleIsland") } }
  /// Isla: el estante de archivos y los avisos de carga y AirPods (spec «Estante y avisos» §2), encendidos de fábrica.
  var islandShelf: Bool { didSet { defaults.set(islandShelf, forKey: "islandShelf") } }
  var islandDeviceNotices: Bool { didSet { defaults.set(islandDeviceNotices, forKey: "islandDeviceNotices") } }
```

Y cambiar:

```swift
      "moduleAltTab": false, "moduleDock": false, "moduleIsland": false, "moduleRemote": false, "remoteAlwaysOn": false,
```

por:

```swift
      "moduleAltTab": false, "moduleDock": false, "moduleIsland": false, "moduleRemote": false, "remoteAlwaysOn": false,
      "islandShelf": true, "islandDeviceNotices": true,
```

Y cambiar:

```swift
    moduleIsland = defaults.bool(forKey: "moduleIsland")
```

por:

```swift
    moduleIsland = defaults.bool(forKey: "moduleIsland")
    islandShelf = defaults.bool(forKey: "islandShelf")
    islandDeviceNotices = defaults.bool(forKey: "islandDeviceNotices")
```

- [ ] **Step 3: `ShelfStore`: guardar, marcadores y miniaturas**

Crear `Sources/Sintecla/ShelfStore.swift`:

```swift
import AppKit
import Observation
import QuickLookThumbnailing
import SinteclaCore

/// El estante guardado (spec «Estante y avisos» §3.4): la lista en `estante.json`, con un marcador por archivo para
/// encontrarlo aunque se mueva o se renombre, y la miniatura de cada uno.
@MainActor @Observable
final class ShelfStore {
  private(set) var shelf: Shelf
  private(set) var thumbnails: [UUID: NSImage] = [:]
  @ObservationIgnored private let url: URL

  init(url: URL = AppPaths.shelfURL) {
    self.url = url
    shelf = JSONFileStore.load(Shelf.self, from: url) ?? Shelf()
    refresh()
  }

  var items: [ShelfItem] { shelf.items }

  /// Los archivos soltados en la isla, al final y sin repetir.
  func add(_ urls: [URL]) {
    let items = urls.compactMap { url -> ShelfItem? in
      guard let bookmark = try? url.bookmarkData() else { return nil }
      return ShelfItem(path: url.path, name: url.lastPathComponent, bookmark: bookmark)
    }
    guard shelf.add(items) > 0 else { return }
    save()
  }

  func remove(_ id: UUID) {
    shelf.remove(id)
    thumbnails[id] = nil
    save()
  }

  func clear() {
    shelf.clear()
    thumbnails.removeAll()
    save()
  }

  /// Sacado arrastrando: fuera, salvo que no se soltara en ningún sitio o se mantuviera ⌥.
  func dragEnded(_ id: UUID, dropped: Bool, keep: Bool) {
    shelf.dragEnded(id, dropped: dropped, keep: keep)
    if !shelf.items.contains(where: { $0.id == id }) { thumbnails[id] = nil }
    save()
  }

  /// Dónde está ahora el archivo, o nil si ya no se encuentra (borrado o en la Papelera).
  func url(of item: ShelfItem) -> URL? {
    var stale = false
    guard let url = try? URL(resolvingBookmarkData: item.bookmark, bookmarkDataIsStale: &stale),
          FileManager.default.fileExists(atPath: url.path),
          !url.path.contains("/.Trash/") else { return nil }
    return url
  }

  func open(_ item: ShelfItem) {
    guard let url = url(of: item) else { return refresh() }
    NSWorkspace.shared.open(url)
  }

  /// Al arrancar y al abrir la desplegada: quita los que faltan y sigue a los que se movieron.
  func refresh() {
    if shelf.refresh({ [self] item in url(of: item).map { (path: $0.path, name: $0.lastPathComponent) } }) { save() }
    loadThumbnails()
  }

  private func save() {
    try? JSONFileStore.save(shelf, to: url)
    loadThumbnails()
  }

  /// El icono de Finder al momento y, cuando llega, la miniatura (de una imagen o un PDF, por ejemplo).
  private func loadThumbnails() {
    for item in shelf.items where thumbnails[item.id] == nil {
      thumbnails[item.id] = NSWorkspace.shared.icon(forFile: item.path)
      let request = QLThumbnailGenerator.Request(fileAt: URL(fileURLWithPath: item.path),
                                                 size: CGSize(width: 64, height: 64), scale: 2,
                                                 representationTypes: .thumbnail)
      let id = item.id
      QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] thumbnail, _ in
        guard let image = thumbnail?.nsImage else { return }
        Task { @MainActor in
          if self?.thumbnails[id] != nil { self?.thumbnails[id] = image }
        }
      }
    }
  }
}
```

- [ ] **Step 4: `FileDragWatcher`, `FileDropView` y `ShelfDropWindow`**

Crear `Sources/Sintecla/ShelfDrop.swift`:

```swift
import AppKit
import SinteclaCore

/// Sabe si se están arrastrando archivos desde otra app y dónde va el ratón (spec «Estante y avisos» §3.1): el
/// portapapeles de arrastre cambia al empezar cada arrastre, y el monitor global ve el ratón aunque lo lleve Finder.
/// Los arrastres que salen de Sintecla (sacar del estante) no llegan al monitor global.
@MainActor
final class FileDragWatcher {
  /// Cada movimiento con archivos (dónde va el ratón) y, al soltar el botón, nil.
  var onChange: ((NSPoint?) -> Void)?
  private let board = NSPasteboard(name: .drag)
  private var baseline: Int
  private var dragging = false
  private var monitor: Any?

  init() {
    baseline = board.changeCount
  }

  func start() {
    guard monitor == nil else { return }
    baseline = board.changeCount
    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
      let type = event.type
      MainActor.assumeIsolated { self?.handle(type) }
    }
  }

  func stop() {
    if let monitor { NSEvent.removeMonitor(monitor) }
    monitor = nil
    dragging = false
  }

  /// Tras soltar en la isla: este arrastre ya está atendido.
  func finish() {
    baseline = board.changeCount
    if dragging {
      dragging = false
      onChange?(nil)
    }
  }

  private func handle(_ type: NSEvent.EventType) {
    if type == .leftMouseUp {
      finish()
      return
    }
    if !dragging {
      guard board.changeCount != baseline, board.types?.contains(.fileURL) == true else { return }
      dragging = true
    }
    onChange?(NSEvent.mouseLocation)
  }
}

/// Recibe archivos arrastrados (la bandeja de la isla y la ventana sobre la muesca). Solo los acepta cuando
/// `accepting` es true.
final class FileDropView: NSView {
  var accepting = true
  var onEnter: (() -> Void)?
  var onDrop: (([URL]) -> Void)?

  override init(frame: NSRect) {
    super.init(frame: frame)
    registerForDraggedTypes([.fileURL])
  }

  required init?(coder: NSCoder) { nil }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard accepting else { return [] }
    onEnter?()
    return .copy
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    accepting ? .copy : []
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    guard accepting else { return false }
    let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                    options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    guard !urls.isEmpty else { return false }
    onDrop?(urls)
    return true
  }
}

/// La ventana invisible sobre la muesca real, por si el arrastre llega ahí antes de abrirse la bandeja (spec «Estante
/// y avisos» §3.1). Ahí no hay nada de la barra de menús, así que no tapa ningún clic.
@MainActor
final class ShelfDropWindow {
  private let panel: NSPanel
  let view = FileDropView(frame: .zero)

  init() {
    panel = NSPanel(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    panel.contentView = view
  }

  func show(over notch: CGRect) {
    if panel.frame != notch { panel.setFrame(notch, display: false) }
    if !panel.isVisible { panel.orderFrontRegardless() }
  }

  func hide() {
    panel.orderOut(nil)
  }
}
```

- [ ] **Step 5: `ShelfRow` y el arrastre hacia fuera (`ShelfDragSource`)**

Crear `Sources/Sintecla/ShelfRow.swift`:

```swift
import AppKit
import SinteclaCore
import SwiftUI

/// La fila del estante en la isla desplegada (spec «Estante y avisos» §3.2): cada archivo con su miniatura y su nombre;
/// se saca arrastrándolo, se abre con doble clic y se quita con la ✕. «Vaciar» a la derecha.
struct ShelfRow: View {
  let store: ShelfStore
  let drag: ShelfDragSource
  var onDragStart: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 4) {
          ForEach(store.items) { item in
            ShelfCell(item: item, thumbnail: store.thumbnails[item.id], store: store, drag: drag,
                      onDragStart: onDragStart)
          }
        }
      }
      Button("Vaciar") { store.clear() }
        .buttonStyle(.plain)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.white.opacity(0.55))
        .padding(.leading, 4)
    }
    .frame(height: 66)
  }
}

private struct ShelfCell: View {
  let item: ShelfItem
  let thumbnail: NSImage?
  let store: ShelfStore
  let drag: ShelfDragSource
  var onDragStart: () -> Void
  @State private var hovering = false

  var body: some View {
    VStack(spacing: 3) {
      Group {
        if let thumbnail {
          Image(nsImage: thumbnail).resizable().scaledToFit()
        } else {
          Image(systemName: "doc").resizable().scaledToFit().padding(6)
        }
      }
      .frame(width: 38, height: 38)
      Text(item.name)
        .font(.system(size: 9.5))
        .lineLimit(1)
        .truncationMode(.middle)
        .foregroundStyle(.white.opacity(0.85))
    }
    .frame(width: 62)
    .padding(.vertical, 4)
    .background(.white.opacity(hovering ? 0.12 : 0), in: .rect(cornerRadius: 8))
    .overlay {
      FileDragArea(onDrag: { event, view in
        guard let url = store.url(of: item) else { return store.refresh() }
        onDragStart()
        drag.begin(item: item.id, url: url, image: thumbnail, event: event, from: view)
      }, onDoubleClick: { store.open(item) }, onHover: { hovering = $0 })
    }
    .overlay(alignment: .topTrailing) {
      if hovering {
        Button { store.remove(item.id) } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 13))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.black, .white.opacity(0.85))
        }
        .buttonStyle(.plain)
        .help("Quitar del estante")
        .offset(x: 2, y: -2)
      }
    }
    .help(item.name)
  }
}

/// Lo de AppKit de cada archivo: empezar el arrastre, el doble clic y el ratón encima.
private struct FileDragArea: NSViewRepresentable {
  var onDrag: (NSEvent, NSView) -> Void
  var onDoubleClick: () -> Void
  var onHover: (Bool) -> Void

  func makeNSView(context: Context) -> DragAreaView {
    DragAreaView()
  }

  func updateNSView(_ view: DragAreaView, context: Context) {
    view.onDrag = onDrag
    view.onDoubleClick = onDoubleClick
    view.onHover = onHover
  }

  final class DragAreaView: NSView {
    var onDrag: ((NSEvent, NSView) -> Void)?
    var onDoubleClick: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    private var down: NSEvent?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
      super.updateTrackingAreas()
      trackingAreas.forEach(removeTrackingArea)
      addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                     owner: self))
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }

    override func mouseDown(with event: NSEvent) {
      down = event
      if event.clickCount == 2 { onDoubleClick?() }
    }

    /// El arrastre empieza al moverse unos puntos con el botón pulsado.
    override func mouseDragged(with event: NSEvent) {
      guard let down else { return }
      let start = down.locationInWindow, now = event.locationInWindow
      guard hypot(now.x - start.x, now.y - start.y) > 3 else { return }
      self.down = nil
      onHover?(false)
      onDrag?(down, self)
    }

    override func mouseUp(with event: NSEvent) {
      down = nil
    }
  }
}

/// El arrastre hacia fuera del estante (spec «Estante y avisos» §3.3). Vive en el controlador, no en la vista: la isla
/// puede recogerse mientras se arrastra. Al acabar dice si se soltó en algún sitio y si se mantenía ⌥.
@MainActor
final class ShelfDragSource: NSObject, NSDraggingSource {
  var onEnd: ((UUID, _ dropped: Bool, _ keep: Bool) -> Void)?
  private var item: UUID?

  func begin(item: UUID, url: URL, image: NSImage?, event: NSEvent, from view: NSView) {
    self.item = item
    let dragging = NSDraggingItem(pasteboardWriter: url as NSURL)
    let side: CGFloat = 38
    let origin = view.convert(event.locationInWindow, from: nil)
    dragging.setDraggingFrame(NSRect(x: origin.x - side / 2, y: origin.y - side / 2, width: side, height: side),
                              contents: image ?? NSWorkspace.shared.icon(forFile: url.path))
    view.beginDraggingSession(with: [dragging], event: event, source: self)
  }

  nonisolated func draggingSession(_ session: NSDraggingSession,
                                   sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    context == .outsideApplication ? [.copy, .move, .link, .generic] : []
  }

  nonisolated func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint,
                                   operation: NSDragOperation) {
    let keep = NSEvent.modifierFlags.contains(.option)
    MainActor.assumeIsolated {
      guard let item else { return }
      self.item = nil
      onEnd?(item, !operation.isEmpty, keep)
    }
  }
}
```

- [ ] **Step 6: `PowerMonitor`: la API de energía**

Crear `Sources/Sintecla/PowerMonitor.swift`:

```swift
import Foundation
import IOKit.ps
import SinteclaCore

/// La carga del Mac con la API de energía de macOS (spec «Estante y avisos» §4.3): avisa sola de cada cambio. Solo lee;
/// no toca el SMC.
@MainActor
final class PowerMonitor {
  var onChange: ((PowerState) -> Void)?
  private var source: CFRunLoopSource?

  func start() {
    guard source == nil else { return }
    let context = Unmanaged.passUnretained(self).toOpaque()
    guard let created = IOPSNotificationCreateRunLoopSource({ context in
      guard let context else { return }
      let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
      MainActor.assumeIsolated { monitor.changed() }
    }, context)?.takeRetainedValue() else { return }
    source = created
    CFRunLoopAddSource(CFRunLoopGetMain(), created, .defaultMode)
    changed()
  }

  func stop() {
    guard let source else { return }
    CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
    self.source = nil
  }

  private func changed() {
    if let state = Self.current() { onChange?(state) }
  }

  /// La batería interna; nil en un Mac sin batería.
  static func current() -> PowerState? {
    let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let sources = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]
    for source in sources {
      guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
            info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
            let percent = info[kIOPSCurrentCapacityKey] as? Int else { continue }
      let minutes = info[kIOPSTimeToEmptyKey] as? Int
      return PowerState(percent: percent, pluggedIn: info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                        charging: info[kIOPSIsChargingKey] as? Bool ?? false,
                        minutesLeft: minutes.flatMap { $0 > 0 ? $0 : nil })
    }
    return nil
  }
}
```

- [ ] **Step 7: `AirPodsMonitor`: dispositivos de audio y `system_profiler`**

Crear `Sources/Sintecla/AirPodsMonitor.swift`:

```swift
import CoreAudio
import Foundation
import SinteclaCore

/// Los AirPods sin permisos nuevos (spec «Estante y avisos» §4.3): al conectarse aparecen como dispositivo de audio
/// Bluetooth, y la batería sale de `system_profiler` (la vía Bluetooth directa pide el permiso de Bluetooth).
@MainActor
final class AirPodsMonitor {
  /// Unos AirPods recién conectados (con la batería que haya tras los reintentos).
  var onConnect: ((AirPodsDevice) -> Void)?
  var onDisconnect: ((String) -> Void)?
  /// Cada minuto, mientras sigan conectados.
  var onBattery: ((AirPodsDevice) -> Void)?
  /// Los que ya estaban al arrancar.
  var onKnown: ((AirPodsDevice) -> Void)?

  /// Recién conectados puede que aún no den la batería: se vuelve a mirar a los 1, 3 y 6 s.
  static let retries: [Double] = [1, 3, 6]
  static let pollInterval: Duration = .seconds(60)

  private var listener: AudioObjectPropertyListenerBlock?
  /// Las direcciones de los AirPods conectados.
  private var connected: Set<String> = []
  private var bluetoothAudio: Set<String> = []
  private var pollTask: Task<Void, Never>?
  private var running = false

  func start() {
    guard !running else { return }
    running = true
    bluetoothAudio = Self.bluetoothAudioDevices()
    Task {
      for device in await Self.read() {
        connected.insert(device.address)
        onKnown?(device)
      }
      poll()
    }
    var address = Self.devicesAddress
    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      Task { @MainActor in self?.devicesChanged() }
    }
    listener = block
    AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block)
  }

  func stop() {
    guard running else { return }
    running = false
    if let listener {
      var address = Self.devicesAddress
      AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
    }
    listener = nil
    pollTask?.cancel()
    pollTask = nil
    connected.removeAll()
  }

  private func devicesChanged() {
    let now = Self.bluetoothAudioDevices()
    let appeared = !now.subtracting(bluetoothAudio).isEmpty
    let left = !bluetoothAudio.subtracting(now).isEmpty
    bluetoothAudio = now
    if left { Task { await checkDisconnected() } }
    if appeared { Task { await findNew() } }
  }

  private func findNew() async {
    for (index, delay) in Self.retries.enumerated() {
      try? await Task.sleep(for: .seconds(delay - (index == 0 ? 0 : Self.retries[index - 1])))
      guard running else { return }
      let new = await Self.read().filter { !connected.contains($0.address) }
      // Sin batería todavía: se espera al siguiente intento, salvo en el último.
      let ready = new.filter { !$0.battery.isEmpty || index == Self.retries.count - 1 }
      for device in ready {
        connected.insert(device.address)
        onConnect?(device)
      }
      if !new.isEmpty, ready.count == new.count { return }
    }
  }

  private func checkDisconnected() async {
    let still = Set(await Self.read().map(\.address))
    for address in connected.subtracting(still) {
      connected.remove(address)
      onDisconnect?(address)
    }
  }

  private func poll() {
    pollTask?.cancel()
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: Self.pollInterval)
        guard let self else { return }
        guard self.running, !self.connected.isEmpty else { continue }
        for device in await Self.read() where self.connected.contains(device.address) {
          self.onBattery?(device)
        }
      }
    }
  }

  // MARK: Fuentes

  private static var devicesAddress: AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal,
                               mElement: kAudioObjectPropertyElementMain)
  }

  /// Los identificadores de los dispositivos de audio Bluetooth conectados.
  private static func bluetoothAudioDevices() -> Set<String> {
    var address = devicesAddress
    var size: UInt32 = 0
    let system = AudioObjectID(kAudioObjectSystemObject)
    guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
    var result: Set<String> = []
    for id in ids {
      var transport: UInt32 = 0
      var transportSize = UInt32(MemoryLayout<UInt32>.size)
      var transportAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType,
                                                        mScope: kAudioObjectPropertyScopeGlobal,
                                                        mElement: kAudioObjectPropertyElementMain)
      guard AudioObjectGetPropertyData(id, &transportAddress, 0, nil, &transportSize, &transport) == noErr,
            transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
      else { continue }
      result.insert(String(id))
    }
    return result
  }

  /// `system_profiler SPBluetoothDataType -json`, fuera del hilo principal (tarda unos 60 ms).
  private nonisolated static func read() async -> [AirPodsDevice] {
    await Task.detached {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
      process.arguments = ["SPBluetoothDataType", "-json"]
      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = FileHandle.nullDevice
      guard (try? process.run()) != nil else { return [] }
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      return AirPodsDevice.parse(systemProfiler: data)
    }.value
  }
}
```

- [ ] **Step 8: Compilar la release (sin avisos)**

Run:

```bash
source scripts/sdk-env.sh && swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build complete' | grep -v 'ld: warning: search path' | tail -3
```

Esperado: `Build complete!`.

- [ ] **Step 9: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 374 tests in 60 suites passed`.

- [ ] **Step 10: Commit**

```bash
git add Sources/SinteclaCore/Storage.swift Sources/Sintecla/AppSettings.swift Sources/Sintecla/ShelfStore.swift Sources/Sintecla/ShelfDrop.swift Sources/Sintecla/ShelfRow.swift Sources/Sintecla/PowerMonitor.swift Sources/Sintecla/AirPodsMonitor.swift
git commit -m 'feat: piezas del estante y monitores de carga y AirPods

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 4: La isla con el estante, la bandeja y los avisos

**Files:**
- Modify: `Sources/SinteclaCore/Island.swift` y `Sources/SinteclaCoreTests/IslandTests.swift` (formas nuevas)
- Modify: `Sources/Sintecla/IslandView.swift`, `Sources/Sintecla/IslandPanel.swift`, `Sources/Sintecla/IslandController.swift`, `Sources/Sintecla/IslandPage.swift` y `Sources/Sintecla/MainWindow.swift`

**Interfaces:**
- Consumes: Tareas 1 a 3.
- Produces: `IslandActivity.device`; `IslandForm.shelf`, `.tray` y `.expanded(music:shelf:)`; `IslandLayout.form(…, shelf:dragging:)`, `dropZone(around:)`, `isHoverable(_:)` y las medidas `shelfRow`, `shelfOnlyGap`, `trayDrop`, `dropZoneSide`, `dropZoneDrop`; `IslandModel.device`; `IslandView(model:overlay:music:shelf:drag:onOpenApp:onShelfDrag:onCommand:onSeek:)`; `IslandPanel.dropView` (panel de 760 × 300); `IslandPage(settings:)`.

La bandeja manda sobre todo (también a pantalla completa) y no sale sin muesca; los avisos son una actividad más (con burbuja si hay música) y sí salen en la isla virtual. La desplegada lleva la música arriba y la fila del estante debajo. El controlador une la cola de avisos con lo que hace Sintecla.

- [ ] **Step 1: Tests: formas del estante, bandeja, avisos, zona de la muesca y medidas**

Sustituir todo el contenido de `Sources/SinteclaCoreTests/IslandTests.swift`:

```swift
import CoreGraphics
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct IslandTests {
  // MARK: Formas

  @Test func withNothingItIsTheNotch() {
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: false) == .notch)
    #expect(IslandLayout.form(activity: nil, music: false, hovering: true, fullScreen: false) == .notch)
  }

  @Test func musicIsCompactAndExpandsWithTheMouse() {
    #expect(IslandLayout.form(activity: nil, music: true, hovering: false, fullScreen: false) == .compact)
    #expect(IslandLayout.form(activity: nil, music: true, hovering: true, fullScreen: false)
              == .expanded(music: true, shelf: false))
  }

  @Test func sinteclaWinsAndMusicGoesToTheBubble() {
    #expect(IslandLayout.form(activity: .listening, music: false, hovering: true, fullScreen: false)
              == .activity(.listening, bubble: false))
    #expect(IslandLayout.form(activity: .meeting, music: true, hovering: true, fullScreen: false)
              == .activity(.meeting, bubble: true))
  }

  @Test func fullScreenHidesTheRestButNotSintecla() {
    #expect(IslandLayout.form(activity: nil, music: true, hovering: false, fullScreen: true) == .hidden)
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: true) == .hidden)
    #expect(IslandLayout.form(activity: .notice, music: false, hovering: false, fullScreen: true)
              == .activity(.notice, bubble: false))
  }

  @Test func withoutNotchOnlySinteclaShows() {
    #expect(IslandLayout.form(activity: nil, music: true, hovering: true, fullScreen: false, hasNotch: false) == .hidden)
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: false, hasNotch: false) == .hidden)
    #expect(IslandLayout.form(activity: .listening, music: true, hovering: false, fullScreen: false, hasNotch: false)
              == .activity(.listening, bubble: false))
  }

  // MARK: Estante y avisos

  @Test func withFilesAndNoMusicItIsTheShelf() {
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: false, shelf: 3) == .shelf)
    #expect(IslandLayout.form(activity: nil, music: false, hovering: true, fullScreen: false, shelf: 3)
              == .expanded(music: false, shelf: true))
  }

  @Test func withMusicTheCompactIsTheMusicsAndTheExpandedHasBoth() {
    #expect(IslandLayout.form(activity: nil, music: true, hovering: false, fullScreen: false, shelf: 3) == .compact)
    #expect(IslandLayout.form(activity: nil, music: true, hovering: true, fullScreen: false, shelf: 3)
              == .expanded(music: true, shelf: true))
  }

  @Test func draggingFilesOpensTheTrayOverEverything() {
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: false, dragging: true) == .tray)
    #expect(IslandLayout.form(activity: .listening, music: true, hovering: false, fullScreen: true, dragging: true)
              == .tray)
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: false, hasNotch: false,
                              shelf: 3, dragging: true) == .hidden)
  }

  @Test func deviceNoticesAreActivitiesAlsoWithoutNotch() {
    #expect(IslandLayout.form(activity: .device, music: true, hovering: false, fullScreen: false)
              == .activity(.device, bubble: true))
    #expect(IslandLayout.form(activity: .device, music: true, hovering: false, fullScreen: false, hasNotch: false)
              == .activity(.device, bubble: false))
    #expect(IslandActivity.device.isTall)
  }

  @Test func onlyMusicAndShelfFormsExpand() {
    #expect(IslandLayout.isHoverable(.compact) && IslandLayout.isHoverable(.shelf))
    #expect(IslandLayout.isHoverable(.expanded(music: false, shelf: true)))
    #expect(!IslandLayout.isHoverable(.tray) && !IslandLayout.isHoverable(.notch))
    #expect(!IslandLayout.isHoverable(.activity(.device, bubble: false)))
  }

  @Test func theDropZoneSurroundsTheNotch() {
    let rect = CGRect(x: 751, y: 1074.5, width: 208, height: 37.5)
    #expect(IslandLayout.dropZone(around: rect) == CGRect(x: 631, y: 964.5, width: 448, height: 147.5))
  }

  // MARK: Medidas

  private let notch = CGSize(width: 208, height: 37.5)

  @Test func sizesGrowFromTheNotch() {
    #expect(IslandLayout.size(of: .hidden, notch: notch) == .zero)
    #expect(IslandLayout.size(of: .notch, notch: notch) == notch)
    #expect(IslandLayout.size(of: .compact, notch: notch) == CGSize(width: 288, height: 37.5))
    #expect(IslandLayout.size(of: .expanded(music: true, shelf: false), notch: notch) == CGSize(width: 420, height: 185.5))
    #expect(IslandLayout.size(of: .activity(.listening, bubble: true), notch: notch) == CGSize(width: 380, height: 67.5))
    // «Hecho» cabe en los lados, como la compacta.
    #expect(IslandLayout.size(of: .activity(.done, bubble: false), notch: notch) == CGSize(width: 288, height: 37.5))
    #expect(IslandLayout.bubbleDiameter(notch: notch) == 37.5)
  }

  @Test func shelfSizes() {
    #expect(IslandLayout.size(of: .shelf, notch: notch) == CGSize(width: 288, height: 37.5))
    #expect(IslandLayout.size(of: .expanded(music: false, shelf: true), notch: notch) == CGSize(width: 420, height: 121.5))
    #expect(IslandLayout.size(of: .expanded(music: true, shelf: true), notch: notch) == CGSize(width: 420, height: 263.5))
    #expect(IslandLayout.size(of: .tray, notch: notch) == CGSize(width: 420, height: 133.5))
  }

  @Test func withoutNotchActivitiesAreOneRow() {
    let virtual = CGSize(width: 180, height: 24)
    #expect(IslandLayout.size(of: .activity(.listening, bubble: false), notch: virtual, hasNotch: false)
              == CGSize(width: 352, height: 38))
    #expect(IslandLayout.size(of: .activity(.done, bubble: false), notch: virtual, hasNotch: false)
              == CGSize(width: 260, height: 24))
  }

  @Test func onlyDoneStaysShort() {
    #expect(IslandActivity.listening.isTall && IslandActivity.meeting.isTall && IslandActivity.processing.isTall)
    #expect(IslandActivity.notice.isTall)
    #expect(!IslandActivity.done.isTall)
  }

  // MARK: Ratón

  private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

  @Test func expandsAfterAShortHover() {
    var hover = IslandHover()
    var changed = hover.update(inside: true, at: t0)
    #expect(!changed)
    changed = hover.update(inside: true, at: t0 + 0.1)
    #expect(!changed)
    changed = hover.update(inside: true, at: t0 + 0.15)
    #expect(changed)
    #expect(hover.isExpanded)
  }

  @Test func passingByDoesNotExpand() {
    var hover = IslandHover()
    hover.update(inside: true, at: t0)
    hover.update(inside: false, at: t0 + 0.1)
    let changed = hover.update(inside: true, at: t0 + 0.2)
    #expect(!changed)
    #expect(!hover.isExpanded)
  }

  @Test func collapsesAfterLeavingAndComingBackKeepsIt() {
    var hover = IslandHover()
    hover.update(inside: true, at: t0)
    hover.update(inside: true, at: t0 + 0.2)
    var changed = hover.update(inside: false, at: t0 + 1)
    #expect(!changed)
    changed = hover.update(inside: true, at: t0 + 1.2)
    #expect(!changed)
    changed = hover.update(inside: false, at: t0 + 1.3)
    #expect(!changed)
    changed = hover.update(inside: false, at: t0 + 1.5)
    #expect(!changed)
    changed = hover.update(inside: false, at: t0 + 1.6)
    #expect(changed)
    #expect(!hover.isExpanded)
  }

  @Test func resetCollapses() {
    var hover = IslandHover()
    hover.update(inside: true, at: t0)
    hover.update(inside: true, at: t0 + 0.2)
    hover.reset()
    #expect(!hover.isExpanded)
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: type 'IslandForm' has no member 'shelf'` (y otros parecidos: `tray`, `IslandActivity.device`, `expanded` sin valores asociados).

- [ ] **Step 3: `IslandLayout` con el estante, la bandeja y los avisos**

Sustituir todo el contenido de `Sources/SinteclaCore/Island.swift`:

```swift
import CoreGraphics
import Foundation

/// Lo que hace Sintecla, visto desde la isla (spec «La isla» §3.3).
public enum IslandActivity: Equatable, Sendable {
  /// Dictado, traducir, preguntar o notas.
  case listening
  case meeting
  case processing
  case done
  /// Avisos y mensajes de la pastilla.
  case notice
  /// Avisos de carga y AirPods (spec «Estante y avisos» §4).
  case device

  /// Las que bajan por debajo de la muesca, con el texto debajo. «Hecho» cabe en los lados.
  public var isTall: Bool { self != .done }
}

/// La forma de la isla (spec «La isla» §3.1).
public enum IslandForm: Equatable, Sendable {
  /// A pantalla completa, sin nada de Sintecla: no se ve.
  case hidden
  /// Igual que la muesca real.
  case notch
  /// Con música: carátula a un lado y onda al otro.
  case compact
  /// Sin música y con archivos en el estante: la bandeja y cuántos hay (spec «Estante y avisos» §3.2).
  case shelf
  /// Con el ratón encima: la música arriba (si la hay) y la fila del estante debajo (si hay archivos).
  case expanded(music: Bool, shelf: Bool)
  /// Arrastrando archivos cerca de la muesca: la bandeja donde soltarlos (spec «Estante y avisos» §3.1).
  case tray
  /// Sintecla; con `bubble`, la música va al lado en una burbuja.
  case activity(IslandActivity, bubble: Bool)
}

/// Qué forma toca y cuánto mide (spec «La isla» §3.1).
public enum IslandLayout {
  /// Lo que crece la forma compacta por cada lado de la muesca.
  public static let wing: CGFloat = 40
  /// Lo que crecen por cada lado las actividades altas, y lo que bajan por debajo de la muesca.
  public static let tallWing: CGFloat = 86
  public static let tallDrop: CGFloat = 30
  /// Sin muesca, todo va en una fila: lo que baja por debajo de la barra de menús.
  public static let virtualDrop: CGFloat = 14
  /// La desplegada: ancho mínimo y lo que baja por debajo de la muesca.
  public static let expandedWidth: CGFloat = 420
  public static let expandedDrop: CGFloat = 148
  /// La fila del estante en la desplegada, y lo que baja la desplegada solo con estante antes de la fila.
  public static let shelfRow: CGFloat = 78
  public static let shelfOnlyGap: CGFloat = 6
  /// Lo que baja la bandeja por debajo de la muesca.
  public static let trayDrop: CGFloat = 96
  /// La zona de la muesca donde un arrastre de archivos abre la bandeja: tanto por cada lado y por debajo.
  public static let dropZoneSide: CGFloat = 120
  public static let dropZoneDrop: CGFloat = 110
  /// Hueco entre la isla y la burbuja de la música.
  public static let bubbleGap: CGFloat = 8

  /// `hasNotch` a false: tapa cerrada, isla virtual arriba en el centro, solo con lo de Sintecla y los avisos; sin
  /// nada, no se ve. `shelf`: cuántos archivos hay en el estante; `dragging`: hay archivos arrastrándose en la zona de
  /// la muesca (la bandeja manda sobre todo, también a pantalla completa).
  public static func form(activity: IslandActivity?, music: Bool, hovering: Bool, fullScreen: Bool,
                          hasNotch: Bool = true, shelf: Int = 0, dragging: Bool = false) -> IslandForm {
    guard hasNotch else { return activity.map { .activity($0, bubble: false) } ?? .hidden }
    if dragging { return .tray }
    if let activity { return .activity(activity, bubble: music) }
    if fullScreen { return .hidden }
    let hasShelf = shelf > 0
    guard music || hasShelf else { return .notch }
    if hovering { return .expanded(music: music, shelf: hasShelf) }
    return music ? .compact : .shelf
  }

  /// La zona de la muesca donde un arrastre de archivos abre la bandeja, en coordenadas de pantalla (spec «Estante y
  /// avisos» §3.1). Llega hasta arriba: el borde de la pantalla también cuenta.
  public static func dropZone(around notch: CGRect) -> CGRect {
    CGRect(x: notch.minX - dropZoneSide, y: notch.minY - dropZoneDrop, width: notch.width + 2 * dropZoneSide,
           height: notch.height + dropZoneDrop)
  }

  /// `hasNotch` a false: isla virtual; las actividades altas llevan todo en una fila y bajan menos.
  public static func size(of form: IslandForm, notch: CGSize, hasNotch: Bool = true) -> CGSize {
    switch form {
    case .hidden: .zero
    case .notch: notch
    case .compact, .shelf, .activity(.done, _): CGSize(width: notch.width + 2 * wing, height: notch.height)
    case .expanded(let music, let shelf):
      CGSize(width: max(notch.width + 2 * wing, expandedWidth),
             height: notch.height + (music ? expandedDrop : shelfOnlyGap) + (shelf ? shelfRow : 0))
    case .tray: CGSize(width: max(notch.width + 2 * wing, expandedWidth), height: notch.height + trayDrop)
    case .activity: CGSize(width: notch.width + 2 * tallWing, height: notch.height + (hasNotch ? tallDrop : virtualDrop))
    }
  }

  /// Las que se despliegan con el ratón encima.
  public static func isHoverable(_ form: IslandForm) -> Bool {
    switch form {
    case .compact, .shelf, .expanded: true
    default: false
    }
  }

  /// La burbuja de la música: un círculo del alto de la muesca.
  public static func bubbleDiameter(notch: CGSize) -> CGFloat { notch.height }
}

/// Desplegar al tener el ratón encima 0,15 s y recoger a los 0,3 s de sacarlo (spec «La isla» §3.1).
public struct IslandHover: Equatable, Sendable {
  public static var expandDelay: TimeInterval { 0.15 }
  public static var collapseDelay: TimeInterval { 0.3 }
  /// Las fechas son grandes: sin este margen, 0,15 s podrían medir 0,1499999.
  static var epsilon: TimeInterval { 0.001 }

  public private(set) var isExpanded = false
  private var insideSince: Date?
  private var outsideSince: Date?

  public init() {}

  /// Cada vez que se mueve el ratón (y al cumplirse cada espera). Devuelve si cambió `isExpanded`.
  @discardableResult
  public mutating func update(inside: Bool, at now: Date) -> Bool {
    if inside {
      outsideSince = nil
      guard !isExpanded else { return false }
      let since = insideSince ?? now
      insideSince = since
      guard now.timeIntervalSince(since) >= Self.expandDelay - Self.epsilon else { return false }
      isExpanded = true
      return true
    }
    insideSince = nil
    guard isExpanded else { return false }
    let since = outsideSince ?? now
    outsideSince = since
    guard now.timeIntervalSince(since) >= Self.collapseDelay - Self.epsilon else { return false }
    isExpanded = false
    outsideSince = nil
    return true
  }

  /// Sin música que desplegar, o al cambiar de pantalla.
  public mutating func reset() {
    self = IslandHover()
  }
}
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 381 tests in 60 suites passed`.

- [ ] **Step 5: `IslandView`: compacta del estante, desplegada con la fila, bandeja y avisos**

Sustituir todo el contenido de `Sources/Sintecla/IslandView.swift`:

```swift
import AppKit
import Observation
import SinteclaCore
import SwiftUI

/// Lo que decide el controlador y pinta la isla.
@MainActor @Observable
final class IslandModel {
  var form = IslandForm.notch
  /// El tamaño de la muesca de esta pantalla.
  var notch = CGSize(width: 200, height: 32)
  /// Sin muesca (tapa cerrada): isla virtual, con lo de Sintecla en una fila centrada.
  var hasNotch = true
  /// Mientras se arrastra la barra de progreso: la fracción que se enseña (de 0 a 1).
  var scrub: Double?
  /// El aviso de carga o AirPods que se enseña (spec «Estante y avisos» §4).
  var device: DeviceNotice?
}

/// La isla (spec «La isla» §3): una sola forma negra que cambia de tamaño con un muelle; dentro, la música o lo de
/// Sintecla, que entran y salen con fundido. Siempre en blanco sobre negro.
struct IslandView: View {
  let model: IslandModel
  let overlay: OverlayModel
  let music: NowPlayingClient
  let shelf: ShelfStore
  let drag: ShelfDragSource
  var onOpenApp: () -> Void
  /// Al empezar a sacar un archivo del estante.
  var onShelfDrag: () -> Void
  var onCommand: (NowPlayingClient.Command) -> Void
  var onSeek: (Double) -> Void

  /// Lo que se abren las esquinas de arriba hacia los lados.
  static let flare: CGFloat = 6
  static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
  /// Los avisos bajan con un rebote.
  static let bounce = Animation.spring(response: 0.4, dampingFraction: 0.62)

  var body: some View {
    let size = IslandLayout.size(of: model.form, notch: model.notch, hasNotch: model.hasNotch)
    island(size)
      .overlay(alignment: .topTrailing) {
        if case .activity(_, true) = model.form {
          bubble
            .offset(x: IslandLayout.bubbleDiameter(notch: model.notch) + IslandLayout.bubbleGap)
            .transition(.scale(scale: 0.3, anchor: .leading).combined(with: .opacity))
        }
      }
      .animation(isNotice ? Self.bounce : Self.spring, value: model.form)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .foregroundStyle(.white)
      .environment(\.colorScheme, .dark)
  }

  private var isNotice: Bool {
    switch model.form {
    case .activity(.notice, _), .activity(.device, _): true
    default: false
    }
  }

  private var isOpen: Bool {
    switch model.form {
    case .expanded, .tray: true
    default: false
    }
  }

  // MARK: La forma

  private func island(_ size: CGSize) -> some View {
    ZStack(alignment: .top) {
      IslandShape(flare: Self.flare, bottomRadius: bottomRadius).fill(.black)
      if case .activity(.processing, _) = model.form {
        Shimmer(flare: Self.flare, bottomRadius: bottomRadius)
      }
      content
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipped()
    }
    .frame(width: size.width + 2 * Self.flare, height: size.height)
    .shadow(color: .black.opacity(isOpen ? 0.35 : 0), radius: 18, y: 8)
    .opacity(model.form == .hidden ? 0 : 1)
  }

  private var bottomRadius: CGFloat {
    switch model.form {
    case .hidden, .notch: 10
    case .compact, .shelf, .activity(.done, _): 13
    case .activity: 22
    case .tray: 26
    case .expanded: 32
    }
  }

  // MARK: Lo de dentro

  @ViewBuilder private var content: some View {
    switch model.form {
    case .hidden, .notch:
      Color.clear
    case .compact:
      compact.transition(.opacity)
    case .shelf:
      shelfCompact.transition(.opacity)
    case .expanded(let showsMusic, let showsShelf):
      expanded(music: showsMusic, shelf: showsShelf)
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
    case .tray:
      tray.transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
    case .activity(.device, _):
      deviceView
        .id(model.device.map { "\($0)" } ?? "")
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
    case .activity(let activity, _):
      activityView(activity)
        .id(activity)
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
    }
  }

  private var compact: some View {
    HStack(spacing: 0) {
      Artwork(music: music, side: 22).padding(.leading, 9)
      Spacer()
      MusicBars(playing: music.track?.isPlaying ?? false, tint: music.tint).padding(.trailing, 12)
    }
    .frame(height: model.notch.height)
  }

  /// Sin música y con archivos: la bandeja y cuántos hay.
  private var shelfCompact: some View {
    HStack(spacing: 0) {
      Image(systemName: "tray.full.fill").font(.system(size: 13, weight: .semibold)).padding(.leading, 12)
      Spacer()
      Text("\(shelf.items.count)")
        .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
        .contentTransition(.numericText())
        .padding(.trailing, 14)
    }
    .frame(height: model.notch.height)
  }

  /// Arriba la música (si la hay) y debajo la fila del estante (si hay archivos).
  private func expanded(music showsMusic: Bool, shelf showsShelf: Bool) -> some View {
    VStack(spacing: 0) {
      Color.clear.frame(height: model.notch.height)
      if showsMusic {
        musicControls.frame(height: IslandLayout.expandedDrop, alignment: .top)
      } else {
        Color.clear.frame(height: IslandLayout.shelfOnlyGap)
      }
      if showsShelf {
        VStack(spacing: 0) {
          if showsMusic { Rectangle().fill(.white.opacity(0.15)).frame(height: 1).padding(.bottom, 6) }
          ShelfRow(store: shelf, drag: drag, onDragStart: onShelfDrag)
        }
        .frame(height: IslandLayout.shelfRow, alignment: .top)
      }
    }
    .padding(.horizontal, 22)
  }

  @ViewBuilder private var musicControls: some View {
    if let track = music.track {
      VStack(spacing: 0) {
        HStack(spacing: 12) {
          Button(action: onOpenApp) { Artwork(music: music, side: 56) }
            .buttonStyle(.plain)
            .help("Abrir la app que suena")
          VStack(alignment: .leading, spacing: 2) {
            Text(track.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            Text(track.artist.isEmpty ? track.album : track.artist)
              .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
          }
          Spacer(minLength: 8)
          MusicBars(playing: track.isPlaying, tint: music.tint)
        }
        .padding(.top, 6)
        if track.duration > 0 {
          ProgressRow(track: track, model: model, onSeek: onSeek).padding(.top, 10)
        }
        HStack(spacing: 34) {
          ControlButton(symbol: "backward.fill", size: 15) { onCommand(.previous) }
          ControlButton(symbol: track.isPlaying ? "pause.fill" : "play.fill", size: 21) { onCommand(.toggle) }
          ControlButton(symbol: "forward.fill", size: 15) { onCommand(.next) }
        }
        .padding(.top, 4)
      }
    }
  }

  /// Arrastrando archivos cerca de la muesca: dónde soltarlos.
  private var tray: some View {
    VStack(spacing: 0) {
      Color.clear.frame(height: model.notch.height)
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        .overlay {
          Label("Suelta aquí para guardarlo en el estante", systemImage: "tray.and.arrow.down.fill")
            .font(.system(size: 13, weight: .medium))
        }
        .frame(height: IslandLayout.trayDrop - 18)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
  }

  // MARK: Avisos de carga y AirPods

  @ViewBuilder private var deviceView: some View {
    if let notice = model.device {
      if !model.hasNotch {
        HStack(spacing: 10) {
          deviceIcon(notice)
          Text(notice.text).font(.system(size: 13, weight: .medium, design: .rounded)).lineLimit(1)
            .foregroundStyle(Self.color(notice.tint == .red ? .red : .plain))
          if let pods = notice.airPods { PodRings(battery: pods) }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        VStack(spacing: 0) {
          HStack(spacing: 0) {
            deviceIcon(notice).frame(width: IslandLayout.tallWing)
            Spacer()
            Group {
              if let pods = notice.airPods { PodRings(battery: pods) }
            }
            .frame(width: IslandLayout.tallWing)
          }
          .frame(height: model.notch.height)
          Text(notice.text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(Self.color(notice.tint == .red ? .red : .plain))
            .lineLimit(1)
            .padding(.horizontal, 18)
            .frame(height: IslandLayout.tallDrop - 6)
        }
      }
    }
  }

  private func deviceIcon(_ notice: DeviceNotice) -> some View {
    Image(systemName: notice.symbol)
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(Self.color(notice.tint))
  }

  static func color(_ tint: DeviceNotice.Tint) -> Color {
    switch tint {
    case .plain: .white
    case .green: Color(red: 0.2, green: 0.84, blue: 0.35)
    case .red: Color(red: 1, green: 0.27, blue: 0.23)
    }
  }

  @ViewBuilder private func activityView(_ activity: IslandActivity) -> some View {
    let phase = overlay.phase
    if !model.hasNotch {
      // Sin cámara en medio: el icono, el texto y la onda, en una fila centrada.
      HStack(spacing: 10) {
        leftWing(phase)
        if activity.isTall {
          Text(OverlayView.label(for: phase, liveText: overlay.liveText) ?? "")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .lineLimit(1)
            .truncationMode(.head)
            .contentTransition(.opacity)
        }
        rightWing(phase)
      }
      .padding(.horizontal, 18)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if activity.isTall {
      VStack(spacing: 0) {
        HStack(spacing: 0) {
          leftWing(phase).frame(width: IslandLayout.tallWing)
          Spacer()
          rightWing(phase).frame(width: IslandLayout.tallWing)
        }
        .frame(height: model.notch.height)
        Text(OverlayView.label(for: phase, liveText: overlay.liveText) ?? "")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .lineLimit(1)
          .truncationMode(.head)
          .contentTransition(.opacity)
          .padding(.horizontal, 18)
          .frame(height: IslandLayout.tallDrop - 6)
      }
    } else {
      HStack {
        leftWing(phase).frame(width: IslandLayout.wing)
        Spacer()
      }
      .frame(height: model.notch.height)
    }
  }

  @ViewBuilder private func leftWing(_ phase: OverlayModel.Phase) -> some View {
    if case .processing = phase {
      Spinner()
    } else {
      Image(systemName: OverlayView.symbol(for: phase))
        .font(.system(size: 15, weight: .semibold))
        .contentTransition(.symbolEffect(.replace))
    }
  }

  @ViewBuilder private func rightWing(_ phase: OverlayModel.Phase) -> some View {
    switch phase {
    case .listening(.meeting):
      if let startedAt = overlay.startedAt {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
          Text(OverlayView.clock(context.date.timeIntervalSince(startedAt)))
            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
        }
      }
    case .listening(.notes):
      HStack(spacing: 6) {
        if let startedAt = overlay.startedAt {
          TimelineView(.periodic(from: startedAt, by: 1)) { context in
            Text(OverlayView.clock(context.date.timeIntervalSince(startedAt)))
              .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
          }
        }
        LevelBars(level: overlay.level).scaleEffect(0.8)
      }
    case .listening:
      LevelBars(level: overlay.level).scaleEffect(0.8)
    default:
      EmptyView()
    }
  }

  // MARK: La burbuja

  private var bubble: some View {
    let side = IslandLayout.bubbleDiameter(notch: model.notch)
    return Circle().fill(.black)
      .frame(width: side, height: side)
      .overlay {
        Artwork(music: music, side: side - 10).clipShape(.circle)
      }
      .overlay(alignment: .bottomTrailing) {
        if music.track?.isPlaying == false {
          Image(systemName: "pause.fill").font(.system(size: 7, weight: .bold))
            .padding(3).background(.black, in: .circle)
        }
      }
  }
}

/// La batería de los AirPods: izquierdo, derecho y estuche, cada uno en un anillo con su %; el que no da dato no sale.
private struct PodRings: View {
  let battery: AirPodsBattery

  var body: some View {
    HStack(spacing: 4) {
      ForEach(Array([battery.left, battery.right, battery.case].enumerated()), id: \.offset) { _, level in
        if let level {
          ZStack {
            Circle().stroke(.white.opacity(0.2), lineWidth: 2)
            Circle().trim(from: 0, to: CGFloat(level) / 100)
              .stroke(IslandView.color(level <= AirPodsNotices.lowLevel ? .red : .green),
                      style: StrokeStyle(lineWidth: 2, lineCap: .round))
              .rotationEffect(.degrees(-90))
            Text("\(level)").font(.system(size: 7.5, weight: .bold, design: .rounded).monospacedDigit())
          }
          .frame(width: 21, height: 21)
        }
      }
    }
  }
}

/// La carátula, o el icono de la app que suena si no hay.
private struct Artwork: View {
  let music: NowPlayingClient
  let side: CGFloat

  var body: some View {
    Group {
      if let artwork = music.artwork {
        Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
      } else if let pid = music.track?.pid, let icon = NSRunningApplication(processIdentifier: pid)?.icon {
        Image(nsImage: icon).resizable()
      } else {
        Image(systemName: "music.note").resizable().scaledToFit().padding(side * 0.2)
      }
    }
    .frame(width: side, height: side)
    .clipShape(.rect(cornerRadius: side * 0.24))
  }
}

/// La onda de la música: 4 barras animadas del color de la carátula, quietas en pausa (spec «La isla» §3.2). No sigue
/// el sonido real.
struct MusicBars: View {
  let playing: Bool
  let tint: ArtworkTint
  private static let speeds: [Double] = [5.1, 7.3, 6.2, 8.9]
  private static let phases: [Double] = [0, 1.3, 2.1, 0.7]

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playing)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      HStack(spacing: 2) {
        ForEach(0..<4, id: \.self) { index in
          Capsule()
            .fill(Color(red: tint.red, green: tint.green, blue: tint.blue))
            .frame(width: 3, height: playing ? Self.height(index, time) : 3)
        }
      }
    }
    .frame(height: 14)
    .animation(.easeInOut(duration: 0.25), value: playing)
  }

  private static func height(_ index: Int, _ time: Double) -> CGFloat {
    let wave = (sin(time * speeds[index] + phases[index]) + 1) / 2
    let swell = 0.6 + 0.4 * (sin(time * 1.7 + Double(index)) + 1) / 2
    return 4 + 10 * CGFloat(wave * swell)
  }
}

/// La barra de progreso, que se puede arrastrar, y los tiempos.
private struct ProgressRow: View {
  let track: NowPlaying
  let model: IslandModel
  var onSeek: (Double) -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.5)) { context in
      let fraction = model.scrub ?? track.progress(at: context.date)
      let position = fraction * track.duration
      VStack(spacing: 4) {
        GeometryReader { geometry in
          Capsule().fill(.white.opacity(0.2))
            .overlay(alignment: .leading) {
              Capsule().fill(.white).frame(width: geometry.size.width * fraction)
            }
            .frame(height: model.scrub == nil ? 4 : 6)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0)
              .onChanged { model.scrub = min(1, max(0, $0.location.x / geometry.size.width)) }
              .onEnded { _ in if let scrub = model.scrub { onSeek(scrub) } })
        }
        .frame(height: 10)
        .animation(.easeOut(duration: 0.15), value: model.scrub == nil)
        HStack {
          Text(NowPlaying.clock(position))
          Spacer()
          Text("-" + NowPlaying.clock(track.duration - position))
        }
        .font(.system(size: 10, weight: .medium).monospacedDigit())
        .foregroundStyle(.white.opacity(0.55))
      }
    }
  }
}

/// Un control de la música: se ilumina con el ratón encima.
private struct ControlButton: View {
  let symbol: String
  let size: CGFloat
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: size, weight: .semibold))
        .contentTransition(.symbolEffect(.replace))
        .frame(width: 30, height: 26)
        .opacity(hovering ? 1 : 0.85)
        .scaleEffect(hovering ? 1.1 : 1)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

/// Procesando: un arco que gira, dibujado a mano para que vaya a juego con el brillo del borde.
private struct Spinner: View {
  var body: some View {
    TimelineView(.animation) { context in
      Circle()
        .trim(from: 0.15, to: 1)
        .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate * 360))
    }
    .frame(width: 14, height: 14)
  }
}

/// Procesando: un brillo que recorre el borde de la isla.
private struct Shimmer: View {
  let flare: CGFloat
  let bottomRadius: CGFloat

  var body: some View {
    TimelineView(.animation) { context in
      let angle = context.date.timeIntervalSinceReferenceDate * 220
      IslandShape(flare: flare, bottomRadius: bottomRadius)
        .stroke(AngularGradient(colors: [.clear, .white.opacity(0.85), .clear, .clear], center: .center,
                                angle: .degrees(angle)), lineWidth: 1.5)
    }
  }
}
```

- [ ] **Step 6: `IslandPanel`: más alto y con zona para soltar**

Sustituir todo el contenido de `Sources/Sintecla/IslandPanel.swift`:

```swift
import AppKit
import SwiftUI

/// El panel de la isla: transparente, encima de la barra de menús y pegado arriba, centrado en la muesca. No activa
/// Sintecla, y solo recibe el ratón cuando el controlador se lo pide (con el ratón dentro de la isla): así la barra de
/// menús de alrededor sigue funcionando.
@MainActor
final class IslandPanel {
  /// Cabe la isla más grande (desplegada con música y estante) con su sombra, y la burbuja al lado.
  static let size = CGSize(width: 760, height: 300)

  private let panel: NSPanel
  /// Recibe los archivos cuando la isla es la bandeja (spec «Estante y avisos» §3.1).
  let dropView = FileDropView(frame: NSRect(origin: .zero, size: IslandPanel.size))

  init(view: IslandView) {
    panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.nonactivatingPanel, .borderless],
                    backing: .buffered, defer: false)
    // Por encima de la barra de menús.
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    let hosting = FirstMouseHostingView(rootView: view)
    hosting.frame = dropView.bounds
    hosting.autoresizingMask = [.width, .height]
    dropView.addSubview(hosting)
    dropView.accepting = false
    panel.contentView = dropView
  }

  var acceptsMouse: Bool {
    get { !panel.ignoresMouseEvents }
    set { if panel.ignoresMouseEvents == newValue { panel.ignoresMouseEvents = !newValue } }
  }

  /// Pegado arriba de la pantalla y centrado en la muesca.
  func show(on screen: NSScreen, notch: CGRect) {
    let frame = NSRect(x: notch.midX - Self.size.width / 2, y: screen.frame.maxY - Self.size.height,
                       width: Self.size.width, height: Self.size.height)
    if panel.frame != frame { panel.setFrame(frame, display: true) }
    panel.orderFrontRegardless()
  }

  func hide() {
    acceptsMouse = false
    panel.orderOut(nil)
  }
}
```

- [ ] **Step 7: `IslandController`: bandeja, estante, arrastre fuera y cola de avisos**

Sustituir todo el contenido de `Sources/Sintecla/IslandController.swift`:

```swift
import AppKit
import Observation
import SinteclaCore

/// Módulo Isla (spec «La isla»): une lo que suena, lo que hace Sintecla (el mismo `OverlayModel` de la pastilla), el
/// ratón y la pantalla completa, y decide la forma de la isla. También pausa la música al dictar (§3.4). Desde la
/// 0.15.0, el estante de archivos y los avisos de carga y AirPods (spec «Estante y avisos»).
@MainActor
final class IslandController {
  private let settings: AppSettings
  private let overlay: OverlayModel
  private let music = NowPlayingClient.shared
  private let model = IslandModel()
  private let shelf = ShelfStore()
  private let drag = ShelfDragSource()
  private lazy var panel = IslandPanel(view: IslandView(
    model: model, overlay: overlay, music: music, shelf: shelf, drag: drag,
    onOpenApp: { [weak self] in self?.openPlayingApp() },
    onShelfDrag: { [weak self] in self?.draggingOut = true },
    onCommand: { [weak self] in self?.music.send($0) },
    onSeek: { [weak self] in self?.seek(to: $0) }))
  private let dropWindow = ShelfDropWindow()
  private let fileDrag = FileDragWatcher()
  private let power = PowerMonitor()
  private let airPods = AirPodsMonitor()
  private var powerNotices = PowerNotices()
  private var airPodsNotices = AirPodsNotices()
  private var notices = NoticeQueue()
  private var noticeTask: Task<Void, Never>?
  /// La bandeja: se abre al acercar archivos a la muesca y se recoge al alejarse (como la desplegada).
  private var trayHover = IslandHover()
  private var trayTask: Task<Void, Never>?
  /// Sacando un archivo del estante: la isla no se recoge hasta soltarlo.
  private var draggingOut = false
  private var hover = IslandHover()
  private var presence = MusicPresence()
  private var pauser = MusicPauser()
  private var screen: NSScreen?
  private var notch: CGRect?
  private var fullScreen = false
  /// Sin muesca (tapa cerrada): isla virtual en la pantalla principal, solo con lo de Sintecla.
  private var hasNotch = true
  /// Lo de Sintecla sale en la isla, y no en la pastilla (lo pide `DictationController` con `claimActivity()`).
  private var takesActivity = false
  /// El modo que se estaba escuchando, para saber cuándo empieza y cuándo termina.
  private var listening: HotkeyMode?
  private var monitors: [Any] = []
  private var observers: [NSObjectProtocol] = []
  private var observingPhase = false
  private var lingerTask: Task<Void, Never>?
  private var recheckTask: Task<Void, Never>?

  init(settings: AppSettings, overlay: OverlayModel) {
    self.settings = settings
    self.overlay = overlay
  }

  /// Encendido y con una pantalla: la del MacBook o, con la tapa cerrada, la principal (isla virtual).
  var isActive: Bool { settings.moduleIsland && screen != nil }

  /// Lo llama Sintecla al arrancar: desde ahí, la isla sigue al interruptor del módulo y a los del estante y los avisos.
  func start() {
    apply()
    withObservationTracking {
      _ = settings.moduleIsland
      _ = settings.islandShelf
      _ = settings.islandDeviceNotices
    } onChange: { [weak self] in
      Task { @MainActor in self?.start() }
    }
  }

  /// Antes de enseñar un estado de Sintecla: true si lo enseña la isla (encendida, aunque se esté trabajando en otra
  /// pantalla); si no, va a la pastilla de abajo.
  func claimActivity() -> Bool {
    takesActivity = isActive
    refresh()
    return takesActivity
  }

  private func apply() {
    if settings.moduleIsland {
      music.onChange = { [weak self] in self?.musicChanged($0) }
      music.start()
      install()
      watchPhase()
      applyShelf()
      applyDeviceNotices()
      screensChanged()
    } else {
      music.onChange = nil
      music.stop()
      uninstall()
      stopShelf()
      stopDeviceNotices()
      takesActivity = false
      screen = nil
      notch = nil
      panel.hide()
    }
  }

  private var shelfOn: Bool { settings.moduleIsland && settings.islandShelf }

  private func applyShelf() {
    guard settings.islandShelf else { return stopShelf() }
    fileDrag.onChange = { [weak self] in self?.fileDragMoved($0) }
    fileDrag.start()
    panel.dropView.onDrop = { [weak self] in self?.dropped($0) }
    dropWindow.view.onEnter = { [weak self] in self?.openTray() }
    dropWindow.view.onDrop = { [weak self] in self?.dropped($0) }
    drag.onEnd = { [weak self] id, dropped, keep in self?.draggedOut(id, dropped: dropped, keep: keep) }
    shelf.refresh()
    watchShelf()
  }

  /// Al cambiar el estante (soltar, ✕, Vaciar, sacar), la forma puede cambiar.
  private var observingShelf = false
  private func watchShelf() {
    guard !observingShelf else { return }
    observingShelf = true
    withObservationTracking { _ = shelf.items } onChange: { [weak self] in
      Task { @MainActor in
        self?.observingShelf = false
        self?.refresh()
        self?.watchShelf()
      }
    }
  }

  private func stopShelf() {
    fileDrag.stop()
    dropWindow.hide()
    trayHover.reset()
  }

  private func applyDeviceNotices() {
    guard settings.islandDeviceNotices else { return stopDeviceNotices() }
    power.onChange = { [weak self] in self?.push(self?.powerNotices.update($0) ?? []) }
    airPods.onKnown = { [weak self] in self?.airPodsNotices.known($0) }
    airPods.onConnect = { [weak self] in self?.push(self?.airPodsNotices.connected($0) ?? []) }
    airPods.onBattery = { [weak self] in self?.push(self?.airPodsNotices.batteryChanged($0) ?? []) }
    airPods.onDisconnect = { [weak self] in self?.airPodsNotices.disconnected(address: $0) }
    power.start()
    airPods.start()
  }

  private func stopDeviceNotices() {
    power.stop()
    airPods.stop()
    powerNotices = PowerNotices()
    airPodsNotices = AirPodsNotices()
    notices = NoticeQueue()
    noticeTask?.cancel()
    model.device = nil
  }

  // MARK: Avisos

  private func install() {
    guard monitors.isEmpty else { return }
    let moved: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
    if let global = NSEvent.addGlobalMonitorForEvents(matching: moved, handler: { [weak self] _ in
      MainActor.assumeIsolated { self?.mouseMoved() }
    }) {
      monitors.append(global)
    }
    if let local = NSEvent.addLocalMonitorForEvents(matching: moved, handler: { [weak self] event in
      MainActor.assumeIsolated { self?.mouseMoved() }
      return event
    }) {
      monitors.append(local)
    }
    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                        queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.screensChanged() }
    })
    let workspace = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
      observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.spaceChanged() }
      })
    }
  }

  private func uninstall() {
    monitors.forEach(NSEvent.removeMonitor)
    monitors.removeAll()
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    observers.removeAll()
  }

  /// Cada cambio de estado de Sintecla: la forma y, al empezar y terminar de escuchar, la pausa de la música.
  private func watchPhase() {
    guard !observingPhase else { return }
    observingPhase = true
    withObservationTracking { _ = overlay.phase } onChange: { [weak self] in
      Task { @MainActor in
        self?.observingPhase = false
        self?.phaseChanged()
        self?.watchPhase()
      }
    }
  }

  private func phaseChanged() {
    guard settings.moduleIsland else { return }
    var mode: HotkeyMode?
    if case .listening(let current) = overlay.phase { mode = current }
    if let mode, listening == nil,
       let command = pauser.listeningStarted(mode: mode, musicPlaying: music.track?.isPlaying ?? false) {
      send(command)
    }
    if mode == nil, listening != nil, let command = pauser.listeningEnded() {
      send(command)
    }
    listening = mode
    tickNotices()
    refresh()
  }

  private func send(_ command: MusicPauser.Command) {
    music.send(command == .pause ? .pause : .play)
  }

  private func musicChanged(_ track: NowPlaying?) {
    pauser.musicChanged(isPlaying: track?.isPlaying ?? false)
    presence.update(track, at: Date())
    // En pausa, la música se va de la isla a los 5 minutos.
    lingerTask?.cancel()
    if let track, !track.isPlaying {
      lingerTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(MusicPresence.pausedLinger + 0.5))
        guard !Task.isCancelled else { return }
        self?.refresh()
      }
    }
    refresh()
  }

  private func screensChanged() {
    if let real = NotchScreen.current, let rect = NotchScreen.notchRect(on: real) {
      screen = real
      notch = rect
      hasNotch = true
    } else {
      // La pantalla principal es la de la barra de menús.
      screen = NSScreen.screens.first
      notch = screen.map(NotchScreen.virtualNotch(on:))
      hasNotch = false
    }
    hover.reset()
    checkFullScreen()
    refresh()
  }

  /// Al cambiar de escritorio o de app; la animación de macOS tarda un poco en dejar la ventana en su sitio.
  private func spaceChanged() {
    checkFullScreen()
    refresh()
    Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(700))
      self?.checkFullScreen()
      self?.refresh()
    }
  }

  /// A pantalla completa: la app de delante tiene una ventana normal del tamaño de la pantalla de la muesca.
  private func checkFullScreen() {
    guard let screen, let app = NSWorkspace.shared.frontmostApplication,
          let primary = NSScreen.screens.first?.frame else {
      fullScreen = false
      return
    }
    // La lista de ventanas mide desde arriba a la izquierda de la pantalla principal.
    let target = CGRect(x: screen.frame.minX, y: primary.maxY - screen.frame.maxY, width: screen.frame.width,
                        height: screen.frame.height)
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
      as? [[String: Any]] ?? []
    fullScreen = windows.contains { window in
      guard (window[kCGWindowOwnerPID as String] as? Int32) == app.processIdentifier,
            (window[kCGWindowLayer as String] as? Int) == 0,
            let bounds = window[kCGWindowBounds as String] as? NSDictionary,
            let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
      return rect == target
    }
  }

  // MARK: Forma y ratón

  private func refresh() {
    guard isActive, let screen, let notch else {
      panel.hide()
      dropWindow.hide()
      return
    }
    let activity = (takesActivity ? Self.activity(for: overlay.phase) : nil) ?? (model.device == nil ? nil : .device)
    let showsMusic = presence.isShown(music.track, at: Date())
    // Al desplegarse, se quitan del estante los archivos que ya no están.
    if shelfOn, hover.isExpanded, !Self.isExpanded(model.form) { shelf.refresh() }
    let files = shelfOn ? shelf.items.count : 0
    if !showsMusic, files == 0 { hover.reset() }
    let form = IslandLayout.form(activity: activity, music: showsMusic, hovering: hover.isExpanded || draggingOut,
                                 fullScreen: fullScreen, hasNotch: hasNotch, shelf: files,
                                 dragging: shelfOn && trayHover.isExpanded)
    model.notch = notch.size
    model.hasNotch = hasNotch
    if model.form != form { model.form = form }
    panel.dropView.accepting = form == .tray
    panel.show(on: screen, notch: notch)
    if shelfOn, hasNotch { dropWindow.show(over: notch) } else { dropWindow.hide() }
    updateMouse()
  }

  private static func activity(for phase: OverlayModel.Phase) -> IslandActivity? {
    switch phase {
    case .hidden: nil
    case .listening(.meeting): .meeting
    case .listening: .listening
    case .processing: .processing
    case .done: .done
    case .message, .notice: .notice
    }
  }

  private static func isExpanded(_ form: IslandForm) -> Bool {
    if case .expanded = form { return true }
    return false
  }

  /// Sintecla ocupa la isla: los avisos esperan (spec «Estante y avisos» §4.2).
  private var sinteclaBusy: Bool {
    takesActivity && Self.activity(for: overlay.phase) != nil
  }

  /// El sitio de la isla en la pantalla, con las curvas de arriba.
  private var islandRect: CGRect? {
    guard let screen, let notch else { return nil }
    let size = IslandLayout.size(of: model.form, notch: notch.size, hasNotch: hasNotch)
    guard size != .zero else { return nil }
    let width = size.width + 2 * IslandView.flare
    return CGRect(x: notch.midX - width / 2, y: screen.frame.maxY - size.height, width: width, height: size.height)
  }

  private func mouseMoved() {
    guard isActive else { return }
    updateMouse()
  }

  /// Con música o archivos, el ratón dentro de la isla la despliega (y fuera la recoge); solo entonces el panel recibe
  /// clics. La bandeja recibe el arrastre en toda su forma.
  private func updateMouse() {
    let inside = islandRect?.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) ?? false
    let hoverable = IslandLayout.isHoverable(model.form)
    panel.acceptsMouse = model.form == .tray || draggingOut || (inside && hoverable)
    if hover.update(inside: inside && hoverable, at: Date()) { refresh() }
    // El ratón puede quedarse quieto: se vuelve a mirar cuando se cumple la espera.
    recheckTask?.cancel()
    let waiting = hoverable && inside != hover.isExpanded
    guard waiting else { return }
    let delay = inside ? IslandHover.expandDelay : IslandHover.collapseDelay
    recheckTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay + 0.02))
      guard !Task.isCancelled else { return }
      self?.updateMouse()
    }
  }

  // MARK: Estante

  /// Cada movimiento de un arrastre de archivos desde otra app (nil al soltar el botón).
  private func fileDragMoved(_ location: NSPoint?) {
    guard shelfOn, hasNotch, let notch else { return }
    guard let location else {
      // Al soltar, la bandeja espera un poco para no perder la entrega.
      trayTask?.cancel()
      trayTask = Task { [weak self] in
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        self?.closeTray()
      }
      return
    }
    let inZone = IslandLayout.dropZone(around: notch).contains(location)
    if trayHover.update(inside: inZone, at: Date()) { refresh() }
    recheckTray(inZone)
  }

  /// El ratón puede quedarse quieto en la zona o fuera de ella: se vuelve a mirar al cumplirse la espera.
  private func recheckTray(_ inZone: Bool) {
    trayTask?.cancel()
    guard inZone != trayHover.isExpanded else { return }
    let delay = inZone ? IslandHover.expandDelay : IslandHover.collapseDelay
    trayTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay + 0.02))
      guard !Task.isCancelled, let self else { return }
      if self.trayHover.update(inside: inZone, at: Date()) { self.refresh() }
    }
  }

  /// El arrastre llegó a la ventana de la muesca antes que a la zona.
  private func openTray() {
    guard !trayHover.isExpanded else { return }
    trayHover.update(inside: true, at: Date())
    trayHover.update(inside: true, at: Date() + IslandHover.expandDelay)
    refresh()
  }

  private func closeTray() {
    trayTask?.cancel()
    guard trayHover.isExpanded else { return }
    trayHover.reset()
    refresh()
  }

  private func dropped(_ urls: [URL]) {
    shelf.add(urls)
    fileDrag.finish()
    closeTray()
  }

  private func draggedOut(_ id: UUID, dropped: Bool, keep: Bool) {
    shelf.dragEnded(id, dropped: dropped, keep: keep)
    draggingOut = false
    refresh()
  }

  // MARK: Avisos de carga y AirPods

  private func push(_ new: [DeviceNotice]) {
    guard !new.isEmpty else { return }
    notices.push(new, at: Date())
    tickNotices()
  }

  /// Enseña el siguiente aviso cuando toca y programa el final del de ahora.
  private func tickNotices() {
    if notices.tick(at: Date(), busy: sinteclaBusy) {
      model.device = notices.current
      refresh()
    }
    noticeTask?.cancel()
    guard let next = notices.nextTick else { return }
    noticeTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(max(0, next.timeIntervalSinceNow) + 0.02))
      guard !Task.isCancelled else { return }
      self?.tickNotices()
    }
  }

  // MARK: Acciones

  private func openPlayingApp() {
    guard let pid = music.track?.pid, let url = NSRunningApplication(processIdentifier: pid)?.bundleURL else { return }
    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
  }

  /// La barra se queda donde se soltó hasta que la app confirma el salto.
  private func seek(to fraction: Double) {
    guard let track = music.track, track.duration > 0 else { return }
    music.seek(to: fraction * track.duration)
    Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(900))
      self?.model.scrub = nil
    }
  }
}
```

- [ ] **Step 8: `IslandPage`: los dos interruptores y la ayuda**

Sustituir todo el contenido de `Sources/Sintecla/IslandPage.swift`:

```swift
import Combine
import SinteclaCore
import SwiftUI

/// Isla → Isla (spec «La isla» §2): qué enseña, si hay muesca y si la música funciona en este macOS. Desde la 0.16.0,
/// los interruptores del estante y de los avisos de carga y AirPods (spec «Estante y avisos» §2).
struct IslandPage: View {
  @Bindable var settings: AppSettings
  private let music = NowPlayingClient.shared
  @State private var hasNotch = NotchScreen.current != nil
  private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

  var body: some View {
    Form {
      Section("Qué enseña") {
        LabeledContent("Música", value: "Carátula y onda; al pasar el ratón, la canción y sus controles")
        LabeledContent("Sintecla", value: "Dictado, reuniones y avisos, en lugar de la pastilla de abajo")
        LabeledContent("Al dictar", value: "La música se pausa y vuelve al terminar")
        Text("Al pasar el ratón por la isla con música se despliega: un clic en la carátula abre la app que suena y la "
             + "barra de progreso se puede arrastrar.")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("Estante") {
        Toggle("Estante de archivos", isOn: $settings.islandShelf)
        Text("Arrastra archivos hacia la muesca: la isla se abre como bandeja para soltarlos. Al pasar el ratón ves la "
             + "fila; arrastra uno fuera para sacarlo (con ⌥ se queda), doble clic lo abre y la ✕ lo quita. Guarda "
             + "el original, no una copia, y no sale con la tapa cerrada.")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("Avisos") {
        Toggle("Avisos de batería y AirPods", isOn: $settings.islandDeviceNotices)
        Text("Al enchufar y desenchufar el cargador, al conectar los AirPods y cuando queda poca batería (20 % y 10 % "
             + "en el Mac, 10 % en un auricular).")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("Estado") {
        LabeledContent("Muesca") {
          Label(hasNotch ? "Pantalla del MacBook" : "Sin muesca: isla arriba en el centro, solo con Sintecla",
                systemImage: hasNotch ? "checkmark.circle.fill" : "macbook")
        }
        LabeledContent("Música") {
          switch music.status {
          case .ready: Label("Lista", systemImage: "checkmark.circle.fill")
          case .unavailable: Label("No disponible en este macOS", systemImage: "xmark.circle")
          case .starting, .stopped: Label("Comprobando…", systemImage: "hourglass")
          }
        }
      }
    }
    .formStyle(.grouped)
    .onReceive(timer) { _ in hasNotch = NotchScreen.current != nil }
  }
}
```

- [ ] **Step 9: `MainWindow`: la página Isla con los ajustes**

En `Sources/Sintecla/MainWindow.swift`, cambiar:

```swift
    case .island: IslandPage()
```

por:

```swift
    case .island: IslandPage(settings: settings)
```

- [ ] **Step 10: Compilar la release (sin avisos)**

Run:

```bash
source scripts/sdk-env.sh && swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build complete' | grep -v 'ld: warning: search path' | tail -3
```

Esperado: `Build complete!`.

- [ ] **Step 11: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 381 tests in 60 suites passed`.

- [ ] **Step 12: Commit**

```bash
git add Sources/SinteclaCore/Island.swift Sources/SinteclaCoreTests/IslandTests.swift Sources/Sintecla/IslandView.swift Sources/Sintecla/IslandPanel.swift Sources/Sintecla/IslandController.swift Sources/Sintecla/IslandPage.swift Sources/Sintecla/MainWindow.swift
git commit -m 'feat: la isla con el estante, la bandeja y los avisos de carga y AirPods

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 5: Versión 0.16.0, README y spec principal

**Files:**
- Modify: `Sources/SinteclaCoreTests/SmokeTests.swift`, `Sources/SinteclaCore/AppInfo.swift` y `Resources/Info.plist`
- Modify: `README.md` y `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§7)

**Interfaces:**
- Consumes: Todo lo anterior.
- Produces: La versión 0.16.0 (build 18), instalada.

La línea «Estado» de la spec principal y la etiqueta `v0.16.0` se ponen al cerrar la versión, cuando el usuario lo pida.

- [ ] **Step 1: El test de la versión**

En `Sources/SinteclaCoreTests/SmokeTests.swift`, cambiar:

```swift
    #expect(AppInfo.version == "0.15.1")
```

por:

```swift
    #expect(AppInfo.version == "0.16.0")
```

- [ ] **Step 2: Ver que falla**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA el test con `Expectation failed: AppInfo.version == "0.16.0"`.

- [ ] **Step 3: `AppInfo.version`**

En `Sources/SinteclaCore/AppInfo.swift`, cambiar:

```swift
  public static let version = "0.15.1"
```

por:

```swift
  public static let version = "0.16.0"
```

- [ ] **Step 4: `Info.plist`**

En `Resources/Info.plist`, cambiar:

```xml
  <key>CFBundleShortVersionString</key><string>0.15.1</string>
```

por:

```xml
  <key>CFBundleShortVersionString</key><string>0.16.0</string>
```

Y cambiar:

```xml
  <key>CFBundleVersion</key><string>17</string>
```

por:

```xml
  <key>CFBundleVersion</key><string>18</string>
```

- [ ] **Step 5: Ver que pasa**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 381 tests in 60 suites passed`.

- [ ] **Step 6: README: el estante y los avisos en la isla**

En `README.md`, cambiar:

```text
Al dictar, la música se pausa y vuelve al terminar. |
```

por:

```text
Al dictar, la música se pausa y vuelve al terminar. Desde la 0.16.0, un **estante de archivos** (arrástralos a la muesca y sácalos después; guarda el original) y **avisos de carga y AirPods** (al enchufar o desenchufar, al conectar los AirPods con la batería de cada auricular, y con batería baja). |
```

- [ ] **Step 7: Spec principal (§7): el estante, los avisos y el Mando**

En `docs/superpowers/specs/2026-09-23-sintecla-design.md`, cambiar:

```text
Capturas, Alt-Tab, Dock e Isla; los cinco últimos, apagados de fábrica)
```

por:

```text
Capturas, Alt-Tab, Dock, Isla y Mando; los seis últimos, apagados de fábrica)
```

Y cambiar:

```text
e **Isla** (qué enseña, la muesca y la música, ver `2026-10-03-isla-design.md`).
```

por:

```text
**Isla** (qué enseña, el estante, los avisos, la muesca y la música, ver `2026-10-03-isla-design.md` y `2026-10-03-estante-design.md`) y **Mando** (encenderlo y el QR del móvil).
```

Y cambiar:

```text
si suena música, se aparta a una burbuja y se pausa mientras se dicta.
```

por:

```text
si suena música, se aparta a una burbuja y se pausa mientras se dicta. Desde la 0.16.0, la isla tiene un estante de archivos (se arrastran a la muesca, se abre una bandeja y se sacan arrastrándolos; guarda el original) y avisos de carga y AirPods (al enchufar o desenchufar, al conectar los AirPods y con batería baja).
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
git commit -m 'feat: versión 0.16.0 con el estante y los avisos en la isla

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

- [ ] **Step 10: Instalar la versión nueva**

Run:

```bash
scripts/build-app.sh
```

Esperado: `✅ Instalada en /Applications/Sintecla.app`. Los dos interruptores vienen encendidos.

---
### Task 6: Aceptación a mano

**Files:**
- —

**Interfaces:**
- Consumes: La app instalada (Tarea 5).
- Produces: Nada nuevo. La 0.16.0 se cierra cuando el usuario lo pida.

La hace el usuario (spec §6.3).

- [ ] **Step 1: Checklist. Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | Página Isla | Los dos interruptores, encendidos |
| 2 | Arrastrar un archivo de Finder hacia la muesca | Antes de llegar arriba se abre la bandeja; al soltar, la compacta muestra 🗂 1; no sale Mission Control |
| 3 | Meter tres más, uno repetido | 🗂 3… sin repetir |
| 4 | Ratón encima, sin y con música | La fila con iconos; con música, la música arriba y la fila debajo |
| 5 | Sacar uno al escritorio; otro con ⌥ | Se copia y se quita; con ⌥ se copia y se queda |
| 6 | ✕ en uno, doble clic en otro, «Vaciar» | Se quita; se abre; se vacía |
| 7 | Reiniciar Sintecla; mover un archivo de carpeta; borrar otro | Siguen; el movido sigue; el borrado desaparece |
| 8 | Desenchufar y enchufar el cargador | «80 % · …» y «Cargando · 80 %» (o «Enchufado») |
| 9 | Conectar los AirPods | El aviso con izquierdo, derecho y estuche |
| 10 | Dictar con música y enchufar a la vez | El aviso sale al terminar |
| 11 | Tapa cerrada: conectar los AirPods | El aviso en la isla virtual; sin estante |
| 12 | Apagar los interruptores y volver a encenderlos | Nada del estante ni avisos; al encender, los archivos siguen |
| 13 | La música, Sintecla, el Mando, Alt-Tab, el Dock y Capturas | Como antes |

---
## Autorrevisión frente a la especificación

| Requisito (spec «Estante y avisos») | Dónde |
|---|---|
| §2 Ajustes encendidos de fábrica, sin permisos, ayuda en la página Isla | Tareas 3 y 4 |
| §3.1 Bandeja al acercarse, ventana sobre la muesca, 0,5 s al soltar, pantalla completa | Tareas 3 y 4 |
| §3.2 Compacta del estante, desplegada con la fila, ✕, doble clic y «Vaciar» | Tareas 3 y 4 |
| §3.3 Sacar arrastrando, ⌥, el original | Tareas 1 y 3 |
| §3.4 Guardado con marcadores y limpieza | Tareas 1 y 3 |
| §3.5 Sin estante con la tapa cerrada | Tarea 4 |
| §4.1 Avisos y umbrales | Tarea 2 |
| §4.2 Duración, burbuja, espera a Sintecla, fila, tapa cerrada | Tareas 2 y 4 |
| §4.3 API de energía, Core Audio y `system_profiler` con reintentos | Tarea 3 |
| §5 Piezas y 0.16.0 (build 18) | Tareas 1 a 5 |
| §6.2 Tests | Tareas 1, 2 y 4 |
| §6.3 Aceptación | Tarea 6 |

**Consistencia de tipos revisada:**
- `Shelf` y `ShelfItem` (Tarea 1) los usa `ShelfStore` (Tarea 3), que usan `ShelfRow` (Tarea 3), `IslandView` e `IslandController` (Tarea 4).
- `PowerState` y `AirPodsDevice` (Tarea 2) los producen `PowerMonitor` y `AirPodsMonitor` (Tarea 3); `PowerNotices`, `AirPodsNotices` y `NoticeQueue` (Tarea 2) los usa `IslandController` (Tarea 4).
- `DeviceNotice` (Tarea 2) lo pinta `IslandView` (Tarea 4) desde `IslandModel.device`.
- `FileDragWatcher`, `FileDropView`, `ShelfDropWindow` y `ShelfDragSource` (Tarea 3) los usan `IslandPanel` e `IslandController` (Tarea 4).
- `AppSettings.islandShelf` e `islandDeviceNotices` (Tarea 3) los leen `IslandController` e `IslandPage` (Tarea 4).
