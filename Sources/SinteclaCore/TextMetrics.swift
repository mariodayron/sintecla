import Foundation

/// Utilidades de texto compartidas por el filtro, el historial y los respaldos.
public enum TextMetrics {
  static let stopwords: Set<String> = [
    "el", "la", "los", "las", "un", "una", "unos", "unas", "de", "del", "a", "al", "y", "e", "o", "u",
    "que", "en", "es", "por", "para", "con", "se", "lo", "le", "les", "me", "te", "nos", "su", "sus",
    "mi", "mis", "tu", "tus", "no", "si", "ya", "muy", "mas", "pero",
  ]
  static let interrogatives: Set<String> = [
    "qué", "cómo", "cuál", "cuáles", "cuándo", "dónde", "adónde", "quién", "quiénes",
    "cuánto", "cuánta", "cuántos", "cuántas",
  ]

  /// Minúsculas y sin tildes: "Reunión" → "reunion".
  public static func fold(_ text: String) -> String {
    text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
  }

  /// Palabras con contenido (sin artículos, preposiciones…), plegadas con `fold`.
  public static func contentWords(_ text: String) -> [String] {
    fold(text)
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty && !stopwords.contains($0) }
  }

  /// ¿Es una pregunta? Tiene "?" o empieza por un interrogativo con tilde.
  public static func isQuestion(_ text: String) -> Bool {
    if text.contains("?") { return true }
    let words = text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
    guard let first = words.first else { return false }
    if first == "por", words.count > 1, words[1] == "qué" { return true }
    return interrogatives.contains(first)
  }

  public static func wordCount(_ text: String) -> Int {
    text.split(whereSeparator: \.isWhitespace).count
  }

  /// Para textos que no pasan por la IA: mayúscula inicial y cierre
  /// ("¿…?" si es pregunta, "." si no).
  public static func finalize(_ text: String) -> String {
    var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return s }
    if isQuestion(s) && !s.contains("?") {
      s = (s.hasPrefix("¿") ? s : "¿" + s) + "?"
    }
    if let i = s.firstIndex(where: \.isLetter) {
      s.replaceSubrange(i...i, with: String(s[i]).uppercased())
    }
    if let last = s.last, !".?!…:".contains(last) {
      s += "."
    }
    return s
  }
}
