import AVFoundation
import CoreMedia
import Speech

/// Transcribe una pista de una reunión (micro o sistema) y entrega cada frase final con su tiempo,
/// en segundos desde el inicio de la reunión. Se llama en un hilo de fondo.
final class MeetingTrack: @unchecked Sendable {
  private let transcriber: SpeechTranscriber
  private let analyzer: SpeechAnalyzer
  private let stream: AsyncStream<AnalyzerInput>
  private let continuation: AsyncStream<AnalyzerInput>.Continuation
  private let lock = NSLock()
  /// Dónde empezaría el siguiente búfer si llega seguido, en segundos de reunión.
  private var expected: Double?
  private var startTask: Task<Void, Error>?
  private var resultsTask: Task<Void, Error>?
  var onSegment: ((_ start: Double, _ end: Double, _ text: String) -> Void)?

  /// Un hueco mayor que este (el audio llega tarde respecto al reloj) se marca con su tiempo real.
  static let gap = 0.3

  init(locale: Locale) {
    transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
    analyzer = SpeechAnalyzer(modules: [transcriber])
    (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
  }

  func begin() {
    let transcriber = self.transcriber
    let analyzer = self.analyzer
    let stream = self.stream
    resultsTask = Task { [self] in
      for try await result in transcriber.results where result.isFinal {
        let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { continue }
        onSegment?(result.range.start.seconds, result.range.end.seconds, text)
      }
    }
    startTask = Task { try await analyzer.start(inputSequence: stream) }
  }

  /// `arrival`: segundos de reunión en que llegó el búfer (su final). Las dos pistas usan el mismo reloj; si el audio
  /// llega seguido no se marca (el analizador lo encadena) y solo los huecos llevan su tiempo.
  func append(_ buffer: AVAudioPCMBuffer, arrival: Double) {
    let duration = Double(buffer.frameLength) / buffer.format.sampleRate
    let measured = max(0, arrival - duration)
    let startTime: CMTime? = lock.withLock {
      if let expected, measured - expected < Self.gap {
        self.expected = expected + duration
        return nil
      }
      expected = measured + duration
      return CMTime(seconds: measured, preferredTimescale: 16_000)
    }
    continuation.yield(AnalyzerInput(buffer: buffer, bufferStartTime: startTime))
  }

  func finish() async throws {
    continuation.finish()
    try await startTask?.value
    try await analyzer.finalizeAndFinishThroughEndOfInput()
    try await resultsTask?.value
  }
}
