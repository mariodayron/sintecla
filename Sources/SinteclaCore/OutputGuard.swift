import Foundation

/// Rechaza salidas de la IA que inventan o cambian el sentido del dictado
/// (p. ej. responder "¿qué hora es?" en vez de limpiarla). Sirve para Apple y para Gemini.
public struct OutputGuard: Sendable {
  /// Máximo de palabras de contenido nuevas (que no estaban en la entrada).
  public var maxNovelRatio = 0.25
  /// Al ordenar se quitan repeticiones: la salida puede quedarse en un 30 % de la entrada.
  public var minLengthRatio = 0.3
  public var maxLengthRatio = 1.3
  /// Margen absoluto para textos muy cortos ("vale" → "Vale.").
  public var extraCharsAllowance = 5

  /// Palabras de saludo o despedida: si salen y no se dijeron, la IA se las ha inventado
  /// (Gemini las sacaba de «Mi estilo»). Plegadas con `TextMetrics.fold`.
  static let greetingWords: Set<String> = [
    "hola", "buenas", "buenos", "estimado", "estimada", "estimados", "estimadas", "querido", "querida",
    "saludo", "saludos", "abrazo", "abrazos", "besos", "atentamente", "cordialmente", "gracias",
  ]

  public init() {}

  public func accepts(input: String, output: String, allowedNewWords: Set<String> = []) -> Bool {
    let out = output.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !out.isEmpty else { return false }

    let inCount = Double(input.count)
    let outCount = Double(out.count)
    guard outCount >= inCount * minLengthRatio,
          outCount <= max(inCount * maxLengthRatio, inCount + Double(extraCharsAllowance)) else { return false }

    let known = Set(TextMetrics.contentWords(input))
      .union(allowedNewWords.flatMap { TextMetrics.contentWords($0) })
    let outWords = TextMetrics.contentWords(Self.withoutListMarkers(out))
    if !outWords.isEmpty {
      let novel = outWords.filter { !known.contains($0) }
      guard Double(novel.count) / Double(outWords.count) <= maxNovelRatio,
            !novel.contains(where: Self.greetingWords.contains) else { return false }
    }

    if TextMetrics.isQuestion(input) && !TextMetrics.isQuestion(out) { return false }
    return true
  }

  /// Quita las marcas de lista al principio de cada línea («- », «• », «1. », «2) »): no son palabras dichas.
  static func withoutListMarkers(_ text: String) -> String {
    text.replacingOccurrences(of: #"(?m)^[ \t]*(?:[-•*]|\d+[.)])[ \t]+"#, with: "", options: .regularExpression)
  }
}
