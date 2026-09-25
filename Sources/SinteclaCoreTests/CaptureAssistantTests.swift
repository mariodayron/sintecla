import Testing
@testable import SinteclaCore

@Suite struct CaptureAssistantTests {
  @Test func spanishGoesToTheChosenLanguageAndTheRestToSpanish() {
    let spanish = "Configuración de la cuenta: añade tu correo y la contraseña nueva"
    let english = "Please add your email address and the new password to the account settings"
    let french = "Veuillez ajouter votre adresse e-mail et le nouveau mot de passe"
    #expect(CaptureAssistant.languages(for: spanish, preferred: .en) == (.es, .en))
    #expect(CaptureAssistant.languages(for: spanish, preferred: .fr) == (.es, .fr))
    #expect(CaptureAssistant.languages(for: spanish, preferred: .es) == (.es, .en))  // al mismo idioma no se traduce
    #expect(CaptureAssistant.languages(for: english, preferred: .en) == (.en, .es))
    #expect(CaptureAssistant.languages(for: french, preferred: .en) == (.fr, .es))
  }

  @Test func translatesWithTheFallbackIfTheFirstFails() async {
    let failing = FakeTranslator { _, _ in nil }
    let fallback = FakeTranslator { text, to in "[→\(to.rawValue)] \(text)" }
    let assistant = CaptureAssistant(translators: [failing, fallback], models: [])
    let text = "Please add your email address and the new password"
    #expect(await assistant.translate(text, preferred: .en) == "[→es] \(text)")
  }

  @Test func emptyTranslationCountsAsFailure() async {
    let empty = FakeTranslator { _, _ in "  " }
    #expect(await CaptureAssistant(translators: [empty], models: []).translate("hello world", preferred: .en) == nil)
  }

  @Test func asksTheFallbackModelAndSendsTextAndQuestion() async {
    let answer = FakeModel { prompt in prompt.contains("«Pago pendiente: 42 €»") && prompt.contains("¿Qué debo?") ? "42 euros" : "?" }
    let assistant = CaptureAssistant(translators: [], models: [FailingModel(), answer])
    #expect(await assistant.ask("¿Qué debo?", about: "Pago pendiente: 42 €") == "42 euros")
  }

  @Test func noModelNoAnswer() async {
    #expect(await CaptureAssistant(translators: [], models: [FailingModel()]).ask("¿Qué es?", about: "x") == nil)
  }
}
