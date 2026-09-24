import AVFoundation
import Foundation
import SinteclaCore

/// Modos de prueba sin micrófono (para comprobaciones automáticas), con la clave y el modelo de los Ajustes:
///   Sintecla --transcribe audio.aiff [es_ES|en_US]
///   Sintecla --translate "texto"            (al idioma de Ajustes → General → Traducir a)
///   Sintecla --ask "orden" ["texto seleccionado"]
///   Sintecla --rewrite "texto" [formal|informal|technical|neutral]   (el dictado como en la app: Gemini si hay clave)
///   Sintecla --rewrite-bench [ruta.json]    (banco de ordenar, por defecto Resources/eval/ordenar_es.json)
///   Sintecla --notes transcripcion.txt
///   Sintecla --gemini-check                 (texto y los dos esquemas JSON, con el error completo si falla)
///   Sintecla --ask-bench                    (10 preguntas seguidas, como dentro de la app: latencia y mediana)
///   Sintecla --mic-test [segundos]          (abre el micrófono; lanzar con `open`, ver `micTest`)
///   Sintecla --meeting-summary transcripcion.jsonl       (acta en Markdown de una reunión ya transcrita)
///   Sintecla --meeting-pdf transcripcion.jsonl acta.pdf  (la misma acta en PDF)
///   Sintecla --meeting-record segundos carpeta           (reunión real con el grabador; lanzar con `open`)
///   Sintecla --make-icon carpeta.iconset                 (PNG del icono; lo usa scripts/make-icon.sh)
enum DebugCommands {
  static let usage = """
    Uso: Sintecla --transcribe audio.aiff [es_ES|en_US] | --translate "texto" | --ask "orden" ["selección"]
                  | --rewrite "texto" [tono] | --rewrite-bench [ruta.json]
                  | --notes transcripcion.txt | --gemini-check | --ask-bench | --mic-test [segundos]
                  | --meeting-summary transcripcion.jsonl | --meeting-pdf transcripcion.jsonl acta.pdf
                  | --meeting-record segundos carpeta | --make-icon carpeta.iconset
    """

  /// nil = arrancar la app normal. Una opción "--" desconocida o incompleta muestra el uso (nunca abre la app).
  static func command(for arguments: [String]) -> (@MainActor () async -> String)? {
    guard arguments.count >= 2, arguments[1].hasPrefix("--") else { return nil }
    let rest = Array(arguments.dropFirst(2))
    let first = rest.first ?? ""
    let second = rest.count > 1 ? rest[1] : nil
    switch arguments[1] {
    case "--transcribe" where !rest.isEmpty: return { await transcribe(path: first, language: second ?? "es_ES") }
    case "--translate" where !rest.isEmpty: return { await translate(first) }
    case "--ask" where !rest.isEmpty: return { await ask(first, selection: second) }
    case "--rewrite" where !rest.isEmpty: return { await rewrite(first, tone: second) }
    case "--rewrite-bench": return { await rewriteBench(path: rest.first) }
    case "--notes" where !rest.isEmpty: return { await notes(path: first) }
    case "--gemini-check": return { await geminiCheck() }
    case "--ask-bench": return { await askBench() }
    case "--mic-test": return { await micTest(seconds: Double(first) ?? 3) }
    case "--meeting-summary" where !rest.isEmpty: return { await meetingSummary(path: first) }
    case "--meeting-pdf" where rest.count >= 2: return { await meetingPDF(path: first, output: rest[1]) }
    case "--meeting-record" where rest.count >= 2: return { await meetingRecord(seconds: Double(first) ?? 30, folder: rest[1]) }
    case "--make-icon" where !rest.isEmpty: return { makeIcon(folder: first) }
    default: return { usage }
    }
  }

  /// `Sintecla --mic-test [segundos]`: abre el micrófono como al dictar y mide cuándo llega el audio.
  /// Hay que lanzarlo con `open` para que use el permiso de micrófono de Sintecla:
  ///   open -n -W --stdout /tmp/mic.txt /Applications/Sintecla.app --args --mic-test 3
  static func micTest(seconds: Double) async -> String {
    guard let format = await TranscriptionSession.audioFormat(for: Locale(identifier: "es_ES")) else {
      return "ERROR: sin formato de audio"
    }
    final class Stats: @unchecked Sendable {
      let lock = NSLock()
      var first: Double?
      var frames = 0
      var peak: Float = 0
      var failed = false
    }
    let stats = Stats()
    let start = Date()
    let capture = AudioCapture()
    capture.onBuffer = { buffer in
      stats.lock.withLock {
        if stats.first == nil { stats.first = Date().timeIntervalSince(start) }
        stats.frames += Int(buffer.frameLength)
      }
    }
    capture.onLevel = { level in stats.lock.withLock { stats.peak = max(stats.peak, level) } }
    capture.start(format: format) { stats.lock.withLock { stats.failed = true } }
    try? await Task.sleep(for: .seconds(seconds))
    capture.stop()
    return stats.lock.withLock {
      let first = stats.first.map { String(format: "%.0f ms", $0 * 1000) } ?? "nunca"
      return String(format: "Micrófono: %@ · primer audio: %@ · %.1f s de audio · nivel máx %.2f%@",
                    AudioDevices.defaultInputName() ?? "?", first, Double(stats.frames) / format.sampleRate,
                    stats.peak, stats.failed ? " · ERROR al abrir" : "")
    }
  }

  /// `Sintecla --meeting-summary transcripcion.jsonl`: acta con Gemini de una reunión ya transcrita (latencia y Markdown).
  @MainActor static func meetingSummary(path: String) async -> String {
    let settings = AppSettings()
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return "ERROR: no se pudo leer \(path)" }
    guard let model = settings.cloudModel(timeout: 120) else { return "Sin clave de Gemini (Ajustes → IA)" }
    let segments = MeetingTranscript.removingEcho(MeetingTranscript.parse(text))
    let start = Date()
    do {
      let summary = try await MeetingSummarizer.summarize(segments, model: model, style: settings.myStyle)
      let ms = Int(Date().timeIntervalSince(start) * 1000)
      return "[gemini · \(ms) ms · \(segments.count) frases]\n" + MeetingRenderer.markdown(summary, date: Date(), duration: segments.last?.fin ?? 0)
    } catch {
      return "ERROR: \(error)"
    }
  }

  /// `Sintecla --meeting-pdf transcripcion.jsonl acta.pdf`: acta con Gemini → HTML → PDF.
  @MainActor static func meetingPDF(path: String, output: String) async -> String {
    let settings = AppSettings()
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return "ERROR: no se pudo leer \(path)" }
    guard let model = settings.cloudModel(timeout: 120) else { return "Sin clave de Gemini (Ajustes → IA)" }
    let segments = MeetingTranscript.removingEcho(MeetingTranscript.parse(text))
    do {
      let start = Date()
      let summary = try await MeetingSummarizer.summarize(segments, model: model, style: settings.myStyle)
      let ms = Int(Date().timeIntervalSince(start) * 1000)
      let html = MeetingRenderer.html(summary, date: Date(), duration: segments.last?.fin ?? 0, segments: segments)
      let pdfStart = Date()
      try await PDFRenderer().render(html: html, to: URL(fileURLWithPath: output))
      let pdfMs = Int(Date().timeIntervalSince(pdfStart) * 1000)
      return "[gemini \(ms) ms · PDF \(pdfMs) ms] \(output)"
    } catch {
      return "ERROR: \(error)"
    }
  }

  /// `Sintecla --meeting-record segundos carpeta`: una reunión de verdad (micro + sistema) con el grabador de la app,
  /// guardada en `carpeta` (no en tus Documentos). Lanzarlo con `open` para que use los permisos de Sintecla.
  @MainActor static func meetingRecord(seconds: Double, folder: String) async -> String {
    let settings = AppSettings()
    let base = URL(fileURLWithPath: folder)
    let library = MeetingLibrary(store: MeetingStore(directory: base.appendingPathComponent("meetings")))
    let recorder = MeetingRecorder(settings: settings, library: library, minutesDirectory: base.appendingPathComponent("actas"))
    guard let format = await TranscriptionSession.audioFormat(for: Locale(identifier: settings.language)) else {
      return "ERROR: sin formato de audio"
    }
    var live: [String] = []
    var peak: Float = 0
    recorder.onLiveText = { live.append($0) }
    recorder.onLevel = { peak = max(peak, $0) }
    do { try recorder.start(format: format) } catch { return "ERROR al empezar: \(error)" }
    try? await Task.sleep(for: .seconds(seconds))
    let stopAt = Date()
    let outcome = await recorder.stop()
    let ms = Int(Date().timeIntervalSince(stopAt) * 1000)
    let head = String(format: "frases en vivo: %d · nivel máx %.2f · acta en %d ms", live.count, peak, ms)
    switch outcome {
    case .ready(let record, _): return "\(head)\nLISTA · \(record.title ?? "") · \(record.tasks) tareas\n\(record.pdfPath ?? "")"
    case .pending(let record): return "\(head)\nPENDIENTE: \(record.problem ?? "")"
    case .empty: return "\(head)\nVACÍA"
    }
  }

  static func transcribe(path: String, language: String) async -> String {
    let locale = Locale(identifier: language)
    do {
      try await TranscriptionSession.ensureAssets(for: locale)
      guard let format = await TranscriptionSession.audioFormat(for: locale) else { return "ERROR: sin formato de audio" }
      let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
      guard let converter = AVAudioConverter(from: file.processingFormat, to: format) else { return "ERROR: sin conversor" }
      let session = TranscriptionSession(locale: locale, contextualStrings: [])
      session.begin()
      while file.framePosition < file.length {
        guard let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096) else { break }
        try file.read(into: input)
        if let output = AudioConversion.convert(input, using: converter, to: format) { session.append(output) }
      }
      return try await session.finish()
    } catch {
      return "ERROR: \(error)"
    }
  }

  @MainActor
  static func translate(_ text: String) async -> String {
    let settings = AppSettings()
    let recording = Recording(mode: .translation, raw: text, audioSeconds: 0, target: (nil, nil),
                              language: settings.language, selection: nil, releasedAt: Date())
    return await run(recording, settings: settings)
  }

  @MainActor
  static func ask(_ command: String, selection: String?) async -> String {
    let settings = AppSettings()
    let recording = Recording(mode: .ask, raw: command, audioSeconds: 0, target: (nil, nil), language: settings.language,
                              selection: selection.map { Selection(text: $0, editable: true) }, releasedAt: Date())
    return await run(recording, settings: settings)
  }

  /// `Sintecla --rewrite "texto" [tono]`: motor, milisegundos, el error de Gemini si lo hubo y el texto.
  @MainActor
  static func rewrite(_ text: String, tone: String?) async -> String {
    let settings = AppSettings()
    let start = Date()
    let result = await rewriter(settings).rewrite(text, tone: Tone(rawValue: tone ?? "") ?? .neutral, style: settings.myStyle)
    let ms = Int(Date().timeIntervalSince(start) * 1000)
    let error = result.cloudError.map { " · " + $0.userMessage } ?? ""
    return "[\(result.engine.rawValue) · \(ms) ms\(error)] \(result.text)"
  }

  /// `Sintecla --rewrite-bench [ruta.json]`: el banco de ordenar por el camino de la app. Solo manda los casos inventados.
  @MainActor
  static func rewriteBench(path: String?) async -> String {
    let settings = AppSettings()
    let file = path ?? "Resources/eval/ordenar_es.json"
    guard let samples = try? EvalBench.load(file) else { return "ERROR: no se pudo leer \(file)" }
    let rewriter = rewriter(settings)
    if rewriter.cloud == nil { return "Sin Gemini: falta la clave o «Ordenar el dictado con Gemini» está apagado (Ajustes → IA)" }
    var lines: [String] = []
    var passed = 0
    var latencies: [Double] = []
    for sample in samples {
      let start = Date()
      let result = await rewriter.rewrite(sample.entrada, tone: sample.tono ?? .neutral, style: settings.myStyle)
      latencies.append(Date().timeIntervalSince(start))
      let problems = EvalBench.problems(in: result.text, for: sample)
      if problems.isEmpty { passed += 1 }
      let error = result.cloudError.map { " · " + $0.userMessage } ?? ""
      lines.append("\(problems.isEmpty ? "✔" : "✘") [\(result.engine.rawValue)\(error)] \(sample.entrada)\n    → \(result.text)")
      if !problems.isEmpty { lines.append("    " + problems.joined(separator: ", ")) }
    }
    lines.append(EvalBench.summary(passed: passed, total: samples.count, latencies: latencies))
    return lines.joined(separator: "\n")
  }

  /// El de la app, con el modelo de Apple de respaldo.
  @MainActor
  private static func rewriter(_ settings: AppSettings) -> DictationRewriter {
    ModeRunner(settings: settings, appleModel: AppleTextModel.isAvailable ? AppleTextModel() : nil).rewriter()
  }

  @MainActor
  static func notes(path: String) async -> String {
    let settings = AppSettings()
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return "ERROR: no se pudo leer \(path)" }
    let recording = Recording(mode: .notes, raw: text, audioSeconds: 0, target: (nil, nil), language: settings.language,
                              selection: nil, releasedAt: Date())
    return await run(recording, settings: settings)
  }

  @MainActor
  static func geminiCheck() async -> String {
    guard let model = AppSettings().cloudModel(timeout: 60) else { return "Sin clave de Gemini (Ajustes → IA)" }
    var lines = ["Modelo: \(model.config.model)"]
    func step(_ name: String, _ body: () async throws -> String) async {
      let start = Date()
      do {
        let reply = try await body()
        lines.append("✔ \(name) (\(Int(Date().timeIntervalSince(start) * 1000)) ms): \(reply.prefix(300))")
      } catch {
        lines.append("✘ \(name): \(error)")
      }
    }
    await step("Texto") { try await model.complete(instructions: "Responde solo con la palabra OK.", prompt: "ping") }
    await step("JSON acción web") {
      let data = try await model.completeJSON(instructions: PromptLibrary.webActionInstructions,
                                              prompt: "pon la última canción de Rosalía", schemaName: "accion_web",
                                              schema: WebAction.jsonSchema)
      return String(decoding: data, as: UTF8.self)
    }
    await step("JSON notas") {
      let data = try await model.completeJSON(instructions: PromptLibrary.notesInstructions(style: ""),
                                              prompt: PromptLibrary.wrap("hay que pedir los radiadores y no sé si contratar a otro oficial"),
                                              schemaName: "notas", schema: NotesDocument.jsonSchema)
      return String(decoding: data, as: UTF8.self)
    }
    return lines.joined(separator: "\n")
  }

  /// Mide Ask Anything como dentro de la app: un solo proceso, conexión y clave ya abiertas tras la primera.
  @MainActor
  static func askBench() async -> String {
    let settings = AppSettings()
    let questions = [
      "cuál es la capital de Australia", "qué es la aerotermia", "cuántos días tiene un año bisiesto",
      "quién escribió el Quijote", "qué significa IVA", "cómo se dice presupuesto en inglés",
      "qué es un kilovatio hora", "para qué sirve un diferencial eléctrico", "qué es una factura proforma",
      "cuál es la diferencia entre CIF y NIF",
    ]
    var lines: [String] = []
    var times: [Int] = []
    for question in questions {
      let recording = Recording(mode: .ask, raw: question, audioSeconds: 0, target: (nil, nil),
                                language: settings.language, selection: nil, releasedAt: Date())
      let (_, entry) = await ModeRunner(settings: settings, appleModel: nil).run(recording)
      let ms = Int(Date().timeIntervalSince(recording.releasedAt) * 1000)
      times.append(ms)
      lines.append("\(entry?.engine ?? "fallo") · \(ms) ms · \(question)")
    }
    let sorted = times.sorted()
    lines.append("Mediana: \((sorted[4] + sorted[5]) / 2) ms (objetivo ≤ 2500)")
    return lines.joined(separator: "\n")
  }

  /// `Sintecla --make-icon carpeta.iconset`: los PNG del icono que junta `iconutil` (scripts/make-icon.sh).
  static func makeIcon(folder: String) -> String {
    let url = URL(fileURLWithPath: folder)
    do {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
      for file in BrandMarkRenderer.iconFiles {
        guard let png = BrandMarkRenderer.iconPNG(pixels: file.pixels) else { return "ERROR: no se pudo dibujar \(file.name)" }
        try png.write(to: url.appendingPathComponent(file.name))
      }
    } catch {
      return "ERROR: \(error.localizedDescription)"
    }
    return "\(BrandMarkRenderer.iconFiles.count) PNG en \(folder)"
  }

  @MainActor
  private static func run(_ recording: Recording, settings: AppSettings) async -> String {
    let model: AppleTextModel? = AppleTextModel.isAvailable ? AppleTextModel() : nil
    let (output, entry) = await ModeRunner(settings: settings, appleModel: model).run(recording)
    let ms = Int(Date().timeIntervalSince(recording.releasedAt) * 1000)
    return "[\(entry?.engine ?? "-") · \(ms) ms] \(output)"
  }
}
