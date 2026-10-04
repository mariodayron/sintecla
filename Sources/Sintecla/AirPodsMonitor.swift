import CoreAudio
import Foundation
import SinteclaCore

/// Los AirPods sin permisos nuevos (spec «Estante y avisos» §4.3): al conectarse aparecen como dispositivo de audio
/// Bluetooth, y la batería sale de `system_profiler` (la vía Bluetooth directa pide el permiso de Bluetooth).
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
  /// Las direcciones de los AirPods conectados.
  private var connected: Set<String> = []
  private var bluetoothAudio: Set<String> = []
  private var pollTask: Task<Void, Never>?
  private var running = false

  func start() {
    guard !running else { return }
    running = true
    bluetoothAudio = Self.bluetoothAudioDevices()
    Task {
      for device in await Self.read() {
        connected.insert(device.address)
        onKnown?(device)
      }
      poll()
    }
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
    let now = Self.bluetoothAudioDevices()
    let appeared = !now.subtracting(bluetoothAudio).isEmpty
    let left = !bluetoothAudio.subtracting(now).isEmpty
    bluetoothAudio = now
    if left { Task { await checkDisconnected() } }
    if appeared { Task { await findNew() } }
  }

  private func findNew() async {
    for (index, delay) in Self.retries.enumerated() {
      try? await Task.sleep(for: .seconds(delay - (index == 0 ? 0 : Self.retries[index - 1])))
      guard running else { return }
      let new = await Self.read().filter { !connected.contains($0.address) }
      // Sin batería todavía: se espera al siguiente intento, salvo en el último.
      let ready = new.filter { !$0.battery.isEmpty || index == Self.retries.count - 1 }
      for device in ready {
        connected.insert(device.address)
        onConnect?(device)
      }
      if !new.isEmpty, ready.count == new.count { return }
    }
  }

  private func checkDisconnected() async {
    let still = Set(await Self.read().map(\.address))
    for address in connected.subtracting(still) {
      connected.remove(address)
      onDisconnect?(address)
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

  /// Los identificadores de los dispositivos de audio Bluetooth conectados.
  private static func bluetoothAudioDevices() -> Set<String> {
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
      result.insert(String(id))
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
