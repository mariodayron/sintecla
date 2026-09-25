/// Los avisos de la pastilla del módulo Capturas (spec «Capturas» §2).
public enum CaptureNotice {
  public static let copied = "Captura copiada"
  public static let noText = "No hay texto en esa zona"
  public static let noPermission = "Falta el permiso de Grabación de pantalla"
  /// Largo máximo del contenido de un código en el aviso.
  static let maxPayload = 40

  public static func text(_ text: String) -> String {
    let words = TextMetrics.wordCount(text)
    return "Texto copiado · \(words) \(words == 1 ? "palabra" : "palabras")"
  }

  public static func codes(_ codes: [RecognizedCode]) -> String {
    guard codes.count == 1, let code = codes.first else { return "\(codes.count) códigos copiados" }
    let payload = code.payload.count > maxPayload ? String(code.payload.prefix(maxPayload)) + "…" : code.payload
    return (code.isQR ? "QR copiado: " : "Código copiado: ") + payload
  }
}
