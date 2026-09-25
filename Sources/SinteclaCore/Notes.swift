import Foundation

/// Notas organizadas de una grabación larga (lo que devuelve Gemini en JSON).
public struct NotesDocument: Codable, Equatable, Sendable {
  public struct Topic: Codable, Equatable, Sendable {
    public var tema: String
    public var puntos: [String]

    public init(tema: String, puntos: [String]) {
      self.tema = tema
      self.puntos = puntos
    }
  }

  public var resumen: String
  public var ideas: [Topic]
  public var tareas: [String]
  public var pendiente: [String]

  public init(resumen: String = "", ideas: [Topic] = [], tareas: [String] = [], pendiente: [String] = []) {
    self.resumen = resumen
    self.ideas = ideas
    self.tareas = tareas
    self.pendiente = pendiente
  }

  public var isEmpty: Bool {
    resumen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && ideas.allSatisfy { $0.puntos.isEmpty } && tareas.isEmpty && pendiente.isEmpty
  }

  public static let jsonSchema = """
    {"type": "object",
     "properties": {
       "resumen": {"type": "string"},
       "ideas": {"type": "array", "items": {"type": "object",
         "properties": {"tema": {"type": "string"}, "puntos": {"type": "array", "items": {"type": "string"}}},
         "required": ["tema", "puntos"]}},
       "tareas": {"type": "array", "items": {"type": "string"}},
       "pendiente": {"type": "array", "items": {"type": "string"}}},
     "required": ["resumen", "ideas", "tareas", "pendiente"]}
    """
}

/// Markdown en apps que lo muestran; texto plano (títulos con ":" y viñetas "•") en el resto.
public enum NotesFormat: Equatable, Sendable {
  case markdown, plainText

  static let markdownApps: Set<String> = ["md.obsidian", "notion.id", "net.shinyfrog.bear"]

  public static func forApp(bundleID: String?, tone: Tone) -> NotesFormat {
    if tone == .technical || tone == .prompt { return .markdown }
    if let bundleID, markdownApps.contains(bundleID) { return .markdown }
    return .plainText
  }
}

public enum NotesRenderer {
  /// Solo aparecen las secciones con contenido. Un tema sin título se pinta como viñetas sueltas.
  public static func render(_ doc: NotesDocument, format: NotesFormat) -> String {
    let md = format == .markdown
    let bullet = md ? "- " : "• "
    func title(_ text: String) -> String { md ? "## \(text)" : "\(text):" }
    var sections: [String] = []

    let summary = doc.resumen.trimmingCharacters(in: .whitespacesAndNewlines)
    if !summary.isEmpty { sections.append(title("Resumen") + "\n" + summary) }

    let topics = doc.ideas.filter { !$0.puntos.isEmpty }
    if !topics.isEmpty {
      let body = topics.map { topic in
        let points = topic.puntos.map { bullet + $0 }.joined(separator: "\n")
        let name = topic.tema.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return points }
        return (md ? "### \(name)" : "\(name):") + "\n" + points
      }.joined(separator: "\n\n")
      sections.append(title("Ideas clave") + "\n" + body)
    }

    if !doc.tareas.isEmpty {
      sections.append(title("Tareas") + "\n" + doc.tareas.map { (md ? "- [ ] " : bullet) + $0 }.joined(separator: "\n"))
    }
    if !doc.pendiente.isEmpty {
      sections.append(title("Pendiente de decidir") + "\n" + doc.pendiente.map { bullet + $0 }.joined(separator: "\n"))
    }
    return sections.joined(separator: "\n\n")
  }
}

public struct NotesResult: Equatable, Sendable {
  public enum Engine: String, Sendable {
    /// `apple`: resumen local en viñetas; `rules`: transcripción limpia sin organizar.
    case gemini, apple, rules
  }

  public var text: String
  public var engine: Engine
  /// Por qué no se usó Gemini (para avisar en la pastilla).
  public var cloudError: CloudError?

  public init(text: String, engine: Engine, cloudError: CloudError? = nil) {
    self.text = text
    self.engine = engine
    self.cloudError = cloudError
  }
}

/// Transcripción larga → notas organizadas. Gemini (JSON) → Apple (viñetas por trozos) → reglas.
public struct NotesOrganizer: Sendable {
  /// Trozos para el modelo de Apple (contexto de 4.096 tokens).
  public static let chunkChars = 2000

  public let cloud: StructuredModel?
  public let apple: TextModel?
  public let dictionary: PersonalDictionary
  public let isKnownWord: @Sendable (String) -> Bool
  /// "Mi estilo" (Ajustes → IA).
  public var style: String

  public init(cloud: StructuredModel?, apple: TextModel?, dictionary: PersonalDictionary,
              isKnownWord: @escaping @Sendable (String) -> Bool, style: String = "") {
    self.cloud = cloud
    self.apple = apple
    self.dictionary = dictionary
    self.isKnownWord = isKnownWord
    self.style = style
  }

  public func organize(_ transcript: String, format: NotesFormat) async -> NotesResult {
    var text = RulesCleaner().clean(transcript)
    text = dictionary.applyRules(to: text)
    text = dictionary.fuzzyFix(text, isKnownWord: isKnownWord)
    guard !text.isEmpty else { return NotesResult(text: "", engine: .rules) }

    var cloudError: CloudError?
    if let cloud {
      do {
        let data = try await cloud.completeJSON(instructions: PromptLibrary.notesInstructions(style: style),
                                                prompt: PromptLibrary.wrap(text), schemaName: "notas",
                                                schema: NotesDocument.jsonSchema)
        let doc = try JSONDecoder().decode(NotesDocument.self, from: data)
        if !doc.isEmpty { return NotesResult(text: finish(doc, format), engine: .gemini) }
        cloudError = .invalidResponse
      } catch {
        cloudError = (error as? CloudError) ?? .invalidResponse
      }
    }

    if let apple {
      var points: [String] = []
      for chunk in Chunker.split(text, maxChars: Self.chunkChars) {
        if let output = try? await apple.complete(instructions: PromptLibrary.notesMapInstructions,
                                                  prompt: PromptLibrary.wrap(chunk), maxTokens: chunk.count / 2 + 64) {
          points += Self.bullets(from: output)
        }
      }
      if !points.isEmpty {
        let doc = NotesDocument(ideas: [NotesDocument.Topic(tema: "", puntos: Self.unique(points))])
        return NotesResult(text: finish(doc, format), engine: .apple, cloudError: cloudError)
      }
    }
    return NotesResult(text: dictionary.restoreTerms(TextMetrics.finalize(text)), engine: .rules, cloudError: cloudError)
  }

  private func finish(_ doc: NotesDocument, _ format: NotesFormat) -> String {
    dictionary.restoreTerms(NotesRenderer.render(doc, format: format))
  }

  /// Quita viñetas repetidas (sin distinguir tildes ni mayúsculas), conservando el orden.
  static func unique(_ points: [String]) -> [String] {
    var seen: Set<String> = []
    return points.filter { seen.insert(TextMetrics.fold($0)).inserted }
  }

  /// Líneas de viñetas ("- ", "* ", "• ", "1. ") sin la marca; ignora las vacías.
  static func bullets(from text: String) -> [String] {
    text.components(separatedBy: .newlines).compactMap { line in
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      let stripped = trimmed.replacingOccurrences(of: #"^([-*•]|\d+[.)])\s*"#, with: "", options: .regularExpression)
      let point = stripped.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
      return point.isEmpty ? nil : point
    }
  }
}

/// Borradores de notas: cada frase reconocida se guarda al momento para no perder nada
/// si algo falla. Se borran cuando las notas se pegan bien.
public final class DraftStore: @unchecked Sendable {
  public let directory: URL
  private let lock = NSLock()

  public init(directory: URL) {
    self.directory = directory
  }

  public func create() -> URL {
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("\(UUID().uuidString).txt")
    FileManager.default.createFile(atPath: url.path, contents: nil)
    return url
  }

  public func append(_ text: String, to url: URL) {
    lock.withLock {
      guard let handle = try? FileHandle(forWritingTo: url) else { return }
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: Data((text + " ").utf8))
    }
  }

  public func read(_ url: URL) -> String {
    (try? String(contentsOf: url, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  public func delete(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
  }

  /// Borradores con texto que quedaron sin procesar.
  public func pending() -> [URL] {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    return names.filter { $0.hasSuffix(".txt") }.sorted()
      .map { directory.appendingPathComponent($0) }
      .filter { !read($0).isEmpty }
  }
}
