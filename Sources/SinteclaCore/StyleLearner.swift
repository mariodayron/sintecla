import Foundation

/// "Mi estilo" a partir de los dictados del historial, con Gemini.
public enum StyleLearner {
  public static let minimumDictations = 20
  public static let minimumWords = 4
  public static let maxCharacters = 15_000
  public static let maxLength = 400

  public struct Proposal: Equatable, Sendable {
    public var style: String
    /// Dictados enviados.
    public var used: Int
  }

  public enum Failure: Error, Equatable {
    case notEnough(Int)

    public var message: String {
      switch self {
      case .notEnough(let count): "Aún hay pocos dictados (\(count)): vuelve cuando tengas \(StyleLearner.minimumDictations)"
      }
    }
  }

  /// Solo dictados (lo demás no lo escribe el usuario) de 4 palabras o más, de los más recientes a los más antiguos,
  /// hasta 15.000 caracteres.
  public static func sample(_ entries: [HistoryEntry]) -> [HistoryEntry] {
    var picked: [HistoryEntry] = []
    var total = 0
    for entry in entries.sorted(by: { $0.date > $1.date }) where entry.mode == .dictation && entry.words >= minimumWords {
      let length = line(entry).count
      if total + length > maxCharacters { break }
      picked.append(entry)
      total += length
    }
    return picked
  }

  /// Una línea por dictado: "[App] texto".
  public static func promptText(_ entries: [HistoryEntry]) -> String {
    entries.map(line).joined(separator: "\n")
  }

  static func line(_ entry: HistoryEntry) -> String {
    "[\(entry.appName ?? "Otra app")] " + entry.finalText.replacingOccurrences(of: "\n", with: " ")
  }

  public static func learn(from entries: [HistoryEntry], currentStyle: String, model: StructuredModel) async throws -> Proposal {
    let picked = sample(entries)
    guard picked.count >= minimumDictations else { throw Failure.notEnough(picked.count) }
    let data = try await model.completeJSON(instructions: PromptLibrary.styleInstructions,
                                            prompt: PromptLibrary.stylePrompt(promptText(picked), current: currentStyle),
                                            schemaName: "estilo", schema: jsonSchema)
    struct Reply: Decodable { let estilo: String }
    guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else { throw CloudError.invalidResponse }
    let style = trim(reply.estilo)
    guard !style.isEmpty else { throw CloudError.invalidResponse }
    return Proposal(style: style, used: picked.count)
  }

  /// Sin espacios alrededor y, si pasa de 400 caracteres, cortado en la última frase completa.
  public static func trim(_ text: String) -> String {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.count > maxLength else { return text }
    let head = String(text.prefix(maxLength))
    guard let end = head.range(of: ".", options: .backwards) else { return head }
    return String(head[..<end.upperBound])
  }

  public static let jsonSchema = #"{"type": "object", "properties": {"estilo": {"type": "string"}}, "required": ["estilo"]}"#
}
