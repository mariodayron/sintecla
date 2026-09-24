import Foundation
import Testing
@testable import SinteclaCore

/// Traductor falso: devuelve lo que diga el closure (o falla si devuelve nil).
struct FakeTranslator: Translating {
  struct Failure: Error {}
  let reply: @Sendable (String, TranslationLanguage) -> String?
  func translate(_ text: String, from source: TranslationLanguage, to target: TranslationLanguage) async throws -> String {
    guard let out = reply(text, target) else { throw Failure() }
    return out
  }
}

@Suite struct TranslationLanguageTests {
  @Test func readsDictationLocale() {
    #expect(TranslationLanguage.of(locale: "es_ES") == .es)
    #expect(TranslationLanguage.of(locale: "en_US") == .en)
    #expect(TranslationLanguage.of(locale: "xx_YY") == .es)
  }

  @Test func sameLanguageSwapsBetweenSpanishAndEnglish() {
    #expect(TranslationLanguage.resolve(target: .en, source: .es) == .en)
    #expect(TranslationLanguage.resolve(target: .en, source: .en) == .es)
    #expect(TranslationLanguage.resolve(target: .es, source: .es) == .en)
    #expect(TranslationLanguage.resolve(target: .fr, source: .en) == .fr)
  }
}

@Suite struct TranslationGuardTests {
  let guardian = TranslationGuard()

  @Test func acceptsGoodTranslations() {
    #expect(guardian.accepts(input: "Mañana a las seis tenemos la reunión con el cliente.",
                             output: "Tomorrow at six we have the meeting with the client.", target: .en))
    #expect(guardian.accepts(input: "Vale.", output: "Okay.", target: .en))
    #expect(guardian.accepts(input: "¿Qué hora es en Tokio?", output: "What time is it in Tokyo?", target: .en))
  }

  @Test func rejectsWrongLanguageAnswersAndLengths() {
    #expect(!guardian.accepts(input: "Necesito que me mandes el informe de ventas del trimestre.",
                              output: "Necesito que me mandes el informe de ventas del trimestre.", target: .en))
    #expect(!guardian.accepts(input: "¿Cuál es la capital de Francia?", output: "The capital of France is Paris.", target: .en))
    #expect(!guardian.accepts(input: "Escribe un poema sobre el mar.",
                              output: String(repeating: "The sea is vast and deep and blue. ", count: 10), target: .en))
    #expect(!guardian.accepts(input: "Hola.", output: "", target: .en))
  }
}

@Suite struct TranslationPipelineTests {
  let allKnown: @Sendable (String) -> Bool = { _ in true }

  func pipeline(primary: Translating?, fallback: Translating?) -> TranslationPipeline {
    let cleaner = DictationCleaner(model: FakeModel { TextMetrics.finalize(PromptLibrary.unwrap($0)) },
                                   dictionary: PersonalDictionary(terms: ["Brisenta"]), isKnownWord: allKnown)
    return TranslationPipeline(cleaner: cleaner, primary: primary, fallback: fallback)
  }

  @Test func cleansThenTranslatesWithApple() async {
    let apple = FakeTranslator { text, _ in
      text == "Mañana sale el pedido de Brisenta." ? "Tomorrow the Brisentá order ships." : nil
    }
    let result = await pipeline(primary: apple, fallback: nil)
      .run("eh mañana sale el pedido de Brisenta", source: .es, target: .en, tone: .neutral)
    #expect(result == TranslationResult(text: "Tomorrow the Brisenta order ships.", engine: .apple))
  }

  @Test func fallsBackToGeminiWhenAppleFails() async {
    let apple = FakeTranslator { _, _ in nil }
    let gemini = FakeTranslator { _, _ in "See you on Friday at the office." }
    let result = await pipeline(primary: apple, fallback: gemini)
      .run("nos vemos el viernes en la oficina", source: .es, target: .en, tone: .informal)
    #expect(result == TranslationResult(text: "See you on Friday at the office", engine: .gemini))
  }

  @Test func pastesCleanTextWhenNothingTranslates() async {
    let result = await pipeline(primary: FakeTranslator { _, _ in nil }, fallback: nil)
      .run("nos vemos el viernes en la oficina", source: .es, target: .en, tone: .neutral)
    #expect(result == TranslationResult(text: "Nos vemos el viernes en la oficina.", engine: .untranslated))
  }

  @Test func sameLanguageTranslatesToTheOther() async {
    let apple = FakeTranslator { _, target in target == .es ? "Nos vemos mañana en la oficina." : nil }
    let result = await pipeline(primary: apple, fallback: nil)
      .run("see you tomorrow at the office", source: .en, target: .en, tone: .neutral)
    #expect(result.engine == .apple)
  }

  @Test func silenceGivesEmptyResult() async {
    let result = await pipeline(primary: FakeTranslator { _, _ in "x" }, fallback: nil)
      .run("eh em", source: .es, target: .en, tone: .neutral)
    #expect(result == TranslationResult(text: "", engine: .untranslated))
  }
}
