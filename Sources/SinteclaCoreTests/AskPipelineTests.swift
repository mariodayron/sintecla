import Foundation
import Testing
@testable import SinteclaCore

/// Gemini falso: texto con `reply`, JSON con `json`; `error` hace fallar las dos.
final class FakeCloud: TextModel, StructuredModel, @unchecked Sendable {
  var reply: String = ""
  var json: String = "{}"
  var error: CloudError?
  var prompts: [String] = []

  func complete(instructions: String, prompt: String, maxTokens: Int?) async throws -> String {
    prompts.append(prompt)
    if let error { throw error }
    return reply
  }

  func completeJSON(instructions: String, prompt: String, schemaName: String, schema: String) async throws -> Data {
    prompts.append(prompt)
    if let error { throw error }
    return Data(json.utf8)
  }
}

@Suite struct EditGuardTests {
  let guardian = EditGuard()

  @Test func cleansFencesQuotesAndIntros() {
    #expect(guardian.accept("```swift\nlet x = 1 // uno\n```", selection: "let x = 1") == "let x = 1 // uno")
    #expect(guardian.accept("«Hola, Juan.»", selection: "hola juan") == "Hola, Juan.")
    #expect(guardian.accept("Aquí tienes el texto corregido:\nHola, ¿qué tal?", selection: "ola q tal") == "Hola, ¿qué tal?")
    #expect(guardian.accept("<texto>Te paso el enlace luego.</texto>", selection: "te paso el enlace luego")
            == "Te paso el enlace luego.")
  }

  @Test func rejectsNoOpsPlaceholdersAndBadLengths() {
    #expect(guardian.accept("Estimado cliente, le informamos.", selection: "Estimado cliente, le informamos.") == nil)
    #expect(guardian.accept("Estimado Juan:\n\nNo podré asistir.\n\nAtentamente,\n\\[Tu Nombre]",
                            selection: "hola juan no podre ir") == nil)
    #expect(guardian.accept("", selection: "algo") == nil)
    #expect(guardian.accept("Ok.", selection: String(repeating: "texto largo ", count: 20)) == nil)
    #expect(guardian.accept("Hecho.", selection: String(repeating: "Frase de un informe. ", count: 200)) == nil)
    #expect(guardian.accept(String(repeating: "mucho más texto ", count: 30), selection: "El proyecto va bien.") == nil)
  }

  @Test func acceptsShortSummariesOfLongTexts() {
    let long = String(repeating: "Frase larga de un informe de ventas. ", count: 100)
    #expect(guardian.accept("Las ventas suben un 5 %.", selection: long) == "Las ventas suben un 5 %.")
  }

  @Test func rejectsASurpriseChangeOfLanguage() {
    let selection = "ola q tal, mañana ablamos del tema"
    #expect(guardian.accept("Olá, tudo bem, amanhã vamos falar do tema.", selection: selection) == nil)
    #expect(guardian.accept("Olá, tudo bem, amanhã vamos falar do tema.", selection: selection, sameLanguage: false) != nil)
    #expect(guardian.accept("func suma(a: Int, b: Int) -> Int {\n    // Suma dos enteros\n    return a + b\n}",
                            selection: "func suma(a: Int, b: Int) -> Int { return a + b }") != nil)
  }

  @Test func acceptsRealEdits() {
    #expect(guardian.accept("- Tornillos\n- Tacos", selection: "tornillos y tacos") == "- Tornillos\n- Tacos")
    #expect(guardian.accept("MAÑANA TE LLAMO", selection: "mañana te llamo") == "MAÑANA TE LLAMO")
  }
}

@Suite struct AskPipelineTests {
  let editable = Selection(text: "hola juan no podre ir mañana", editable: true)

  @Test func editableSelectionIsEditedLocallyAndReplaced() async {
    let pipeline = AskPipeline(apple: FakeModel { _ in "Hola, Juan: no podré ir mañana." }, cloud: FakeCloud())
    #expect(await pipeline.run(command: "corrige las faltas", selection: editable)
            == .replace("Hola, Juan: no podré ir mañana.", engine: "apple"))
  }

  @Test func rejectedLocalEditGoesToGemini() async {
    let cloud = FakeCloud()
    cloud.reply = "Estimado Juan: lamento comunicarle que mañana no podré asistir."
    let pipeline = AskPipeline(apple: FakeModel { _ in "hola juan no podre ir mañana" }, cloud: cloud)
    #expect(await pipeline.run(command: "hazlo más formal", selection: editable)
            == .replace("Estimado Juan: lamento comunicarle que mañana no podré asistir.", engine: "gemini"))
  }

  @Test func longSelectionSkipsTheLocalModel() async {
    let cloud = FakeCloud()
    cloud.reply = "Resumen: el informe repite la misma frase."
    let long = Selection(text: String(repeating: "Frase larga de un informe. ", count: 120), editable: true)
    let pipeline = AskPipeline(apple: FailingModel(), cloud: cloud)
    #expect(await pipeline.run(command: "resúmelo", selection: long)
            == .replace("Resumen: el informe repite la misma frase.", engine: "gemini"))
  }

  @Test func failedEditNeverTouchesTheSelection() async {
    let cloud = FakeCloud()
    cloud.error = .network("offline")
    let pipeline = AskPipeline(apple: FailingModel(), cloud: cloud)
    #expect(await pipeline.run(command: "hazlo más formal", selection: editable) == .failure("Sin conexión con Gemini"))
  }

  @Test func questionsGoToGeminiWithTheSelection() async {
    let cloud = FakeCloud()
    cloud.reply = "Es una disculpa por no ir."
    let pipeline = AskPipeline(apple: FakeModel { _ in "no" }, cloud: cloud)
    #expect(await pipeline.run(command: "qué significa esto", selection: editable)
            == .answer("Es una disculpa por no ir.", local: false, engine: "gemini"))
    #expect(cloud.prompts == ["<texto>hola juan no podre ir mañana</texto>\nqué significa esto"])
  }

  @Test func readOnlySelectionAlwaysAnswersInTheCard() async {
    let cloud = FakeCloud()
    cloud.reply = "The meeting was moved."
    let web = Selection(text: "La reunión se ha movido.", editable: false)
    let pipeline = AskPipeline(apple: nil, cloud: cloud)
    #expect(await pipeline.run(command: "tradúcelo al inglés", selection: web)
            == .answer("The meeting was moved.", local: false, engine: "gemini"))
  }

  @Test func withoutGeminiAnswersLocally() async {
    let pipeline = AskPipeline(apple: FailingModel(), localAnswers: FakeModel { _ in " París. " }, cloud: nil)
    #expect(await pipeline.run(command: "cuál es la capital de Francia", selection: nil)
            == .answer("París.", local: true, engine: "apple"))
  }

  @Test func webActionsUseGeminiThenRules() async {
    let cloud = FakeCloud()
    cloud.json = #"{"sitio": "youtube", "consulta": "Rosalía última canción"}"#
    let online = AskPipeline(apple: nil, cloud: cloud)
    #expect(await online.run(command: "pon la última canción de Rosalía", selection: nil)
            == .open(WebSite.youtube.url(for: "Rosalía última canción")))
    let offline = AskPipeline(apple: nil, cloud: nil)
    #expect(await offline.run(command: "busca vídeos de gatos en YouTube", selection: nil)
            == .open(WebSite.youtube.url(for: "vídeos de gatos")))
  }

  @Test func translationCommandsUseTheTranslator() async {
    let translator = FakeTranslator { _, target in target == .en ? "I'll send you the link later." : nil }
    let pipeline = AskPipeline(apple: FailingModel(), cloud: nil, translator: translator)
    let text = "te paso el enlace luego y lo revisamos juntos"
    #expect(await pipeline.run(command: "tradúcelo al inglés", selection: Selection(text: text, editable: true))
            == .replace("I'll send you the link later.", engine: "apple"))
    #expect(await pipeline.run(command: "tradúcelo al inglés", selection: Selection(text: text, editable: false))
            == .answer("I'll send you the link later.", local: true, engine: "apple"))
  }

  @Test func silenceIsReported() async {
    #expect(await AskPipeline(apple: nil, cloud: nil).run(command: "eh em", selection: nil) == .silence)
  }

  @Test func styleGoesIntoEditInstructions() {
    #expect(PromptLibrary.editInstructions(style: "tuteo, sin emojis").contains("- Estilo del usuario: tuteo, sin emojis."))
    #expect(!PromptLibrary.editInstructions(style: " ").contains("Estilo del usuario"))
  }
}
