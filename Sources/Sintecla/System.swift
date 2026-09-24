import AppKit
import AVFoundation
import ApplicationServices
import CoreAudio
import ServiceManagement

/// Estado y solicitud de permisos de macOS.
enum Permissions {
  static var microphoneGranted: Bool { AVCaptureDevice.authorizationStatus(for: .audio) == .authorized }
  static var accessibilityGranted: Bool { AXIsProcessTrusted() }
  static var inputMonitoringGranted: Bool { CGPreflightListenEventAccess() }
  static var essentialsGranted: Bool { microphoneGranted && accessibilityGranted }

  /// "Pulsar tecla 🌐 para: No hacer nada" = AppleFnUsageType 0.
  static var globeKeyDoesNothing: Bool {
    (UserDefaults(suiteName: "com.apple.HIToolbox")?.object(forKey: "AppleFnUsageType") as? Int) == 0
  }

  static var typelessRunning: Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: typelessBundleID).isEmpty
  }

  /// Typeless también usa la tecla 🌐: no pueden funcionar a la vez.
  static func quitTypeless() {
    NSRunningApplication.runningApplications(withBundleIdentifier: typelessBundleID).forEach { $0.terminate() }
  }

  private static let typelessBundleID = "now.typeless.desktop"

  static func requestMicrophone() async -> Bool {
    await AVCaptureDevice.requestAccess(for: .audio)
  }

  static func promptAccessibility() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  static func requestInputMonitoring() {
    _ = CGRequestListenEventAccess()
  }

  enum Pane: String {
    case microphone = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
    case accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    case inputMonitoring = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    case keyboard = "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
  }

  static func open(_ pane: Pane) {
    if let url = URL(string: pane.rawValue) { NSWorkspace.shared.open(url) }
  }
}

/// Dispositivos de audio del sistema.
enum AudioDevices {
  /// UID de la salida interna del Mac (altavoces o auriculares con cable).
  static func builtInOutputUID() -> String? { builtInUID(scope: kAudioObjectPropertyScopeOutput) }

  private static func builtInUID(scope: AudioObjectPropertyScope) -> String? {
    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal,
                                             mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return nil }
    var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices) == noErr else { return nil }
    for device in devices {
      var transport: UInt32 = 0
      var transportSize = UInt32(MemoryLayout<UInt32>.size)
      var transportAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType,
                                                        mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
      var streamsAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: scope,
                                                      mElement: kAudioObjectPropertyElementMain)
      var streamsSize: UInt32 = 0
      guard AudioObjectGetPropertyData(device, &transportAddress, 0, nil, &transportSize, &transport) == noErr,
            transport == kAudioDeviceTransportTypeBuiltIn,
            AudioObjectGetPropertyDataSize(device, &streamsAddress, 0, nil, &streamsSize) == noErr, streamsSize > 0 else { continue }
      var uidAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal,
                                                  mElement: kAudioObjectPropertyElementMain)
      var uid: Unmanaged<CFString>?
      var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
      if AudioObjectGetPropertyData(device, &uidAddress, 0, nil, &uidSize, &uid) == noErr, let uid {
        return uid.takeRetainedValue() as String
      }
    }
    return nil
  }

  /// Nombre del micrófono que macOS usa ahora como entrada ("Micrófono del MacBook Air",
  /// "AirPods Pro de…"). Solo lee la configuración: no abre el micrófono.
  static func defaultInputName() -> String? {
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                             mScope: kAudioObjectPropertyScopeGlobal,
                                             mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID) == noErr,
          deviceID != kAudioObjectUnknown else { return nil }
    var name: Unmanaged<CFString>?
    size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    address.mSelector = kAudioObjectPropertyName
    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name) == noErr, let name else { return nil }
    return name.takeRetainedValue() as String
  }
}

/// Arranque automático al iniciar sesión.
enum LoginItem {
  static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

  static func set(_ enabled: Bool) {
    do {
      if enabled, SMAppService.mainApp.status != .enabled {
        try SMAppService.mainApp.register()
      } else if !enabled, SMAppService.mainApp.status == .enabled {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      NSLog("Sintecla: no se pudo cambiar el inicio de sesión: \(error)")
    }
  }
}

/// Sonidos del sistema para empezar, terminar y avisar.
@MainActor
enum Sounds {
  static var enabled = true
  static func start() { play("Tink") }
  static func done() { play("Pop") }
  static func error() { play("Basso") }

  private static func play(_ name: String) {
    guard enabled else { return }
    NSSound(named: NSSound.Name(name))?.play()
  }
}
