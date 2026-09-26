import CoreGraphics
import Testing
@testable import SinteclaCore

@Suite struct AnnotationPixelateTests {
  /// Rayas verticales de un píxel, negras y blancas: un patrón fino que el pixelado vuelve liso.
  static func stripes(width: Int = 240, height: Int = 120) -> CGImage? {
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
    for x in stride(from: 0, to: width, by: 2) { context.fill(CGRect(x: x, y: 0, width: 1, height: height)) }
    return context.makeImage()
  }

  /// La captura de rayas con las anotaciones, leída píxel a píxel.
  private func exported(_ document: AnnotationDocument) throws -> ImagePixels {
    let image = try #require(Self.stripes())
    let rendered = try #require(AnnotationRenderer.render(image, document))
    return try #require(ImagePixels(rendered))
  }

  /// Cuadros de 12 px (grosor medio a escala 1): la zona de 96 × 48 son 8 × 4 cuadros justos.
  private let zone = CGRect(x: 24, y: 24, width: 96, height: 48)

  @Test func eachBlockIsOneFlatColor() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.pixelate(zone), style: AnnotationStyle())
    let pixels = try exported(document)
    let block = Set((36..<48).flatMap { x in (24..<36).map { y in pixels.hex(x: x, y: y) } })
    #expect(block.count == 1)
    let hex = try #require(block.first ?? nil)
    let gray = try #require(Int(hex.dropFirst().prefix(2), radix: 16))
    #expect((0x40...0xC0).contains(gray))  // ni negro ni blanco: la media de las rayas
  }

  @Test func outsideTheZoneTheCaptureIsUntouched() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.pixelate(zone), style: AnnotationStyle())
    let pixels = try exported(document)
    #expect(pixels.hex(x: 10, y: 10) == "#000000")
    #expect(pixels.hex(x: 11, y: 10) == "#FFFFFF")
    #expect(pixels.hex(x: 130, y: 50) == "#000000")
  }

  @Test func annotationsStayOnTopEvenIfDrawnBefore() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.arrow(from: CGPoint(x: 0, y: 60), to: CGPoint(x: 200, y: 60)), style: AnnotationStyle(width: .thick))
    document.add(.pixelate(zone), style: AnnotationStyle())
    let pixels = try exported(document)
    #expect(pixels.hex(x: 60, y: 60) == "#FF3B30")
  }

  @Test func biggerWidthMeansBiggerBlocks() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.pixelate(CGRect(x: 0, y: 0, width: 72, height: 72)), style: AnnotationStyle(width: .thick))
    let pixels = try exported(document)
    #expect(Set((0..<18).map { pixels.hex(x: $0, y: 5) }).count == 1)  // cuadros de 18 px
    #expect([AnnotationWidth.thin, .medium, .thick].map(\.pixelBlock) == [8, 12, 18])
  }

  @Test func pixelateIsAnAnnotationLikeTheOthers() {
    var document = AnnotationDocument(scale: 2)
    let id = document.add(.pixelate(zone), style: AnnotationStyle())
    #expect(document.hit(CGPoint(x: 60, y: 40)) == id)  // se toca por dentro
    #expect(document.hit(CGPoint(x: 200, y: 100)) == nil)
    document.move(id, by: CGVector(dx: 10, dy: 0))
    #expect(document.annotation(id)?.shape == .pixelate(zone.offsetBy(dx: 10, dy: 0)))
    #expect(AnnotationShape.pixelate(CGRect(x: 0, y: 0, width: 3, height: 3)).isTooSmall(scale: 1))
    document.undo()
    #expect(document.annotation(id)?.shape == .pixelate(zone))
  }
}
