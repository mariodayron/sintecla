import CoreAudio
import Foundation
import SinteclaCore

/// Los AirPods sin permisos nuevos (spec «Estante y avisos» §4.3): al conectarse aparecen como dispositivo de audio
/// Bluetooth, y la batería sale de `system_profiler` (la vía Bluetooth directa pide el permiso de Bluetooth). Si están
/// conectados lo dice Core Audio, no `system_profiler`: este los sigue dando por conectados un rato después de
/// guardarlos en el estuche, y al sacarlos de nuevo no parecerían recién conectados.
@MainActor
final class AirPodsMonitor {
  /// Unos AirPods recién conectados (con la batería que haya tras los reintentos).
  var onConnect: ((AirPodsDevice) -> Void)?
  var onDisconnect: ((String) -> Void)?
  /// Cada minuto, mientras sigan conectados.
  var onBattery: ((AirPodsDevice) -> Void)?
  /// Los que ya estaban al arrancar.
  var onKnown: ((AirPodsDevice) -> Void)?

  /// Recién conectados puede que aún no den la batería: se vuelve a mirar a los 1, 3 y 6 s.
  static let retries: [Double] = [1, 3, 6]
  static let pollInterval: Duration = .seconds(60)

  private var listener: AudioObjectPropertyListenerBlock?
  /// Las direcciones Bluetooth de los dispositivos de audio conectados.
  private var connected: Set<String> = []
  private var pollTask: Task<Void, Never>?
  private var running = false

  func start() {
    guard !running else { return }
    running = true
    connected = Self.bluetoothAudioAddresses()
    let present = connected
    Task {
      for device in await Self.read() where present.contains(device.address) { onKnown?(device) }
    }
    poll()
    var address = Self.devicesAddress
    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      Task { @MainActor in self?.devicesChanged() }
    }
    listener = block
    AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block)
  }

  func stop() {
    guard running else { return }
    running = false
    if let listener {
      var address = Self.devicesAddress
      AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
    }
    listener = nil
    pollTask?.cancel()
    pollTask = nil
    connected.removeAll()
  }

  private func devicesChanged() {
    let now = Self.bluetoothAudioAddresses()
    let appeared = now.subtracting(connected)
    let left = connected.subtracting(now)
    connected = now
    for address in left { onDisconnect?(address) }
    for address in appeared { Task { await announce(address) } }
  }

  /// Unos AirPods recién conectados, con su batería en cuanto `system_profiler` la dé. Otros auriculares no salen.
  private func announce(_ address: String) async {
    var waited = 0.0
    for (index, delay) in Self.retries.enumerated() {
      try? await Task.sleep(for: .seconds(delay - waited))
      waited = delay
      guard running, connected.contains(address) else { return }
      guard let device = await Self.read().first(where: { $0.address == address }) else { continue }
      // Sin batería todavía: se espera al siguiente intento, salvo en el último.
      if !device.battery.isEmpty || index == Self.retries.count - 1 {
        onConnect?(device)
        return
      }
    }
  }

  private func poll() {
    pollTask?.cancel()
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: Self.pollInterval)
        guard let self else { return }
        guard self.running, !self.connected.isEmpty else { continue }
        for device in await Self.read() where self.connected.contains(device.address) {
          self.onBattery?(device)
        }
      }
    }
  }

  // MARK: Fuentes

  private static var devicesAddress: AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal,
                               mElement: kAudioObjectPropertyElementMain)
  }

  /// Las direcciones Bluetooth de los dispositivos de audio conectados (de su identificador de Core Audio).
  private static func bluetoothAudioAddresses() -> Set<String> {
    var address = devicesAddress
    var size: UInt32 = 0
    let system = AudioObjectID(kAudioObjectSystemObject)
    guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
    var result: Set<String> = []
    for id in ids {
      var transport: UInt32 = 0
      var transportSize = UInt32(MemoryLayout<UInt32>.size)
      var transportAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType,
                                                        mScope: kAudioObjectPropertyScopeGlobal,
                                                        mElement: kAudioObjectPropertyElementMain)
      guard AudioObjectGetPropertyData(id, &transportAddress, 0, nil, &transportSize, &transport) == noErr,
            transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
      else { continue }
      var uid: Unmanaged<CFString>?
      var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
      var uidAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID,
                                                  mScope: kAudioObjectPropertyScopeGlobal,
                                                  mElement: kAudioObjectPropertyElementMain)
      guard AudioObjectGetPropertyData(id, &uidAddress, 0, nil, &uidSize, &uid) == noErr,
            let text = uid?.takeRetainedValue() as String?,
            let bluetooth = AirPodsDevice.bluetoothAddress(audioUID: text) else { continue }
      result.insert(bluetooth)
    }
    return result
  }

  /// `system_profiler SPBluetoothDataType -json`, fuera del hilo principal (tarda unos 60 ms).
  private nonisolated static func read() async -> [AirPodsDevice] {
    await Task.detached {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
      process.arguments = ["SPBluetoothDataType", "-json"]
      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = FileHandle.nullDevice
      guard (try? process.run()) != nil else { return [] }
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      return AirPodsDevice.parse(systemProfiler: data)
    }.value
  }
}
