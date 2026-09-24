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
    #expect(text.contains("Estilo de la persona: tuteo, sin emojis."))
    #expect(text.contains("Escribe así estos términos: Brisenta, Supabase."))
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
