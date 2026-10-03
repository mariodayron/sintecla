import AppKit
import CoreGraphics
import SinteclaCore

/// Lo que hace el Mac con cada orden del móvil. Ratón y teclado con eventos de Quartz (el permiso de Accesibilidad de
/// Sintecla), sin AppleScript ni System Events: así no salen avisos de Automatización.
@MainActor
final class RemoteControl {
  /// Dónde guarda las capturas pedidas desde el móvil.
  var captureFolder: () -> URL = { URL(fileURLWithPath: NSHomeDirectory() + "/Desktop") }
  private var sleepTask: Task<Void, Never>?

  func perform(_ action: RemoteAction) {
    switch action {
    case .move(let dx, let dy): move(dx: dx, dy: dy)
    case .click(let right, let double): click(right: right, double: double)
    case .scroll(let dy):
      let lines = RemoteAction.scrollLines(dy)
      guard lines != 0 else { return }
      CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: lines, wheel2: 0, wheel3: 0)?
        .post(tap: .cghidEventTap)
    case .volume(let value): run("/usr/bin/osascript", ["-e", "set volume output volume \(value)"])
    case .type(let text):
      type(text)
      key(36)
    case .media(.playPause): systemKey(Self.playKey)
    case .media(.forward10): seek(by: 10, fallbackKey: 37)
    case .media(.backward10): seek(by: -10, fallbackKey: 38)
    case .fullScreen: key(3)
    case .tab(.next): key(124, [.maskCommand, .maskAlternate])
    case .tab(.prev): key(123, [.maskCommand, .maskAlternate])
    case .tab(.close): key(13, .maskCommand)
    case .system(.sleep): run("/usr/bin/pmset", ["sleepnow"])
    case .system(.spotlight): key(49, .maskCommand)
    case .system(.brightnessUp): systemKey(Self.brightnessUpKey)
    case .system(.brightnessDown): systemKey(Self.brightnessDownKey)
    case .system(.screenshot): screenshot()
    case .app(let name): run("/usr/bin/open", ["-a", name == "Música" ? "Music" : name])
    case .open(let url): NSWorkspace.shared.open(url)
    case .sleepTimer(let minutes): sleepTimer(minutes)
    }
  }

  // MARK: Ratón

  private func move(dx: Double, dy: Double) {
    guard let now = CGEvent(source: nil)?.location else { return }
    let target = Self.clamp(CGPoint(x: now.x + dx, y: now.y + dy))
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: target, mouseButton: .left)?
      .post(tap: .cghidEventTap)
  }

  private func click(right: Bool, double: Bool) {
    guard let point = CGEvent(source: nil)?.location else { return }
    let (down, up, button): (CGEventType, CGEventType, CGMouseButton) =
      right ? (.rightMouseDown, .rightMouseUp, .right) : (.leftMouseDown, .leftMouseUp, .left)
    for count in double ? [1, 2] : [1] {
      for type in [down, up] {
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button)
        event?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
        event?.post(tap: .cghidEventTap)
      }
    }
  }

  /// Dentro de alguna pantalla (las coordenadas de Quartz miden desde arriba a la izquierda de la principal).
  private static func clamp(_ point: CGPoint) -> CGPoint {
    var displays = [CGDirectDisplayID](repeating: 0, count: 16)
    var count: UInt32 = 0
    CGGetActiveDisplayList(16, &displays, &count)
    let bounds = displays.prefix(Int(count)).map { CGDisplayBounds($0) }
    if bounds.contains(where: { $0.contains(point) }) { return point }
    guard let nearest = bounds.min(by: { distance($0, point) < distance($1, point) }) else { return point }
    return CGPoint(x: min(max(point.x, nearest.minX), nearest.maxX - 1),
                   y: min(max(point.y, nearest.minY), nearest.maxY - 1))
  }

  private static func distance(_ rect: CGRect, _ point: CGPoint) -> CGFloat {
    hypot(max(rect.minX - point.x, 0, point.x - rect.maxX), max(rect.minY - point.y, 0, point.y - rect.maxY))
  }

  // MARK: Teclado

  private func key(_ code: CGKeyCode, _ flags: CGEventFlags = []) {
    for down in [true, false] {
      let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
      event?.flags = flags
      event?.post(tap: .cghidEventTap)
    }
  }

  /// El texto tal cual, en trozos (macOS admite unos 20 caracteres por evento).
  private func type(_ text: String) {
    let units = Array(text.utf16)
    var start = 0
    while start < units.count {
      let chunk = Array(units[start..<min(start + 20, units.count)])
      for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)
        event?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
        event?.post(tap: .cghidEventTap)
      }
      start += 20
    }
  }

  /// Teclas de sistema (multimedia y brillo), como las del teclado de Apple.
  private static let playKey: Int32 = 16
  private static let brightnessUpKey: Int32 = 2
  private static let brightnessDownKey: Int32 = 3

  private func systemKey(_ key: Int32) {
    for down in [true, false] {
      let state = down ? 0xA00 : 0xB00
      let event = NSEvent.otherEvent(with: .systemDefined, location: .zero,
                                     modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state)), timestamp: 0,
                                     windowNumber: 0, context: nil, subtype: 8, data1: Int(key) << 16 | state,
                                     data2: -1)
      event?.cgEvent?.post(tap: .cghidEventTap)
    }
  }

  /// Con algo sonando que macOS reconoce (lo lee la isla), salta ±10 s; si no, la tecla de YouTube (L o J).
  private func seek(by seconds: TimeInterval, fallbackKey: CGKeyCode) {
    let music = NowPlayingClient.shared
    if let track = music.track, track.duration > 0 {
      music.seek(to: min(track.duration, max(0, track.position(at: Date()) + seconds)))
    } else {
      key(fallbackKey)
    }
  }

  // MARK: Sistema

  private func screenshot() {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd 'a las' HH.mm.ss"
    let file = captureFolder().appendingPathComponent("Captura desde el móvil \(formatter.string(from: Date())).jpg")
    run("/usr/sbin/screencapture", ["-x", "-t", "jpg", file.path])
  }

  private func sleepTimer(_ minutes: Int) {
    sleepTask?.cancel()
    guard minutes > 0 else { return }
    sleepTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(minutes * 60))
      guard !Task.isCancelled else { return }
      self?.run("/usr/bin/pmset", ["sleepnow"])
    }
  }

  private func run(_ tool: String, _ arguments: [String]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
  }
}
