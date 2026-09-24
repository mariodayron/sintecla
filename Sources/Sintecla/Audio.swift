import AudioToolbox
import AVFoundation
import Speech

/// Micrófono → búferes en el formato que pide el transcriptor (16 kHz mono Int16).
///
/// Usa una AudioQueue de solo entrada con el micrófono que macOS tenga en cada grabación (el del
/// Mac, unos AirPods…). No usa AVAudioEngine: con unos AirPods junta su entrada (perfil de llamada)
/// y su salida (música) en un dispositivo agregado que no llega a arrancar. Probado con AirPods Pro:
/// AVAudioEngine, 0 muestras; AudioQueue, primer audio a los 0,25 s.
final class AudioCapture: @unchecked Sendable {
  /// Abrir y cerrar el micrófono puede tardar (Bluetooth): nunca en el hilo principal, que es el del teclado.
  private let control = DispatchQueue(label: "local.sintecla.audio.control")
  private let callbacks = DispatchQueue(label: "local.sintecla.audio.buffers")
  private let lock = NSLock()
  private var audioQueue: AudioQueueRef?  // solo en `control`
  private var running = false
  private var gainValue: Float = 1

  /// Ganancia digital (modo susurro ≈ 3,2 = +10 dB). Se aplica con limitador.
  var gain: Float {
    get { lock.withLock { gainValue } }
    set { lock.withLock { gainValue = newValue } }
  }
  /// Se llaman en un hilo de fondo.
  var onBuffer: ((AVAudioPCMBuffer) -> Void)?
  var onLevel: ((Float) -> Void)?

  /// Abre el micrófono en segundo plano y entrega el audio ya en `format`. Si no se puede, llama a `onFailure`.
  func start(format: AVAudioFormat, onFailure: @escaping () -> Void) {
    control.async { [self] in
      guard audioQueue == nil else { return }
      var description = format.streamDescription.pointee
      var queue: AudioQueueRef?
      let status = AudioQueueNewInputWithDispatchQueue(&queue, &description, 0, callbacks) { [weak self] queue, buffer, _, _, _ in
        self?.deliver(buffer, from: queue, format: format)
      }
      guard status == noErr, let queue else { return onFailure() }
      // Tres búferes de 100 ms.
      let bytes = UInt32(format.sampleRate / 10) * description.mBytesPerFrame
      for _ in 0..<3 {
        var buffer: AudioQueueBufferRef?
        if AudioQueueAllocateBuffer(queue, bytes, &buffer) == noErr, let buffer {
          AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
        }
      }
      lock.withLock { running = true }
      guard AudioQueueStart(queue, nil) == noErr else {
        lock.withLock { running = false }
        AudioQueueDispose(queue, true)
        return onFailure()
      }
      audioQueue = queue
    }
  }

  func stop() {
    control.async { [self] in
      guard let queue = audioQueue else { return }
      lock.withLock { running = false }
      AudioQueueStop(queue, true)
      AudioQueueDispose(queue, true)
      audioQueue = nil
    }
  }

  private func deliver(_ buffer: AudioQueueBufferRef, from queue: AudioQueueRef, format: AVAudioFormat) {
    guard lock.withLock({ running }) else { return }
    let bytes = Int(buffer.pointee.mAudioDataByteSize)
    let frames = AVAudioFrameCount(bytes / Int(format.streamDescription.pointee.mBytesPerFrame))
    if frames > 0, let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
       let data = pcm.mutableAudioBufferList.pointee.mBuffers.mData {
      pcm.frameLength = frames
      memcpy(data, buffer.pointee.mAudioData, bytes)
      applyGain(to: pcm)
      onBuffer?(pcm)
    }
    AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
  }

  /// Ganancia con limitador y nivel para la pastilla (Int16 o Float32).
  private func applyGain(to buffer: AVAudioPCMBuffer) {
    let gain = self.gain
    let frames = Int(buffer.frameLength)
    var sumOfSquares: Float = 0
    if let samples = buffer.int16ChannelData?[0] {
      for i in 0..<frames {
        if gain != 1 { samples[i] = Int16(clamping: Int((Float(samples[i]) * gain).rounded())) }
        let value = Float(samples[i]) / 32768
        sumOfSquares += value * value
      }
    } else if let samples = buffer.floatChannelData?[0] {
      for i in 0..<frames {
        if gain != 1 { samples[i] = max(-1, min(1, samples[i] * gain)) }
        sumOfSquares += samples[i] * samples[i]
      }
    }
    let rms = frames > 0 ? (sumOfSquares / Float(frames)).squareRoot() : 0
    onLevel?(min(1, rms * 8))
  }
}

enum AudioConversion {
  /// Convierte un búfer completo al formato destino (p. ej. 48 kHz Float32 → 16 kHz Int16).
  static func convert(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter,
                      to target: AVAudioFormat) -> AVAudioPCMBuffer? {
    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * target.sampleRate / buffer.format.sampleRate) + 64
    guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
    nonisolated(unsafe) var delivered = false
    var error: NSError?
    converter.convert(to: output, error: &error) { _, status in
      if delivered {
        status.pointee = .noDataNow
        return nil
      }
      delivered = true
      status.pointee = .haveData
      return buffer
    }
    return error == nil && output.frameLength > 0 ? output : nil
  }
}

/// Una sesión de dictado: recibe audio en streaming y devuelve el texto final.
final class TranscriptionSession: @unchecked Sendable {
  private let transcriber: SpeechTranscriber
  private let analyzer: SpeechAnalyzer
  private let stream: AsyncStream<AnalyzerInput>
  private let continuation: AsyncStream<AnalyzerInput>.Continuation
  private let contextualStrings: [String]
  private let lock = NSLock()
  private var frames: AVAudioFramePosition = 0
  private var sampleRate: Double = 16_000
  private var finalText = ""
  private var finalHandler: ((String) -> Void)?
  private var startTask: Task<Void, Error>?
  private var resultsTask: Task<String, Error>?

  init(locale: Locale, contextualStrings: [String]) {
    transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
    analyzer = SpeechAnalyzer(modules: [transcriber])
    (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
    self.contextualStrings = contextualStrings
  }

  /// Formato de audio que espera el transcriptor (16 kHz mono Int16 en macOS 26).
  static func audioFormat(for locale: Locale) async -> AVAudioFormat? {
    let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
    return await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
  }

  /// Descarga el modelo de voz del idioma si aún no está instalado.
  static func ensureAssets(for locale: Locale) async throws {
    let installed = await SpeechTranscriber.installedLocales
    if installed.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) { return }
    let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
    if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
      try await request.downloadAndInstall()
    }
  }

  /// Empieza a consumir el audio (el que llegue antes se guarda en el stream).
  func begin() {
    let transcriber = self.transcriber
    let analyzer = self.analyzer
    let stream = self.stream
    let strings = contextualStrings
    resultsTask = Task { [self] in
      for try await result in transcriber.results where result.isFinal {
        let piece = String(result.text.characters)
        lock.withLock {
          finalText += piece
          finalHandler?(piece)
        }
      }
      return lock.withLock { finalText }
    }
    startTask = Task {
      if !strings.isEmpty {
        let context = AnalysisContext()
        context.contextualStrings[.general] = strings
        try await analyzer.setContext(context)
      }
      try await analyzer.start(inputSequence: stream)
    }
  }

  /// Notas: recibe enseguida lo ya reconocido y después cada frase final nueva, en orden
  /// y en un hilo de fondo.
  func observeFinals(_ handler: @escaping (String) -> Void) {
    lock.withLock {
      finalHandler = handler
      if !finalText.isEmpty { handler(finalText) }
    }
  }

  func append(_ buffer: AVAudioPCMBuffer) {
    lock.withLock {
      frames += AVAudioFramePosition(buffer.frameLength)
      sampleRate = buffer.format.sampleRate
    }
    continuation.yield(AnalyzerInput(buffer: buffer))
  }

  var audioSeconds: Double {
    lock.withLock { Double(frames) / sampleRate }
  }

  func finish() async throws -> String {
    continuation.finish()
    try await startTask?.value
    try await analyzer.finalizeAndFinishThroughEndOfInput()
    let text = try await resultsTask?.value ?? ""
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func cancel() async {
    continuation.finish()
    _ = try? await startTask?.value
    await analyzer.cancelAndFinishNow()
    resultsTask?.cancel()
  }
}
