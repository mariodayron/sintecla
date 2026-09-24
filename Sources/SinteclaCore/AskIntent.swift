import Foundation
import NaturalLanguage

/// Qué pide una orden de Ask Anything.
public enum AskIntent: String, Equatable, Sendable {
  case question, webAction, edit
}

/// Reglas para clasificar lo dictado con `Fn + Space`.
public enum IntentClassifier {
  static let webVerbs: Set<String> = [
    "busca", "buscame", "abre", "abreme", "pon", "ponme", "ensename", "muestrame",
  ]
  static let questionMarkers = ["explica", "que significa", "de que va"]

  public static func classify(_ text: String, hasSelection: Bool) -> AskIntent {
    let folded = TextMetrics.fold(text)
    let first = folded.split(whereSeparator: { !$0.isLetter }).first.map(String.init)
    if !hasSelection, let first, webVerbs.contains(first) { return .webAction }
    if TextMetrics.isQuestion(text) || questionMarkers.contains(where: { folded.contains($0) }) { return .question }
    return .edit
  }
}

/// "Tradúcelo al inglés" sobre una selección: se traduce con el traductor de Apple, que lo hace
/// mejor que el modelo de lenguaje local ("te paso el enlace luego" → él: "I pass the link later").
public enum TranslationCommand {
  static let languages: [(word: String, language: TranslationLanguage)] = [
    ("ingles", .en), ("espanol", .es), ("castellano", .es), ("frances", .fr), ("aleman", .de),
    ("italiano", .it), ("portugues", .pt), ("japones", .ja), ("chino", .zh), ("coreano", .ko),
  ]

  /// Idioma pedido si la orden es traducir; nil si no lo es.
  public static func target(of command: String) -> TranslationLanguage? {
    let words = TextMetrics.fold(command).split(whereSeparator: { !$0.isLetter }).map(String.init)
    guard words.contains(where: { $0.hasPrefix("traduc") }) else { return nil }
    return languages.first { entry in words.contains(entry.word) }?.language
  }

  /// ¿Nombra algún idioma? ("hazlo en inglés"): entonces la edición puede cambiar de idioma.
  public static func mentionsLanguage(_ command: String) -> Bool {
    let words = TextMetrics.fold(command).split(whereSeparator: { !$0.isLetter }).map(String.init)
    return languages.contains { entry in words.contains(entry.word) }
  }

  /// Idioma de un texto, si es uno de los que se traducen.
  public static func language(of text: String) -> TranslationLanguage? {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    guard let code = recognizer.dominantLanguage?.rawValue else { return nil }
    return TranslationLanguage(rawValue: String(code.prefix(2)))
  }
}

/// Webs permitidas para las acciones de Ask Anything (no se abre ninguna otra).
public enum WebSite: String, CaseIterable, Codable, Sendable {
  case google, youtube, amazon, maps, wikipedia

  static let keywords: [String: WebSite] = [
    "google": .google, "youtube": .youtube, "amazon": .amazon,
    "maps": .maps, "mapa": .maps, "mapas": .maps, "wikipedia": .wikipedia, "wiki": .wikipedia,
  ]

  /// URL de búsqueda; la consulta va codificada.
  public func url(for query: String) -> URL {
    // Solo caracteres no reservados sin codificar (RFC 3986): el espacio pasa a %20.
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    let q = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    let text = switch self {
    case .google: "https://www.google.com/search?q=\(q)"
    case .youtube: "https://www.youtube.com/results?search_query=\(q)"
    case .amazon: "https://www.amazon.es/s?k=\(q)"
    case .maps: "https://www.google.com/maps/search/\(q)"
    case .wikipedia: "https://es.wikipedia.org/w/index.php?search=\(q)"
    }
    return URL(string: text)!
  }
}

/// Búsqueda que se abre en el navegador.
public struct WebAction: Codable, Equatable, Sendable {
  public var site: WebSite
  public var query: String

  public init(site: WebSite, query: String) {
    self.site = site
    self.query = query
  }

  public var url: URL { site.url(for: query) }

  /// Esquema para la respuesta JSON de Gemini: `{"sitio": "youtube", "consulta": "…"}`.
  public static let jsonSchema = """
    {"type": "object",
     "properties": {
       "sitio": {"type": "string", "enum": ["google", "youtube", "amazon", "maps", "wikipedia"]},
       "consulta": {"type": "string"}},
     "required": ["sitio", "consulta"]}
    """

  /// Lee la respuesta de Gemini; un sitio desconocido pasa a Google.
  public static func decode(_ data: Data) -> WebAction? {
    struct Reply: Decodable {
      let sitio: String
      let consulta: String
    }
    guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return nil }
    let query = reply.consulta.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return nil }
    return WebAction(site: WebSite(rawValue: reply.sitio.lowercased()) ?? .google, query: query)
  }
}

/// Respaldo sin IA: "busca vídeos de gatos en YouTube" → YouTube, "vídeos de gatos".
public enum WebActionParser {
  static let linkWords: Set<String> = ["en", "el", "la", "los", "las", "de"]

  public static func parse(_ text: String) -> WebAction {
    var words = text.split(whereSeparator: \.isWhitespace).map {
      String($0).trimmingCharacters(in: .punctuationCharacters)
    }.filter { !$0.isEmpty }
    let key = { (word: String) in TextMetrics.fold(word) }

    if let first = words.first, IntentClassifier.webVerbs.contains(key(first)) { words.removeFirst() }

    var site = WebSite.google
    if let i = words.firstIndex(where: { WebSite.keywords[key($0)] != nil }) {
      site = WebSite.keywords[key(words[i])]!
      var end = i + 1
      if site == .google, end < words.count, key(words[end]) == "maps" {  // "Google Maps"
        site = .maps
        end += 1
      }
      // "YouTube y pon …", "Amazon y busca …"
      if end < words.count, key(words[end]) == "y" {
        end += 1
        if end < words.count, IntentClassifier.webVerbs.contains(key(words[end])) { end += 1 }
      }
      // "… en el mapa", "en la Wikipedia"
      var start = i
      while start > 0, linkWords.contains(key(words[start - 1])) { start -= 1 }
      if start > 0, key(words[start]) != "en" { start = i }
      words.removeSubrange(start..<end)
    }
    return WebAction(site: site, query: words.joined(separator: " "))
  }
}
