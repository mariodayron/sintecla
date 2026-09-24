import AppKit
import AVFoundation
import SinteclaCore
import UserNotifications

/// Cómo acabó una reunión al procesarla.
enum MeetingOutcome {
  /// Acta hecha: la ficha (con las rutas del PDF y del Markdown) y el Markdown para el portapapeles.
  case ready(MeetingRecord, markdown: String)
  /// Sin acta por ahora (sin red, sin clave…): se puede reintentar desde la ventana.
  case pending(MeetingRecord)
  /// No se oyó nada: no queda reunión.
  case empty
}

/// Graba una reunión: tu micro ("Tú") y el audio del sistema ("Otros"), cada uno con su transcriptor. Cada frase
/// se guarda al momento en `transcript.jsonl`, así que un cierre inesperado no pierde lo grabado. Al terminar
/// quita el eco y hace el acta con Gemini (PDF y Markdown en Documentos › Sintecla › Reuniones).
@MainActor
final class MeetingRecorder {
  private let settings: AppSettings
  private let library: MeetingLibrary
  private let minutesDirectory: URL
  private var active: Active?
  /// Nivel de voz (el mayor de las dos pistas) y última frase reconocida, en el hilo principal.
  var onLevel: ((Float) -> Void)?
  var onLiveText: ((String) -> Void)?

  private final class Active: @unchecked Sendable {
    let start = Date()
    var record: MeetingRecord
    let me: MeetingTrack
    let others: MeetingTrack
    let mic = AudioCapture()
    let system = SystemAudioTap()
    let micAudio: MeetingAudioWriter?
    let systemAudio: MeetingAudioWriter?
    /// Las dos pistas escriben en el mismo archivo: una cola para no mezclar líneas.
    let writer = DispatchQueue(label: "local.sintecla.meeting.writer")
    let lock = NSLock()
    var micLevel: Float = 0
    var systemLevel: Float = 0

    init(record: MeetingRecord, locale: Locale, folder: URL, format: AVAudioFormat, saveAudio: Bool) {
      self.record = record
      me = MeetingTrack(locale: locale)
      others = MeetingTrack(locale: locale)
      micAudio = saveAudio ? MeetingAudioWriter(url: folder.appendingPathComponent("mic.m4a"), format: format) : nil
      systemAudio = saveAudio ? MeetingAudioWriter(url: folder.appendingPathComponent("sistema.m4a"), format: format) : nil
    }

    var seconds: Double { Date().timeIntervalSince(start) }
  }

  init(settings: AppSettings, library: MeetingLibrary, minutesDirectory: URL = AppPaths.minutesDirectory) {
    self.settings = settings
    self.library = library
    self.minutesDirectory = minutesDirectory
  }

  var isRecording: Bool { active != nil }

  func start(format: AVAudioFormat) throws {
    guard active == nil else { return }
    let store = library.store
    let record = try store.create()
    let active = Active(record: record, locale: Locale(identifier: settings.language), folder: store.folder(record.id),
                        format: format, saveAudio: settings.saveMeetingAudio)
    self.active = active
    for (track, name) in [(active.me, MeetingSegment.me), (active.others, MeetingSegment.others)] {
      track.onSegment = { [weak self] start, end, text in
        let segment = MeetingSegment(t: start, fin: end, pista: name, texto: text)
        active.writer.async { store.append(segment, to: record.id) }
        DispatchQueue.main.async { self?.onLiveText?(text) }
      }
      track.begin()
    }
    active.mic.onBuffer = { buffer in
      active.me.append(buffer, arrival: active.seconds)
      active.micAudio?.write(buffer)
    }
    active.mic.onLevel = { [weak self] level in
      let combined = active.lock.withLock { active.micLevel = level; return max(level, active.systemLevel) }
      DispatchQueue.main.async { self?.onLevel?(combined) }
    }
    active.system.onBuffer = { buffer in
      active.others.append(buffer, arrival: active.seconds)
      active.systemAudio?.write(buffer)
      let level = Self.level(of: buffer)
      active.lock.withLock { active.systemLevel = level }
    }
    active.mic.start(format: format) {}
    active.system.start(format: format) { _ in }
    library.recordingSince = active.start
    library.reload()
  }

  /// Termina la grabación (espera a las últimas frases) y hace el acta.
  func stop() async -> MeetingOutcome {
    guard let active else { return .empty }
    self.active = nil
    active.mic.stop()
    active.system.stop()
    try? await Task.sleep(for: .milliseconds(300))
    try? await active.me.finish()
    try? await active.others.finish()
    await withCheckedContinuation { continuation in active.writer.async { continuation.resume() } }
    active.micAudio?.close()
    active.systemAudio?.close()
    var record = active.record
    record.duration = active.seconds
    try? library.store.save(record)
    library.recordingSince = nil
    return await process(record)
  }

  /// Acta de una reunión ya grabada (al terminar o al reintentar una pendiente).
  func process(_ record: MeetingRecord) async -> MeetingOutcome {
    let store = library.store
    var record = record
    record.status = .processing
    record.problem = nil
    try? store.save(record)
    library.reload()
    defer { library.reload() }

    let segments = MeetingTranscript.removingEcho(store.segments(record.id))
    guard !segments.isEmpty else {
      try? store.delete(record.id)
      return .empty
    }
    if record.duration == 0, let last = segments.last { record.duration = last.fin }
    guard let model = settings.cloudModel(timeout: 120) else {
      return pending(record, "Sin clave de Gemini (Ajustes › IA)")
    }
    do {
      let summary = try await MeetingSummarizer.summarize(segments, model: model, style: settings.myStyle)
      let title = MeetingRenderer.title(summary)
      let folder = minutesDirectory
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let base = Self.freeName(MeetingFiles.baseName(title: title, date: record.startedAt), in: folder)
      let markdown = MeetingRenderer.markdown(summary, date: record.startedAt, duration: record.duration)
      let markdownURL = folder.appendingPathComponent(base + ".md")
      try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
      let pdfURL = folder.appendingPathComponent(base + ".pdf")
      let html = MeetingRenderer.html(summary, date: record.startedAt, duration: record.duration, segments: segments)
      try await PDFRenderer().render(html: html, to: pdfURL)
      record.status = .ready
      record.title = title
      record.tasks = summary.tareas.count
      record.pdfPath = pdfURL.path
      record.markdownPath = markdownURL.path
      try? store.save(record)
      return .ready(record, markdown: markdown)
    } catch let error as CloudError {
      return pending(record, error.userMessage)
    } catch {
      return pending(record, "No se pudo crear el acta")
    }
  }

  private func pending(_ record: MeetingRecord, _ problem: String) -> MeetingOutcome {
    var record = record
    record.status = .pending
    record.problem = problem
    try? library.store.save(record)
    return .pending(record)
  }

  /// "base", o "base (2)"… si ya hay un acta con ese nombre.
  static func freeName(_ base: String, in folder: URL) -> String {
    var name = base
    var n = 2
    while FileManager.default.fileExists(atPath: folder.appendingPathComponent(name + ".pdf").path) {
      name = "\(base) (\(n))"
      n += 1
    }
    return name
  }

  /// Nivel (0…1) de un búfer Int16 para la pastilla, con la misma escala que el micro.
  nonisolated static func level(of buffer: AVAudioPCMBuffer) -> Float {
    guard let samples = buffer.int16ChannelData?[0], buffer.frameLength > 0 else { return 0 }
    var sum: Float = 0
    for i in 0..<Int(buffer.frameLength) {
      let value = Float(samples[i]) / 32768
      sum += value * value
    }
    return min(1, (sum / Float(buffer.frameLength)).squareRoot() * 8)
  }
}

/// Audio de una pista en AAC (m4a), 16 kHz mono, para volver a escucharlo o transcribirlo.
final class MeetingAudioWriter: @unchecked Sendable {
  private let lock = NSLock()
  private var file: AVAudioFile?

  init?(url: URL, format: AVAudioFormat) {
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: format.sampleRate,
      AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 32_000,
    ]
    guard let file = try? AVAudioFile(forWriting: url, settings: settings, commonFormat: format.commonFormat,
                                      interleaved: format.isInterleaved) else { return nil }
    self.file = file
  }

  func write(_ buffer: AVAudioPCMBuffer) {
    lock.withLock { try? file?.write(from: buffer) }
  }

  func close() {
    lock.withLock { file = nil }
  }
}

/// Avisos del sistema (acta lista o pendiente). La primera vez macOS pide permiso.
enum Notifier {
  static func post(title: String, body: String) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      guard granted else { return }
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
  }
}
