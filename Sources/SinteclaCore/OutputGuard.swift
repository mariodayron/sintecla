import Foundation

/// Rechaza salidas de la IA que inventan o cambian el sentido del dictado
/// (p. ej. responder "¿qué hora es?" en vez de limpiarla).
public struct OutputGuard: Sendable {
  /// Máximo de palabras de contenido nuevas (que no estaban en la entrada).
  public var maxNovelRatio = 0.15
  public var minLengthRatio = 0.5
  public var maxLengthRatio = 1.3
  /// Margen absoluto para textos muy cortos ("vale" → "Vale.").
  public var extraCharsAllowance = 5

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
    let outWords = TextMetrics.contentWords(out)
    if !outWords.isEmpty {
      let novel = outWords.filter { !known.contains($0) }.count
      guard Double(novel) / Double(outWords.count) <= maxNovelRatio else { return false }
    }

    if TextMetrics.isQuestion(input) && !TextMetrics.isQuestion(out) { return false }
    return true
  }
}
