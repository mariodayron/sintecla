import Testing
@testable import SinteclaCore

@Suite struct TextMetricsTests {
  @Test func detectsQuestions() {
    #expect(TextMetrics.isQuestion("¿Qué hora es?"))
    #expect(TextMetrics.isQuestion("cuál es la capital de Francia"))
    #expect(TextMetrics.isQuestion("por qué no vienes"))
    #expect(!TextMetrics.isQuestion("que venga mañana"))
    #expect(!TextMetrics.isQuestion("recuérdame comprar pan"))
  }

  @Test func finalizesTextWithoutAI() {
    #expect(TextMetrics.finalize("nos vemos") == "Nos vemos.")
    #expect(TextMetrics.finalize("qué hora es en Tokio") == "¿Qué hora es en Tokio?")
    #expect(TextMetrics.finalize("¿vienes?") == "¿Vienes?")
    #expect(TextMetrics.finalize("") == "")
  }

  @Test func contentWordsIgnoreAccentsCaseAndStopwords() {
    #expect(TextMetrics.contentWords("La reunión con Brisenta") == ["reunion", "brisenta"])
  }
}

@Suite struct OutputGuardTests {
  let guardian = OutputGuard()

  @Test func acceptsPunctuationAndAccentFixes() {
    #expect(guardian.accepts(input: "mañana a las seis tenemos la reunion con brisenta",
                             output: "Mañana a las seis tenemos la reunión con Brisenta."))
  }

  @Test func rejectsAnsweringTheQuestion() {
    #expect(!guardian.accepts(input: "¿Qué hora es en Tokio ahora mismo?",
                              output: "En Tokio ahora mismo son las 10:00 AM."))
    #expect(!guardian.accepts(input: "cuál es la capital de Francia",
                              output: "La capital de Francia es París."))
  }

  @Test func rejectsTooShortOrTooLong() {
    #expect(!guardian.accepts(input: "necesito que me mandes el informe de ventas del trimestre", output: "Vale."))
    #expect(!guardian.accepts(input: "hola", output: "Hola, ¿en qué puedo ayudarte hoy? Estoy aquí para lo que necesites."))
    #expect(guardian.accepts(input: "vale", output: "Vale."))
  }

  @Test func allowsDictionaryTermsAsNewWords() {
    #expect(guardian.accepts(input: "subir los datos del brosanta", output: "Subir los datos de Brisenta.",
                             allowedNewWords: ["Brisenta"]))
  }

  @Test func acceptsRemovingRepetitionsDownToThirtyPercent() {
    let dictated = "lo que te quería decir es que el pedido del cliente de Valencia, el pedido de Valencia, no ha llegado, "
      + "que no ha llegado todavía"
    #expect(guardian.accepts(input: dictated, output: "El pedido del cliente de Valencia no ha llegado todavía."))  // 44 %
    #expect(!guardian.accepts(input: dictated, output: "No ha llegado."))  // 11 %
  }

  @Test func allowsAQuarterOfNewWords() {
    #expect(guardian.accepts(input: "mañana llamo al proveedor por el pedido",
                             output: "Mañana llamo seguro al proveedor por el pedido."))  // 1 de 5
    #expect(!guardian.accepts(input: "mañana llamo al proveedor por el pedido",
                              output: "Mañana llamo sin falta al proveedor por el pedido."))  // 2 de 6
  }

  @Test func listMarkersAreNotNewWords() {
    #expect(guardian.accepts(input: "primero abre el terminal luego ejecuta swift build y después lanza los tests",
                             output: "1. Abre el terminal.\n2. Ejecuta swift build.\n3. Lanza los tests."))
  }
}

@Suite struct ChunkerTests {
  @Test func shortTextIsOneChunk() {
    #expect(Chunker.split("Hola. Adiós.", maxChars: 100) == ["Hola. Adiós."])
    #expect(Chunker.split("   ", maxChars: 100) == [])
  }

  @Test func splitsBetweenSentences() {
    let text = "Uno dos tres cuatro. Cinco seis siete ocho. Nueve diez once doce."
    let chunks = Chunker.split(text, maxChars: 25)
    #expect(chunks == ["Uno dos tres cuatro.", "Cinco seis siete ocho.", "Nueve diez once doce."])
  }

  @Test func splitsHugeSentenceBetweenWords() {
    let chunks = Chunker.split("palabra palabra palabra palabra palabra", maxChars: 16)
    #expect(chunks.allSatisfy { $0.count <= 16 })
    #expect(chunks.joined(separator: " ") == "palabra palabra palabra palabra palabra")
  }
}
