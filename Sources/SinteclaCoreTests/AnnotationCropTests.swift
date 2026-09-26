import CoreGraphics
import Testing
@testable import SinteclaCore

@Suite struct AnnotationCropTests {
  private let size = CGSize(width: 400, height: 200)

  /// Mitad de arriba azul y mitad de abajo blanca.
  static func twoHalves() -> CGImage? {
    guard let context = CGContext(data: nil, width: 400, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 400, height: 100))  // abajo (el contexto va de abajo arriba)
    context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 100, width: 400, height: 100))  // arriba
    return context.makeImage()
  }

  private func exported(_ document: AnnotationDocument) throws -> ImagePixels {
    let image = try #require(Self.twoHalves())
    let rendered = try #require(AnnotationRenderer.render(image, document))
    return try #require(ImagePixels(rendered))
  }

  @Test func exportHasTheSizeAndContentOfTheCrop() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.rectangle(CGRect(x: 110, y: 160, width: 50, height: 20)), style: AnnotationStyle(width: .thick))
    document.setCrop(CGRect(x: 100, y: 150, width: 100, height: 50), in: size)
    let bottom = try exported(document)
    #expect(bottom.width == 100 && bottom.height == 50)
    #expect(bottom.hex(x: 50, y: 2) == "#FFFFFF")  // de la mitad de abajo
    #expect(bottom.hex(x: 10, y: 20) == "#FF3B30")  // el borde izquierdo del rectángulo, en x = 110 − 100
    document.setCrop(CGRect(x: 0, y: 0, width: 100, height: 50), in: size)
    #expect(try exported(document).hex(x: 50, y: 25) == "#0000FF")  // de la mitad de arriba
  }

  @Test func undoBringsBackTheWholeCapture() throws {
    var document = AnnotationDocument(scale: 1)
    document.setCrop(CGRect(x: 10, y: 10, width: 50, height: 40), in: size)
    #expect(document.visibleRect(in: size) == CGRect(x: 10, y: 10, width: 50, height: 40))
    document.undo()
    #expect(document.crop == nil)
    #expect(try exported(document).width == 400)
    document.redo()
    #expect(try exported(document).width == 50)
  }

  @Test func annotationsOutsideTheCropAreKept() {
    var document = AnnotationDocument(scale: 1)
    let id = document.add(.arrow(from: CGPoint(x: 300, y: 20), to: CGPoint(x: 380, y: 20)), style: AnnotationStyle())
    document.setCrop(CGRect(x: 0, y: 100, width: 100, height: 100), in: size)
    #expect(document.annotations.map(\.id) == [id])
    #expect(document.hit(CGPoint(x: 340, y: 20)) == id)  // en píxeles de la captura entera
  }

  @Test func cropIsClampedToTheCapture() {
    var document = AnnotationDocument(scale: 1)
    document.setCrop(CGRect(x: -20, y: 150, width: 500, height: 100), in: size)
    #expect(document.crop == CGRect(x: 0, y: 150, width: 400, height: 50))
    document.setCrop(CGRect(x: 0, y: 150, width: 400, height: 50), in: size)  // el mismo: no es un cambio
    document.undo()
    #expect(document.crop == nil)
    #expect(!document.canUndo)
    document.setCrop(CGRect(origin: .zero, size: size), in: size)  // la captura entera no es un recorte
    #expect(document.crop == nil && !document.canUndo)
  }

  @Test func undoingAnAnnotationKeepsTheCrop() {
    var document = AnnotationDocument(scale: 1)
    document.setCrop(CGRect(x: 0, y: 0, width: 100, height: 100), in: size)
    document.add(.step(at: CGPoint(x: 50, y: 50)), style: AnnotationStyle())
    document.undo()
    #expect(document.annotations.isEmpty)
    #expect(document.crop == CGRect(x: 0, y: 0, width: 100, height: 100))
  }
}
