import Foundation
import Testing
@testable import SinteclaCore

@Suite struct RewritePromptTests {
  @Test func appleNowOrdersInsteadOfKeepingEveryWord() {
    let text = PromptLibrary.dictationInstructions(tone: .neutral)
    #expect(text.contains("repeticiones"))
    #expect(text.contains("Recuérdame llamar a Luis mañana."))
    #expect(!text.contains("Conserva TODAS"))
  }

  @Test func geminiGetsPlaceToneStyleAndTerms() {
    let text = PromptLibrary.rewriteInstructions(tone: .formal, context: "Safari · mail.google.com", style: "tuteo, sin emojis",
                                                 terms: ["Brisenta", "Supabase"])
    #expect(text.contains("Escribe en: Safari · mail.google.com."))
    #expect(text.contains("Tono: " + ToneFormatter.cloudInstruction(for: .formal) + "."))
    #expect(text.contains("Estilo de la persona (solo para la forma de escribir; no añadas por él saludos, despedidas ni nada que "
                          + "no se haya dicho): tuteo, sin emojis."))
    #expect(text.contains("Escribe así estos términos: Brisenta, Supabase."))
  }

  @Test func geminiKeepsWhatWasSaidAndDropsFillers() {
    let text = PromptLibrary.rewriteInstructions(tone: .neutral, context: nil, style: "", terms: [])
    #expect(text.contains("Conserva los saludos y despedidas que diga; no añadas ninguno que no diga, ni firmas."))
    #expect(text.contains("Quita muletillas (eh, este, o sea, bueno, pues, vale, oye, digo)"))
    #expect(text.contains("<t>pásame el informe, o sea el informe de ventas, cuando puedas</t> -> Pásame el informe de ventas cuando puedas."))
    #expect(text.contains("<t>hola luis te paso el informe, el informe de ventas, un saludo</t> -> Hola, Luis, te paso el informe de ventas. Un saludo."))
  }

  @Test func geminiLeavesOutEmptyLinesAndCapsTerms() {
    let text = PromptLibrary.rewriteInstructions(tone: .neutral, context: nil, style: "  ", terms: [])
    #expect(!text.contains("Escribe en:"))
    #expect(!text.contains("Estilo de la persona"))
    #expect(!text.contains("Escribe así"))
    #expect(text.contains("Tono: neutro: claro y correcto."))
    let many = (1...60).map { "Término\($0)" }
    let capped = PromptLibrary.rewriteInstructions(tone: .neutral, context: nil, style: "", terms: many)
    #expect(capped.contains("Término50."))
    #expect(!capped.contains("Término51"))
  }

  @Test func writingPlaceIsTheAppAndTheWeb() {
    #expect(PromptLibrary.writingPlace(appName: "WhatsApp", site: nil) == "WhatsApp")
    #expect(PromptLibrary.writingPlace(appName: "Safari", site: "mail.google.com") == "Safari · mail.google.com")
    #expect(PromptLibrary.writingPlace(appName: nil, site: "mail.google.com") == nil)
  }
}
