import Foundation
import Testing
@testable import SinteclaCore

@Suite struct CorrectionLearnerTests {
  @Test func findsSingleWordCorrection() {
    #expect(CorrectionLearner.corrections(pasted: "Mañana me reúno con brisa en la oficina.",
                                          field: "Mañana me reúno con Brisenta en la oficina.")
            == [Correction(dictated: "brisa", corrected: "Brisenta")])
  }

  @Test func findsJoinedWords() {
    #expect(CorrectionLearner.corrections(pasted: "El informe de bri senta está listo.", field: "El informe de Brisenta está listo.")
            == [Correction(dictated: "bri senta", corrected: "Brisenta")])
  }

  @Test func findsCorrectionInsideALongerField() {
    let field = "Hola Marta:\n\nTe escribo por lo de ayer. El presupuesto de Brisenta llega el lunes.\n\nUn saludo"
    #expect(CorrectionLearner.corrections(pasted: "El presupuesto de brosanta llega el lunes.", field: field)
            == [Correction(dictated: "brosanta", corrected: "Brisenta")])
  }

  @Test func ignoresRewrites() {
    #expect(CorrectionLearner.corrections(pasted: "Nos vemos mañana a las cinco.", field: "Quedamos el lunes por la tarde.").isEmpty)
    #expect(CorrectionLearner.corrections(pasted: "llamo a Juan mañana", field: "escribo a Pedro mañana").isEmpty)
  }

  @Test func ignoresCaseAccentsAndDissimilarChanges() {
    #expect(CorrectionLearner.corrections(pasted: "Vamos a madrid el martes que viene", field: "Vamos a Madrid el martes que viene").isEmpty)
    #expect(CorrectionLearner.corrections(pasted: "No se que hora es ahora mismo", field: "No sé qué hora es ahora mismo").isEmpty)
    #expect(CorrectionLearner.corrections(pasted: "Nos vemos mañana en la oficina", field: "Nos vemos el lunes en la oficina").isEmpty)
  }

  @Test func ignoresNumbersAndShortWords() {
    #expect(CorrectionLearner.corrections(pasted: "Son veinte euros por persona", field: "Son 20 euros por persona").isEmpty)
    #expect(CorrectionLearner.corrections(pasted: "Voy a la tienda con ella", field: "Voy a la tienda con él").isEmpty)
  }

  @Test func ignoresInsertionsAndDeletions() {
    #expect(CorrectionLearner.corrections(pasted: "Te llamo mañana por la tarde", field: "Te llamo mañana por la tarde sin falta").isEmpty)
    #expect(CorrectionLearner.corrections(pasted: "Te llamo mañana por la tarde", field: "Te llamo por la tarde").isEmpty)
  }

  @Test func knowsWhenThePastedTextIsGone() {
    #expect(!CorrectionLearner.contains("Te llamo mañana por la tarde", in: ""))
    #expect(!CorrectionLearner.contains("Te llamo mañana por la tarde", in: "Otro mensaje distinto"))
    #expect(CorrectionLearner.contains("Te llamo mañana por la tarde", in: "Hola. Te llamo mañana por la tarde con Brisenta."))
    #expect(CorrectionLearner.corrections(pasted: "Te llamo mañana por la tarde", field: "").isEmpty)
  }

  @Test func soundKeyMergesSpanishSpellings() {
    #expect(CorrectionLearner.soundKey("Vaca") == CorrectionLearner.soundKey("baca"))
    #expect(CorrectionLearner.soundKey("cena") == CorrectionLearner.soundKey("zena"))
    #expect(CorrectionLearner.soundKey("calle") == CorrectionLearner.soundKey("caye"))
    #expect(CorrectionLearner.soundKey("hola") == "ola")
    #expect(CorrectionLearner.soundKey("queso") == "keso")
    #expect(CorrectionLearner.soundKey("gente") == "jente")
    #expect(CorrectionLearner.soundKey("coche") == "coche")
  }
}

@Suite struct DictionaryLearningTests {
  let known: (String) -> Bool = { ["brisa", "vaca", "baca", "manana", "de", "senta"].contains(TextMetrics.fold($0)) }

  @Test func unknownDictatedWordLearnsTermAndRuleAtOnce() {
    var dict = PersonalDictionary()
    let result = dict.learn(Correction(dictated: "brosanta", corrected: "Brisenta"), isKnownWord: known)
    #expect(result == LearnResult(term: "Brisenta", rule: DictionaryRule(from: "brosanta", to: "Brisenta", learned: true)))
    #expect(result.notice == "Aprendido: brosanta → Brisenta")
    #expect(dict.terms == ["Brisenta"])
    #expect(dict.learnedTerms == ["Brisenta"])
    #expect(dict.rules == [DictionaryRule(from: "brosanta", to: "Brisenta", learned: true)])
  }

  @Test func realDictatedWordNeedsASecondCorrection() {
    var dict = PersonalDictionary()
    let first = dict.learn(Correction(dictated: "brisa", corrected: "Brisenta"), isKnownWord: known)
    #expect(first == LearnResult(term: "Brisenta"))
    #expect(first.notice == "Aprendido: Brisenta")
    #expect(dict.rules.isEmpty)
    #expect(dict.candidates == [LearnedCandidate(from: "brisa", to: "Brisenta", count: 1)])
    let second = dict.learn(Correction(dictated: "Brisa", corrected: "Brisenta"), isKnownWord: known)
    #expect(second == LearnResult(rule: DictionaryRule(from: "brisa", to: "Brisenta", learned: true)))
    #expect(second.notice == "Aprendido: brisa → Brisenta")
    #expect(dict.candidates.isEmpty)
  }

  @Test func commonLowercaseWordIsNotATerm() {
    var dict = PersonalDictionary()
    let result = dict.learn(Correction(dictated: "vaca", corrected: "baca"), isKnownWord: known)
    #expect(result == LearnResult())
    #expect(result.notice == nil)
    #expect(dict.terms.isEmpty)
    #expect(dict.candidates == [LearnedCandidate(from: "vaca", to: "baca", count: 1)])
  }

  @Test func joinedWordsWithAnUnknownPartLearnTheRuleAtOnce() {
    var dict = PersonalDictionary()
    let result = dict.learn(Correction(dictated: "bri senta", corrected: "Brisenta"), isKnownWord: known)
    #expect(result.rule == DictionaryRule(from: "bri senta", to: "Brisenta", learned: true))
  }

  @Test func newTargetReplacesTheRuleAndKnownCorrectionsAreSilent() {
    var dict = PersonalDictionary(terms: ["Brisenta"], rules: [DictionaryRule(from: "brosanta", to: "Brisenta")])
    #expect(dict.learn(Correction(dictated: "brosanta", corrected: "Brisenta"), isKnownWord: known) == LearnResult())
    let changed = dict.learn(Correction(dictated: "brosanta", corrected: "Proinsta"), isKnownWord: known)
    #expect(changed.rule == DictionaryRule(from: "brosanta", to: "Proinsta", learned: true))
    #expect(dict.rules == [DictionaryRule(from: "brosanta", to: "Proinsta", learned: true)])
  }

  @Test func removingForgetsLearnedMarksAndCandidates() {
    var dict = PersonalDictionary(terms: ["Brisenta"], rules: [DictionaryRule(from: "brisa", to: "Brisenta", learned: true)],
                                  learnedTerms: ["Brisenta"], candidates: [LearnedCandidate(from: "brisa", to: "Brisa", count: 1)])
    dict.remove(rule: DictionaryRule(from: "brisa", to: "Brisenta", learned: true))
    #expect(dict.rules.isEmpty && dict.candidates.isEmpty)
    dict.remove(term: "Brisenta")
    #expect(dict.terms.isEmpty && dict.learnedTerms.isEmpty)
  }

  @Test func readsOldDictionaryFiles() throws {
    let old = #"{"terms": ["Supabase"], "rules": [{"from": "bri senta", "to": "Brisenta"}]}"#
    let dict = try JSONDecoder().decode(PersonalDictionary.self, from: Data(old.utf8))
    #expect(dict.rules == [DictionaryRule(from: "bri senta", to: "Brisenta")])
    #expect(dict.learnedTerms.isEmpty && dict.candidates.isEmpty)
  }

  @Test func manualAddAcceptsShortSelections() {
    var dict = PersonalDictionary(terms: ["Supabase"])
    #expect(dict.addTerm(fromSelection: "  Brisenta, ") == .added("Brisenta"))
    #expect(dict.addTerm(fromSelection: "supabase") == .alreadyThere("Supabase"))
    #expect(dict.addTerm(fromSelection: "esto es una frase demasiado larga") == .invalid)
    #expect(dict.addTerm(fromSelection: "  ") == .invalid)
    #expect(dict.terms == ["Supabase", "Brisenta"])
    #expect(dict.learnedTerms.isEmpty)
    #expect(PersonalDictionary.ManualAdd.added("Brisenta").message == "Añadido al diccionario: Brisenta")
    #expect(PersonalDictionary.ManualAdd.invalid.message == "Selecciona una palabra o un nombre corto")
    #expect(PersonalDictionary.ManualAdd.invalid.isError)
    #expect(!PersonalDictionary.ManualAdd.added("Brisenta").isError)
    #expect(!PersonalDictionary.ManualAdd.alreadyThere("Brisenta").isError)
  }
}

@Suite struct DictionaryCommandTests {
  @Test(arguments: ["añádelo al diccionario", "Añade esto al diccionario.", "guárdalo en el diccionario",
                    "agrega esta palabra al diccionario", "mételo en el diccionario"])
  func recognizes(_ command: String) {
    #expect(DictionaryCommand.matches(command))
  }

  @Test(arguments: ["busca diccionario de inglés", "qué es un diccionario", "añade una coma", "tradúcelo al inglés"])
  func ignores(_ command: String) {
    #expect(!DictionaryCommand.matches(command))
  }
}

@Suite struct StyleLearnerTests {
  func entry(_ text: String, mode: HotkeyMode = .dictation, app: String? = "Mail", minutesAgo: Double) -> HistoryEntry {
    HistoryEntry(date: Date(timeIntervalSince1970: 1_790_000_000 - minutesAgo * 60), mode: mode, appBundleID: nil, appName: app,
                 language: "es_ES", audioSeconds: 3, rawText: text, finalText: text, engine: "apple", latencyMs: 300)
  }

  @Test func picksRecentDictationsWithFourWords() {
    let entries = [entry("Un saludo y gracias por todo.", app: nil, minutesAgo: 4), entry("Vale.", minutesAgo: 2),
                   entry("Nos vemos mañana en la oficina.", mode: .notes, minutesAgo: 3),
                   entry("Hola Marta, te llamo luego.", minutesAgo: 1)]
    let picked = StyleLearner.sample(entries)
    #expect(picked.map(\.finalText) == ["Hola Marta, te llamo luego.", "Un saludo y gracias por todo."])
    #expect(StyleLearner.promptText(picked) == "[Mail] Hola Marta, te llamo luego.\n[Otra app] Un saludo y gracias por todo.")
  }

  @Test func stopsAtTheCharacterLimit() {
    let long = String(repeating: "palabra ", count: 1000)
    #expect(StyleLearner.sample((0..<5).map { entry(long, minutesAgo: Double($0)) }).count == 1)
  }

  @Test func needsTwentyDictations() async {
    let entries = (0..<19).map { entry("Te escribo luego con los datos.", minutesAgo: Double($0)) }
    await #expect(throws: StyleLearner.Failure.notEnough(19)) {
      try await StyleLearner.learn(from: entries, currentStyle: "", model: FakeCloud())
    }
    #expect(StyleLearner.Failure.notEnough(19).message == "Aún hay pocos dictados (19): vuelve cuando tengas 20")
  }

  @Test func sendsDictationsWithTheCurrentStyle() async throws {
    let cloud = FakeCloud()
    cloud.json = #"{"estilo": "Tuteo y frases cortas. Sin emojis."}"#
    let entries = (0..<20).map { entry("Te escribo luego con los datos.", minutesAgo: Double($0)) }
    let proposal = try await StyleLearner.learn(from: entries, currentStyle: "sin emojis", model: cloud)
    #expect(proposal == StyleLearner.Proposal(style: "Tuteo y frases cortas. Sin emojis.", used: 20))
    #expect(cloud.prompts.count == 1)
    #expect(cloud.prompts[0].hasPrefix("Estilo actual: sin emojis\n<d>\n[Mail] Te escribo luego con los datos.\n"))
    #expect(cloud.prompts[0].hasSuffix("\n</d>"))
  }

  @Test func invalidReplyIsInvalidResponse() async {
    let cloud = FakeCloud()
    cloud.json = #"{"otro": 1}"#
    let entries = (0..<20).map { entry("Te escribo luego con los datos.", minutesAgo: Double($0)) }
    await #expect(throws: CloudError.invalidResponse) {
      try await StyleLearner.learn(from: entries, currentStyle: "", model: cloud)
    }
  }

  @Test func trimsLongStylesAtASentence() {
    let trimmed = StyleLearner.trim(String(repeating: "Frase corta. ", count: 40))
    #expect(trimmed.count <= 400)
    #expect(trimmed.hasSuffix("Frase corta."))
    #expect(StyleLearner.trim("  Tuteo.  ") == "Tuteo.")
    #expect(PromptLibrary.stylePrompt("[Mail] Hola.", current: " ") == "Estilo actual: (ninguno)\n<d>\n[Mail] Hola.\n</d>")
  }
}
