import Foundation
import IOKit.ps
import SinteclaCore

/// La carga del Mac con la API de energía de macOS (spec «Estante y avisos» §4.3): avisa sola de cada cambio. Solo lee;
/// no toca el SMC.
@MainActor
final class PowerMonitor {
  var onChange: ((PowerState) -> Void)?
  private var source: CFRunLoopSource?

  func start() {
    guard source == nil else { return }
    let context = Unmanaged.passUnretained(self).toOpaque()
    guard let created = IOPSNotificationCreateRunLoopSource({ context in
      guard let context else { return }
      let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
      MainActor.assumeIsolated { monitor.changed() }
    }, context)?.takeRetainedValue() else { return }
    source = created
    CFRunLoopAddSource(CFRunLoopGetMain(), created, .defaultMode)
    changed()
  }

  func stop() {
    guard let source else { return }
    CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
    self.source = nil
  }

  private func changed() {
    if let state = Self.current() { onChange?(state) }
  }

  /// La batería interna; nil en un Mac sin batería.
  static func current() -> PowerState? {
    let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let sources = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]
    for source in sources {
      guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
            info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
            let percent = info[kIOPSCurrentCapacityKey] as? Int else { continue }
      let minutes = info[kIOPSTimeToEmptyKey] as? Int
      return PowerState(percent: percent, pluggedIn: info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                        charging: info[kIOPSIsChargingKey] as? Bool ?? false,
                        minutesLeft: minutes.flatMap { $0 > 0 ? $0 : nil })
    }
    return nil
  }
}
