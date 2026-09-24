import Foundation

/// Una frase de una reunión: segundos desde el inicio, pista ("Tú" o "Otros") y texto.
public struct MeetingSegment: Codable, Equatable, Sendable {
  public static let me = "Tú"
  public static let others = "Otros"

  public var t: Double
  public var fin: Double
  public var pista: String
  public var texto: String

  public init(t: Double, fin: Double, pista: String, texto: String) {
    self.t = t
    self.fin = fin
    self.pista = pista
    self.texto = texto
  }

  enum CodingKeys: String, CodingKey { case t, fin, pista, texto }

  /// `fin` es opcional al leer (transcripciones antiguas o escritas a mano): se toma `t`.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    t = try c.decode(Double.self, forKey: .t)
    fin = try c.decodeIfPresent(Double.self, forKey: .fin) ?? t
    pista = try c.decode(String.self, forKey: .pista)
    texto = try c.decode(String.self, forKey: .texto)
  }
}

public enum MeetingTranscript {
  /// Una línea JSONL (sin salto final).
  public static func line(_ segment: MeetingSegment) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return (try? encoder.encode(segment)).map { String(decoding: $0, as: UTF8.self) } ?? ""
  }

  /// JSONL → frases ordenadas por tiempo. Las líneas vacías o rotas (un corte a mitad de escritura) se ignoran.
  public static func parse(_ jsonl: String) -> [MeetingSegment] {
    let decoder = JSONDecoder()
    return jsonl.split(whereSeparator: \.isNewline)
      .compactMap { try? decoder.decode(MeetingSegment.self, from: Data($0.utf8)) }
      .sorted { $0.t < $1.t }
  }

  /// Con altavoces, el micro oye a los demás y "Tú" repite lo que dice "Otros". Se quita cada frase de "Tú" que
  /// coincide en el tiempo (±1,5 s) con frases de "Otros" que contienen al menos el 60 % de sus palabras.
  /// Las frases de menos de 3 palabras se dejan: son respuestas cortas ("sí", "vale").
  public static func removingEcho(_ segments: [MeetingSegment]) -> [MeetingSegment] {
    let others = segments.filter { $0.pista == MeetingSegment.others }
    return segments.filter { segment in
      guard segment.pista == MeetingSegment.me else { return true }
      let words = Self.words(segment.texto)
      guard words.count >= 3 else { return true }
      let nearby = others.filter { $0.t <= segment.fin + 1.5 && $0.fin >= segment.t - 1.5 }
      let heard = Set(nearby.flatMap { Self.words($0.texto) })
      let repeated = words.filter { heard.contains($0) }.count
      return Double(repeated) / Double(words.count) < 0.6
    }
  }

  /// Texto para el modelo: una línea "[mm:ss] Tú: …" por frase, en orden.
  public static func promptText(_ segments: [MeetingSegment]) -> String {
    segments.map { "[\(clock($0.t))] \($0.pista): \($0.texto)" }.joined(separator: "\n")
  }

  /// "mm:ss", o "h:mm:ss" a partir de una hora.
  public static func clock(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    let (h, m, s) = (total / 3600, total % 3600 / 60, total % 60)
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
  }

  static func words(_ text: String) -> [String] {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
  }
}

/// Acta de una reunión (lo que devuelve Gemini en JSON; esquema de la spec §5.5).
public struct MeetingSummary: Codable, Equatable, Sendable {
  public struct Topic: Codable, Equatable, Sendable {
    public var titulo: String
    public var puntos: [String]

    public init(titulo: String, puntos: [String]) {
      self.titulo = titulo
      self.puntos = puntos
    }
  }

  public struct Task: Codable, Equatable, Sendable {
    public var responsable: String
    public var tarea: String
    public var fecha: String

    public init(responsable: String, tarea: String, fecha: String) {
      self.responsable = responsable
      self.tarea = tarea
      self.fecha = fecha
    }
  }

  public var titulo: String
  public var participantes: [String]
  public var resumen: String
  public var temas: [Topic]
  public var decisiones: [String]
  public var tareas: [Task]
  public var dudas: [String]
  public var proximosPasos: [String]

  enum CodingKeys: String, CodingKey {
    case titulo, participantes, resumen, temas, decisiones, tareas, dudas
    case proximosPasos = "proximos_pasos"
  }

  public init(titulo: String = "", participantes: [String] = [], resumen: String = "", temas: [Topic] = [],
              decisiones: [String] = [], tareas: [Task] = [], dudas: [String] = [], proximosPasos: [String] = []) {
    self.titulo = titulo
    self.participantes = participantes
    self.resumen = resumen
    self.temas = temas
    self.decisiones = decisiones
    self.tareas = tareas
    self.dudas = dudas
    self.proximosPasos = proximosPasos
  }

  public static let jsonSchema = """
    {"type": "object",
     "properties": {
       "titulo": {"type": "string"},
       "participantes": {"type": "array", "items": {"type": "string"}},
       "resumen": {"type": "string"},
       "temas": {"type": "array", "items": {"type": "object",
         "properties": {"titulo": {"type": "string"}, "puntos": {"type": "array", "items": {"type": "string"}}},
         "required": ["titulo", "puntos"]}},
       "decisiones": {"type": "array", "items": {"type": "string"}},
       "tareas": {"type": "array", "items": {"type": "object",
         "properties": {"responsable": {"type": "string"}, "tarea": {"type": "string"}, "fecha": {"type": "string"}},
         "required": ["responsable", "tarea", "fecha"]}},
       "dudas": {"type": "array", "items": {"type": "string"}},
       "proximos_pasos": {"type": "array", "items": {"type": "string"}}},
     "required": ["titulo", "participantes", "resumen", "temas", "decisiones", "tareas", "dudas", "proximos_pasos"]}
    """
}

public enum MeetingRenderer {
  /// Markdown del acta. Solo aparecen las secciones con contenido.
  public static func markdown(_ summary: MeetingSummary, date: Date, duration: Double) -> String {
    var parts = ["# \(title(summary))", "*\(dateLine(date, duration: duration))*"]
    if !summary.participantes.isEmpty { parts.append("**Participantes:** " + summary.participantes.joined(separator: ", ")) }
    if !summary.resumen.isEmpty { parts.append("## Resumen\n\(summary.resumen)") }
    let topics = summary.temas.filter { !$0.puntos.isEmpty }
    if !topics.isEmpty {
      parts.append("## Temas\n" + topics.map { "### \($0.titulo)\n" + $0.puntos.map { "- \($0)" }.joined(separator: "\n") }
        .joined(separator: "\n\n"))
    }
    if !summary.decisiones.isEmpty { parts.append("## Decisiones\n" + summary.decisiones.map { "- \($0)" }.joined(separator: "\n")) }
    if !summary.tareas.isEmpty {
      let rows = summary.tareas.map { "| \(cell($0.responsable)) | \(cell($0.tarea)) | \(cell($0.fecha)) |" }
      parts.append("## Tareas\n| Responsable | Tarea | Fecha |\n|---|---|---|\n" + rows.joined(separator: "\n"))
    }
    if !summary.dudas.isEmpty { parts.append("## Dudas\n" + summary.dudas.map { "- \($0)" }.joined(separator: "\n")) }
    if !summary.proximosPasos.isEmpty {
      parts.append("## Próximos pasos\n" + summary.proximosPasos.map { "- \($0)" }.joined(separator: "\n"))
    }
    return parts.joined(separator: "\n\n") + "\n"
  }

  /// HTML del acta para el PDF (A4): cabecera, secciones con contenido, tabla de tareas y, en otra página, la transcripción.
  public static func html(_ summary: MeetingSummary, date: Date, duration: Double, segments: [MeetingSegment]) -> String {
    func e(_ text: String) -> String {
      text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    func list(_ items: [String], _ cls: String = "") -> String {
      "<ul class=\"\(cls)\">" + items.map { "<li>\(e($0))</li>" }.joined() + "</ul>"
    }
    var body = """
      <header><div class="kicker">Acta de reunión</div><h1>\(e(title(summary)))</h1>
      <div class="meta">\(e(dateLine(date, duration: duration)))</div>
      """
    if !summary.participantes.isEmpty {
      body += "<div class=\"people\">" + summary.participantes.map { "<span>\(e($0))</span>" }.joined() + "</div>"
    }
    body += "</header>"
    if !summary.resumen.isEmpty { body += "<h2>Resumen</h2><p class=\"summary\">\(e(summary.resumen))</p>" }
    let topics = summary.temas.filter { !$0.puntos.isEmpty }
    if !topics.isEmpty {
      body += "<h2>Temas</h2>" + topics.map { "<section class=\"topic\"><h3>\(e($0.titulo))</h3>\(list($0.puntos))</section>" }.joined()
    }
    if !summary.decisiones.isEmpty { body += "<h2>Decisiones</h2>" + list(summary.decisiones, "decisions") }
    if !summary.tareas.isEmpty {
      let rows = summary.tareas.map {
        "<tr><td class=\"who\">\(e($0.responsable))</td><td>\(e($0.tarea))</td><td class=\"when\">\(e($0.fecha))</td></tr>"
      }.joined()
      body += "<h2>Tareas</h2><table><thead><tr><th>Responsable</th><th>Tarea</th><th>Fecha</th></tr></thead><tbody>\(rows)</tbody></table>"
    }
    if !summary.dudas.isEmpty { body += "<h2>Dudas</h2>" + list(summary.dudas) }
    if !summary.proximosPasos.isEmpty { body += "<h2>Próximos pasos</h2>" + list(summary.proximosPasos) }
    body += "<p class=\"note\">Resumen generado con Sintecla a partir de la transcripción: revisa nombres, cifras y fechas importantes.</p>"
    if !segments.isEmpty {
      let lines = segments.map { segment in
        let cls = segment.pista == MeetingSegment.me ? "me" : "others"
        return "<div class=\"line\"><span class=\"t\">\(MeetingTranscript.clock(segment.t))</span> "
          + "<span class=\"\(cls)\">\(e(segment.pista))</span> \(e(segment.texto))</div>"
      }.joined()
      body += "<section class=\"annex\"><h2>Anexo: transcripción</h2>\(lines)</section>"
    }
    return "<!doctype html><html lang=\"es\"><head><meta charset=\"utf-8\"><style>\(css)</style></head><body>\(body)</body></html>"
  }

  static let css = """
    :root { --accent: #111111; --muted: #6B6B6B; --line: #E3E3E3; --soft: #F4F4F4; --others: #555555; }
    body { font: 10.5pt/1.45 -apple-system, "Helvetica Neue", Helvetica, Arial, sans-serif; color: #1D2433; margin: 0; }
    header { border-bottom: 2px solid var(--accent); padding-bottom: 10pt; margin-bottom: 6pt; }
    .kicker { font-size: 8pt; letter-spacing: .09em; text-transform: uppercase; color: var(--accent); font-weight: 600; }
    h1 { font-size: 19pt; line-height: 1.2; margin: 3pt 0 4pt; }
    .meta { color: var(--muted); font-size: 9.5pt; }
    .people { margin-top: 7pt; }
    .people span { display: inline-block; background: var(--soft); border: 1px solid var(--line); border-radius: 9pt;
      padding: 1pt 8pt; margin: 0 4pt 4pt 0; font-size: 9pt; }
    h2 { font-size: 12pt; color: var(--accent); margin: 16pt 0 6pt; padding-bottom: 3pt; border-bottom: 1px solid var(--line);
      break-after: avoid; page-break-after: avoid; }
    h3 { font-size: 10.5pt; margin: 9pt 0 3pt; break-after: avoid; page-break-after: avoid; }
    .topic { break-inside: avoid; page-break-inside: avoid; }
    p { margin: 0 0 6pt; }
    .summary { background: var(--soft); border-left: 3px solid var(--accent); padding: 8pt 10pt; }
    ul { margin: 0; padding-left: 15pt; }
    li { margin: 2pt 0; }
    ul.decisions { list-style: none; padding-left: 0; }
    ul.decisions li { padding-left: 16pt; position: relative; }
    ul.decisions li::before { content: "✓"; color: var(--accent); font-weight: 700; position: absolute; left: 2pt; }
    table { width: 100%; border-collapse: collapse; font-size: 9.5pt; }
    th { text-align: left; background: var(--soft); color: #344054; font-weight: 600; padding: 5pt 6pt; border-bottom: 1px solid var(--line); }
    td { padding: 5pt 6pt; border-bottom: 1px solid var(--line); vertical-align: top; }
    tr { break-inside: avoid; page-break-inside: avoid; }
    td.who { white-space: nowrap; font-weight: 600; }
    td.when { white-space: nowrap; color: var(--muted); }
    .note { margin-top: 18pt; color: var(--muted); font-size: 8.5pt; }
    .annex { break-before: page; page-break-before: always; }
    .line { font-size: 9pt; margin: 3pt 0; break-inside: avoid; page-break-inside: avoid; }
    .t { color: var(--muted); font-variant-numeric: tabular-nums; margin-right: 4pt; }
    .me { color: var(--accent); font-weight: 600; }
    .others { color: var(--others); font-weight: 600; }
    """

  public static func title(_ summary: MeetingSummary) -> String {
    let title = summary.titulo.trimmingCharacters(in: .whitespacesAndNewlines)
    return title.isEmpty ? "Reunión" : title
  }

  static func dateLine(_ date: Date, duration: Double) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateFormat = "d 'de' MMMM 'de' yyyy, HH:mm"
    return "\(formatter.string(from: date)) · \(durationText(duration))"
  }

  /// "menos de 1 min", "21 min", "1 h", "1 h 5 min".
  public static func durationText(_ seconds: Double) -> String {
    guard seconds >= 60 else { return "menos de 1 min" }
    let minutes = Int((seconds / 60).rounded())
    let (h, m) = (minutes / 60, minutes % 60)
    if h == 0 { return "\(m) min" }
    return m == 0 ? "\(h) h" : "\(h) h \(m) min"
  }

  static func cell(_ text: String) -> String {
    text.replacingOccurrences(of: "|", with: "/").replacingOccurrences(of: "\n", with: " ")
  }
}

public enum MeetingSummarizer {
  /// Acta con Gemini (JSON con el esquema de `MeetingSummary`), a partir de las frases ya sin eco.
  public static func summarize(_ segments: [MeetingSegment], model: StructuredModel, style: String) async throws -> MeetingSummary {
    let transcript = MeetingTranscript.promptText(segments)
    let data = try await model.completeJSON(instructions: PromptLibrary.meetingInstructions(style: style),
                                            prompt: PromptLibrary.meetingPrompt(transcript),
                                            schemaName: "acta", schema: MeetingSummary.jsonSchema)
    do {
      return try JSONDecoder().decode(MeetingSummary.self, from: data)
    } catch {
      throw CloudError.invalidResponse
    }
  }
}
