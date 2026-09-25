import CoreGraphics
import CoreImage
import CoreText
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct TextRecognizerTests {
  /// Caja en coordenadas normalizadas de Vision (origen abajo a la izquierda).
  private func line(_ text: String, x: Double, y: Double, width: Double = 0.2, height: Double = 0.04) -> RecognizedLine {
    RecognizedLine(text: text, box: CGRect(x: x, y: y, width: width, height: height))
  }

  @Test func rowsFromTopToBottomAndLeftToRight() {
    let lines = [
      line("segunda", x: 0.1, y: 0.50),
      line("derecha", x: 0.6, y: 0.80),
      line("izquierda", x: 0.1, y: 0.81),  // misma fila que «derecha» (se solapan)
      line("tercera", x: 0.1, y: 0.20),
    ]
    #expect(TextRecognizer.compose(lines: lines) == "izquierda derecha\nsegunda\ntercera")
  }

  @Test func barelyTouchingLinesAreDifferentRows() {
    let lines = [line("arriba", x: 0.1, y: 0.53), line("abajo", x: 0.5, y: 0.50)]  // se solapan 0,01 de 0,04
    #expect(TextRecognizer.compose(lines: lines) == "arriba\nabajo")
  }

  @Test func codesGoBeforeText() {
    let code = RecognizedCode(payload: "https://example.com", isQR: true)
    #expect(TextRecognizer.content(codes: [code], lines: [line("hola", x: 0, y: 0)]) == .codes([code]))
    #expect(TextRecognizer.content(codes: [], lines: [line("hola", x: 0, y: 0)]) == .text("hola"))
    #expect(TextRecognizer.content(codes: [], lines: [line("  ", x: 0, y: 0)]) == .nothing)
    #expect(RecognizedContent.codes([code, RecognizedCode(payload: "123", isQR: false)]).copiedText == "https://example.com\n123")
  }

  @Test func readsSpanishTextWithVision() async throws {
    let image = try #require(Self.render("Configuración: añadir 3 términos"))
    let content = try await TextRecognizer.recognize(image)
    guard case .text(let text) = content else { Issue.record("sin texto: \(content)"); return }
    #expect(text.contains("Configuración"))
    #expect(text.contains("términos"))
  }

  @Test func readsAQRCodeWithVision() async throws {
    let image = try #require(Self.qr("https://example.com"))
    #expect(try await TextRecognizer.recognize(image) == .codes([RecognizedCode(payload: "https://example.com", isQR: true)]))
  }

  @Test func blankImageHasNothing() async throws {
    let image = try #require(Self.render(""))
    #expect(try await TextRecognizer.recognize(image) == .nothing)
  }

  /// Texto negro sobre blanco, a 48 pt, como en una captura.
  static func render(_ text: String) -> CGImage? {
    let width = 1400, height = 200
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let font = CTFontCreateWithName("Helvetica" as CFString, 48, nil)
    let attributes: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key(kCTFontAttributeName as String): font,
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1),
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    context.textPosition = CGPoint(x: 40, y: 80)
    CTLineDraw(line, context)
    return context.makeImage()
  }

  static func qr(_ payload: String) -> CGImage? {
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(Data(payload.utf8), forKey: "inputMessage")
    guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)) else { return nil }
    let padded = output.transformed(by: CGAffineTransform(translationX: 60, y: 60))
      .composited(over: CIImage(color: .white).cropped(to: output.extent.insetBy(dx: -60, dy: -60).offsetBy(dx: 60, dy: 60)))
    return CIContext().createCGImage(padded, from: padded.extent)
  }
}

@Suite struct CaptureNoticeTests {
  @Test func textWithWordCount() {
    #expect(CaptureNotice.text("hola") == "Texto copiado · 1 palabra")
    #expect(CaptureNotice.text("Configuración: añadir 3 términos\nsegunda línea") == "Texto copiado · 6 palabras")
  }

  @Test func codesShowTheirContentCut() {
    #expect(CaptureNotice.codes([RecognizedCode(payload: "https://example.com", isQR: true)]) == "QR copiado: https://example.com")
    #expect(CaptureNotice.codes([RecognizedCode(payload: "8412345678905", isQR: false)]) == "Código copiado: 8412345678905")
    let long = String(repeating: "a", count: 50)
    #expect(CaptureNotice.codes([RecognizedCode(payload: long, isQR: true)]) == "QR copiado: " + String(repeating: "a", count: 40) + "…")
    #expect(CaptureNotice.codes([RecognizedCode(payload: "a", isQR: true), RecognizedCode(payload: "b", isQR: false)])
            == "2 códigos copiados")
  }

  @Test func fixedNotices() {
    #expect(CaptureNotice.copied == "Captura copiada")
    #expect(CaptureNotice.noText == "No hay texto en esa zona")
    #expect(CaptureNotice.noPermission == "Falta el permiso de Grabación de pantalla")
  }
}
