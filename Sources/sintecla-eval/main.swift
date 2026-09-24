import Foundation
import SinteclaCore

// Banco de calidad: pasa cada frase por el flujo real y comprueba el resultado.
// Uso: swift run sintecla-eval [--traduccion] [ruta.json] [--verbose]
//   (por defecto)   dictado:    Resources/eval/dictado_es.json
//   --traduccion    traducción: Resources/eval/traduccion_es.json (español → inglés)

struct Sample: Decodable {
  let entrada: String
  let requeridas: [String]
  let prohibidas: [String]
  let pregunta: Bool?
}

func containsWord(_ text: String, _ word: String) -> Bool {
  let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: word) + "(?![\\p{L}\\p{N}])"
  return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}

let args = CommandLine.arguments.dropFirst()
let verbose = args.contains("--verbose")
let translation = args.contains("--traduccion")
let defaultPath = translation ? "Resources/eval/traduccion_es.json" : "Resources/eval/dictado_es.json"
let path = args.first(where: { !$0.hasPrefix("--") }) ?? defaultPath
let samples = try JSONDecoder().decode([Sample].self, from: Data(contentsOf: URL(fileURLWithPath: path)))

let model: TextModel? = AppleTextModel.isAvailable ? AppleTextModel() : nil
if model == nil { print("⚠️  Apple Intelligence no disponible: solo reglas.") }
let dictionary = PersonalDictionary(terms: ["Brisenta", "Supabase"])
let cleaner = DictationCleaner(model: model, dictionary: dictionary, isKnownWord: { SpellChecker.isKnownWord($0) })
let translator = TranslationPipeline(cleaner: cleaner, primary: AppleTranslator(), fallback: nil)

var passed = 0
var latencies: [Double] = []
for sample in samples {
  let start = Date()
  let (text, engine): (String, String)
  if translation {
    let result = await translator.run(sample.entrada, source: .es, target: .en, tone: .neutral)
    (text, engine) = (result.text, result.engine.rawValue)
  } else {
    let result = await cleaner.clean(sample.entrada, tone: .neutral)
    (text, engine) = (result.text, result.engine.rawValue)
  }
  latencies.append(Date().timeIntervalSince(start))
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
  if problems.isEmpty { passed += 1 }
  if verbose || !problems.isEmpty {
    print("\(problems.isEmpty ? "✔" : "✘") [\(engine)] \(sample.entrada)\n    → \(text)")
    if !problems.isEmpty { print("    " + problems.joined(separator: ", ")) }
  }
}

let sorted = latencies.sorted()
let median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
let percent = samples.isEmpty ? 0 : passed * 100 / samples.count
print(String(format: "\nAciertos: %d/%d (%d%%) · mediana %.2f s · máx %.2f s",
             passed, samples.count, percent, median, sorted.last ?? 0))
exit(percent >= 90 ? 0 : 1)
