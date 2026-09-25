import CoreGraphics
import CoreText
import Foundation
import ImageIO

/// Dibuja las anotaciones del editor de capturas y exporta la captura anotada a tamaño real (spec «Capturas» §3.3).
public enum AnnotationRenderer {
  /// En un contexto en píxeles de la imagen con el origen arriba a la izquierda (y hacia abajo). `hiding`: la que se
  /// está escribiendo, que dibuja el campo de texto.
  public static func draw(_ document: AnnotationDocument, in context: CGContext, hiding hidden: Int? = nil) {
    for annotation in document.annotations where annotation.id != hidden {
      draw(annotation, number: document.stepNumber(of: annotation.id), scale: document.scale, in: context)
    }
  }

  public static func draw(_ annotation: Annotation, number: Int?, scale: CGFloat, in context: CGContext) {
    context.saveGState()
    defer { context.restoreGState() }
    let color = annotation.style.color.cgColor
    let width = AnnotationGeometry.lineWidth(annotation, scale: scale)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineWidth(width)
    context.setStrokeColor(color)
    context.setFillColor(color)
    switch annotation.shape {
    case .arrow(let from, let to):
      drawArrow(from: from, to: to, width: width, scale: scale, in: context)
    case .rectangle(let rect):
      context.stroke(rect.standardized)
    case .pen(let points):
      stroke(points, in: context)
    case .highlighter(let points):
      // Semitransparente y multiplicado: lo de debajo se sigue leyendo.
      context.setBlendMode(.multiply)
      context.setStrokeColor(color.copy(alpha: 0.45) ?? color)
      stroke(points, in: context)
    case .text(let text, let origin):
      let (_, ascent) = AnnotationGeometry.textFrame(text, at: origin, style: annotation.style, scale: scale)
      let line = AnnotationGeometry.textLine(text, font: AnnotationGeometry.textFont(annotation.style), color: color)
      context.translateBy(x: origin.x, y: origin.y)
      context.scaleBy(x: scale, y: scale)
      context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
      context.textPosition = CGPoint(x: 0, y: ascent)
      CTLineDraw(line, context)
    case .step(let center):
      let radius = AnnotationGeometry.stepRadius(annotation.style, scale: scale)
      context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
      guard let number else { return }
      let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, radius * 1.15, nil)
        ?? CTFontCreateWithName("Helvetica-Bold" as CFString, radius * 1.15, nil)
      let line = AnnotationGeometry.textLine(String(number), font: font, color: annotation.style.color.contrast.cgColor)
      let glyphs = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
      context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
      context.textPosition = CGPoint(x: center.x - glyphs.midX, y: center.y + glyphs.midY)
      CTLineDraw(line, context)
    }
  }

  /// La captura con sus anotaciones, con los píxeles de la captura y su espacio de color.
  public static func render(_ image: CGImage, _ document: AnnotationDocument) -> CGImage? {
    let width = image.width, height = image.height
    let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    draw(document, in: context)
    return context.makeImage()
  }

  public static func png(_ image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination) ? data as Data : nil
  }

  private static func stroke(_ points: [CGPoint], in context: CGContext) {
    guard let first = points.first else { return }
    context.move(to: first)
    // Un solo punto: un trazo de largo cero, que con la punta redonda es un círculo.
    points.count == 1 ? context.addLine(to: first) : context.addLines(between: points)
    context.strokePath()
  }

  private static func drawArrow(from: CGPoint, to: CGPoint, width: CGFloat, scale: CGFloat, in context: CGContext) {
    let dx = to.x - from.x, dy = to.y - from.y
    let length = hypot(dx, dy)
    guard length > 0 else { return }
    let head = min(length, AnnotationGeometry.arrowHead(lineWidth: width, scale: scale))
    let ux = dx / length, uy = dy / length
    let base = CGPoint(x: to.x - ux * head, y: to.y - uy * head)
    // La línea entra un poco en la punta para que no quede hueco.
    context.move(to: from)
    context.addLine(to: CGPoint(x: base.x + ux * head * 0.3, y: base.y + uy * head * 0.3))
    context.strokePath()
    let half = head * 0.55
    context.move(to: to)
    context.addLine(to: CGPoint(x: base.x - uy * half, y: base.y + ux * half))
    context.addLine(to: CGPoint(x: base.x + uy * half, y: base.y - ux * half))
    context.closePath()
    context.fillPath()
  }
}

/// Los colores de una captura, en sRGB, para el color bajo el cursor (spec «Capturas» §3.1).
public struct ImagePixels {
  public let width: Int
  public let height: Int
  private let bytes: [UInt8]

  public init?(_ image: CGImage) {
    let width = image.width, height = image.height
    guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
      guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: space,
                                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else { return nil }
    self.width = width
    self.height = height
    self.bytes = bytes
  }

  /// `#RRGGBB` del píxel (x, y), con el origen arriba a la izquierda; nil fuera de la imagen.
  public func hex(x: Int, y: Int) -> String? {
    guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
    let index = (y * width + x) * 4
    return String(format: "#%02X%02X%02X", bytes[index], bytes[index + 1], bytes[index + 2])
  }
}
