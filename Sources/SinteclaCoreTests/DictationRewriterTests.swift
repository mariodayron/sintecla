import Foundation
import Testing
@testable import SinteclaCore

/// Gemini falso que falla con un `CloudError`.
struct CloudFailingModel: TextModel {
  let error: CloudError
  func complete(instructions: String, prompt: String, maxTokens: Int?) async throws -> String { throw error }
}

/// Guarda lo que recibe y responde con `reply`.
final class PromptSpy: TextModel, @unchecked Sendable {
  let reply: String
  var calls: [(instructions: String, prompt: String)] = []
  init(reply: String) { self.reply = reply }
  func complete(instructions: String, prompt: String, maxTokens: Int?) async throws -> String {
    calls.append((instructions, prompt))
    return reply
  }
}

@Suite struct DictationRewriterTests {
  let allKnown: @Sendable (String) -> Bool = { _ in true }
  let repeated = "necesito el informe, el informe de ventas digo, para el lunes, lo necesito el lunes"

  func rewriter(_ cloud: TextModel?, local: TextModel? = nil, dictionary: PersonalDictionary = PersonalDictionary()) -> DictationRewriter {
    DictationRewriter(cloud: cloud, local: DictationCleaner(model: local, dictionary: dictionary, isKnownWord: allKnown))
  }

  @Test func usesGeminiWhenTheGuardAccepts() async {
    let result = await rewriter(FakeModel { _ in "Necesito el informe de ventas para el lunes." }).rewrite(repeated, tone: .neutral)
    #expect(result == DictationRewriter.Result(text: "Necesito el informe de ventas para el lunes.", engine: .gemini))
    #expect(result.engine.rawValue == "gemini")
  }

  @Test func restoresTermsAndAppliesTheTone() async {
    let dictionary = PersonalDictionary(terms: ["Brisenta"])
    let cloud = FakeModel { _ in "Te paso lo de brisenta mañana por la tarde." }
    let result = await rewriter(cloud, dictionary: dictionary).rewrite("te paso lo de Brisenta mañana por la tarde", tone: .informal)
    #expect(result == DictationRewriter.Result(text: "Te paso lo de Brisenta mañana por la tarde", engine: .gemini))
  }

  @Test func sendsPlaceStyleAndTheCleanedText() async {
    let spy = PromptSpy(reply: "Hola, Marta, te mando el presupuesto de la reforma.")
    _ = await rewriter(spy).rewrite("eh hola marta te mando el presupuesto de la reforma", tone: .formal,
                                    appName: "Safari", site: "mail.google.com", style: "tuteo")
    #expect(spy.calls.count == 1)
    #expect(spy.calls.first?.prompt == "<t>hola marta te mando el presupuesto de la reforma</t>")
    #expect(spy.calls.first?.instructions.contains("Escribe en: Safari · mail.google.com.") == true)
    #expect(spy.calls.first?.instructions.contains("no se haya dicho): tuteo.") == true)
  }

  @Test func dropsGreetingsAndFarewellsItMadeUp() async {
    // «Mi estilo» dice que saluda con «Hola, buenas»: Gemini a veces lo añade aunque no se diga.
    let greeting = FakeModel { _ in "Hola, buenas. La idea es que la app sea más rápida, sobre todo al abrir, que tarda mucho." }
    #expect(await rewriter(greeting).rewrite("bueno la idea es que la app sea más rápida que vaya más rápido sobre todo al abrir que al abrir tarda mucho",
                                             tone: .neutral)
            == DictationRewriter.Result(text: "La idea es que la app sea más rápida, sobre todo al abrir, que tarda mucho.", engine: .gemini))
    let farewell = FakeModel { _ in "Te mando el presupuesto de la reforma con el total corregido.\n\nUn saludo." }
    #expect(await rewriter(farewell).rewrite("te mando el presupuesto de la reforma con el total corregido", tone: .formal).text
            == "Te mando el presupuesto de la reforma con el total corregido.")
  }

  @Test func keepsGreetingsAndFarewellsThatWereSaid() {
    let output = "Hola, buenas.\n\nTe mando el presupuesto.\n\nUn saludo."
    #expect(DictationRewriter.removingMadeUpGreetings(output, dictated: "hola buenas te mando el presupuesto un saludo") == output)
    #expect(DictationRewriter.removingMadeUpGreetings("Hola, Marta: te mando el presupuesto.", dictated: "marta te mando el presupuesto")
            == "Hola, Marta: te mando el presupuesto.")
  }

  @Test func promptLabelsCountAsSaid() async {
    let dictated = "revisa el login porque falla en safari y en chrome, falla en los dos, y añade tests"
    let structured = "Contexto:\nEl login falla en Safari y en Chrome.\n\nRequisitos:\n- Revísalo.\n- Añade tests."
    let cloud = FakeModel { _ in structured }
    #expect(await rewriter(cloud).rewrite(dictated, tone: .prompt) == DictationRewriter.Result(text: structured, engine: .gemini))
    // Con otro tono, «Contexto» y «Requisitos» son palabras nuevas y el filtro lo rechaza.
    #expect(await rewriter(cloud).rewrite(dictated, tone: .technical).engine == .rules)
  }

  @Test func promptAllowsRewritingIntoTheImperative() async {
    // Salida real de Gemini: al pasar a imperativo cambian muchas palabras («lea» → «Lee», «mueva» → «moverlo»).
    let dictated = "oye quiero que me hagas una función en swift que, o sea, que lea un json de la carpeta de documentos, "
      + "y que si el json está roto pues que no pete, que lo mueva a otro sitio, y bueno que tenga tests"
    let prompt = "Crea una función en Swift.\nContexto:\n- Lee un JSON de la carpeta de documentos.\n"
      + "- Si el JSON está roto, no debe petar y hay que moverlo a otro sitio.\n- Debe incluir tests."
    let cloud = FakeModel { _ in prompt }
    #expect(await rewriter(cloud).rewrite(dictated, tone: .prompt).engine == .gemini)
    #expect(await rewriter(cloud).rewrite(dictated, tone: .technical).engine == .rules)
  }

  @Test func answerRejectedByTheGuardFallsBackWithoutError() async {
    let cloud = FakeModel { _ in "Ahora mismo en Tokio son las diez y cuarto de la noche." }
    let result = await rewriter(cloud).rewrite("qué hora es en Tokio ahora mismo dime", tone: .neutral)
    #expect(result == DictationRewriter.Result(text: "¿Qué hora es en Tokio ahora mismo dime?", engine: .rules))
  }

  @Test func geminiErrorFallsBackAndSaysWhy() async {
    let local = FakeModel { _ in "Necesito el informe de ventas para el lunes." }
    let result = await rewriter(CloudFailingModel(error: .http(status: 429, message: "")), local: local)
      .rewrite(repeated, tone: .neutral)
    #expect(result == DictationRewriter.Result(text: "Necesito el informe de ventas para el lunes.", engine: .apple,
                                               cloudError: .http(status: 429, message: "")))
  }

  @Test func shortDictationsStayOnTheMac() async {
    let spy = PromptSpy(reply: "Llego en diez.")
    let result = await rewriter(spy).rewrite("vale llego en diez", tone: .neutral)
    #expect(spy.calls.isEmpty)
    #expect(result == DictationRewriter.Result(text: "Llego en diez.", engine: .rules))
  }

  @Test func withoutGeminiItIsTheLocalCleaner() async {
    let local = FakeModel { _ in "Necesito el informe de ventas para el lunes." }
    let result = await rewriter(nil, local: local).rewrite(repeated, tone: .neutral)
    #expect(result == DictationRewriter.Result(text: "Necesito el informe de ventas para el lunes.", engine: .apple))
  }
}
