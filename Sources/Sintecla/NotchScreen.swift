import AppKit

/// La pantalla con muesca y el sitio de la muesca (spec «La isla» §5). Solo la del MacBook la tiene: con la tapa
/// cerrada no hay ninguna, y la isla es virtual (`virtualNotch(on:)`).
@MainActor
enum NotchScreen {
  static var current: NSScreen? {
    NSScreen.screens.first { $0.safeAreaInsets.top > 0 && $0.auxiliaryTopLeftArea != nil }
  }

  /// El rectángulo de la muesca, en coordenadas de AppKit: entre las dos zonas libres de arriba
  /// (`auxiliaryTopLeftArea` y `auxiliaryTopRightArea`), con el alto de `safeAreaInsets.top`.
  static func notchRect(on screen: NSScreen) -> CGRect? {
    guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return nil }
    let frame = screen.frame
    let height = screen.safeAreaInsets.top
    let width = frame.width - left.width - right.width
    guard width > 0, height > 0 else { return nil }
    return CGRect(x: frame.minX + left.width, y: frame.maxY - height, width: width, height: height)
  }

  /// Sin muesca: una muesca imaginaria arriba en el centro, del alto de la barra de menús, de donde cuelga la isla.
  static func virtualNotch(on screen: NSScreen) -> CGRect {
    let size = CGSize(width: 180, height: NSStatusBar.system.thickness)
    return CGRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height, width: size.width,
                  height: size.height)
  }
}
