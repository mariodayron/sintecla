# Sintecla — Estadísticas — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Estadísticas de verdad en una sección nueva de la ventana: hoy, racha, tiempo ahorrado, mejor día, gráfica y reparto por app y por modo, con un resumen por día que no se recorta con el historial.

**Architecture:** El núcleo `SinteclaCore` gana dos piezas, con tests:
- `UsageStats`, un resumen puro y Codable por día (en total, por app y por modo) que calcula cifras, series y repartos;
- `UsageStatsStore`, que lo lee y lo guarda en `stats.json`.

`DictationController` rellena el resumen con el historial al arrancar, **antes** de recortarlo, y suma cada uso nuevo. Una vista SwiftUI nueva, `StatsView`, lo enseña con Swift Charts. La fila de cifras del Historial desaparece.

**Tech Stack:** Lo de siempre (Swift 6.3 de las Command Line Tools en modo de lenguaje 5, SwiftPM, AppKit, SwiftUI, Swift Testing). Además, Swift Charts (`import Charts`, que está en el SDK de las Command Line Tools).

**Especificación:** `docs/superpowers/specs/2026-09-24-estadisticas-design.md` (y la fila «Estadísticas (0.7.0)» de §12 de la spec principal).

**Punto de partida:** la rama `estadisticas`, que sale de `main` (`v0.6.0`) con la especificación:

```bash
git checkout estadisticas
```

## Global Constraints

- Todo lo de antes sigue vigente:
  - macOS 26.0 o superior, Apple Silicon.
  - Sin Xcode ni dependencias externas; todos los targets en `.swiftLanguageMode(.v5)`.
  - Tests con `swift run sintecla-tests` (**nunca `swift test`**).
  - Bundle id `local.sintecla.app`; textos visibles en español; solo blanco, negro y grises.
- **Qué cuenta:**
  - Cada entrada del historial (dictado, traducción, Ask, notas).
  - Palabras = las del texto final; en **Ask**, las de `rawText`.
  - Día = día local en el momento del uso.
  - Las reuniones no cuentan.
- **Datos:**
  - `~/Library/Application Support/Sintecla/stats.json`, solo números y sin recortar.
  - Si falta, se rellena con el historial antes de recortarlo.
  - Si está roto, se aparta como `stats.json.roto` y se rehace.
- **Cifras:**
  - Tiempo ahorrado = max(0, palabras ÷ **40** − minutos hablando).
  - Racha desde hoy (o desde ayer si hoy aún no hay usos), con su récord.
  - Mejor día.
- **Gráfica:** **30** días, **12** semanas (de lunes a domingo) o **12** meses, con ceros; la barra más alta va más oscura.
- **Repartos:** periodos **7 días**, **30 días** (por defecto) o **Siempre**; por app, las **5** primeras y «Otras»; sin bundle id, «Otra».
- Versión **0.7.0** (build 8).
- Commits: en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código de este plan se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `estadisticas`: compiló y pasó los tests en cada tarea, y el árbol final quedó idéntico al del prototipo.

- **196 tests** (38 suites) en verde: los 185 de la F4c, 12 nuevos y uno menos (el de `HistoryStore.stats`, que desaparece). La release compila sin avisos.
- **La página se revisó a ojo:** se pintó `StatsView` con `ImageRenderer` y 70 días de datos inventados. Las cifras, la gráfica con la barra más alta oscura y los repartos con sus barras salen bien. Los selectores nativos no salen en `ImageRenderer`, pero en la app sí.
- `Charts.framework` está en el SDK de las Command Line Tools y compila sin Xcode.

**Lo que no se pudo probar aquí** (queda para la aceptación, Tarea 4):
- **El relleno con el historial real.** Leería los dictados del usuario; se prueba con historiales inventados en los tests.
- **La página dentro de la ventana,** con los selectores funcionando.

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| `start()` recorta el historial a 500; si el resumen se rellena después, se pierde lo recortado | `usage.prepare(history:)` va en el `init` de `DictationController`, antes de `start()` (Tarea 2) |
| Si no hay permiso de Accesibilidad, `start()` sale antes y nunca se rellenaría | Por lo mismo: el relleno no depende de `start()` (Tarea 2) |
| En Ask, `finalText` es la respuesta de Gemini, no lo que escribiste | `UsageStats.words(of:)` usa `rawText` en Ask (Tarea 1) |
| El calendario del Mac puede empezar la semana en domingo | `series` usa una copia del calendario con `firstWeekday = 2` (Tarea 1) |
| `ProgressView` no respeta bien el gris y `ImageRenderer` no lo pinta | Barras propias con `Capsule` y `GeometryReader` (Tarea 3) |
| Tras mover la carpeta del proyecto, `swift build` falla con `missing required module 'SwiftShims'` | Caché de módulos con rutas viejas: `rm -rf .build` |

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/UsageStats.swift` | `UsageStats` y `UsageStatsStore` | 1 |
| `Sources/SinteclaCoreTests/UsageStatsTests.swift` | Tests del resumen y del almacén | 1 |
| `Sources/SinteclaCore/Storage.swift` | `AppPaths.statsURL` | 2 |
| `Sources/Sintecla/DictationController.swift` | Rellenar al arrancar, sumar cada uso (2) y avisar a la página (3) | 2, 3 |
| `Sources/Sintecla/StatsView.swift` | La página Estadísticas | 3 |
| `Sources/Sintecla/MainWindow.swift`, `Sources/Sintecla/AppDelegate.swift` | Sección en la barra lateral y el almacén hasta la vista | 3 |
| `Sources/Sintecla/Windows.swift` | El Historial sin su fila de cifras | 3 |
| `Sources/SinteclaCore/History.swift`, `Sources/SinteclaCoreTests/HistoryAndStorageTests.swift` | Quitar `HistoryStats`, `HistoryStore.stats` y su test | 3 |
| `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`, `Sources/SinteclaCoreTests/SmokeTests.swift` | Versión 0.7.0 | 3 |

---

### Task 1: El resumen por día

**Files:**
- Create: `Sources/SinteclaCore/UsageStats.swift`
- Test: `Sources/SinteclaCoreTests/UsageStatsTests.swift`

**Interfaces:**
- Consumes: `HistoryEntry` (con `words`, `rawText`, `audioSeconds`, `appBundleID`, `appName`, `mode`, `date`) y `TextMetrics.wordCount` (F1).
- Produces: `struct UsageStats: Codable, Equatable, Sendable` con `Tally`, `Day`, `Bar(start:words:)`, `Share(name:words:fraction:)`, `enum Scale { days, weeks, months }`, `enum Period { week, month, all }`; `init(history:calendar:)`, `add(_:calendar:)`, `static words(of:)`, `totalWords`, `totalUses`, `wordsPerMinute`, `minutesSaved`, `words(on:calendar:)`, `firstDay(calendar:)`, `streak(now:calendar:)`, `recordStreak(calendar:)`, `bestDay(calendar:) -> Bar?`, `series(_:now:calendar:) -> [Bar]`, `byApp(_:now:calendar:)` y `byMode(_:now:calendar:) -> [Share]`. `final class UsageStatsStore { init(fileURL:); prepare(history:calendar:); add(_:calendar:) throws; current: UsageStats }`.

Todo puro salvo el almacén, que solo lee y escribe un archivo. Los tests usan un calendario fijo (Madrid) y el 24 de septiembre de 2026, jueves, como hoy.

- [ ] **Step 1: Escribir los tests**

Crear `Sources/SinteclaCoreTests/UsageStatsTests.swift`:

```swift
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct UsageStatsTests {
  let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
    return calendar
  }()

  /// 24 de septiembre de 2026 (jueves) a las `hour`, más `days` días.
  func date(_ days: Int = 0, hour: Int = 12) -> Date {
    let base = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: hour))!
    return calendar.date(byAdding: .day, value: days, to: base)!
  }

  func entry(_ text: String, days: Int = 0, mode: HotkeyMode = .dictation, app: String? = "net.whatsapp.WhatsApp",
             name: String? = "WhatsApp", seconds: Double = 60, raw: String? = nil) -> HistoryEntry {
    HistoryEntry(date: date(days), mode: mode, appBundleID: app, appName: name, language: "es_ES", audioSeconds: seconds,
                 rawText: raw ?? text, finalText: text, engine: "apple", latencyMs: 0)
  }

  func stats(_ entries: [HistoryEntry]) -> UsageStats {
    UsageStats(history: entries, calendar: calendar)
  }

  @Test func addsByDayAppAndMode() {
    let s = stats([
      entry("uno dos tres"),
      entry("cuatro cinco", mode: .notes, app: "com.apple.Notes", name: "Notas"),
      entry("seis", days: -1),
    ])
    let today = s.days["2026-09-24"]!
    #expect(today.total == UsageStats.Tally(words: 5, seconds: 120, uses: 2))
    #expect(today.byApp["net.whatsapp.WhatsApp"] == UsageStats.Tally(words: 3, seconds: 60, uses: 1))
    #expect(today.byMode["notes"] == UsageStats.Tally(words: 2, seconds: 60, uses: 1))
    #expect(s.days["2026-09-23"]?.total.words == 1)
    #expect(s.appNames == ["net.whatsapp.WhatsApp": "WhatsApp", "com.apple.Notes": "Notas"])
    #expect(s.totalWords == 6 && s.totalUses == 3)
  }

  @Test func askCountsWhatYouSaid() {
    let s = stats([entry("una respuesta larga de Gemini con muchas palabras", mode: .ask, raw: "qué hora es")])
    #expect(s.totalWords == 3)
  }

  @Test func withoutBundleIDTheAppIsOther() {
    let s = stats([entry("hola", app: nil, name: nil)])
    #expect(s.byApp(.all, now: date(), calendar: calendar) == [UsageStats.Share(name: "Otra", words: 1, fraction: 1)])
  }

  @Test func fillingFromHistoryEqualsAddingOneByOne() {
    let entries = [entry("uno dos"), entry("tres", days: -3), entry("cuatro cinco seis", days: -40, mode: .translation)]
    var added = UsageStats()
    for e in entries { added.add(e, calendar: calendar) }
    #expect(stats(entries) == added)
  }

  @Test func streakCountsBackFromTodayOrYesterday() {
    // Hoy, ayer y anteayer; hueco; y cuatro días seguidos antes.
    let days = [0, -1, -2, -4, -5, -6, -7]
    #expect(stats(days.map { entry("hola", days: $0) }).streak(now: date(), calendar: calendar) == 3)
    // Si hoy aún no hay nada, cuenta desde ayer.
    #expect(stats(days.dropFirst().map { entry("hola", days: $0) }).streak(now: date(), calendar: calendar) == 2)
    #expect(stats([entry("hola", days: -3)]).streak(now: date(), calendar: calendar) == 0)
    #expect(stats(days.map { entry("hola", days: $0) }).recordStreak(calendar: calendar) == 4)
    #expect(UsageStats().recordStreak(calendar: calendar) == 0)
  }

  @Test func timeSavedIsNeverNegative() {
    // 400 palabras en 2 minutos: 10 min tecleando − 2 hablando = 8 min.
    let many = Array(repeating: "palabra", count: 400).joined(separator: " ")
    #expect(stats([entry(many, seconds: 120)]).minutesSaved == 8)
    #expect(stats([entry("hola", seconds: 600)]).minutesSaved == 0)
    #expect(stats([entry(many, seconds: 120)]).wordsPerMinute == 200)
    #expect(UsageStats().wordsPerMinute == 0)
  }

  @Test func todayAndBestDay() {
    let s = stats([entry("uno dos"), entry("tres cuatro cinco seis", days: -5), entry("siete", days: -5)])
    #expect(s.words(on: date(), calendar: calendar) == 2)
    #expect(s.bestDay(calendar: calendar) == UsageStats.Bar(start: calendar.startOfDay(for: date(-5)), words: 5))
    #expect(s.firstDay(calendar: calendar) == calendar.startOfDay(for: date(-5)))
    #expect(UsageStats().bestDay(calendar: calendar) == nil)
  }

  @Test func seriesOfDaysWeeksAndMonths() {
    let s = stats([entry("uno"), entry("dos tres", days: -1), entry("cuatro", days: -29), entry("cinco", days: -30),
                   entry("seis siete", days: -3), entry("ocho", days: -60)])
    let days = s.series(.days, now: date(), calendar: calendar)
    #expect(days.count == 30)
    #expect(days.last == UsageStats.Bar(start: calendar.startOfDay(for: date()), words: 1))
    #expect(days.first == UsageStats.Bar(start: calendar.startOfDay(for: date(-29)), words: 1))
    #expect(days.map(\.words).reduce(0, +) == 6)  // el de hace 30 y 60 días no entran

    // Semanas de lunes a domingo: el 24 es jueves, así que esta semana empieza el lunes 21.
    let weeks = s.series(.weeks, now: date(), calendar: calendar)
    #expect(weeks.count == 12)
    #expect(weeks.last == UsageStats.Bar(start: calendar.startOfDay(for: date(-3)), words: 5))

    let months = s.series(.months, now: date(), calendar: calendar)
    #expect(months.count == 12)
    #expect(months.last?.start == calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
    #expect(months.last?.words == 5)  // septiembre: el 21, el 23 y el 24
    #expect(months[10].words == 2)    // agosto: el 25 y el 26
    #expect(months[9].words == 1)     // julio: el 26
  }

  @Test func sharesByAppWithTopFiveAndOthers() {
    let apps = (1...7).map { i in entry(Array(repeating: "x", count: 8 - i).joined(separator: " "), app: "app\(i)", name: "App \(i)") }
    let shares = stats(apps).byApp(.all, now: date(), calendar: calendar)
    #expect(shares.map(\.name) == ["App 1", "App 2", "App 3", "App 4", "App 5", "Otras"])
    #expect(shares.map(\.words) == [7, 6, 5, 4, 3, 3])
    #expect(abs(shares.map(\.fraction).reduce(0, +) - 1) < 0.0001)
  }

  @Test func sharesByModeAndPeriod() {
    let s = stats([entry("uno dos tres"), entry("cuatro", days: -3, mode: .translation), entry("cinco", days: -20, mode: .notes)])
    #expect(s.byMode(.week, now: date(), calendar: calendar).map(\.name) == ["Dictado", "Traducir"])
    #expect(s.byMode(.month, now: date(), calendar: calendar).map(\.words) == [3, 1, 1])
    #expect(s.byMode(.week, now: date(), calendar: calendar).first?.fraction == 0.75)
    #expect(UsageStats().byMode(.all, now: date(), calendar: calendar).isEmpty)
  }

  @Test func storeFillsFromHistoryTheFirstTimeAndThenKeepsItsOwnData() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("stats-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = UsageStatsStore(fileURL: url)
    store.prepare(history: [entry("uno dos")], calendar: calendar)
    #expect(store.current.totalWords == 2)
    #expect(FileManager.default.fileExists(atPath: url.path))
    try store.add(entry("tres"), calendar: calendar)

    // Otra vez (otro arranque): ya no mira el historial, lee su archivo.
    let again = UsageStatsStore(fileURL: url)
    again.prepare(history: [], calendar: calendar)
    #expect(again.current.totalWords == 3)
  }

  @Test func aBrokenFileIsMovedAsideAndRebuilt() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("stats-\(UUID().uuidString).json")
    let broken = url.appendingPathExtension("roto")
    defer {
      try? FileManager.default.removeItem(at: url)
      try? FileManager.default.removeItem(at: broken)
    }
    try Data("{roto".utf8).write(to: url)
    let store = UsageStatsStore(fileURL: url)
    store.prepare(history: [entry("uno dos tres")], calendar: calendar)
    #expect(store.current.totalWords == 3)
    #expect(try String(contentsOf: broken, encoding: .utf8) == "{roto")
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find type 'UsageStats' in scope`.

- [ ] **Step 3: El resumen, sus cifras, series y repartos, y el almacén**

Crear `Sources/SinteclaCore/UsageStats.swift`:

```swift
import Foundation

/// Lo que se ha dictado cada día, en total, por app y por modo. Solo números, nunca texto. Se guarda en
/// `stats.json` y, a diferencia del historial, no se recorta.
public struct UsageStats: Codable, Equatable, Sendable {
  public struct Tally: Codable, Equatable, Sendable {
    public var words = 0
    public var seconds = 0.0
    public var uses = 0

    public init(words: Int = 0, seconds: Double = 0, uses: Int = 0) {
      self.words = words
      self.seconds = seconds
      self.uses = uses
    }

    mutating func add(_ other: Tally) {
      words += other.words
      seconds += other.seconds
      uses += other.uses
    }
  }

  public struct Day: Codable, Equatable, Sendable {
    public var total = Tally()
    /// Bundle id ("" si no se sabe) → lo de esa app.
    public var byApp: [String: Tally] = [:]
    /// `HotkeyMode.rawValue` → lo de ese modo.
    public var byMode: [String: Tally] = [:]
  }

  /// Una barra de la gráfica: el principio del periodo y sus palabras.
  public struct Bar: Equatable, Sendable {
    public var start: Date
    public var words: Int

    public init(start: Date, words: Int) {
      self.start = start
      self.words = words
    }
  }

  /// Una fila de los repartos.
  public struct Share: Equatable, Sendable {
    public var name: String
    public var words: Int
    public var fraction: Double

    public init(name: String, words: Int, fraction: Double) {
      self.name = name
      self.words = words
      self.fraction = fraction
    }
  }

  public enum Scale: CaseIterable, Sendable {
    case days, weeks, months
  }

  /// Periodo de los repartos: 7 días, 30 días o siempre.
  public enum Period: CaseIterable, Sendable {
    case week, month, all
  }

  /// Palabras que cuestan tanto como un minuto tecleando.
  public static let typingWordsPerMinute = 40.0
  /// Apps con nombre en el reparto; el resto va a «Otras».
  public static let topApps = 5

  /// Día local "aaaa-mm-dd" → lo de ese día.
  public var days: [String: Day] = [:]
  /// Bundle id → último nombre conocido de la app.
  public var appNames: [String: String] = [:]

  public init() {}

  /// Rellena el resumen con todo lo que haya en el historial.
  public init(history: [HistoryEntry], calendar: Calendar = .current) {
    for entry in history { add(entry, calendar: calendar) }
  }

  /// Palabras de un uso: las del texto final; en Ask, las de lo que dijiste (la respuesta no la escribes tú).
  public static func words(of entry: HistoryEntry) -> Int {
    entry.mode == .ask ? TextMetrics.wordCount(entry.rawText) : entry.words
  }

  public mutating func add(_ entry: HistoryEntry, calendar: Calendar = .current) {
    let tally = Tally(words: Self.words(of: entry), seconds: entry.audioSeconds, uses: 1)
    let key = Self.key(for: entry.date, calendar: calendar)
    var day = days[key] ?? Day()
    day.total.add(tally)
    day.byApp[entry.appBundleID ?? "", default: Tally()].add(tally)
    day.byMode[entry.mode.rawValue, default: Tally()].add(tally)
    days[key] = day
    if let id = entry.appBundleID, let name = entry.appName { appNames[id] = name }
  }

  // MARK: - Cifras

  public var totalWords: Int { days.values.reduce(0) { $0 + $1.total.words } }
  public var totalUses: Int { days.values.reduce(0) { $0 + $1.total.uses } }
  public var totalSeconds: Double { days.values.reduce(0) { $0 + $1.total.seconds } }

  public var wordsPerMinute: Int {
    totalSeconds > 0 ? Int((Double(totalWords) / (totalSeconds / 60)).rounded()) : 0
  }

  /// Minutos que habría costado teclearlo, menos los que se habló. Nunca negativo.
  public var minutesSaved: Int {
    max(0, Int((Double(totalWords) / Self.typingWordsPerMinute - totalSeconds / 60).rounded()))
  }

  public func words(on date: Date, calendar: Calendar = .current) -> Int {
    days[Self.key(for: date, calendar: calendar)]?.total.words ?? 0
  }

  public func firstDay(calendar: Calendar = .current) -> Date? {
    days.keys.min().flatMap { Self.date(fromKey: $0, calendar: calendar) }
  }

  /// Días seguidos con algún uso hasta hoy; si hoy aún no hay, hasta ayer.
  public func streak(now: Date = Date(), calendar: Calendar = .current) -> Int {
    var day = calendar.startOfDay(for: now)
    if uses(on: day, calendar: calendar) == 0 { day = calendar.date(byAdding: .day, value: -1, to: day)! }
    var count = 0
    while uses(on: day, calendar: calendar) > 0 {
      count += 1
      day = calendar.date(byAdding: .day, value: -1, to: day)!
    }
    return count
  }

  /// La racha más larga de todas.
  public func recordStreak(calendar: Calendar = .current) -> Int {
    let dates = days.filter { $0.value.total.uses > 0 }.keys.sorted().compactMap { Self.date(fromKey: $0, calendar: calendar) }
    var best = 0
    var run = 0
    var previous: Date?
    for date in dates {
      let follows = previous.map { calendar.date(byAdding: .day, value: 1, to: $0) == date } ?? false
      run = follows ? run + 1 : 1
      best = max(best, run)
      previous = date
    }
    return best
  }

  /// El día con más palabras (el primero si empatan).
  public func bestDay(calendar: Calendar = .current) -> Bar? {
    guard let best = days.filter({ $0.value.total.words > 0 })
      .max(by: { ($0.value.total.words, $1.key) < ($1.value.total.words, $0.key) }),
      let date = Self.date(fromKey: best.key, calendar: calendar) else { return nil }
    return Bar(start: date, words: best.value.total.words)
  }

  // MARK: - Gráfica

  /// 30 días, 12 semanas (de lunes a domingo) o 12 meses, el último el actual. Los periodos sin usos, a cero.
  public func series(_ scale: Scale, now: Date = Date(), calendar: Calendar = .current) -> [Bar] {
    var calendar = calendar
    calendar.firstWeekday = 2  // lunes
    let (unit, count): (Calendar.Component, Int) = switch scale {
    case .days: (.day, 30)
    case .weeks: (.weekOfYear, 12)
    case .months: (.month, 12)
    }
    let current = calendar.dateInterval(of: unit, for: now)!.start
    return (0..<count).map { i in
      let start = calendar.date(byAdding: unit, value: i - count + 1, to: current)!
      let end = calendar.date(byAdding: unit, value: 1, to: start)!
      return Bar(start: start, words: tally(from: start, to: end, calendar: calendar).total.words)
    }
  }

  // MARK: - Repartos

  /// Las `topApps` apps con más palabras y «Otras» con el resto.
  public func byApp(_ period: Period, now: Date = Date(), calendar: Calendar = .current) -> [Share] {
    let range = tally(period, now: now, calendar: calendar)
    let apps = range.byApp.map { (name: appName($0.key), words: $0.value.words) }
    var named = Array(Self.sorted(apps).prefix(Self.topApps))
    let others = range.total.words - named.reduce(0) { $0 + $1.words }
    if others > 0 { named.append((name: "Otras", words: others)) }
    return Self.shares(named, total: range.total.words)
  }

  public func byMode(_ period: Period, now: Date = Date(), calendar: Calendar = .current) -> [Share] {
    let range = tally(period, now: now, calendar: calendar)
    let modes = range.byMode.compactMap { key, tally in
      HotkeyMode(rawValue: key).map { (name: Self.modeName($0), words: tally.words) }
    }
    return Self.shares(Self.sorted(modes), total: range.total.words)
  }

  static func modeName(_ mode: HotkeyMode) -> String {
    switch mode {
    case .dictation: "Dictado"
    case .translation: "Traducir"
    case .ask: "Ask"
    case .notes: "Notas"
    case .meeting: "Reuniones"
    }
  }

  // MARK: - Ayudas

  static func key(for date: Date, calendar: Calendar) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
  }

  static func date(fromKey key: String, calendar: Calendar) -> Date? {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
  }

  private func uses(on day: Date, calendar: Calendar) -> Int {
    days[Self.key(for: day, calendar: calendar)]?.total.uses ?? 0
  }

  private func appName(_ id: String) -> String {
    appNames[id] ?? (id.isEmpty ? "Otra" : id)
  }

  /// Suma de los días en [start, end).
  private func tally(from start: Date, to end: Date, calendar: Calendar) -> Day {
    var sum = Day()
    for (key, day) in days {
      guard let date = Self.date(fromKey: key, calendar: calendar), date >= start, date < end else { continue }
      sum.total.add(day.total)
      for (app, tally) in day.byApp { sum.byApp[app, default: Tally()].add(tally) }
      for (mode, tally) in day.byMode { sum.byMode[mode, default: Tally()].add(tally) }
    }
    return sum
  }

  /// 7 días y 30 días incluyen hoy.
  private func tally(_ period: Period, now: Date, calendar: Calendar) -> Day {
    let today = calendar.startOfDay(for: now)
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
    let start: Date = switch period {
    case .week: calendar.date(byAdding: .day, value: -6, to: today)!
    case .month: calendar.date(byAdding: .day, value: -29, to: today)!
    case .all: .distantPast
    }
    return tally(from: start, to: tomorrow, calendar: calendar)
  }

  /// De más a menos palabras (por nombre si empatan), sin los que no tienen.
  private static func sorted(_ rows: [(name: String, words: Int)]) -> [(name: String, words: Int)] {
    rows.filter { $0.words > 0 }.sorted { ($1.words, $0.name) < ($0.words, $1.name) }
  }

  private static func shares(_ rows: [(name: String, words: Int)], total: Int) -> [Share] {
    guard total > 0 else { return [] }
    return rows.map { Share(name: $0.name, words: $0.words, fraction: Double($0.words) / Double(total)) }
  }
}

/// `stats.json`: se lee al arrancar y se guarda tras cada uso. Seguro entre hilos.
public final class UsageStatsStore: @unchecked Sendable {
  public let fileURL: URL
  private let lock = NSLock()
  private var stats = UsageStats()

  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  /// Al arrancar, antes de recortar el historial: lee `stats.json`; si no existe, lo rellena con el historial;
  /// si está roto, lo aparta como `stats.json.roto` y lo rehace.
  public func prepare(history: [HistoryEntry], calendar: Calendar = .current) {
    lock.withLock {
      if let data = try? Data(contentsOf: fileURL) {
        if let loaded = try? JSONDecoder().decode(UsageStats.self, from: data) {
          stats = loaded
          return
        }
        let broken = fileURL.appendingPathExtension("roto")
        try? FileManager.default.removeItem(at: broken)
        try? FileManager.default.moveItem(at: fileURL, to: broken)
      }
      stats = UsageStats(history: history, calendar: calendar)
      try? save()
    }
  }

  public func add(_ entry: HistoryEntry, calendar: Calendar = .current) throws {
    try lock.withLock {
      stats.add(entry, calendar: calendar)
      try save()
    }
  }

  public var current: UsageStats {
    lock.withLock { stats }
  }

  private func save() throws {
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(stats).write(to: fileURL, options: .atomic)
  }
}
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 197 tests in 38 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/UsageStats.swift Sources/SinteclaCoreTests/UsageStatsTests.swift
git commit -m 'feat: resumen de uso por día que no se recorta

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: Guardar cada uso en el resumen

**Files:**
- Modify: `Sources/SinteclaCore/Storage.swift`
- Modify: `Sources/Sintecla/DictationController.swift`

**Interfaces:**
- Consumes: `UsageStatsStore` (Tarea 1); `HistoryStore.load()` y `history.append` (F1).
- Produces: `AppPaths.statsURL`; `DictationController.usage: UsageStatsStore`, ya rellenado al crear el controlador.

Desde aquí `stats.json` se crea al abrir la app y crece con cada uso, aunque todavía no se vea en ningún sitio.

- [ ] **Step 1: Ruta de `stats.json`**

En `Sources/SinteclaCore/Storage.swift`, cambiar:

```swift
  public static var historyURL: URL { supportDirectory.appendingPathComponent("history.jsonl") }
```

por:

```swift
  public static var historyURL: URL { supportDirectory.appendingPathComponent("history.jsonl") }
  public static var statsURL: URL { supportDirectory.appendingPathComponent("stats.json") }
```

- [ ] **Step 2: Rellenar antes de recortar el historial y sumar cada uso**

En `Sources/Sintecla/DictationController.swift`, cambiar:

```swift
  let history = HistoryStore(fileURL: AppPaths.historyURL)
```

por:

```swift
  let history = HistoryStore(fileURL: AppPaths.historyURL)
  /// Resumen por día para Estadísticas: a diferencia del historial, no se recorta.
  let usage = UsageStatsStore(fileURL: AppPaths.statsURL)
```

Y cambiar:

```swift
    card.onInsert = { text in Task { await Paster.paste(text) } }
```

por:

```swift
    card.onInsert = { text in Task { await Paster.paste(text) } }
    // Antes de que `start()` recorte el historial: la primera vez, el resumen se rellena con todo lo que hay.
    usage.prepare(history: history.load())
```

Y cambiar:

```swift
      if let entry { try? self.history.append(entry) }
```

por:

```swift
      if let entry {
        try? self.history.append(entry)
        try? self.usage.add(entry)
      }
```

- [ ] **Step 3: Compilar**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | tail -1
```

Esperado: `Build of product 'Sintecla' complete!`.

- [ ] **Step 4: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 197 tests in 38 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/Storage.swift Sources/Sintecla/DictationController.swift
git commit -m 'feat: cada uso se suma al resumen de stats.json

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: La página Estadísticas y versión 0.7.0

**Files:**
- Create: `Sources/Sintecla/StatsView.swift`
- Modify: `Sources/Sintecla/DictationController.swift`, `Sources/Sintecla/MainWindow.swift`, `Sources/Sintecla/AppDelegate.swift`
- Modify: `Sources/Sintecla/Windows.swift` (`HistoryView`)
- Modify: `Sources/SinteclaCore/History.swift`, `Sources/SinteclaCoreTests/HistoryAndStorageTests.swift`
- Modify: `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`
- Test: `Sources/SinteclaCoreTests/SmokeTests.swift`

**Interfaces:**
- Consumes: `UsageStats` (Tarea 1) y `DictationController.usage` (Tarea 2).
- Produces: `struct StatsView: View` (con `store: UsageStatsStore`), `Notification.Name.usageChanged`, `MainSection.stats`, `MainView.usage`; sin `HistoryStats` ni `HistoryStore.stats`; versión 0.7.0 (build 8).

La vista no tiene tests automáticos (la app no tiene target de tests): se compila y se mira en la Tarea 4.

- [ ] **Step 1: Test de la versión nueva**

En `Sources/SinteclaCoreTests/SmokeTests.swift`, cambiar:

```swift
#expect(AppInfo.version == "0.6.0")
```

por:

```swift
#expect(AppInfo.version == "0.7.0")
```

- [ ] **Step 2: Ver que falla**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA el test con `Expectation failed: (AppInfo.version → "0.6.0") == "0.7.0"`.

- [ ] **Step 3: Versión 0.7.0**

En `Sources/SinteclaCore/AppInfo.swift`, cambiar:

```swift
public static let version = "0.6.0"
```

por:

```swift
public static let version = "0.7.0"
```

- [ ] **Step 4: Versión 0.7.0 (build 8) en el Info.plist**

En `Resources/Info.plist`, cambiar:

```xml
<key>CFBundleShortVersionString</key><string>0.6.0</string>
```

por:

```xml
<key>CFBundleShortVersionString</key><string>0.7.0</string>
```

Y cambiar:

```xml
<key>CFBundleVersion</key><string>7</string>
```

por:

```xml
<key>CFBundleVersion</key><string>8</string>
```

- [ ] **Step 5: Ver que pasa**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 197 tests in 38 suites passed`.

- [ ] **Step 6: La página: cifras, gráfica, repartos y pie**

Crear `Sources/Sintecla/StatsView.swift`:

```swift
import Charts
import SinteclaCore
import SwiftUI

extension Notification.Name {
  /// Se ha sumado un uso a las estadísticas.
  static let usageChanged = Notification.Name("SinteclaUsageChanged")
}

/// Sección Estadísticas: cifras, gráfica y reparto por app y por modo, con el resumen de `stats.json`.
struct StatsView: View {
  let store: UsageStatsStore
  @State private var stats = UsageStats()
  @State private var scale: UsageStats.Scale = .days
  @State private var period: UsageStats.Period = .month

  var body: some View {
    let now = Date()
    Group {
      if stats.totalUses == 0 {
        ContentUnavailableView("Aún no hay dictados", systemImage: "chart.bar",
                               description: Text("Cuando dictes, aquí verás cuánto, cuándo y dónde."))
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            if let first = stats.firstDay() {
              Text("Desde el \(first.formatted(.dateTime.day().month(.wide))) · \(stats.totalUses.formatted()) usos")
                .font(.caption).foregroundStyle(.secondary)
            }
            figures(now: now)
            chart(now: now)
            Picker("Periodo", selection: $period) {
              Text("7 días").tag(UsageStats.Period.week)
              Text("30 días").tag(UsageStats.Period.month)
              Text("Siempre").tag(UsageStats.Period.all)
            }
            .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 260)
            HStack(alignment: .top, spacing: 12) {
              shares("Por app", stats.byApp(period, now: now))
              shares("Por modo", stats.byMode(period, now: now))
            }
            Text("\(stats.wordsPerMinute) palabras/min al dictar · \(stats.totalWords.formatted()) palabras en total")
              .font(.caption).foregroundStyle(.secondary)
          }
          .padding(20)
        }
      }
    }
    .onAppear { stats = store.current }
    .onReceive(NotificationCenter.default.publisher(for: .usageChanged)) { _ in stats = store.current }
  }

  private func figures(now: Date) -> some View {
    let best = stats.bestDay()
    return HStack(spacing: 12) {
      figure("Hoy", stats.words(on: now).formatted(), "palabras")
      figure("Racha", stats.streak(now: now) == 1 ? "1 día" : "\(stats.streak(now: now)) días",
             "récord: \(stats.recordStreak())")
      figure("Tiempo ahorrado", Self.duration(minutes: stats.minutesSaved), "frente a teclear")
      figure("Mejor día", best.map { $0.words.formatted() } ?? "—",
             best.map { $0.start.formatted(.dateTime.day().month(.abbreviated)) } ?? "")
    }
  }

  private func figure(_ title: String, _ value: String, _ detail: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value).font(.title2.weight(.semibold)).monospacedDigit()
      Text(detail).font(.caption2).foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
  }

  private func chart(now: Date) -> some View {
    let bars = stats.series(scale, now: now)
    let most = bars.map(\.words).max() ?? 0
    let unit: Calendar.Component = switch scale {
    case .days: .day
    case .weeks: .weekOfYear
    case .months: .month
    }
    return VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Palabras").font(.headline)
        Spacer()
        Picker("Escala", selection: $scale) {
          Text("Días").tag(UsageStats.Scale.days)
          Text("Semanas").tag(UsageStats.Scale.weeks)
          Text("Meses").tag(UsageStats.Scale.months)
        }
        .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 240)
      }
      Chart(bars, id: \.start) { bar in
        BarMark(x: .value("Periodo", bar.start, unit: unit), y: .value("Palabras", bar.words))
          .foregroundStyle(bar.words == most && most > 0 ? Color.primary : Color.secondary.opacity(0.6))
          .cornerRadius(3)
      }
      .frame(height: 170)
    }
    .padding(12)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
  }

  private func shares(_ title: String, _ rows: [UsageStats.Share]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.headline)
      if rows.isEmpty {
        Text("Aún no hay dictados en este periodo").font(.caption).foregroundStyle(.secondary)
      }
      ForEach(rows, id: \.name) { row in
        HStack(spacing: 8) {
          Text(row.name).lineLimit(1).frame(width: 90, alignment: .leading)
          Capsule().fill(.quaternary).frame(height: 6)
            .overlay(alignment: .leading) {
              GeometryReader { box in Capsule().fill(.secondary).frame(width: box.size.width * row.fraction) }
            }
          Text(row.fraction.formatted(.percent.precision(.fractionLength(0))))
            .monospacedDigit().foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
        }
        .font(.caption)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
  }

  /// «18 h 40 min», «25 min».
  static func duration(minutes: Int) -> String {
    minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
  }
}
```

- [ ] **Step 7: Avisar a la página cuando llega un uso**

En `Sources/Sintecla/DictationController.swift`, cambiar:

```swift
        try? self.usage.add(entry)
```

por:

```swift
        try? self.usage.add(entry)
        NotificationCenter.default.post(name: .usageChanged, object: nil)
```

- [ ] **Step 8: Sección «Estadísticas» en la barra lateral**

En `Sources/Sintecla/MainWindow.swift`, cambiar:

```swift
  case meetings, history, general, dictionary, tones, ai
```

por:

```swift
  case meetings, history, stats, general, dictionary, tones, ai
```

Y cambiar:

```swift
/// Ventana principal: barra lateral de Liquid Glass (nativa en macOS 26) con Reuniones, Historial y Ajustes.
struct MainView: View {
  @Bindable var navigation: MainNavigation
  @Bindable var settings: AppSettings
  let history: HistoryStore
```

por:

```swift
/// Ventana principal: barra lateral de Liquid Glass (nativa en macOS 26) con Reuniones, Historial, Estadísticas y Ajustes.
struct MainView: View {
  @Bindable var navigation: MainNavigation
  @Bindable var settings: AppSettings
  let history: HistoryStore
  let usage: UsageStatsStore
```

Y cambiar:

```swift
        Label("Historial", systemImage: "clock.arrow.circlepath").tag(MainSection.history)
```

por:

```swift
        Label("Historial", systemImage: "clock.arrow.circlepath").tag(MainSection.history)
        Label("Estadísticas", systemImage: "chart.bar").tag(MainSection.stats)
```

Y cambiar:

```swift
    case .history: HistoryView(store: history).navigationTitle("Historial")
```

por:

```swift
    case .history: HistoryView(store: history).navigationTitle("Historial")
    case .stats: StatsView(store: usage).navigationTitle("Estadísticas")
```

- [ ] **Step 9: La ventana recibe el resumen**

En `Sources/Sintecla/AppDelegate.swift`, cambiar:

```swift
    AnyView(MainView(navigation: navigation, settings: settings, history: controller.history, meetings: meetings,
```

por:

```swift
    AnyView(MainView(navigation: navigation, settings: settings, history: controller.history, usage: controller.usage,
                     meetings: meetings,
```

- [ ] **Step 10: El Historial pierde su fila de cifras**

En `Sources/Sintecla/Windows.swift`, cambiar:

```swift
  var body: some View {
    let stats = HistoryStore.stats(for: entries)
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 24) {
        stat("Hoy", stats.wordsToday)
        stat("7 días", stats.wordsWeek)
        stat("Total", stats.wordsTotal)
        stat("Palabras/min", stats.averageWPM)
        stat("Min ahorrados", stats.minutesSaved)
      }
      TextField("Buscar", text: $query).textFieldStyle(.roundedBorder)
```

por:

```swift
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("Buscar", text: $query).textFieldStyle(.roundedBorder)
```

Y cambiar:

```swift

  private func stat(_ title: String, _ value: Int) -> some View {
    VStack {
      Text("\(value)").font(.title2.bold())
      Text(title).font(.caption).foregroundStyle(.secondary)
    }
  }
```

por:

```swift

```

- [ ] **Step 11: Quitar las cifras viejas del historial**

En `Sources/SinteclaCore/History.swift`, cambiar:

```swift
public struct HistoryStats: Equatable, Sendable {
  public var wordsToday: Int
  public var wordsWeek: Int
  public var wordsTotal: Int
  public var averageWPM: Int
  /// Minutos ahorrados frente a teclear a 40 palabras por minuto.
  public var minutesSaved: Int
}
```

por:

```swift

```

Y cambiar:

```swift
  public static func stats(for entries: [HistoryEntry], now: Date = Date(), calendar: Calendar = .current) -> HistoryStats {
    let weekAgo = now.addingTimeInterval(-7 * 24 * 3600)
    let total = entries.reduce(0) { $0 + $1.words }
    let today = entries.filter { calendar.isDate($0.date, inSameDayAs: now) }.reduce(0) { $0 + $1.words }
    let week = entries.filter { $0.date >= weekAgo }.reduce(0) { $0 + $1.words }
    let minutes = entries.reduce(0.0) { $0 + $1.audioSeconds } / 60
    let wpm = minutes > 0 ? Int((Double(total) / minutes).rounded()) : 0
    let saved = max(0, Int((Double(total) / 40 - minutes).rounded()))
    return HistoryStats(wordsToday: today, wordsWeek: week, wordsTotal: total, averageWPM: wpm, minutesSaved: saved)
  }
```

por:

```swift

```

- [ ] **Step 12: …y su test**

En `Sources/SinteclaCoreTests/HistoryAndStorageTests.swift`, cambiar:

```swift

  @Test func computesStats() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let entries = [
      entry("una dos tres cuatro", date: now, seconds: 60),                          // hoy
      entry("cinco seis", date: now.addingTimeInterval(-3 * 24 * 3600), seconds: 60),  // esta semana
      entry("siete", date: now.addingTimeInterval(-30 * 24 * 3600), seconds: 60),      // antes
    ]
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let stats = HistoryStore.stats(for: entries, now: now, calendar: calendar)
    #expect(stats == HistoryStats(wordsToday: 4, wordsWeek: 6, wordsTotal: 7, averageWPM: 2, minutesSaved: 0))
  }
```

por:

```swift

```

- [ ] **Step 13: Compilar**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | tail -1
```

Esperado: `Build of product 'Sintecla' complete!`.

- [ ] **Step 14: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 196 tests in 38 suites passed`.

- [ ] **Step 15: Commit**

```bash
git add Sources/Sintecla/StatsView.swift Sources/Sintecla/DictationController.swift Sources/Sintecla/MainWindow.swift Sources/Sintecla/AppDelegate.swift Sources/Sintecla/Windows.swift Sources/SinteclaCore/History.swift Sources/SinteclaCoreTests/HistoryAndStorageTests.swift Sources/SinteclaCore/AppInfo.swift Resources/Info.plist Sources/SinteclaCoreTests/SmokeTests.swift
git commit -m 'feat: sección Estadísticas con gráfica y reparto por app y por modo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

- [ ] **Step 16: Instalar la versión nueva**

Run:

```bash
scripts/build-app.sh
```

Esperado: `✅ Instalada en /Applications/Sintecla.app`. Los permisos se conservan.

---
### Task 4: Aceptación de las estadísticas

**Files:**
- Modify: `docs/superpowers/specs/2026-09-23-sintecla-design.md` (estado)

**Interfaces:**
- Consumes: La app instalada (Tarea 3).
- Produces: Etiqueta `v0.7.0` y la rama `estadisticas` integrada en `main`.

Lo hace el usuario: es su historial real y la página dentro de la ventana (spec de estadísticas §9).

- [ ] **Step 1: Checklist manual de las estadísticas. Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | Abrir Sintecla… → Estadísticas | Cifras, gráfica y repartos con lo que había en el historial, y «Desde el …» con su fecha |
| 2 | Dictar algo y volver a Estadísticas | Suben Hoy, la barra de hoy y el reparto de esa app |
| 3 | Cambiar Días / Semanas / Meses | La gráfica cambia de escala; la barra más alta va más oscura |
| 4 | Cambiar 7 días / 30 días / Siempre | Los repartos cambian |
| 5 | Historial | Sin la fila de cifras; buscador, lista y Copiar igual que antes |
| 6 | Salir de Sintecla y volver a abrirla | Las estadísticas siguen ahí (salen de `stats.json`) |
| 7 | Dictado, traducción, Ask, notas y reuniones | Igual que en la 0.6.0 |

- [ ] **Step 2: Marcar las estadísticas como entregadas en la spec**

En `docs/superpowers/specs/2026-09-23-sintecla-design.md`, cambiar:

```text
F4c entregada (`v0.6.0`).
```

por:

```text
F4c entregada (`v0.6.0`). Estadísticas entregadas (`v0.7.0`).
```

- [ ] **Step 3: Cerrar**

```bash
git add docs/superpowers/specs/2026-09-23-sintecla-design.md
git commit -m 'docs: estadísticas entregadas

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
swift run sintecla-tests
git tag -a v0.7.0 -m 'Estadísticas'
```

Después, integrar `estadisticas` en `main` con superpowers:finishing-a-development-branch.

---
## Autorrevisión frente a la especificación (estadísticas)

| Requisito (spec de estadísticas) | Dónde |
|---|---|
| §2 Qué cuenta: usos del historial, palabras (Ask con `rawText`), segundos, día local, sin reuniones | Tarea 1 |
| §3 Resumen por día, por app y por modo, «Otra», solo números, `stats.json` sin recortar, se suma al guardar, relleno antes de recortar, roto → `.roto` y se rehace | Tareas 1 y 2 |
| §4 Hoy, racha y récord, tiempo ahorrado, mejor día, pie | Tarea 1 (cálculo) y 3 (vista) |
| §5 Gráfica de 30 días, 12 semanas y 12 meses, ceros, barra más alta oscura, Swift Charts | Tareas 1 y 3 |
| §6 Repartos con 7/30 días/Siempre, top 5 + «Otras», modos sin palabras fuera, mensaje sin usos | Tareas 1 y 3 |
| §7 Sección en la barra lateral, orden de la página, recarga al abrir y con cada uso, Historial sin cifras | Tarea 3 |
| §8 Piezas y versión 0.7.0; `HistoryStats` y `HistoryStore.stats` se quitan | Tareas 1–3 |
| §9 Tests y aceptación a mano | Tareas 1 y 4 |

**Consistencia de tipos revisada:**
- `UsageStatsStore.prepare(history:)` y `add(_:)` (Tarea 1) los usa `DictationController` (Tarea 2).
- `DictationController.usage` (Tarea 2) llega a `MainView.usage` y a `StatsView(store:)` (Tarea 3).
- `Notification.Name.usageChanged` se declara en `StatsView.swift` y se envía desde `DictationController` en la misma tarea (Tarea 3).
