/// Cortar y pegar archivos en Finder con ⌘X y ⌘V, como en Windows (spec «Herramientas» §2).
/// Puro: la app le da la tecla, el interruptor, la app activa, si se escribe y el `changeCount` del portapapeles.
public struct FinderCut {
  public static let finderBundleID = "com.apple.finder"

  public enum Key: Equatable, Sendable { case cut, paste }

  public enum Decision: Equatable, Sendable {
    /// La pulsación sigue su camino, como siempre.
    case pass
    /// Tragarse ⌘X, enviar ⌘C y, cuando Finder haya copiado, llamar a `copied(changeCount:files:)`.
    case copyAsCut
    /// Tragarse ⌘V y enviar ⌥⌘V: Finder mueve los archivos a la carpeta abierta.
    case move
  }

  /// `changeCount` del portapapeles al pulsar ⌘X, hasta que se sabe si Finder copió.
  private var copyingFrom: Int?
  /// `changeCount` del portapapeles con los archivos cortados; nil si no hay corte.
  private var cutAt: Int?

  public init() {}

  /// ⌘X o ⌘V (códigos de tecla 7 y 9) con ⌘ y ninguna otra modificadora; nil con cualquier otra pulsación.
  public static func key(keyCode: Int64, modifiers: Set<ComboModifier>) -> Key? {
    guard modifiers == [.command] else { return nil }
    switch keyCode {
    case 7: return .cut
    case 9: return .paste
    default: return nil
    }
  }

  /// `isEditingText` (se pregunta por Accesibilidad) solo se mira en Finder y con la herramienta encendida.
  public mutating func keyDown(_ key: Key, enabled: Bool, app: String?, changeCount: Int,
                               isEditingText: () -> Bool) -> Decision {
    guard enabled, app == Self.finderBundleID, !isEditingText() else { return .pass }
    switch key {
    case .cut:
      // El corte anterior sigue hasta que Finder copie otros archivos: sin nada seleccionado, no copia.
      copyingFrom = changeCount
      return .copyAsCut
    case .paste:
      defer { cutAt = nil }
      return cutAt == changeCount ? .move : .pass
    }
  }

  /// Tras el ⌘C: si el portapapeles cambió y tiene archivos, apunta el corte y devuelve el aviso de la pastilla.
  public mutating func copied(changeCount: Int, files: Int) -> String? {
    guard let from = copyingFrom else { return nil }
    copyingFrom = nil
    guard changeCount != from, files > 0 else { return nil }
    cutAt = changeCount
    return Self.notice(files: files)
  }

  public static func notice(files: Int) -> String {
    "Cortado: \(files) \(files == 1 ? "elemento" : "elementos") · ⌘V para mover"
  }
}
