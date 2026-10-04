import CoreGraphics
import Foundation

/// Lo que hace Sintecla, visto desde la isla (spec «La isla» §3.3).
public enum IslandActivity: Equatable, Sendable {
  /// Dictado, traducir, preguntar o notas.
  case listening
  case meeting
  case processing
  case done
  /// Avisos y mensajes de la pastilla.
  case notice
  /// Avisos de carga y AirPods (spec «Estante y avisos» §4).
  case device

  /// Las que bajan por debajo de la muesca, con el texto debajo. «Hecho» cabe en los lados.
  public var isTall: Bool { self != .done }
}

/// La forma de la isla (spec «La isla» §3.1).
public enum IslandForm: Equatable, Sendable {
  /// A pantalla completa, sin nada de Sintecla: no se ve.
  case hidden
  /// Igual que la muesca real.
  case notch
  /// Con música: carátula a un lado y onda al otro.
  case compact
  /// Sin música y con archivos en el estante: la bandeja y cuántos hay (spec «Estante y avisos» §3.2).
  case shelf
  /// Con el ratón encima: la música arriba (si la hay) y la fila del estante debajo (si hay archivos).
  case expanded(music: Bool, shelf: Bool)
  /// Arrastrando archivos cerca de la muesca: la bandeja donde soltarlos (spec «Estante y avisos» §3.1).
  case tray
  /// Sintecla; con `bubble`, la música va al lado en una burbuja.
  case activity(IslandActivity, bubble: Bool)
}

/// Qué forma toca y cuánto mide (spec «La isla» §3.1).
public enum IslandLayout {
  /// Lo que crece la forma compacta por cada lado de la muesca.
  public static let wing: CGFloat = 40
  /// Lo que crecen por cada lado las actividades altas, y lo que bajan por debajo de la muesca.
  public static let tallWing: CGFloat = 86
  public static let tallDrop: CGFloat = 30
  /// Sin muesca, todo va en una fila: lo que baja por debajo de la barra de menús.
  public static let virtualDrop: CGFloat = 14
  /// La desplegada: ancho mínimo y lo que baja por debajo de la muesca.
  public static let expandedWidth: CGFloat = 420
  public static let expandedDrop: CGFloat = 148
  /// La fila del estante en la desplegada, y lo que baja la desplegada solo con estante antes de la fila.
  public static let shelfRow: CGFloat = 78
  public static let shelfOnlyGap: CGFloat = 6
  /// Lo que baja la bandeja por debajo de la muesca.
  public static let trayDrop: CGFloat = 96
  /// La zona de la muesca donde un arrastre de archivos abre la bandeja: tanto por cada lado y por debajo.
  public static let dropZoneSide: CGFloat = 120
  public static let dropZoneDrop: CGFloat = 110
  /// Hueco entre la isla y la burbuja de la música.
  public static let bubbleGap: CGFloat = 8

  /// `hasNotch` a false: tapa cerrada, isla virtual arriba en el centro, solo con lo de Sintecla y los avisos; sin
  /// nada, no se ve. `shelf`: cuántos archivos hay en el estante; `dragging`: hay archivos arrastrándose en la zona de
  /// la muesca (la bandeja manda sobre todo, también a pantalla completa).
  public static func form(activity: IslandActivity?, music: Bool, hovering: Bool, fullScreen: Bool,
                          hasNotch: Bool = true, shelf: Int = 0, dragging: Bool = false) -> IslandForm {
    guard hasNotch else { return activity.map { .activity($0, bubble: false) } ?? .hidden }
    if dragging { return .tray }
    if let activity { return .activity(activity, bubble: music) }
    if fullScreen { return .hidden }
    let hasShelf = shelf > 0
    guard music || hasShelf else { return .notch }
    if hovering { return .expanded(music: music, shelf: hasShelf) }
    return music ? .compact : .shelf
  }

  /// La zona de la muesca donde un arrastre de archivos abre la bandeja, en coordenadas de pantalla (spec «Estante y
  /// avisos» §3.1). Llega hasta arriba: el borde de la pantalla también cuenta.
  public static func dropZone(around notch: CGRect) -> CGRect {
    CGRect(x: notch.minX - dropZoneSide, y: notch.minY - dropZoneDrop, width: notch.width + 2 * dropZoneSide,
           height: notch.height + dropZoneDrop)
  }

  /// `hasNotch` a false: isla virtual; las actividades altas llevan todo en una fila y bajan menos.
  public static func size(of form: IslandForm, notch: CGSize, hasNotch: Bool = true) -> CGSize {
    switch form {
    case .hidden: .zero
    case .notch: notch
    case .compact, .shelf, .activity(.done, _): CGSize(width: notch.width + 2 * wing, height: notch.height)
    case .expanded(let music, let shelf):
      CGSize(width: max(notch.width + 2 * wing, expandedWidth),
             height: notch.height + (music ? expandedDrop : shelfOnlyGap) + (shelf ? shelfRow : 0))
    case .tray: CGSize(width: max(notch.width + 2 * wing, expandedWidth), height: notch.height + trayDrop)
    case .activity: CGSize(width: notch.width + 2 * tallWing, height: notch.height + (hasNotch ? tallDrop : virtualDrop))
    }
  }

  /// Las que se despliegan con el ratón encima.
  public static func isHoverable(_ form: IslandForm) -> Bool {
    switch form {
    case .compact, .shelf, .expanded: true
    default: false
    }
  }

  /// La burbuja de la música: un círculo del alto de la muesca.
  public static func bubbleDiameter(notch: CGSize) -> CGFloat { notch.height }
}

/// Desplegar al tener el ratón encima 0,15 s y recoger a los 0,3 s de sacarlo (spec «La isla» §3.1).
public struct IslandHover: Equatable, Sendable {
  public static var expandDelay: TimeInterval { 0.15 }
  public static var collapseDelay: TimeInterval { 0.3 }
  /// Las fechas son grandes: sin este margen, 0,15 s podrían medir 0,1499999.
  static var epsilon: TimeInterval { 0.001 }

  public private(set) var isExpanded = false
  private var insideSince: Date?
  private var outsideSince: Date?

  public init() {}

  /// Cada vez que se mueve el ratón (y al cumplirse cada espera). Devuelve si cambió `isExpanded`.
  @discardableResult
  public mutating func update(inside: Bool, at now: Date) -> Bool {
    if inside {
      outsideSince = nil
      guard !isExpanded else { return false }
      let since = insideSince ?? now
      insideSince = since
      guard now.timeIntervalSince(since) >= Self.expandDelay - Self.epsilon else { return false }
      isExpanded = true
      return true
    }
    insideSince = nil
    guard isExpanded else { return false }
    let since = outsideSince ?? now
    outsideSince = since
    guard now.timeIntervalSince(since) >= Self.collapseDelay - Self.epsilon else { return false }
    isExpanded = false
    outsideSince = nil
    return true
  }

  /// Sin música que desplegar, o al cambiar de pantalla.
  public mutating func reset() {
    self = IslandHover()
  }
}
