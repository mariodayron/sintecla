import Foundation

/// Ficha de una reunión (`meetings/<id>/meeting.json`). La carpeta guarda también `transcript.jsonl` y el audio.
public struct MeetingRecord: Codable, Equatable, Sendable, Identifiable {
  public enum Status: String, Codable, Sendable {
    case recording, processing, ready, pending
  }

  public var id: String
  public var startedAt: Date
  public var duration: Double
  public var status: Status
  public var title: String?
  public var tasks: Int
  /// Por qué quedó pendiente ("Sin conexión", "Sin clave de Gemini"…).
  public var problem: String?
  public var pdfPath: String?
  public var markdownPath: String?

  public init(id: String, startedAt: Date, duration: Double = 0, status: Status = .recording, title: String? = nil,
              tasks: Int = 0, problem: String? = nil, pdfPath: String? = nil, markdownPath: String? = nil) {
    self.id = id
    self.startedAt = startedAt
    self.duration = duration
    self.status = status
    self.title = title
    self.tasks = tasks
    self.problem = problem
    self.pdfPath = pdfPath
    self.markdownPath = markdownPath
  }
}

/// Reuniones en disco, una carpeta por reunión. Cada frase se añade al momento a `transcript.jsonl`:
/// si la app se cierra a mitad, no se pierde lo grabado.
public struct MeetingStore: Sendable {
  public let directory: URL

  public init(directory: URL) {
    self.directory = directory
  }

  public func create(startedAt: Date = Date()) throws -> MeetingRecord {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    var id = formatter.string(from: startedAt)
    var suffix = 2
    while FileManager.default.fileExists(atPath: folder(id).path) {
      id = formatter.string(from: startedAt) + "-\(suffix)"
      suffix += 1
    }
    try FileManager.default.createDirectory(at: folder(id), withIntermediateDirectories: true)
    let record = MeetingRecord(id: id, startedAt: startedAt)
    try save(record)
    return record
  }

  public func folder(_ id: String) -> URL { directory.appendingPathComponent(id, isDirectory: true) }
  public func transcriptURL(_ id: String) -> URL { folder(id).appendingPathComponent("transcript.jsonl") }

  public func save(_ record: MeetingRecord) throws {
    try JSONFileStore.save(record, to: folder(record.id).appendingPathComponent("meeting.json"))
  }

  public func record(_ id: String) -> MeetingRecord? {
    JSONFileStore.load(MeetingRecord.self, from: folder(id).appendingPathComponent("meeting.json"))
  }

  /// Todas, de la más reciente a la más antigua. Las carpetas sin ficha legible se ignoran.
  public func all() -> [MeetingRecord] {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    return names.compactMap { record($0) }.sorted { $0.startedAt > $1.startedAt }
  }

  public func append(_ segment: MeetingSegment, to id: String) {
    let line = Data((MeetingTranscript.line(segment) + "\n").utf8)
    let url = transcriptURL(id)
    if let handle = try? FileHandle(forWritingTo: url) {
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: line)
    } else {
      try? line.write(to: url, options: .atomic)
    }
  }

  public func segments(_ id: String) -> [MeetingSegment] {
    MeetingTranscript.parse((try? String(contentsOf: transcriptURL(id), encoding: .utf8)) ?? "")
  }

  public func delete(_ id: String) throws {
    try FileManager.default.removeItem(at: folder(id))
  }

  /// Tras un cierre inesperado, las que seguían grabando o procesando quedan pendientes (se pueden reintentar).
  @discardableResult
  public func recoverInterrupted() -> [MeetingRecord] {
    all().filter { $0.status == .recording || $0.status == .processing }.map { record in
      var record = record
      record.status = .pending
      record.problem = "Sintecla se cerró durante la reunión"
      if record.duration == 0, let last = segments(record.id).last { record.duration = last.fin }
      try? save(record)
      return record
    }
  }
}

public enum MeetingFiles {
  /// "2026-09-23 2208 – Seguimiento de obra": fecha ordenable y un título sin caracteres que el Finder no admite.
  public static func baseName(title: String, date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HHmm"
    let clean = title.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>\n\r\t")).joined(separator: " ")
      .split(separator: " ").joined(separator: " ")
    let short = String(clean.prefix(80)).trimmingCharacters(in: .whitespaces)
    return formatter.string(from: date) + " – " + (short.isEmpty ? "Reunión" : short)
  }
}
