import Foundation

/// Corrección de una palabra real ("brisa" → "Brisenta") vista `count` veces.
public struct LearnedCandidate: Codable, Equatable, Sendable {
  public var from: String
  public var to: String
  public var count: Int

  public init(from: String, to: String, count: Int) {
    self.from = from
    self.to = to
    self.count = count
  }
}

/// Lo que se aprendió de una corrección (para el aviso de la pastilla).
public struct LearnResult: Equatable, Sendable {
  public var term: String?
  public var rule: DictionaryRule?

  public init(term: String? = nil, rule: DictionaryRule? = nil) {
    self.term = term
    self.rule = rule
  }

  /// nil si no se aprendió nada.
  public var notice: String? {
    if let rule { return "Aprendido: \(rule.from) → \(rule.to)" }
    if let term { return "Aprendido: \(term)" }
    return nil
  }
}

extension PersonalDictionary {
  /// Aprende de una corrección. Término: lo corregido, si no es una palabra corriente o empieza por mayúscula.
  /// Regla: ya, si algo de lo dictado no es una palabra real; si todo lo es ("brisa"), a la segunda vez.
  public mutating func learn(_ correction: Correction, isKnownWord: (String) -> Bool) -> LearnResult {
    let from = correction.dictated.lowercased()
    let to = correction.corrected
    guard applyRules(to: from) != to else { return LearnResult() }
    var result = LearnResult()
    let words = to.split(separator: " ").map(String.init)
    if !terms.contains(where: { TextMetrics.fold($0) == TextMetrics.fold(to) }),
       to.first?.isUppercase == true || words.contains(where: { !isKnownWord($0) }) {
      terms.append(to)
      learnedTerms.append(to)
      result.term = to
    }
    let rule = DictionaryRule(from: from, to: to, learned: true)
    if from.split(separator: " ").contains(where: { !isKnownWord(String($0)) }) {
      setRule(rule)
      result.rule = rule
    } else if let i = candidates.firstIndex(where: { TextMetrics.fold($0.from) == TextMetrics.fold(from) }) {
      if candidates[i].to == to {
        candidates.remove(at: i)
        setRule(rule)
        result.rule = rule
      } else {
        candidates[i].to = to
        candidates[i].count = 1
      }
    } else {
      candidates.append(LearnedCandidate(from: from, to: to, count: 1))
    }
    return result
  }

  /// Una regla nueva sustituye a la que tenía el mismo origen: la última corrección manda.
  mutating func setRule(_ rule: DictionaryRule) {
    rules.removeAll { TextMetrics.fold($0.from) == TextMetrics.fold(rule.from) }
    rules.append(rule)
  }

  public mutating func remove(rule: DictionaryRule) {
    rules.removeAll { $0 == rule }
    candidates.removeAll { TextMetrics.fold($0.from) == TextMetrics.fold(rule.from) }
  }

  public mutating func remove(term: String) {
    terms.removeAll { $0 == term }
    learnedTerms.removeAll { $0 == term }
  }

  public enum ManualAdd: Equatable, Sendable {
    case added(String), alreadyThere(String), invalid

    public var message: String {
      switch self {
      case .added(let term): "Añadido al diccionario: \(term)"
      case .alreadyThere(let term): "Ya estaba en el diccionario: \(term)"
      case .invalid: "Selecciona una palabra o un nombre corto"
      }
    }

    /// Solo `.invalid` es un error; lo demás es un aviso normal.
    public var isError: Bool { self == .invalid }
  }

  /// "Añádelo al diccionario": la selección como término, si es corta (hasta 3 palabras y 40 caracteres).
  public mutating func addTerm(fromSelection text: String) -> ManualAdd {
    let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols))
    let words = trimmed.split(whereSeparator: \.isWhitespace)
    let term = words.joined(separator: " ")
    guard !term.isEmpty, words.count <= 3, term.count <= 40 else { return .invalid }
    if let existing = terms.first(where: { TextMetrics.fold($0) == TextMetrics.fold(term) }) { return .alreadyThere(existing) }
    terms.append(term)
    return .added(term)
  }
}

/// Ask Anything: "añádelo al diccionario", "guárdalo en el diccionario"…
public enum DictionaryCommand {
  public static let noSelection = "Selecciona antes la palabra bien escrita"
  static let verbs = ["anad", "agreg", "guard", "met", "inclu", "apunt", "pon"]

  public static func matches(_ command: String) -> Bool {
    let words = TextMetrics.fold(command).split(whereSeparator: { !$0.isLetter }).map(String.init)
    guard words.contains("diccionario") else { return false }
    return words.contains { word in verbs.contains { word.hasPrefix($0) } }
  }
}
