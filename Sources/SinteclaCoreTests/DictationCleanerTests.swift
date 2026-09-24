import Foundation
import Testing
@testable import SinteclaCore

/// Modelo falso: responde con lo que diga el closure.
struct FakeModel: TextModel {
  let reply: @Sendable (String) -> String
  func complete(instructions: String, prompt: String, maxTokens: Int?) async throws -> String { reply(prompt) }
}

struct FailingModel: TextModel {
  struct Failure: Error {}
  func complete(instructions: String, prompt: String, maxTokens: Int?) async throws -> String { throw Failure() }
}

/// Guarda el tope de tokens que recibe.
final class TokenSpy: TextModel, @unchecked Sendable {
  var seen: [Int?] = []
  func complete(instructions: String, prompt: String, maxTokens: Int?) async throws -> String {
    seen.append(maxTokens)
    return PromptLibrary.unwrap(prompt)
  }
}

@Suite struct DictationCleanerTests {
  let allKnown: @Sendable (String) -> Bool = { _ in true }

  @Test func usesModelOutputWhenGuardAccepts() async {
    let cleaner = DictationCleaner(model: FakeModel { _ in "Mañana a las seis." },
                                   dictionary: PersonalDictionary(), isKnownWord: allKnown)
    let result = await cleaner.clean("eh mañana a las cinco no perdón a las seis", tone: .neutral)
    #expect(result == CleanupResult(text: "Mañana a las seis.", engine: .apple))
  }

  @Test func fallsBackToRulesWhenModelAnswers() async {
    let cleaner = DictationCleaner(model: FakeModel { _ in "Son las 10:00 de la noche en Tokio." },
                                   dictionary: PersonalDictionary(), isKnownWord: allKnown)
    let result = await cleaner.clean("qué hora es en Tokio", tone: .neutral)
    #expect(result == CleanupResult(text: "¿Qué hora es en Tokio?", engine: .rules))
  }

  @Test func fallsBackToRulesWhenModelFailsOrIsMissing() async {
    let failing = DictationCleaner(model: FailingModel(), dictionary: PersonalDictionary(), isKnownWord: allKnown)
    #expect(await failing.clean("vale nos vemos", tone: .neutral) == CleanupResult(text: "Nos vemos.", engine: .rules))
    let none = DictationCleaner(model: nil, dictionary: PersonalDictionary(), isKnownWord: allKnown)
    #expect(await none.clean("vale nos vemos", tone: .neutral) == CleanupResult(text: "Nos vemos.", engine: .rules))
  }

  @Test func returnsEmptyWhenOnlyFillers() async {
    let cleaner = DictationCleaner(model: FakeModel { _ in "Algo." }, dictionary: PersonalDictionary(), isKnownWord: allKnown)
    #expect(await cleaner.clean("eh em", tone: .neutral) == CleanupResult(text: "", engine: .rules))
  }

  @Test func dictionaryRulesWinOverTheModel() async {
    let dictionary = PersonalDictionary(terms: ["Brisenta"], rules: [DictionaryRule(from: "bri senta", to: "Brisenta")])
    let cleaner = DictationCleaner(model: FakeModel { _ in "Subir a bri senta." }, dictionary: dictionary, isKnownWord: allKnown)
    #expect(await cleaner.clean("subir a bri senta", tone: .neutral).text == "Subir a Brisenta.")
  }

  @Test func informalToneDropsFinalPeriod() async {
    let cleaner = DictationCleaner(model: FakeModel { _ in "Nos vemos luego." }, dictionary: PersonalDictionary(), isKnownWord: allKnown)
    #expect(await cleaner.clean("nos vemos luego", tone: .informal).text == "Nos vemos luego")
  }

  @Test func restoresExactSpellingOfDictionaryTerms() async {
    let dictionary = PersonalDictionary(terms: ["Brisenta", "Supabase"])
    let cleaner = DictationCleaner(model: FakeModel { _ in "El pedido de Brisentá sale hoy con supabase." },
                                   dictionary: dictionary, isKnownWord: allKnown)
    #expect(await cleaner.clean("el pedido de Brisenta sale hoy con Supabase", tone: .neutral).text
            == "El pedido de Brisenta sale hoy con Supabase.")
  }

  @Test func capsResponseTokensByChunkLength() async {
    let spy = TokenSpy()
    let cleaner = DictationCleaner(model: spy, dictionary: PersonalDictionary(), isKnownWord: allKnown)
    _ = await cleaner.clean("escribe un poema sobre el mar", tone: .neutral)
    #expect(spy.seen == [DictationCleaner.maxTokens(for: "escribe un poema sobre el mar")])
    #expect(DictationCleaner.maxTokens(for: "escribe un poema sobre el mar") == 51)
  }

  @Test func processesLongTextInChunks() async {
    var cleaner = DictationCleaner(model: FakeModel { PromptLibrary.unwrap($0).uppercased() },
                                   dictionary: PersonalDictionary(), isKnownWord: allKnown)
    cleaner.maxChunkChars = 25
    let result = await cleaner.clean("Uno dos tres cuatro. Cinco seis siete ocho. Nueve diez once doce.", tone: .neutral)
    #expect(result == CleanupResult(text: "UNO DOS TRES CUATRO. CINCO SEIS SIETE OCHO. NUEVE DIEZ ONCE DOCE.", engine: .apple))
  }
}
