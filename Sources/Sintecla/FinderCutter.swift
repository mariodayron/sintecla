import AppKit
import SinteclaCore

/// Cortar y pegar archivos en Finder (spec «Herramientas» §2): une `FinderCut` con la app activa, el elemento enfocado,
/// el portapapeles y la pastilla.
@MainActor
final class FinderCutter {
  static let symbol = "scissors"
  /// Aviso para la pastilla («Cortado: 3 elementos · ⌘V para mover»).
  var onNotice: ((String) -> Void)?

  private let settings: AppSettings
  private var cut = FinderCut()

  init(settings: AppSettings) {
    self.settings = settings
  }

  /// Lo llama `EventTap` con cada pulsación que no usan los atajos de dictado. `true`: Sintecla se la queda.
  func keyDown(keyCode: Int64, modifiers: Set<ComboModifier>) -> Bool {
    guard let key = FinderCut.key(keyCode: keyCode, modifiers: modifiers) else { return false }
    let changeCount = NSPasteboard.general.changeCount
    let decision = cut.keyDown(key, enabled: settings.finderCut,
                               app: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                               changeCount: changeCount, isEditingText: Self.isEditingText)
    switch decision {
    case .pass:
      return false
    case .copyAsCut:
      // Fuera del callback del EventTap, que tiene que volver enseguida.
      Task { await copyAsCut(from: changeCount) }
      return true
    case .move:
      Task { Paster.postCommand(key: 9, extra: .maskAlternate) }  // ⌥⌘V: «Mover aquí» de Finder
      return true
    }
  }

  /// Renombrando, en el buscador o en «Ir a la carpeta», ⌘X y ⌘V son de texto.
  private static func isEditingText() -> Bool {
    guard let focused = ContextReader.focusedElement(),
          let role = ContextReader.string(of: focused, kAXRoleAttribute) else { return false }
    return ContextReader.editableRoles.contains(role)
  }

  /// ⌘C y, en cuanto Finder copia (se mira hasta 3 veces en 600 ms), apunta el corte si hay archivos.
  private func copyAsCut(from changeCount: Int) async {
    let pasteboard = NSPasteboard.general
    Paster.postCommand(key: 8)  // 8 = C
    for _ in 0..<3 {
      try? await Task.sleep(for: .milliseconds(200))
      if pasteboard.changeCount != changeCount { break }
    }
    let files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])?.count ?? 0
    if let notice = cut.copied(changeCount: pasteboard.changeCount, files: files) { onNotice?(notice) }
  }
}
