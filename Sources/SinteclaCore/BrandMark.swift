import Foundation

/// El dibujo de Sintecla, «onda que escribe»: las barras de una onda de voz que acaban en un cursor de texto.
/// Geometría en un cuadrado unidad (0–1, origen arriba a la izquierda), para el icono de la app y la barra de menú.
public enum BrandMark {
  public enum Variant: CaseIterable, Sendable {
    /// Icono de 64 px en adelante.
    case large
    /// Icono de 16 y 32 px: menos barras y más gruesas.
    case small
    /// Barra de menú, en reposo y grabando.
    case menuIdle, menuRecording
  }

  /// Rectángulo de esquinas redondas (radio = mitad del lado corto) con su opacidad.
  public struct Piece: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var opacity: Double
    public var isCursor: Bool

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
  }

  public static func pieces(_ variant: Variant) -> [Piece] {
    switch variant {
    case .large:
      bars(x: [0.183, 0.267, 0.350, 0.433, 0.517], width: 0.050, heights: [0.100, 0.233, 0.367, 0.200, 0.133],
           opacities: [0.40, 0.55, 0.70, 0.85, 1])
        + cursor(stemX: 0.683, stemWidth: 0.050, stemHeight: 0.500, serifX: 0.625, serifWidth: 0.167, serifHeight: 0.042,
                 serifY: [0.233, 0.725])
    case .small:
      bars(x: [0.267, 0.383, 0.500], width: 0.067, heights: [0.233, 0.400, 0.167], opacities: [1, 1, 1])
        + cursor(stemX: 0.683, stemWidth: 0.075, stemHeight: 0.567)
    case .menuIdle:
      bars(x: menuBarX, width: 0.11, heights: [0.20, 0.44, 0.69, 0.31], opacities: [0.45, 0.45, 0.45, 0.45]) + menuCursor
    case .menuRecording:
      bars(x: menuBarX, width: 0.11, heights: [0.31, 0.69, 0.94, 0.56], opacities: [1, 1, 1, 1]) + menuCursor
    }
  }

  private static let menuBarX = [0.02, 0.21, 0.40, 0.59]
  private static let menuCursor = cursor(stemX: 0.82, stemWidth: 0.11, stemHeight: 0.88, serifX: 0.75, serifWidth: 0.25,
                                         serifHeight: 0.09, serifY: [0.03, 0.88])

  /// Barras centradas en y = 0,5.
  private static func bars(x: [Double], width: Double, heights: [Double], opacities: [Double]) -> [Piece] {
    zip(x, zip(heights, opacities)).map { x, shape in
      Piece(x: x, y: 0.5 - shape.0 / 2, width: width, height: shape.0, opacity: shape.1, isCursor: false)
    }
  }

  /// Palo centrado en y = 0,5 y, si se piden, remates horizontales arriba y abajo.
  private static func cursor(stemX: Double, stemWidth: Double, stemHeight: Double, serifX: Double = 0, serifWidth: Double = 0,
                             serifHeight: Double = 0, serifY: [Double] = []) -> [Piece] {
    [Piece(x: stemX, y: 0.5 - stemHeight / 2, width: stemWidth, height: stemHeight, opacity: 1, isCursor: true)]
      + serifY.map { Piece(x: serifX, y: $0, width: serifWidth, height: serifHeight, opacity: 1, isCursor: true) }
  }
}
