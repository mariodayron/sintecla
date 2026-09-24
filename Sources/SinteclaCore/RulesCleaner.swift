import Foundation

/// Limpieza determinista antes de la IA: muletillas, relleno inicial,
/// repeticiones y autocorrecciones ("a las cinco, no, perdón, a las seis").
public struct RulesCleaner: Sendable {
  public init() {}

  /// Muletillas puras: se borran siempre ("eh", "ehhh", "em", "mmm", "hmm"…).
  static let fillerRegex = try! NSRegularExpression(pattern: "^(e+h+|e+m+|e+h+m+|m{2,}|h+m+|a+h+|u+h+|u+m+)$")
  /// Relleno que solo se borra al principio del dictado (y nunca si es lo único que hay).
  static let leadingFillers: [[String]] = [["o", "sea"], ["bueno"], ["vale"], ["pues"]]
  /// Marcadores de autocorrección. `strong`: se aplica aunque no aparezca el ancla.
  static let markers: [(words: [String], strong: Bool)] = [
    (["no", "perdón"], true),
    (["mejor", "dicho"], true),
    (["no", "espera"], false),
    (["quiero", "decir"], false),
    (["o", "mejor"], false),
  ]
  /// Anclas demasiado comunes: con marcadores débiles exigen que coincidan dos palabras.
  static let genericAnchors: Set<String> = [
    "a", "al", "de", "del", "en", "y", "o", "que", "el", "la", "los", "las", "un", "una", "por", "con", "para",
  ]
  static let maxLookBack = 6

  public func clean(_ text: String) -> String {
    var tokens = Token.split(text)
    removeFillers(&tokens)
    removeLeadingFillers(&tokens)
    collapseRepeats(&tokens)
    applyCorrections(&tokens)
    return Self.tidy(Token.join(tokens))
  }

  func isFiller(_ key: String) -> Bool {
    Self.fillerRegex.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)) != nil
  }

  func removeFillers(_ tokens: inout [Token]) {
    var i = 0
    while i < tokens.count {
      if isFiller(tokens[i].key) {
        Token.remove(&tokens, range: i..<(i + 1))
      } else if tokens[i].key == "en", i + 1 < tokens.count, tokens[i + 1].key == "plan" {
        Token.remove(&tokens, range: i..<(i + 2))
      } else {
        i += 1
      }
    }
  }

  func removeLeadingFillers(_ tokens: inout [Token]) {
    var changed = true
    while changed {
      changed = false
      for filler in Self.leadingFillers where tokens.count > filler.count {
        if tokens.prefix(filler.count).map(\.key) == filler {
          Token.remove(&tokens, range: 0..<filler.count)
          changed = true
          break
        }
      }
    }
  }

  /// "con con" → "con"; "el precio, el precio" → "el precio" (se borra la primera aparición).
  func collapseRepeats(_ tokens: inout [Token]) {
    for n in [3, 2, 1] {
      var i = 0
      while i + 2 * n <= tokens.count {
        if tokens[i..<(i + n)].map(\.key) == tokens[(i + n)..<(i + 2 * n)].map(\.key) {
          Token.remove(&tokens, range: i..<(i + n))
        } else {
          i += 1
        }
      }
    }
  }

  /// En "X <marcador> Y": la primera palabra de Y es el ancla; se busca hacia atrás
  /// y se borra desde ahí hasta el final del marcador.
  func applyCorrections(_ tokens: inout [Token]) {
    var changed = true
    while changed {
      changed = false
      search: for i in tokens.indices {
        for marker in Self.markers {
          let n = marker.words.count
          guard i > 0, i + n < tokens.count, tokens[i..<(i + n)].map(\.key) == marker.words else { continue }
          let yStart = i + n
          let anchor = tokens[yStart].key
          var start: Int?
          for j in stride(from: i - 1, through: max(0, i - Self.maxLookBack), by: -1) where tokens[j].key == anchor {
            if !marker.strong && Self.genericAnchors.contains(anchor) {
              guard yStart + 1 < tokens.count, j + 1 < i, tokens[j + 1].key == tokens[yStart + 1].key else { continue }
            }
            start = j
            break
          }
          if start == nil && marker.strong { start = i - 1 }
          guard let s = start else { continue }
          Token.remove(&tokens, range: s..<yStart)
          changed = true
          break search
        }
      }
    }
  }

  static func tidy(_ text: String) -> String {
    var s = text.replacingOccurrences(of: #"\s+([,.;:!?…])"#, with: "$1", options: .regularExpression)
    s = s.replacingOccurrences(of: #",{2,}"#, with: ",", options: .regularExpression)
    s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
    s = s.trimmingCharacters(in: .whitespacesAndNewlines)
    while let first = s.first, ",;:".contains(first) {
      s.removeFirst()
      s = s.trimmingCharacters(in: .whitespaces)
    }
    return s
  }
}
