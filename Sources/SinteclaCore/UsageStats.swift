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
