import Foundation
import SinteclaCore

// Banco de calidad: pasa cada frase por el flujo real, con el modelo de Apple, y comprueba el resultado.
// Uso: swift run sintecla-eval [--traduccion | --ordenar] [ruta.json] [--verbose]
//   (por defecto)   dictado:    Resources/eval/dictado_es.json      (aprueba con el 90 %)
//   --traduccion    traducción: Resources/eval/traduccion_es.json   (español → inglés; aprueba con el 90 %)
//   --ordenar       ordenar:    Resources/eval/ordenar_es.json      (repeticiones; aprueba con 8 de 12)
// El mismo banco de ordenar con Gemini: `Sintecla --rewrite-bench` (necesita la clave).

let args = CommandLine.arguments.dropFirst()
let verbose = args.contains("--verbose")
let translation = args.contains("--traduccion")
let ordering = args.contains("--ordenar")
let defaultPath = translation ? "Resources/eval/traduccion_es.json"
  : ordering ? "Resources/eval/ordenar_es.json" : "Resources/eval/dictado_es.json"
let path = args.first(where: { !$0.hasPrefix("--") }) ?? defaultPath
let samples = try EvalBench.load(path)

let model: TextModel? = AppleTextModel.isAvailable ? AppleTextModel() : nil
if model == nil { print("⚠️  Apple Intelligence no disponible: solo reglas.") }
let dictionary = PersonalDictionary(terms: ["Brisenta", "Supabase"])
let cleaner = DictationCleaner(model: model, dictionary: dictionary, isKnownWord: { SpellChecker.isKnownWord($0) })
let translator = TranslationPipeline(cleaner: cleaner, primary: AppleTranslator(), fallback: nil)

var passed = 0
var latencies: [Double] = []
for sample in samples {
  let start = Date()
  let tone = sample.tono ?? .neutral
  let (text, engine): (String, String)
  if translation {
    let result = await translator.run(sample.entrada, source: .es, target: .en, tone: tone)
    (text, engine) = (result.text, result.engine.rawValue)
  } else {
    let result = await cleaner.clean(sample.entrada, tone: tone)
    (text, engine) = (result.text, result.engine.rawValue)
  }
  latencies.append(Date().timeIntervalSince(start))
  let problems = EvalBench.problems(in: text, for: sample)
  if problems.isEmpty { passed += 1 }
  if verbose || !problems.isEmpty {
    print("\(problems.isEmpty ? "✔" : "✘") [\(engine)] \(sample.entrada)\n    → \(text)")
    if !problems.isEmpty { print("    " + problems.joined(separator: ", ")) }
  }
}

print("\n" + EvalBench.summary(passed: passed, total: samples.count, latencies: latencies))
exit(EvalBench.percent(passed: passed, total: samples.count) >= (ordering ? 66 : 90) ? 0 : 1)
