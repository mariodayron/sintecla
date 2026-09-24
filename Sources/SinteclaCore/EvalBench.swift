import Foundation

/// Un caso del banco de calidad (`Resources/eval/*.json`).
public struct EvalSample: Decodable, Equatable, Sendable {
  public var entrada: String
  /// Deben aparecer (sin distinguir mayúsculas; vale dentro de otra palabra: «rápid»).
  public var requeridas: [String]
  /// No deben aparecer como palabra o frase completa.
  public var prohibidas: [String]
  /// Si es true, el resultado debe llevar «?».
  public var pregunta: Bool?
  /// Tono con el que se limpia; sin él, neutro.
  public var tono: Tone?

  public init(entrada: String, requeridas: [String], prohibidas: [String], pregunta: Bool? = nil, tono: Tone? = nil) {
    self.entrada = entrada
    self.requeridas = requeridas
    self.prohibidas = prohibidas
    self.pregunta = pregunta
    self.tono = tono
  }
}

/// Banco de calidad: lo comparten `sintecla-eval` (modelo de Apple) y `Sintecla --rewrite-bench` (Gemini).
public enum EvalBench {
  public static func load(_ path: String) throws -> [EvalSample] {
    try JSONDecoder().decode([EvalSample].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
  }

  /// Lo que falla del resultado: «falta «…»», «sobra «…»» o «falta «?»». Vacío si está bien.
  public static func problems(in text: String, for sample: EvalSample) -> [String] {
    var problems: [String] = []
    for word in sample.requeridas where text.range(of: word, options: .caseInsensitive) == nil {
      problems.append("falta «\(word)»")
    }
    for word in sample.prohibidas where containsWord(text, word) {
      problems.append("sobra «\(word)»")
    }
    if sample.pregunta == true && !text.contains("?") {
      problems.append("falta «?»")
    }
    return problems
  }

  /// Porcentaje de aciertos, redondeado hacia abajo.
  public static func percent(passed: Int, total: Int) -> Int {
    total == 0 ? 0 : passed * 100 / total
  }

  /// «Aciertos: 8/12 (66%) · mediana 0.70 s · máx 1.20 s».
  public static func summary(passed: Int, total: Int, latencies: [Double]) -> String {
    let sorted = latencies.sorted()
    let median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
    return String(format: "Aciertos: %d/%d (%d%%) · mediana %.2f s · máx %.2f s",
                  passed, total, percent(passed: passed, total: total), median, sorted.last ?? 0)
  }

  static func containsWord(_ text: String, _ word: String) -> Bool {
    let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: word) + "(?![\\p{L}\\p{N}])"
    return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
  }
}
