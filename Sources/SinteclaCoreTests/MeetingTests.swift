import Foundation
import Testing
@testable import SinteclaCore

private func me(_ t: Double, _ fin: Double, _ texto: String) -> MeetingSegment {
  MeetingSegment(t: t, fin: fin, pista: MeetingSegment.me, texto: texto)
}

private func others(_ t: Double, _ fin: Double, _ texto: String) -> MeetingSegment {
  MeetingSegment(t: t, fin: fin, pista: MeetingSegment.others, texto: texto)
}

@Suite struct MeetingTranscriptTests {
  @Test func lineAndParseRoundTripSortedByTime() {
    let a = others(12.5, 15, "Te paso la ficha hoy.")
    let b = me(3, 5.25, "Empezamos con la obra.")
    #expect(MeetingTranscript.line(b) == #"{"fin":5.25,"pista":"Tú","t":3,"texto":"Empezamos con la obra."}"#)
    let jsonl = MeetingTranscript.line(a) + "\n" + MeetingTranscript.line(b) + "\n"
    #expect(MeetingTranscript.parse(jsonl) == [b, a])
  }

  @Test func parseSkipsBrokenLinesAndDefaultsEndToStart() {
    let jsonl = """
      {"t": 1, "pista": "Otros", "texto": "Hola."}

      {"t": 2, "pista": "Tú", "tex
      """
    #expect(MeetingTranscript.parse(jsonl) == [others(1, 1, "Hola.")])
  }

  @Test func removesMicEchoOfOthers() {
    let segments = [
      others(10, 14, "Mañana revisamos la caldera de la calle Mayor."),
      me(10.4, 14.2, "mañana revisamos la caldera de la calle mayor"),
      me(20, 23, "Vale, yo llevo los radiadores."),
    ]
    #expect(MeetingTranscript.removingEcho(segments) == [segments[0], segments[2]])
  }

  @Test func keepsShortRepliesAndDistantRepeats() {
    let segments = [
      others(10, 12, "Vale, perfecto."),
      me(10.5, 11, "vale perfecto"),
      others(30, 33, "Mañana revisamos la caldera."),
      me(40, 43, "Mañana revisamos la caldera."),
    ]
    #expect(MeetingTranscript.removingEcho(segments) == segments)
  }

  @Test func promptTextHasClockAndTrack() {
    let text = MeetingTranscript.promptText([me(5, 7, "Empezamos."), others(65.9, 68, "Vale.")])
    #expect(text == "[00:05] Tú: Empezamos.\n[01:05] Otros: Vale.")
  }

  @Test func clockShowsHoursOnlyWhenNeeded() {
    #expect(MeetingTranscript.clock(0) == "00:00")
    #expect(MeetingTranscript.clock(599.9) == "09:59")
    #expect(MeetingTranscript.clock(3725) == "1:02:05")
    #expect(MeetingTranscript.clock(-3) == "00:00")
  }
}

@Suite struct MeetingSummaryTests {
  let summary = MeetingSummary(
    titulo: "Revisión de la obra de Alcobendas",
    participantes: ["Tú", "Lucía"],
    resumen: "Se revisa el avance y se reparten tareas.",
    temas: [MeetingSummary.Topic(titulo: "Caldera", puntos: ["Va al lavadero."]),
            MeetingSummary.Topic(titulo: "Vacío", puntos: [])],
    decisiones: ["Se pide la caldera de 25 kW."],
    tareas: [MeetingSummary.Task(responsable: "Lucía", tarea: "Pasar la ficha | técnica", fecha: "viernes")],
    dudas: ["¿Hace falta permiso de la comunidad?"],
    proximosPasos: ["Visita a la obra."])
  let date = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: .current,
                            year: 2026, month: 9, day: 23, hour: 10, minute: 30).date!

  @Test func decodesGeminiJSONWithSnakeCaseKey() throws {
    let json = #"""
      {"titulo": "T", "participantes": ["Tú"], "resumen": "R", "temas": [{"titulo": "A", "puntos": ["b"]}],
       "decisiones": [], "tareas": [{"responsable": "Tú", "tarea": "x", "fecha": ""}], "dudas": [], "proximos_pasos": ["p"]}
      """#
    let decoded = try JSONDecoder().decode(MeetingSummary.self, from: Data(json.utf8))
    #expect(decoded.proximosPasos == ["p"])
    #expect(decoded.tareas == [MeetingSummary.Task(responsable: "Tú", tarea: "x", fecha: "")])
  }

  @Test func rendersMarkdownWithOnlyFilledSections() {
    #expect(MeetingRenderer.markdown(summary, date: date, duration: 1250) == """
      # Revisión de la obra de Alcobendas

      *23 de septiembre de 2026, 10:30 · 21 min*

      **Participantes:** Tú, Lucía

      ## Resumen
      Se revisa el avance y se reparten tareas.

      ## Temas
      ### Caldera
      - Va al lavadero.

      ## Decisiones
      - Se pide la caldera de 25 kW.

      ## Tareas
      | Responsable | Tarea | Fecha |
      |---|---|---|
      | Lucía | Pasar la ficha / técnica | viernes |

      ## Dudas
      - ¿Hace falta permiso de la comunidad?

      ## Próximos pasos
      - Visita a la obra.

      """)
    #expect(MeetingRenderer.markdown(MeetingSummary(), date: date, duration: 30)
            == "# Reunión\n\n*23 de septiembre de 2026, 10:30 · menos de 1 min*\n")
  }

  @Test func durationTextRoundsToMinutesAndHours() {
    #expect(MeetingRenderer.durationText(9) == "menos de 1 min")
    #expect(MeetingRenderer.durationText(89) == "1 min")
    #expect(MeetingRenderer.durationText(1250) == "21 min")
    #expect(MeetingRenderer.durationText(3600) == "1 h")
    #expect(MeetingRenderer.durationText(3900) == "1 h 5 min")
  }

  @Test func htmlEscapesTextAndPutsTranscriptInAnnex() {
    var risky = summary
    risky.titulo = "Obra <A&B>"
    let html = MeetingRenderer.html(risky, date: date, duration: 1250, segments: [others(65, 66, "¿Y el \"permiso\"?")])
    #expect(html.contains("<h1>Obra &lt;A&amp;B&gt;</h1>"))
    #expect(html.contains(#"<span class="t">01:05</span> <span class="others">Otros</span> ¿Y el &quot;permiso&quot;?"#))
    #expect(html.contains(#"<section class="annex">"#))
    #expect(!html.contains("Vacío"))
    #expect(!MeetingRenderer.html(risky, date: date, duration: 1250, segments: []).contains("annex\">"))
  }

  @Test func summarizerSendsTranscriptAndDecodes() async throws {
    let cloud = FakeCloud()
    cloud.json = #"{"titulo": "Obra", "participantes": ["Tú"], "resumen": "", "temas": [], "decisiones": [], "tareas": [], "dudas": [], "proximos_pasos": []}"#
    let result = try await MeetingSummarizer.summarize([me(5, 7, "Empezamos.")], model: cloud, style: "")
    #expect(result.titulo == "Obra")
    #expect(cloud.prompts == ["<t>\n[00:05] Tú: Empezamos.\n</t>"])
  }

  @Test func summarizerRejectsInvalidJSON() async {
    let cloud = FakeCloud()
    cloud.json = #"{"titulo": 3}"#
    await #expect(throws: CloudError.invalidResponse) {
      try await MeetingSummarizer.summarize([me(5, 7, "Empezamos.")], model: cloud, style: "")
    }
  }

  @Test func instructionsAddUserStyleOnlyWhenSet() {
    #expect(!PromptLibrary.meetingInstructions(style: " ").contains("Estilo del usuario"))
    #expect(PromptLibrary.meetingInstructions(style: "Tuteo, frases cortas").hasSuffix("\nEstilo del usuario: Tuteo, frases cortas."))
  }
}

@Suite struct MeetingStoreTests {
  let store = MeetingStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("meetings-\(UUID().uuidString)"))
  let start = Date(timeIntervalSince1970: 1_790_000_000)

  @Test func createsUniqueFoldersAndListsNewestFirst() throws {
    let a = try store.create(startedAt: start)
    let b = try store.create(startedAt: start)
    let c = try store.create(startedAt: start.addingTimeInterval(60))
    #expect(b.id == a.id + "-2")
    #expect(store.all().first?.id == c.id)
    #expect(Set(store.all().map(\.id)) == [a.id, b.id, c.id])
    #expect(store.record(a.id)?.status == .recording)
    try store.delete(a.id)
    #expect(store.record(a.id) == nil)
  }

  @Test func appendsSegmentsAsTheyArrive() throws {
    let record = try store.create(startedAt: start)
    store.append(me(1, 2, "Uno."), to: record.id)
    store.append(others(3, 4, "Dos."), to: record.id)
    #expect(store.segments(record.id) == [me(1, 2, "Uno."), others(3, 4, "Dos.")])
  }

  @Test func interruptedMeetingsBecomePendingWithTheirDuration() throws {
    var done = try store.create(startedAt: start)
    done.status = .ready
    try store.save(done)
    let cut = try store.create(startedAt: start.addingTimeInterval(120))
    store.append(me(1, 42.5, "Hasta aquí."), to: cut.id)
    let recovered = store.recoverInterrupted()
    #expect(recovered.map(\.id) == [cut.id])
    let saved = try #require(store.record(cut.id))
    #expect(saved.status == .pending)
    #expect(saved.duration == 42.5)
    #expect(saved.problem == "Sintecla se cerró durante la reunión")
    #expect(store.record(done.id)?.status == .ready)
  }

  @Test func fileNamesAreSortableAndFinderSafe() {
    let date = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: .current,
                              year: 2026, month: 9, day: 23, hour: 22, minute: 8).date!
    #expect(MeetingFiles.baseName(title: "Obra: fase 2/3 ¿ok?", date: date) == "2026-09-23 2208 – Obra fase 2 3 ¿ok")
    #expect(MeetingFiles.baseName(title: "  ", date: date) == "2026-09-23 2208 – Reunión")
  }
}
