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
