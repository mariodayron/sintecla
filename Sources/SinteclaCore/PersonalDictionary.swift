import Foundation

/// Reemplazo exacto: "bri senta" → "Brisenta".
public struct DictionaryRule: Codable, Hashable, Sendable {
  public var from: String
  public var to: String
  /// Aprendida de una corrección (no escrita a mano).
  public var learned: Bool

  public init(from: String, to: String, learned: Bool = false) {
    self.from = from
    self.to = to
    self.learned = learned
  }

  enum CodingKeys: String, CodingKey { case from, to, learned }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    from = try c.decode(String.self, forKey: .from)
    to = try c.decode(String.self, forKey: .to)
    learned = try c.decodeIfPresent(Bool.self, forKey: .learned) ?? false
  }
}

/// Diccionario personal: términos (para corrección aproximada) y reglas exactas.
public struct PersonalDictionary: Codable, Equatable, Sendable {
  public var terms: [String]
  public var rules: [DictionaryRule]
  /// Términos que se aprendieron solos (llevan la etiqueta "aprendido").
  public var learnedTerms: [String]
  /// Correcciones de palabras reales vistas una sola vez: la regla llega a la segunda.
  public var candidates: [LearnedCandidate]

  /// Distancia máxima (0…1) para cambiar una palabra inexistente por un término.
  public static let fuzzyThreshold = 0.4
  /// Más estricto al unir dos palabras ("bri senta" → "Brisenta").
  public static let joinThreshold = 0.25

  public init(terms: [String] = [], rules: [DictionaryRule] = [], learnedTerms: [String] = [],
              candidates: [LearnedCandidate] = []) {
    self.terms = terms
    self.rules = rules
    self.learnedTerms = learnedTerms
    self.candidates = candidates
  }

  enum CodingKeys: String, CodingKey { case terms, rules, learnedTerms, candidates }

  /// Los diccionarios anteriores a la F4a no tienen `learnedTerms` ni `candidates`.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    terms = try c.decode([String].self, forKey: .terms)
    rules = try c.decode([DictionaryRule].self, forKey: .rules)
    learnedTerms = try c.decodeIfPresent([String].self, forKey: .learnedTerms) ?? []
    candidates = try c.decodeIfPresent([LearnedCandidate].self, forKey: .candidates) ?? []
  }

  /// Reemplazos exactos: sin distinguir mayúsculas, por palabra completa, los más largos primero.
  public func applyRules(to text: String) -> String {
    var result = text
    for rule in rules.sorted(by: { $0.from.count > $1.from.count }) where !rule.from.isEmpty {
      let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: rule.from) + "(?![\\p{L}\\p{N}])"
      guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
      result = regex.stringByReplacingMatches(
        in: result, range: NSRange(result.startIndex..., in: result),
        withTemplate: NSRegularExpression.escapedTemplate(for: rule.to))
    }
    return result
  }

  /// Cambia palabras que NO existen y se parecen a un término ("brosanta" → "Brisenta",
  /// "supabeis" → "Supabase"). Nunca toca palabras reales ("brisa" se queda).
  public func fuzzyFix(_ text: String, isKnownWord: (String) -> Bool) -> String {
    let candidates = terms.filter { !$0.contains(" ") && $0.count >= 4 }
    guard !candidates.isEmpty else { return text }
    var tokens = Token.split(text)
    var i = 0
    while i < tokens.count {
      if i + 1 < tokens.count, tokens[i].trail.isEmpty,
         let term = bestMatch(for: tokens[i].core + tokens[i + 1].core, in: candidates, threshold: Self.joinThreshold),
         !isKnownWord(tokens[i].core) || !isKnownWord(tokens[i + 1].core) {
        tokens[i] = Token(lead: tokens[i].lead, core: term, trail: tokens[i + 1].trail)
        tokens.remove(at: i + 1)
      } else if tokens[i].core.count >= 4, tokens[i].core.allSatisfy(\.isLetter), !isKnownWord(tokens[i].core),
                let term = bestMatch(for: tokens[i].core, in: candidates, threshold: Self.fuzzyThreshold) {
        tokens[i].core = term
      }
      i += 1
    }
    return Token.join(tokens)
  }

  /// Devuelve a cada término su grafía exacta cuando la IA le cambia tildes o
  /// mayúsculas ("Brisentá" → "Brisenta", "supabase" → "Supabase"). Respeta saltos de línea.
  public func restoreTerms(_ text: String) -> String {
    let byFold = Dictionary(terms.filter { !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber } }
                              .map { (TextMetrics.fold($0), $0) },
                            uniquingKeysWith: { first, _ in first })
    guard !byFold.isEmpty else { return text }
    let ns = text as NSString
    var result = ""
    var last = 0
    for match in Self.wordRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
      result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
      let word = ns.substring(with: match.range)
      result += byFold[TextMetrics.fold(word)] ?? word
      last = match.range.location + match.range.length
    }
    return result + ns.substring(from: last)
  }

  static let wordRegex = try! NSRegularExpression(pattern: "[\\p{L}\\p{N}]+")

  func bestMatch(for word: String, in candidates: [String], threshold: Double) -> String? {
    var best: (term: String, distance: Double)?
    for term in candidates {
      let d = Self.normalizedDistance(word, term)
      if d <= threshold, d < (best?.distance ?? .infinity) { best = (term, d) }
    }
    return best?.term
  }

  /// Distancia de edición normalizada (0 = iguales, 1 = nada en común), sin tildes ni mayúsculas.
  public static func normalizedDistance(_ a: String, _ b: String) -> Double {
    let x = Array(TextMetrics.fold(a)), y = Array(TextMetrics.fold(b))
    if x.isEmpty && y.isEmpty { return 0 }
    if x.isEmpty || y.isEmpty { return 1 }
    var previous = Array(0...y.count)
    for i in 1...x.count {
      var current = [i] + Array(repeating: 0, count: y.count)
      for j in 1...y.count {
        current[j] = x[i - 1] == y[j - 1]
          ? previous[j - 1]
          : 1 + min(previous[j - 1], previous[j], current[j - 1])
      }
      previous = current
    }
    return Double(previous[y.count]) / Double(max(x.count, y.count))
  }
}
