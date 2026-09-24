import AppKit

/// Pega texto en la app activa con ⌘V y, por defecto, deja el portapapeles como estaba.
@MainActor
enum Paster {
  private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
  private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

  /// `restoreClipboard: false` (notas): el texto se queda en el portapapeles como una copia normal.
  static func paste(_ text: String, restoreClipboard: Bool = true) async {
    let pasteboard = NSPasteboard.general
    let saved = snapshot(pasteboard)

    pasteboard.clearContents()
    let item = NSPasteboardItem()
    item.setString(text, forType: .string)
    if restoreClipboard {
      // Para que los gestores de portapapeles ignoren este contenido temporal.
      item.setData(Data(), forType: transientType)
      item.setData(Data(), forType: concealedType)
    }
    pasteboard.writeObjects([item])

    postCommand(key: 9)  // 9 = V
    try? await Task.sleep(for: .milliseconds(300))
    if restoreClipboard { restore(saved, to: pasteboard) }
  }

  /// ⌘ + tecla, marcado para que nuestro EventTap lo ignore.
  static func postCommand(key: CGKeyCode) {
    let source = CGEventSource(stateID: .combinedSessionState)
    for isDown in [true, false] {
      guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown) else { continue }
      event.flags = .maskCommand
      event.setIntegerValueField(.eventSourceUserData, value: EventTap.syntheticMarker)
      event.post(tap: .cghidEventTap)
    }
  }

  static func snapshot(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
    (pasteboard.pasteboardItems ?? []).map { item in
      var copy: [NSPasteboard.PasteboardType: Data] = [:]
      for type in item.types {
        if let data = item.data(forType: type) { copy[type] = data }
      }
      return copy
    }
  }

  static func restore(_ items: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard) {
    pasteboard.clearContents()
    guard !items.isEmpty else { return }
    let restored = items.map { dict -> NSPasteboardItem in
      let item = NSPasteboardItem()
      for (type, data) in dict { item.setData(data, forType: type) }
      return item
    }
    pasteboard.writeObjects(restored)
  }
}
