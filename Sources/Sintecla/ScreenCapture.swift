import AppKit
import CoreGraphics
import ImageIO

/// Capturas con la herramienta de macOS (`screencapture`), el permiso de Grabación de pantalla y el portapapeles
/// (spec «Capturas» §2.1 y §2.3).
@MainActor
enum ScreenCapture {
  struct Shot {
    let png: Data
    let image: CGImage
  }

  enum Kind {
    /// La pantalla donde está el ratón (⇧⌘3).
    case screenUnderMouse
    /// La cruz de macOS: zona, o ventana con Espacio (⇧⌘4, ⇧⌘2, ⇧⌘1).
    case interactive
  }

  static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

  /// La primera vez, macOS enseña su aviso y añade Sintecla a la lista de Grabación de pantalla.
  static func requestPermission() {
    _ = CGRequestScreenCaptureAccess()
  }

  static func openPermissionSettings() {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
  }

  static func openKeyboardShortcuts() {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
  }

  /// ⇧⌘3 o ⇧⌘4 siguen activos como atajos de captura de macOS (28 y 30 en `com.apple.symbolichotkeys`; si no
  /// aparecen, están como vienen de fábrica: activos).
  static var macOSShortcutsActive: Bool {
    let hotkeys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
    return ["28", "30"].contains { id in
      guard let entry = hotkeys[id] as? [String: Any] else { return true }
      return (entry["enabled"] as? Bool) ?? true
    }
  }

  /// nil si se cancela (Esc) o falla. El archivo temporal se borra al leerlo: las capturas no quedan en disco.
  static func capture(_ kind: Kind) async -> Shot? {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Sintecla-capturas", isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appendingPathComponent(UUID().uuidString + ".png")
    defer { try? FileManager.default.removeItem(at: file) }
    var arguments = ["-x"]  // sin el sonido de macOS: avisa la pastilla
    switch kind {
    case .screenUnderMouse: arguments += ["-D", String(displayUnderMouse())]
    case .interactive: arguments += ["-i"]
    }
    arguments.append(file.path)
    _ = await run("/usr/sbin/screencapture", arguments)
    guard let png = try? Data(contentsOf: file), !png.isEmpty,
          let source = CGImageSourceCreateWithData(png as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    return Shot(png: png, image: image)
  }

  /// Número de la pantalla bajo el ratón para `screencapture -D`: 1 es la principal, en el orden de CoreGraphics.
  static func displayUnderMouse() -> Int {
    let mouse = CGEvent(source: nil)?.location ?? .zero
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &displays, &count)
    return (displays.firstIndex { CGDisplayBounds($0).contains(mouse) } ?? 0) + 1
  }

  /// Píxeles por punto de la pantalla del ratón (2 en Retina): el editor mide los grosores y las letras en puntos.
  static var scaleUnderMouse: CGFloat {
    let mouse = NSEvent.mouseLocation
    return (NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main)?.backingScaleFactor ?? 2
  }

  /// En PNG y en TIFF, para que la acepten todas las apps.
  static func copyImage(_ shot: Shot) {
    copyImage(png: shot.png, tiff: NSBitmapImageRep(data: shot.png)?.tiffRepresentation)
  }

  static func copyImage(png: Data, tiff: Data?) {
    let item = NSPasteboardItem()
    item.setData(png, forType: .png)
    if let tiff { item.setData(tiff, forType: .tiff) }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects([item])
  }

  static func copyText(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }

  private static func run(_ path: String, _ arguments: [String]) async -> Bool {
    await withCheckedContinuation { continuation in
      let process = Process()
      process.executableURL = URL(fileURLWithPath: path)
      process.arguments = arguments
      process.terminationHandler = { continuation.resume(returning: $0.terminationStatus == 0) }
      do {
        try process.run()
      } catch {
        continuation.resume(returning: false)
      }
    }
  }
}
