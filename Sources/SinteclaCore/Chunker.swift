import Foundation

/// Trocea textos largos para no pasarse del contexto del modelo de Apple (4.096 tokens).
public enum Chunker {
  /// Trozos de como mucho `maxChars`, cortando entre frases
  /// (o entre palabras si una sola frase no cabe).
  public static func split(_ text: String, maxChars: Int) -> [String] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return [] }
    if trimmed.count <= maxChars { return [trimmed] }

    var sentences: [String] = []
    trimmed.enumerateSubstrings(in: trimmed.startIndex..., options: .bySentences) { sub, _, _, _ in
      if let s = sub?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
        sentences.append(s)
      }
    }

    var chunks: [String] = []
    var current = ""
    for piece in sentences.flatMap({ splitByWords($0, maxChars: maxChars) }) {
      if current.isEmpty {
        current = piece
      } else if current.count + 1 + piece.count <= maxChars {
        current += " " + piece
      } else {
        chunks.append(current)
        current = piece
      }
    }
    if !current.isEmpty { chunks.append(current) }
    return chunks
  }

  static func splitByWords(_ sentence: String, maxChars: Int) -> [String] {
    guard sentence.count > maxChars else { return [sentence] }
    var parts: [String] = []
    var current = ""
    for word in sentence.split(separator: " ") {
      if current.isEmpty {
        current = String(word)
      } else if current.count + 1 + word.count <= maxChars {
        current += " " + word
      } else {
        parts.append(current)
        current = String(word)
      }
    }
    if !current.isEmpty { parts.append(current) }
    return parts
  }
}
