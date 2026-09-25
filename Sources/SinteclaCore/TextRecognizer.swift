import CoreGraphics
import Foundation
import Vision

/// Una línea que ha leído el OCR, con su caja en coordenadas normalizadas de Vision (origen abajo a la izquierda).
public struct RecognizedLine: Equatable, Sendable {
  public var text: String
  public var box: CGRect

  public init(text: String, box: CGRect) {
    self.text = text
    self.box = box
  }
}

/// El contenido de un QR o de un código de barras.
public struct RecognizedCode: Equatable, Sendable {
  public var payload: String
  public var isQR: Bool

  public init(payload: String, isQR: Bool) {
    self.payload = payload
    self.isQR = isQR
  }
}

/// Lo que hay en una zona de la pantalla (spec «Capturas» §2.4): códigos, texto o nada.
public enum RecognizedContent: Equatable, Sendable {
  case codes([RecognizedCode])
  case text(String)
  case nothing

  /// Lo que se copia al portapapeles: los códigos, uno por línea, o el texto.
  public var copiedText: String? {
    switch self {
    case .codes(let codes): codes.map(\.payload).joined(separator: "\n")
    case .text(let text): text
    case .nothing: nil
    }
  }
}

/// OCR y lectura de códigos con Vision de Apple, en español e inglés.
public enum TextRecognizer {
  public static func recognize(_ image: CGImage) async throws -> RecognizedContent {
    try await Task.detached(priority: .userInitiated) {
      let textRequest = VNRecognizeTextRequest()
      textRequest.recognitionLevel = .accurate
      textRequest.recognitionLanguages = ["es-ES", "en-US"]
      textRequest.usesLanguageCorrection = true
      let codeRequest = VNDetectBarcodesRequest()
      try VNImageRequestHandler(cgImage: image).perform([textRequest, codeRequest])
      let lines = (textRequest.results ?? []).compactMap { observation in
        observation.topCandidates(1).first.map { RecognizedLine(text: $0.string, box: observation.boundingBox) }
      }
      var codes: [RecognizedCode] = []
      for observation in codeRequest.results ?? [] {
        guard let payload = observation.payloadStringValue, !codes.contains(where: { $0.payload == payload }) else { continue }
        codes.append(RecognizedCode(payload: payload, isQR: observation.symbology == .qr))
      }
      return content(codes: codes, lines: lines)
    }.value
  }

  /// Si hay códigos, van ellos; si no, el texto; si no hay nada legible, nada.
  public static func content(codes: [RecognizedCode], lines: [RecognizedLine]) -> RecognizedContent {
    if !codes.isEmpty { return .codes(codes) }
    let text = compose(lines: lines).trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? .nothing : .text(text)
  }

  /// Filas de arriba abajo; en cada fila, los trozos de izquierda a derecha unidos por un espacio.
  public static func compose(lines: [RecognizedLine]) -> String {
    var rows: [[RecognizedLine]] = []
    for line in lines.sorted(by: { $0.box.midY > $1.box.midY }) {
      if let index = rows.firstIndex(where: { sameRow($0[0].box, line.box) }) {
        rows[index].append(line)
      } else {
        rows.append([line])
      }
    }
    return rows.map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
      .joined(separator: "\n")
  }

  /// Misma fila si se solapan en vertical más de la mitad de la más baja.
  static func sameRow(_ a: CGRect, _ b: CGRect) -> Bool {
    let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
    return overlap > 0.5 * min(a.height, b.height)
  }
}
