import AppKit
import CoreGraphics
import SinteclaCore

/// Escucha el teclado de todo el sistema y traduce las teclas a `HotkeyEvent`.
/// Vive en el hilo principal (su fuente se añade al run loop principal).
final class EventTap {
  /// Marca de los eventos que genera Sintecla (⌘V, ⌘C) para no procesarlos.
  static let syntheticMarker: Int64 = 0x5354_4B31

  var baseKey: BaseKey {
    get { base.baseKey }
    set { base = BaseKeyTracker(baseKey: newValue) }
  }
  /// Devuelve `true` si el evento debe tragarse (no llega a la app activa).
  var onEvent: ((HotkeyEvent) -> Bool)?
  /// Cada pulsación que no usan los atajos, con su código y sus modificadores, para las herramientas (cortar y pegar
  /// en Finder). Devuelve `true` si hay que tragársela.
  var onKeyDown: ((_ keyCode: Int64, _ modifiers: Set<ComboModifier>) -> Bool)?

  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var base = BaseKeyTracker()
  private var lastModifiers: Set<ComboModifier> = []
  private var swallowedKeyUps: Set<Int64> = []

  var isRunning: Bool { tap != nil }

  /// Falla (false) si macOS no ha dado permiso de Accesibilidad / Monitorización de entrada.
  func start() -> Bool {
    if tap != nil { return true }
    let mask = (1 << CGEventType.flagsChanged.rawValue)
      | (1 << CGEventType.keyDown.rawValue)
      | (1 << CGEventType.keyUp.rawValue)
    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
      eventsOfInterest: CGEventMask(mask), callback: eventTapCallback,
      userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    self.tap = tap
    self.runLoopSource = source
    return true
  }

  func stop() {
    if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
    if let tap {
      CGEvent.tapEnable(tap: tap, enable: false)
      CFMachPortInvalidate(tap)
    }
    tap = nil
    runLoopSource = nil
    base = BaseKeyTracker(baseKey: base.baseKey)
  }

  fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return Unmanaged.passUnretained(event)
    }
    if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
      return Unmanaged.passUnretained(event)
    }
    let now = ProcessInfo.processInfo.systemUptime
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

    switch type {
    case .flagsChanged:
      let flags = event.flags
      if let down = base.update(keyCode: keyCode, fnDown: flags.contains(.maskSecondaryFn),
                                rightOptionDown: flags.rawValue & 0x40 != 0) {  // 0x40 = bit de la ⌥ derecha
        _ = onEvent?(down ? .baseDown(at: now) : .baseUp(at: now))
      }
      let modifiers = comboModifiers(from: event.flags)
      if modifiers != lastModifiers {
        lastModifiers = modifiers
        _ = onEvent?(.modifiers(modifiers, at: now))
      }
      return Unmanaged.passUnretained(event)  // los modificadores nunca se tragan
    case .keyDown:
      let hotkeyEvent: HotkeyEvent = switch keyCode {
      case 49: .space(at: now)
      case 53: .escape(at: now)
      default: .otherKey(at: now)
      }
      // Los atajos de dictado van primero: lo que usan no llega a las herramientas.
      if onEvent?(hotkeyEvent) == true || onKeyDown?(keyCode, Self.modifiers(from: event.flags)) == true {
        swallowedKeyUps.insert(keyCode)
        return nil
      }
      return Unmanaged.passUnretained(event)
    case .keyUp:
      if swallowedKeyUps.remove(keyCode) != nil { return nil }
      return Unmanaged.passUnretained(event)
    default:
      return Unmanaged.passUnretained(event)
    }
  }

  private func comboModifiers(from flags: CGEventFlags) -> Set<ComboModifier> {
    var set = Self.modifiers(from: flags)
    if !base.optionIsModifier { set.remove(.option) }
    return set
  }

  /// Las teclas modificadoras pulsadas, todas (también la ⌥ cuando es la tecla base).
  static func modifiers(from flags: CGEventFlags) -> Set<ComboModifier> {
    var set: Set<ComboModifier> = []
    if flags.contains(.maskShift) { set.insert(.shift) }
    if flags.contains(.maskControl) { set.insert(.control) }
    if flags.contains(.maskAlternate) { set.insert(.option) }
    if flags.contains(.maskCommand) { set.insert(.command) }
    return set
  }
}

private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                              userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
  guard let userInfo else { return Unmanaged.passUnretained(event) }
  return Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue().handle(type: type, event: event)
}
