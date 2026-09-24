import Foundation

/// Palabra con su puntuación pegada: "¿Qué" → lead "¿", core "Qué"; "eh," → core "eh", trail ",".
struct Token: Equatable {
  var lead: String
  var core: String
  var trail: String

  static let leadChars: Set<Character> = ["¿", "¡", "(", "\"", "«", "'", "“"]
  static let trailChars: Set<Character> = [",", ".", ";", ":", "!", "?", "…", ")", "\"", "»", "'", "”"]

  init(lead: String = "", core: String, trail: String = "") {
    self.lead = lead
    self.core = core
    self.trail = trail
  }

  init(_ raw: String) {
    var chars = Array(raw)
    var lead = ""
    while chars.count > 1, let c = chars.first, Token.leadChars.contains(c) {
      lead.append(c)
      chars.removeFirst()
    }
    var trail = ""
    while chars.count > 1, let c = chars.last, Token.trailChars.contains(c) {
      trail.insert(c, at: trail.startIndex)
      chars.removeLast()
    }
    self.init(lead: lead, core: String(chars), trail: trail)
  }

  var text: String { lead + core + trail }
  var key: String { core.lowercased() }

  static func split(_ text: String) -> [Token] {
    text.split(whereSeparator: \.isWhitespace).map { Token(String($0)) }
  }

  static func join(_ tokens: [Token]) -> String {
    tokens.map(\.text).joined(separator: " ")
  }

  /// Quita `range` conservando los signos que importan: "¿"/"¡" iniciales
  /// pasan a la palabra siguiente y ".?!…" finales a la anterior.
  static func remove(_ tokens: inout [Token], range: Range<Int>) {
    guard !range.isEmpty else { return }
    let lead = tokens[range.lowerBound].lead.filter { "¿¡".contains($0) }
    let terminal = tokens[range.upperBound - 1].trail.filter { ".?!…".contains($0) }
    tokens.removeSubrange(range)
    let at = range.lowerBound
    if !lead.isEmpty, at < tokens.count, !tokens[at].lead.contains(where: { "¿¡".contains($0) }) {
      tokens[at].lead = lead + tokens[at].lead
    }
    if !terminal.isEmpty, at > 0, !tokens[at - 1].trail.contains(where: { ".?!…".contains($0) }) {
      tokens[at - 1].trail = tokens[at - 1].trail.filter { !",;:".contains($0) } + terminal
    }
  }
}
