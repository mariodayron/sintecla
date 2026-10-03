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
  /// Con música y el ratón encima.
  case expanded
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
  /// Hueco entre la isla y la burbuja de la música.
  public static let bubbleGap: CGFloat = 8

  /// `hasNotch` a false: tapa cerrada, isla virtual arriba en el centro, solo con lo de Sintecla; sin nada, no se ve.
  public static func form(activity: IslandActivity?, music: Bool, hovering: Bool, fullScreen: Bool,
                          hasNotch: Bool = true) -> IslandForm {
    guard hasNotch else { return activity.map { .activity($0, bubble: false) } ?? .hidden }
    if let activity { return .activity(activity, bubble: music) }
    if fullScreen { return .hidden }
    guard music else { return .notch }
    return hovering ? .expanded : .compact
  }

  /// `hasNotch` a false: isla virtual; las actividades altas llevan todo en una fila y bajan menos.
  public static func size(of form: IslandForm, notch: CGSize, hasNotch: Bool = true) -> CGSize {
    switch form {
    case .hidden: .zero
    case .notch: notch
    case .compact, .activity(.done, _): CGSize(width: notch.width + 2 * wing, height: notch.height)
    case .expanded: CGSize(width: max(notch.width + 2 * wing, expandedWidth), height: notch.height + expandedDrop)
    case .activity: CGSize(width: notch.width + 2 * tallWing, height: notch.height + (hasNotch ? tallDrop : virtualDrop))
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
