import Foundation
import Testing
@testable import SinteclaCore

@Suite struct NotesRendererTests {
  let doc = NotesDocument(
    resumen: "Hay que mover la caldera y pedir los radiadores.",
    ideas: [NotesDocument.Topic(tema: "Obra de la calle Mayor", puntos: ["La caldera va al lavadero.", "Revisar la salida de humos."])],
    tareas: ["Pedir los radiadores (tardan tres semanas)."],
    pendiente: ["¿Contratar otro oficial?"])

  @Test func rendersPlainTextWithColonsAndBullets() {
    #expect(NotesRenderer.render(doc, format: .plainText) == """
      Resumen:
      Hay que mover la caldera y pedir los radiadores.

      Ideas clave:
      Obra de la calle Mayor:
      • La caldera va al lavadero.
      • Revisar la salida de humos.

      Tareas:
      • Pedir los radiadores (tardan tres semanas).

      Pendiente de decidir:
      • ¿Contratar otro oficial?
      """)
  }

  @Test func rendersMarkdown() {
    #expect(NotesRenderer.render(doc, format: .markdown) == """
      ## Resumen
      Hay que mover la caldera y pedir los radiadores.

      ## Ideas clave
      ### Obra de la calle Mayor
      - La caldera va al lavadero.
      - Revisar la salida de humos.

      ## Tareas
      - [ ] Pedir los radiadores (tardan tres semanas).

      ## Pendiente de decidir
      - ¿Contratar otro oficial?
      """)
  }

  @Test func skipsEmptySectionsAndUntitledTopics() {
    let local = NotesDocument(ideas: [NotesDocument.Topic(tema: "", puntos: ["Uno.", "Dos."])])
    #expect(NotesRenderer.render(local, format: .plainText) == "Ideas clave:\n• Uno.\n• Dos.")
    #expect(NotesDocument().isEmpty)
  }

  @Test func picksFormatByApp() {
    #expect(NotesFormat.forApp(bundleID: "md.obsidian", tone: .neutral) == .markdown)
    #expect(NotesFormat.forApp(bundleID: "com.microsoft.VSCode", tone: .technical) == .markdown)
    #expect(NotesFormat.forApp(bundleID: "com.apple.mail", tone: .formal) == .plainText)
    #expect(NotesFormat.forApp(bundleID: nil, tone: .neutral) == .plainText)
  }
}

@Suite struct NotesOrganizerTests {
  let allKnown: @Sendable (String) -> Bool = { _ in true }

  func organizer(cloud: StructuredModel?, apple: TextModel?) -> NotesOrganizer {
    NotesOrganizer(cloud: cloud, apple: apple, dictionary: PersonalDictionary(terms: ["Brisenta"]), isKnownWord: allKnown)
  }

  @Test func geminiJSONBecomesNotes() async {
    let cloud = FakeCloud()
    cloud.json = #"{"resumen": "Todo va bien con brisentá.", "ideas": [], "tareas": ["Llamar a Javi."], "pendiente": []}"#
    let result = await organizer(cloud: cloud, apple: nil).organize("eh bueno todo va bien y hay que llamar a Javi", format: .plainText)
    #expect(result == NotesResult(text: "Resumen:\nTodo va bien con Brisenta.\n\nTareas:\n• Llamar a Javi.", engine: .gemini))
    #expect(cloud.prompts == ["<t>todo va bien y hay que llamar a Javi</t>"])
  }

  @Test func withoutGeminiAppleExtractsBulletsPerChunk() async {
    let cloud = FakeCloud()
    cloud.error = .network("offline")
    let apple = FakeModel { _ in "*   Idea uno.\n\n- Idea dos." }
    let result = await organizer(cloud: cloud, apple: apple).organize("idea uno y idea dos", format: .markdown)
    #expect(result == NotesResult(text: "## Ideas clave\n- Idea uno.\n- Idea dos.", engine: .apple,
                                  cloudError: .network("offline")))
  }

  @Test func withoutAnyAIPastesTheCleanTranscript() async {
    let result = await organizer(cloud: nil, apple: FailingModel()).organize("eh pues nada llamar a Javi mañana", format: .plainText)
    #expect(result == NotesResult(text: "Nada llamar a Javi mañana.", engine: .rules))
  }

  @Test func emptyGeminiReplyFallsBack() async {
    let cloud = FakeCloud()
    cloud.json = #"{"resumen": "", "ideas": [], "tareas": [], "pendiente": []}"#
    let result = await organizer(cloud: cloud, apple: nil).organize("algo que decir", format: .plainText)
    #expect(result == NotesResult(text: "Algo que decir.", engine: .rules, cloudError: .invalidResponse))
  }

  @Test func silenceGivesNothing() async {
    let result = await organizer(cloud: FakeCloud(), apple: nil).organize("eh em", format: .plainText)
    #expect(result == NotesResult(text: "", engine: .rules))
  }

  @Test func dropsRepeatedBullets() {
    #expect(NotesOrganizer.unique(["Pedir radiadores.", "Llamar a Javi.", "pedir radiadores."]) == ["Pedir radiadores.", "Llamar a Javi."])
  }

  @Test func readsBulletsInAnyStyle() {
    #expect(NotesOrganizer.bullets(from: "- uno\n* dos\n•   tres\n1. cuatro\n2) **cinco**\n\n") == ["uno", "dos", "tres", "cuatro", "cinco"])
  }
}

@Suite struct DraftStoreTests {
  @Test func appendsReadsListsAndDeletes() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("drafts-\(UUID().uuidString)")
    let store = DraftStore(directory: dir)
    let url = store.create()
    #expect(store.pending().isEmpty)
    store.append("primera frase.", to: url)
    store.append("segunda frase.", to: url)
    #expect(store.read(url) == "primera frase. segunda frase.")
    #expect(store.pending() == [url])
    store.delete(url)
    #expect(store.pending().isEmpty)
  }
}
