import Foundation
import Testing
@testable import SinteclaCore

@Suite struct EvalBenchTests {
  @Test func findsMissingAndForbiddenWords() {
    let sample = EvalSample(entrada: "", requeridas: ["informe de ventas", "rápid"], prohibidas: ["eh", "o sea"])
    #expect(EvalBench.problems(in: "El informe de ventas va más rápido.", for: sample).isEmpty)
    #expect(EvalBench.problems(in: "Eh, o sea, el informe.", for: sample)
            == ["falta «informe de ventas»", "falta «rápid»", "sobra «eh»", "sobra «o sea»"])
  }

  @Test func forbiddenWordsMustBeWholeWords() {
    let sample = EvalSample(entrada: "", requeridas: [], prohibidas: ["eh"])
    #expect(EvalBench.problems(in: "Lo he hecho.", for: sample).isEmpty)
  }

  @Test func questionsNeedAQuestionMark() {
    let sample = EvalSample(entrada: "", requeridas: [], prohibidas: [], pregunta: true)
    #expect(EvalBench.problems(in: "Sabes si hay reunión.", for: sample) == ["falta «?»"])
    #expect(EvalBench.problems(in: "¿Sabes si hay reunión?", for: sample).isEmpty)
  }

  @Test func decodesTheToneAndSummarizes() throws {
    let json = #"[{"entrada": "hola", "requeridas": ["Hola"], "prohibidas": [], "tono": "formal"}]"#
    let samples = try JSONDecoder().decode([EvalSample].self, from: Data(json.utf8))
    #expect(samples == [EvalSample(entrada: "hola", requeridas: ["Hola"], prohibidas: [], tono: .formal)])
    #expect(EvalBench.percent(passed: 8, total: 12) == 66)
    #expect(EvalBench.summary(passed: 8, total: 12, latencies: [1.2, 0.5, 0.7])
            == "Aciertos: 8/12 (66%) · mediana 0.70 s · máx 1.20 s")
  }
}
