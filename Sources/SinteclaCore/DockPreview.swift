import CoreGraphics
import Foundation

/// Vistas del Dock (spec «Vistas del Dock»): textos y medidas.
public enum DockPreview {
  /// Resumen para la tarjeta de Inicio.
  public static let summary = "Ventanas al pasar por el Dock"
  /// Ancho de cada tarjeta, en puntos (§5).
  public static let cardWidth: CGFloat = 240
}

/// Un icono de app del Dock (spec «Vistas del Dock» §6). Carpetas, Papelera y separadores no lo son.
public struct DockItem: Equatable, Sendable {
  public let appURL: URL

  /// `subrole` y `url`: los atributos `AXSubrole` y `AXURL` del icono.
  public init?(subrole: String?, url: URL?) {
    guard subrole == "AXApplicationDockItem", let url, url.isFileURL, url.pathExtension == "app" else { return nil }
    appURL = url
  }
}

/// El lado de la pantalla donde está el Dock.
public enum DockEdge: Equatable, Sendable {
  case bottom, left, right

  /// El borde de la pantalla más cerca del icono (con la lupa, el icono crece pero sigue pegado a su borde).
  public init(icon: CGRect, screen: CGRect) {
    let bottom = icon.minY - screen.minY
    let left = icon.minX - screen.minX
    let right = screen.maxX - icon.maxX
    if bottom <= left && bottom <= right {
      self = .bottom
    } else {
      self = left <= right ? .left : .right
    }
  }
}

/// Dónde va la vista (spec «Vistas del Dock» §5).
public enum DockPreviewPlacement {
  /// Hueco entre el icono y la vista: deja libre el nombre que el Dock pone junto al icono.
  static let iconGap: CGFloat = 36
  /// Margen con los bordes de la pantalla.
  static let margin: CGFloat = 8

  /// Accesibilidad mide desde arriba a la izquierda de la pantalla principal; AppKit, desde abajo a la izquierda.
  public static func screenRect(fromAccessibility rect: CGRect, primaryHeight: CGFloat) -> CGRect {
    CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
  }

  /// Junto al icono, hacia dentro de la pantalla y centrada en él; si se sale, se corre hasta caber.
  public static func frame(panel: CGSize, icon: CGRect, edge: DockEdge, screen: CGRect) -> CGRect {
    var origin: CGPoint
    switch edge {
    case .bottom: origin = CGPoint(x: icon.midX - panel.width / 2, y: icon.maxY + iconGap)
    case .left: origin = CGPoint(x: icon.maxX + iconGap, y: icon.midY - panel.height / 2)
    case .right: origin = CGPoint(x: icon.minX - iconGap - panel.width, y: icon.midY - panel.height / 2)
    }
    let bounds = screen.insetBy(dx: margin, dy: margin)
    origin.x = min(max(origin.x, bounds.minX), bounds.maxX - panel.width)
    origin.y = min(max(origin.y, bounds.minY), bounds.maxY - panel.height)
    return CGRect(origin: origin, size: panel)
  }
}

/// Los tiempos de la vista (spec «Vistas del Dock» §3). `Item` es el icono (la app) que tiene el ratón.
///
/// - `hover`: el Dock avisa de que el ratón está sobre otro icono de app.
/// - `tick`: cada poco, con `inside` a true si el ratón está sobre el icono (al esperar) o sobre el icono o la vista
///   (con la vista abierta).
public struct DockHoverTimer<Item: Equatable & Sendable>: Sendable {
  public static var showDelay: TimeInterval { 0.3 }
  public static var hideDelay: TimeInterval { 0.25 }
  /// Las fechas son grandes: sin este margen, 0,3 s podrían medir 0,2999999.
  static var epsilon: TimeInterval { 0.001 }

  public enum Action: Equatable, Sendable {
    case none
    case show(Item)
    case hide
  }

  private enum State: Sendable {
    case idle
    case pending(Item, since: Date)
    case shown(Item, outsideSince: Date?)
    /// Cerrada con Esc, un clic o Alt-Tab: ese icono no la vuelve a sacar hasta que el ratón salga de él.
    case dismissed(Item)
  }

  private var state = State.idle

  public init() {}

  /// El icono con la vista abierta.
  public var shown: Item? {
    if case .shown(let item, _) = state { return item }
    return nil
  }

  /// Esperando para enseñar la vista o con ella abierta: hay que seguir mirando el ratón.
  public var isActive: Bool {
    if case .idle = state { return false }
    return true
  }

  public mutating func hover(_ item: Item, at now: Date) -> Action {
    switch state {
    case .idle:
      state = .pending(item, since: now)
    case .pending(let current, _):
      if current != item { state = .pending(item, since: now) }
    case .shown(let current, _):
      // Con la vista abierta, otro icono cambia al momento.
      if current != item {
        state = .shown(item, outsideSince: nil)
        return .show(item)
      }
      state = .shown(item, outsideSince: nil)
    case .dismissed(let current):
      if current != item { state = .pending(item, since: now) }
    }
    return .none
  }

  public mutating func tick(inside: Bool, at now: Date) -> Action {
    switch state {
    case .idle:
      return .none
    case .pending(let item, let since):
      guard inside else {
        state = .idle
        return .none
      }
      guard now.timeIntervalSince(since) >= Self.showDelay - Self.epsilon else { return .none }
      state = .shown(item, outsideSince: nil)
      return .show(item)
    case .shown(let item, let outsideSince):
      if inside {
        state = .shown(item, outsideSince: nil)
        return .none
      }
      guard let outsideSince else {
        state = .shown(item, outsideSince: now)
        return .none
      }
      guard now.timeIntervalSince(outsideSince) >= Self.hideDelay - Self.epsilon else { return .none }
      state = .idle
      return .hide
    case .dismissed:
      if !inside { state = .idle }
      return .none
    }
  }

  /// Esc, un clic o Alt-Tab: la vista se va. El Dock repite su aviso aunque el ratón no cambie de icono: por eso ese
  /// icono no la vuelve a sacar hasta que el ratón sale de él (`tick` con `inside` a false).
  public mutating func cancel() {
    switch state {
    case .pending(let item, _), .shown(let item, _): state = .dismissed(item)
    case .idle, .dismissed: break
    }
  }
}
