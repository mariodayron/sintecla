import AudioToolbox
import AVFoundation
import CoreAudio

/// Audio que suena en el Mac (todas las apps salvo Sintecla), para las reuniones: un *process tap* de
/// Core Audio dentro de un dispositivo agregado privado. Entrega el audio ya en `format` (el del transcriptor).
final class SystemAudioTap: @unchecked Sendable {
  struct Failure: Error, CustomStringConvertible {
    let step: String
    let status: OSStatus
    var description: String { "\(step) (\(status))" }
  }

  /// Abrir y cerrar dispositivos puede tardar: nunca en el hilo principal.
  private let control = DispatchQueue(label: "local.sintecla.systemaudio.control")
  private let callbacks = DispatchQueue(label: "local.sintecla.systemaudio.buffers")
  private var tapID = AudioObjectID(kAudioObjectUnknown)
  private var aggregateID = AudioObjectID(kAudioObjectUnknown)
  private var procID: AudioDeviceIOProcID?
  private let ioLock = NSLock()
  /// Formato del audio que entrega el IOProc y su conversor (cambian si cambia la frecuencia del agregado).
  private var io: (format: AVAudioFormat, converter: AVAudioConverter)?
  private var rateListener: AudioObjectPropertyListenerBlock?
  /// Se llama en un hilo de fondo.
  var onBuffer: ((AVAudioPCMBuffer) -> Void)?

  func start(format: AVAudioFormat, onFailure: @escaping (Error) -> Void) {
    control.async { [self] in
      do {
        try open(format: format)
      } catch {
        close()
        onFailure(error)
      }
    }
  }

  func stop() {
    control.async { [self] in close() }
  }

  private func open(format: AVAudioFormat) throws {
    guard tapID == kAudioObjectUnknown else { return }
    let ownProcess = Self.processObject(pid: getpid())
    let tap = CATapDescription(stereoGlobalTapButExcludeProcesses: ownProcess.map { [$0] } ?? [])
    tap.uuid = UUID()
    tap.isPrivate = true
    tap.muteBehavior = .unmuted
    try check(AudioHardwareCreateProcessTap(tap, &tapID), "crear el tap")

    // Reloj: la salida interna del Mac (48 kHz fijos). La salida por defecto puede cambiar de frecuencia a mitad
    // de reunión (unos AirPods pasan a 24 kHz al abrir su micro) o desaparecer; el tap capta igualmente el
    // audio de todas las apps, suene por donde suene.
    let outputUID = try AudioDevices.builtInOutputUID() ?? Self.defaultOutputUID()
    let aggregate: [String: Any] = [
      kAudioAggregateDeviceNameKey: "Sintecla (reunión)",
      kAudioAggregateDeviceUIDKey: UUID().uuidString,
      kAudioAggregateDeviceMainSubDeviceKey: outputUID,
      kAudioAggregateDeviceIsPrivateKey: true,
      kAudioAggregateDeviceIsStackedKey: false,
      kAudioAggregateDeviceTapAutoStartKey: true,
      kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
      kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: tap.uuid.uuidString]],
    ]
    try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "crear el dispositivo agregado")

    try refreshFormat(target: format)
    var rateAddress = Self.nominalRateAddress
    let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in try? self?.refreshFormat(target: format) }
    AudioObjectAddPropertyListenerBlock(aggregateID, &rateAddress, callbacks, listener)
    rateListener = listener

    try check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, callbacks) { [weak self] _, input, _, _, _ in
      guard let self, let (tapFormat, converter) = self.ioLock.withLock({ self.io }),
            let buffer = AVAudioPCMBuffer(pcmFormat: tapFormat, bufferListNoCopy: input, deallocator: nil),
            buffer.frameLength > 0 else { return }
      guard let converted = AudioConversion.convert(buffer, using: converter, to: format) else { return }
      self.onBuffer?(converted)
    }, "crear el IOProc")
    try check(AudioDeviceStart(aggregateID, procID), "arrancar")
  }

  /// El IOProc entrega el audio a la frecuencia nominal del agregado (la de su reloj), aunque el formato del
  /// flujo diga otra: probado con 24 kHz (AirPods en llamada) y 44,1 kHz (salida del Mac), ambos anunciados como 48 kHz.
  private func refreshFormat(target: AVAudioFormat) throws {
    var description = try Self.inputFormat(of: aggregateID)
    var address = Self.nominalRateAddress
    var rate: Float64 = 0
    var size = UInt32(MemoryLayout<Float64>.size)
    try check(AudioObjectGetPropertyData(aggregateID, &address, 0, nil, &size, &rate), "frecuencia del agregado")
    if rate > 0 { description.mSampleRate = rate }
    guard let ioFormat = AVAudioFormat(streamDescription: &description),
          let converter = AVAudioConverter(from: ioFormat, to: target) else { throw Failure(step: "formato", status: -1) }
    ioLock.withLock { io = (ioFormat, converter) }
  }

  private static let nominalRateAddress = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyNominalSampleRate, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)

  private func close() {
    if let rateListener, aggregateID != kAudioObjectUnknown {
      var address = Self.nominalRateAddress
      AudioObjectRemovePropertyListenerBlock(aggregateID, &address, callbacks, rateListener)
    }
    rateListener = nil
    if aggregateID != kAudioObjectUnknown {
      if let procID {
        AudioDeviceStop(aggregateID, procID)
        AudioDeviceDestroyIOProcID(aggregateID, procID)
      }
      AudioHardwareDestroyAggregateDevice(aggregateID)
    }
    if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
    procID = nil
    aggregateID = AudioObjectID(kAudioObjectUnknown)
    tapID = AudioObjectID(kAudioObjectUnknown)
  }

  /// Formato del flujo de entrada de un dispositivo (el del agregado: el tap ya remuestreado a su reloj).
  private static func inputFormat(of device: AudioObjectID) throws -> AudioStreamBasicDescription {
    var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioObjectPropertyScopeInput,
                                             mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size)
    var streams = [AudioStreamID](repeating: 0, count: max(1, Int(size) / MemoryLayout<AudioStreamID>.size))
    if status == noErr { status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &streams) }
    guard status == noErr, size > 0 else { throw Failure(step: "flujos del agregado", status: status) }
    var formatAddress = AudioObjectPropertyAddress(mSelector: kAudioStreamPropertyVirtualFormat, mScope: kAudioObjectPropertyScopeGlobal,
                                                   mElement: kAudioObjectPropertyElementMain)
    var description = AudioStreamBasicDescription()
    size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    status = AudioObjectGetPropertyData(streams[0], &formatAddress, 0, nil, &size, &description)
    guard status == noErr else { throw Failure(step: "formato del agregado", status: status) }
    return description
  }

  private func check(_ status: OSStatus, _ step: String) throws {
    if status != noErr { throw Failure(step: step, status: status) }
  }

  /// Objeto de audio de un proceso (para excluir a Sintecla); nil si aún no ha usado el audio.
  private static func processObject(pid: pid_t) -> AudioObjectID? {
    var pid = pid
    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
                                             mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var object = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address,
                                            UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object)
    return status == noErr && object != kAudioObjectUnknown ? object : nil
  }

  private static func defaultOutputUID() throws -> String {
    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                             mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var device = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    var status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
    guard status == noErr else { throw Failure(step: "salida por defecto", status: status) }
    address.mSelector = kAudioDevicePropertyDeviceUID
    var uid: Unmanaged<CFString>?
    size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid)
    guard status == noErr, let uid else { throw Failure(step: "UID de la salida", status: status) }
    return uid.takeRetainedValue() as String
  }
}
