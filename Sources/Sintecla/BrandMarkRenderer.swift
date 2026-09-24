import AppKit
import SinteclaCore
import SwiftUI

/// Pinta `BrandMark`: el icono de la app (cristal claro) y la imagen plantilla de la barra de menú.
enum BrandMarkRenderer {
  /// Casi negro del dibujo en el icono.
  static let ink = CGColor(srgbRed: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255, alpha: 1)

  /// Dibuja las piezas en `rect`. Quartz tiene el origen abajo y la geometría arriba: se da la vuelta a la y.
  static func draw(_ variant: BrandMark.Variant, in rect: CGRect, color: CGColor, context: CGContext) {
    for piece in BrandMark.pieces(variant) {
      let frame = CGRect(x: rect.minX + piece.x * rect.width, y: rect.maxY - piece.maxY * rect.height,
                         width: piece.width * rect.width, height: piece.height * rect.height)
      let radius = min(frame.width, frame.height) / 2
      context.addPath(CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil))
      context.setFillColor(color.copy(alpha: piece.opacity) ?? color)
      context.fillPath()
    }
  }

  /// Imagen plantilla de 16 × 16 pt: macOS la pinta en negro o blanco según la barra. El reposo va en el canal alfa.
  static func menuImage(recording: Bool) -> NSImage {
    let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
      guard let context = NSGraphicsContext.current?.cgContext else { return false }
      draw(recording ? .menuRecording : .menuIdle, in: rect.insetBy(dx: 1, dy: 1), color: .black, context: context)
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Sintecla"
    return image
  }

  // MARK: - Icono de la app

  /// Lados en píxeles del `.iconset` y su nombre de archivo.
  static let iconFiles: [(pixels: Int, name: String)] = [16, 32, 128, 256, 512].flatMap { points in
    [(points, "icon_\(points)x\(points).png"), (points * 2, "icon_\(points)x\(points)@2x.png")]
  }

  /// PNG del icono de `pixels` × `pixels`: squircle estándar de macOS (824 de 1024) de cristal claro con el dibujo.
  static func iconPNG(pixels: Int) -> Data? {
    guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let scale = CGFloat(pixels) / 1024
    let tile = CGRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let shape = RoundedRectangle(cornerRadius: 185.4 * scale, style: .continuous).path(in: tile).cgPath

    // Relleno: de blanco arriba a gris perla abajo.
    context.saveGState()
    context.addPath(shape)
    context.clip()
    let fill = CGGradient(colorsSpace: nil, colors: [CGColor(gray: 1, alpha: 1),
                                                     CGColor(srgbRed: 0xE4 / 255, green: 0xE4 / 255, blue: 0xE8 / 255, alpha: 1)] as CFArray,
                          locations: [0, 1])!
    context.drawLinearGradient(fill, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    // Brillo: media elipse blanca en la mitad de arriba, del 35 % a transparente.
    let sheen = CGGradient(colorsSpace: nil, colors: [CGColor(gray: 1, alpha: 0.35), CGColor(gray: 1, alpha: 0)] as CFArray,
                           locations: [0, 1])!
    context.saveGState()
    context.translateBy(x: tile.midX, y: tile.maxY)
    context.scaleBy(x: 1, y: 0.5)
    context.drawRadialGradient(sheen, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: tile.width * 0.75, options: [])
    context.restoreGState()
    // Borde fino por dentro: blanco arriba y gris abajo (el trazo se recorta a la mitad de dentro).
    context.addPath(shape)
    context.setLineWidth(max(8 * scale, 1))
    context.replacePathWithStrokedPath()
    context.clip()
    let rim = CGGradient(colorsSpace: nil, colors: [CGColor(gray: 1, alpha: 1),
                                                    CGColor(srgbRed: 0xC8 / 255, green: 0xC8 / 255, blue: 0xCE / 255, alpha: 1)] as CFArray,
                         locations: [0, 1])!
    context.drawLinearGradient(rim, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    context.restoreGState()

    draw(pixels <= 32 ? .small : .large, in: tile, color: ink, context: context)
    guard let image = context.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
  }
}
