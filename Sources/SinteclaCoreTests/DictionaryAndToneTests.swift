import Testing
@testable import SinteclaCore

@Suite struct PersonalDictionaryTests {
  let known: Set<String> = [
    "hay", "que", "subir", "los", "datos", "del", "antes", "viernes", "la", "brisa", "sube", "el",
    "archivo", "a", "esta", "noche", "salió", "en", "precio", "super", "base",
  ]
  var isKnown: (String) -> Bool { { known.contains($0.lowercased()) } }
  let dictionary = PersonalDictionary(terms: ["Brisenta", "Supabase"])

  @Test func appliesExactRulesCaseInsensitiveWholeWord() {
    let d = PersonalDictionary(rules: [DictionaryRule(from: "bri senta", to: "Brisenta"),
                                       DictionaryRule(from: "ana", to: "Ana")])
    #expect(d.applyRules(to: "subir a Bri Senta hoy") == "subir a Brisenta hoy")
    #expect(d.applyRules(to: "banana y ana") == "banana y Ana")
  }

  @Test func longestRuleWins() {
    let d = PersonalDictionary(rules: [DictionaryRule(from: "su", to: "SU"),
                                       DictionaryRule(from: "su falta", to: "Supabase")])
    #expect(d.applyRules(to: "a su falta") == "a Supabase")
  }

  @Test func fixesUnknownWordsCloseToATerm() {
    #expect(dictionary.fuzzyFix("hay que subir los datos del brosanta antes del viernes", isKnownWord: isKnown)
            == "hay que subir los datos del Brisenta antes del viernes")
    #expect(dictionary.fuzzyFix("sube el archivo a supabeis esta noche", isKnownWord: isKnown)
            == "sube el archivo a Supabase esta noche")
  }

  @Test func joinsTwoWordsIntoATerm() {
    #expect(dictionary.fuzzyFix("subir a bri senta", isKnownWord: isKnown) == "subir a Brisenta")
  }

  @Test func neverTouchesRealWords() {
    #expect(dictionary.fuzzyFix("entró la brisa", isKnownWord: isKnown) == "entró la brisa")
    #expect(dictionary.fuzzyFix("super base", isKnownWord: isKnown) == "super base")
  }

  @Test func restoresTermSpellingIgnoringAccentsAndCase() {
    #expect(dictionary.restoreTerms("El pedido de Brisentá sale con supabase.") == "El pedido de Brisenta sale con Supabase.")
    #expect(dictionary.restoreTerms("¿Brisenta?") == "¿Brisenta?")
    #expect(dictionary.restoreTerms("- brisenta\n- Supabáse") == "- Brisenta\n- Supabase")
    #expect(PersonalDictionary().restoreTerms("sin términos") == "sin términos")
  }

  @Test func distanceIsNormalized() {
    #expect(PersonalDictionary.normalizedDistance("Brisenta", "brisenta") == 0)
    #expect(PersonalDictionary.normalizedDistance("brosanta", "Brisenta") == 0.25)
    #expect(PersonalDictionary.normalizedDistance("", "abc") == 1)
  }
}

@Suite struct ToneTests {
  @Test func looksUpToneByBundleID() {
    #expect(ToneRules.defaults.tone(for: "net.whatsapp.WhatsApp") == .informal)
    #expect(ToneRules.defaults.tone(for: "com.apple.mail") == .formal)
    #expect(ToneRules.defaults.tone(for: "com.unknown.app") == .neutral)
    #expect(ToneRules.defaults.tone(for: nil) == .neutral)
  }

  @Test func informalDropsFinalPeriodOfSingleSentence() {
    #expect(ToneFormatter.postProcess("Nos vemos luego.", tone: .informal) == "Nos vemos luego")
    #expect(ToneFormatter.postProcess("Hola. Nos vemos luego.", tone: .informal) == "Hola. Nos vemos luego.")
    #expect(ToneFormatter.postProcess("¿Vienes?", tone: .informal) == "¿Vienes?")
    #expect(ToneFormatter.postProcess("Nos vemos luego.", tone: .formal) == "Nos vemos luego.")
  }

  @Test(arguments: [
    ("Hola Juan, te quiero confirmar la reunión que tendremos el viernes. Un saludo.",
     "Hola Juan,\n\nTe quiero confirmar la reunión que tendremos el viernes.\n\nUn saludo."),
    ("Buenos días, Marta. Te adjunto el presupuesto que me pediste. Quedo a la espera de tus comentarios. Un abrazo.",
     "Buenos días, Marta.\n\nTe adjunto el presupuesto que me pediste. Quedo a la espera de tus comentarios.\n\nUn abrazo."),
    ("Estimado señor García: le escribo por la factura de marzo. Atentamente, Ana.",
     "Estimado señor García:\n\nLe escribo por la factura de marzo.\n\nAtentamente, Ana."),
    ("Hola a todos, ¿podemos vernos el lunes?", "Hola a todos,\n\n¿Podemos vernos el lunes?"),
    ("Te confirmo la reunión del viernes. Un cordial saludo.", "Te confirmo la reunión del viernes.\n\nUn cordial saludo."),
    ("Hi John, the meeting is on Friday. Best regards.", "Hi John,\n\nThe meeting is on Friday.\n\nBest regards."),
  ])
  func formalPutsGreetingAndFarewellOnTheirOwnLines(input: String, expected: String) {
    #expect(ToneFormatter.postProcess(input, tone: .formal) == expected)
  }

  @Test(arguments: [
    "Nos vemos luego.",
    "Un saludo.",
    "Hola.",
    "Hola que tal todo",
    "Holanda es preciosa en primavera. Un saludo.",
    "Buenas noticias: ya tenemos el presupuesto.",
    "Hola Juan,\n\nTe escribo por la reunión.",
  ])
  func formalLeavesOtherTextsAlone(_ text: String) {
    let expected = text == "Holanda es preciosa en primavera. Un saludo."
      ? "Holanda es preciosa en primavera.\n\nUn saludo." : text
    #expect(ToneFormatter.postProcess(text, tone: .formal) == expected)
  }

  @Test func onlyTheFormalToneSeparatesTheGreeting() {
    let text = "Hola Juan, te escribo por la reunión. Un saludo."
    #expect(ToneFormatter.postProcess(text, tone: .neutral) == text)
    #expect(ToneFormatter.postProcess(text, tone: .technical) == text)
  }
}
