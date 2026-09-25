import CoreGraphics
import ImageIO
import Testing
@testable import SinteclaCore

@Suite struct AnnotationRendererTests {
  /// Una captura en sRGB de un solo color.
  static func blank(width: Int = 400, height: Int = 200, gray: CGFloat = 1) -> CGImage? {
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.setFillColor(CGColor(srgbRed: gray, green: gray, blue: gray, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
  }

  /// La captura anotada, leída píxel a píxel.
  private func exported(_ document: AnnotationDocument, gray: CGFloat = 1) throws -> ImagePixels {
    let image = try #require(Self.blank(gray: gray))
    let rendered = try #require(AnnotationRenderer.render(image, document))
    return try #require(ImagePixels(rendered))
  }

  @Test func exportKeepsThePixelsAndDrawsFromTheTop() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.rectangle(CGRect(x: 50, y: 20, width: 200, height: 40)), style: AnnotationStyle(width: .thick))
    let pixels = try exported(document)
    #expect(pixels.width == 400 && pixels.height == 200)
    #expect(pixels.hex(x: 150, y: 20) == "#FF3B30")  // borde de arriba, a 20 px del borde superior
    #expect(pixels.hex(x: 50, y: 40) == "#FF3B30")
    #expect(pixels.hex(x: 150, y: 40) == "#FFFFFF")  // dentro
    #expect(pixels.hex(x: 150, y: 180) == "#FFFFFF")  // si se dibujara al revés, estaría aquí
  }

  @Test func pngHasTheSizeOfTheCapture() throws {
    let image = try #require(Self.blank(width: 123, height: 45))
    let rendered = try #require(AnnotationRenderer.render(image, AnnotationDocument()))
    let png = try #require(AnnotationRenderer.png(rendered))
    let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
    let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(decoded.width == 123 && decoded.height == 45)
  }

  @Test func highlighterLetsWhatIsBelowShowThrough() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.highlighter([CGPoint(x: 20, y: 100), CGPoint(x: 380, y: 100)]), style: AnnotationStyle(color: .yellow))
    let white = try exported(document), black = try exported(document, gray: 0)
    let hex = try #require(white.hex(x: 200, y: 100))
    let blue = try #require(Int(hex.suffix(2), radix: 16))
    #expect((60...220).contains(blue))  // ni blanco (FF) ni amarillo lleno (00)
    #expect(black.hex(x: 200, y: 100) == "#000000")  // el texto negro sigue negro
  }

  @Test func textIsDrawnTheRightWayUp() async throws {
    var document = AnnotationDocument(scale: 2)
    document.add(.text("Hola mundo", at: CGPoint(x: 40, y: 60)), style: AnnotationStyle(color: .black, width: .thick))
    let blank = try #require(Self.blank(width: 900, height: 240))
    let image = try #require(AnnotationRenderer.render(blank, document))
    guard case .text(let text) = try await TextRecognizer.recognize(image) else {
      Issue.record("el OCR no lee el texto dibujado")
      return
    }
    #expect(text.contains("Hola mundo"))
  }

  @Test func stepIsACircleOfItsColor() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.step(at: CGPoint(x: 100, y: 100)), style: AnnotationStyle(color: .blue))
    let pixels = try exported(document)
    #expect(pixels.hex(x: 100 - 11, y: 100) == "#007AFF")  // radio medio: 14
    #expect(pixels.hex(x: 100 - 20, y: 100) == "#FFFFFF")
  }

  @Test func pixelColorsAsHex() throws {
    let context = try #require(CGContext(data: nil, width: 2, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(srgbRed: 0x15 / 255, green: 0x15 / 255, blue: 0x15 / 255, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    context.setFillColor(CGColor(srgbRed: 1, green: 0x80 / 255, blue: 0, alpha: 1))
    context.fill(CGRect(x: 1, y: 0, width: 1, height: 1))
    let image = try #require(context.makeImage())
    let pixels = try #require(ImagePixels(image))
    #expect(pixels.hex(x: 0, y: 0) == "#151515")
    #expect(pixels.hex(x: 1, y: 0) == "#FF8000")
    #expect(pixels.hex(x: 2, y: 0) == nil)
    #expect(pixels.hex(x: 0, y: -1) == nil)
    #expect(CaptureNotice.color("#151515") == "Color copiado: #151515")
  }
}
