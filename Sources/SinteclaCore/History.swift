import Foundation

public struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
  public var id: UUID
  public var date: Date
  public var mode: HotkeyMode
  public var appBundleID: String?
  public var appName: String?
  public var language: String
  public var audioSeconds: Double
  public var rawText: String
  public var finalText: String
  public var engine: String
  public var latencyMs: Int

  public var words: Int { TextMetrics.wordCount(finalText) }

  public init(id: UUID = UUID(), date: Date = Date(), mode: HotkeyMode, appBundleID: String?, appName: String?,
              language: String, audioSeconds: Double, rawText: String, finalText: String, engine: String, latencyMs: Int) {
    self.id = id
    self.date = date
    self.mode = mode
    self.appBundleID = appBundleID
    self.appName = appName
    self.language = language
    self.audioSeconds = audioSeconds
    self.rawText = rawText
    self.finalText = finalText
    self.engine = engine
    self.latencyMs = latencyMs
  }
}

/// Historial en JSON Lines (una entrada por línea). Seguro entre hilos.
public final class HistoryStore: @unchecked Sendable {
  public let fileURL: URL
  public let maxEntries: Int
  private let lock = NSLock()

  public init(fileURL: URL, maxEntries: Int = 500) {
    self.fileURL = fileURL
    self.maxEntries = maxEntries
  }

  public func append(_ entry: HistoryEntry) throws {
    try lock.withLock {
      var line = try Self.encoder.encode(entry)
      line.append(0x0A)
      let fm = FileManager.default
      try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      if !fm.fileExists(atPath: fileURL.path) {
        fm.createFile(atPath: fileURL.path, contents: nil)
      }
      let handle = try FileHandle(forWritingTo: fileURL)
      defer { try? handle.close() }
      try handle.seekToEnd()
      try handle.write(contentsOf: line)
    }
  }

  /// De la más nueva a la más antigua. Ignora líneas corruptas.
  public func load() -> [HistoryEntry] {
    lock.withLock { readAll().reversed() }
  }

  public func latest() -> HistoryEntry? {
    load().first
  }

  /// Deja solo las `maxEntries` más recientes.
  public func compact() throws {
    try lock.withLock {
      let entries = readAll()
      guard entries.count > maxEntries else { return }
      var data = Data()
      for entry in entries.suffix(maxEntries) {
        data.append(try Self.encoder.encode(entry))
        data.append(0x0A)
      }
      try data.write(to: fileURL, options: .atomic)
    }
  }

  private func readAll() -> [HistoryEntry] {
    guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
    return text.split(separator: "\n").compactMap { try? Self.decoder.decode(HistoryEntry.self, from: Data($0.utf8)) }
  }

  private static let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.sortedKeys]
    return e
  }()

  private static let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }()
}
