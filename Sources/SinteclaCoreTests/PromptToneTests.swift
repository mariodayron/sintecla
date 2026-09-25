import Foundation
import Testing
@testable import SinteclaCore

@Suite struct PromptToneTests {
  let safari = "com.apple.Safari"

  @Test func aiAppsAndSitesUseThePromptTone() {
    let rules = ToneRules.defaults
    #expect(rules.tone(for: "com.anthropic.claudefordesktop") == .prompt)
    #expect(rules.tone(for: "com.openai.chat") == .prompt)
    #expect(rules.tone(for: "com.openai.codex") == .prompt)
    #expect(rules.tone(for: safari, host: "claude.ai") == .prompt)
    #expect(rules.tone(for: safari, host: "chatgpt.com") == .prompt)
    #expect(rules.tone(for: safari, host: "gemini.google.com") == .prompt)
    // Donde también se dictan comandos y código, sigue el técnico.
    #expect(rules.tone(for: "com.apple.Terminal") == .technical)
    #expect(rules.tone(for: safari, host: "github.com") == .technical)
    #expect(Tone.prompt.label == "Prompt para IA")
    #expect(Tone.allCases == [.formal, .informal, .technical, .prompt, .neutral])
  }

  @Test func anOldTonesFileMovesAIFromTechnicalToPrompt() throws {
    let old = #"{"byBundleID":{"com.anthropic.claudefordesktop":"technical","com.openai.chat":"informal","#
      + #""com.apple.Terminal":"technical"},"bySite":{"chatgpt.com":"technical","github.com":"technical"}}"#
    let rules = try JSONDecoder().decode(ToneRules.self, from: Data(old.utf8))
    #expect(rules.byBundleID == ["com.anthropic.claudefordesktop": .prompt, "com.openai.chat": .informal,
                                 "com.apple.Terminal": .technical])
    #expect(rules.bySite == ["chatgpt.com": .prompt, "github.com": .technical])
    #expect(rules.version == ToneRules.currentVersion)
  }

  @Test func theChangeHappensOnlyOnce() throws {
    var rules = ToneRules.defaults
    rules.byBundleID["com.anthropic.claudefordesktop"] = .technical
    let decoded = try JSONDecoder().decode(ToneRules.self, from: JSONEncoder().encode(rules))
    #expect(decoded == rules)
    #expect(decoded.tone(for: "com.anthropic.claudefordesktop") == .technical)
  }

  @Test func promptLinesForAppleAndGemini() {
    #expect(ToneFormatter.instruction(for: .prompt).hasPrefix("Es un mensaje para una IA: pon primero lo que se pide"))
    #expect(ToneFormatter.cloudInstruction(for: .prompt).hasPrefix("prompt para una IA: empieza por lo que se pide"))
    #expect(ToneFormatter.cloudInstruction(for: .prompt).hasSuffix("no añadas requisitos, roles, formatos ni peticiones que no haya dicho"))
    #expect(ToneFormatter.postProcess("Haz una función.", tone: .prompt) == "Haz una función.")
    #expect(ToneFormatter.allowedLabels(for: .prompt) == ["Requisitos", "Contexto", "Pasos", "Objetivo"])
    #expect(ToneFormatter.allowedLabels(for: .technical).isEmpty)
  }

  @Test func notesInAIAppsAreMarkdown() {
    #expect(NotesFormat.forApp(bundleID: "com.anthropic.claudefordesktop", tone: .prompt) == .markdown)
  }
}
