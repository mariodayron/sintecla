import Foundation

/// Conexión con un proveedor compatible con la API de OpenAI. Por defecto, Gemini.
public struct CloudConfig: Sendable, Equatable {
  public static let geminiBaseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/")!
  public static let defaultModel = "gemini-3.5-flash-lite"

  public var baseURL: URL
  public var model: String
  public var apiKey: String
  /// Segundos por intento: 30 en general, 120 en notas.
  public var timeout: TimeInterval

  public init(baseURL: URL = CloudConfig.geminiBaseURL, model: String = CloudConfig.defaultModel,
              apiKey: String, timeout: TimeInterval = 30) {
    self.baseURL = baseURL
    self.model = model
    self.apiKey = apiKey
    self.timeout = timeout
  }
}

public enum CloudError: Error, Equatable, Sendable {
  case missingKey
  case http(status: Int, message: String)
  case network(String)
  case invalidResponse

  /// Mensaje corto para la pastilla o la tarjeta.
  public var userMessage: String {
    switch self {
    case .missingKey: "Falta la clave de Gemini (Ajustes → IA)"
    case .http(let status, let message):
      switch status {
      case 400 where message.localizedCaseInsensitiveContains("api key"), 401, 403: "Gemini rechaza la clave (Ajustes → IA)"
      case 404: "Gemini no encuentra el modelo (Ajustes → IA)"
      case 429: "Límite de Gemini alcanzado: prueba en un rato"
      case 500...: "Gemini no responde ahora mismo"
      default: "Gemini devolvió un error \(status)"
      }
    case .network: "Sin conexión con Gemini"
    case .invalidResponse: "Respuesta de Gemini no válida"
    }
  }
}

/// Un modelo que devuelve JSON conforme a un esquema (JSON Schema en texto).
public protocol StructuredModel: Sendable {
  func completeJSON(instructions: String, prompt: String, schemaName: String, schema: String) async throws -> Data
}

/// Cliente de chat completions (formato OpenAI). Reintenta 2 veces con espera
/// exponencial ante 429 y 5xx; los fallos de red y los tiempos agotados no se reintentan.
public final class CloudTextModel: TextModel, StructuredModel, @unchecked Sendable {
  public let config: CloudConfig
  public var maxRetries = 2
  public var retryDelay: TimeInterval = 0.5
  private let session: URLSession

  public init(config: CloudConfig, session: URLSession = .shared) {
    self.config = config
    self.session = session
  }

  /// `maxTokens` se ignora: el tope solo hace falta con el modelo local.
  public func complete(instructions: String, prompt: String, maxTokens: Int?) async throws -> String {
    try await send(body(instructions: instructions, prompt: prompt, responseFormat: nil))
  }

  public func completeJSON(instructions: String, prompt: String, schemaName: String, schema: String) async throws -> Data {
    guard let schemaObject = try? JSONSerialization.jsonObject(with: Data(schema.utf8)) else {
      throw CloudError.invalidResponse
    }
    let format: [String: Any] = [
      "type": "json_schema",
      "json_schema": ["name": schemaName, "schema": schemaObject],
    ]
    let content = try await send(body(instructions: instructions, prompt: prompt, responseFormat: format))
    return Self.repairingJSONStrings(Data(Self.extractJSON(content).utf8))
  }

  func body(instructions: String, prompt: String, responseFormat: [String: Any]?) -> [String: Any] {
    var body: [String: Any] = [
      "model": config.model,
      "messages": [
        ["role": "system", "content": instructions],
        ["role": "user", "content": prompt],
      ],
    ]
    // Gemini piensa antes de responder; "minimal" lo reduce al mínimo (más rápido y barato).
    if config.model.hasPrefix("gemini") { body["reasoning_effort"] = "minimal" }
    if let responseFormat { body["response_format"] = responseFormat }
    return body
  }

  private func send(_ body: [String: Any]) async throws -> String {
    guard !config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { throw CloudError.missingKey }
    var request = URLRequest(url: config.baseURL.appendingPathComponent("chat/completions"))
    request.httpMethod = "POST"
    request.timeoutInterval = config.timeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    var attempt = 0
    while true {
      let data: Data
      let response: URLResponse
      do {
        (data, response) = try await session.data(for: request)
      } catch {
        throw CloudError.network(error.localizedDescription)
      }
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      if status == 200 { return try Self.content(from: data) }
      let error = CloudError.http(status: status, message: Self.errorMessage(from: data))
      guard status == 429 || status >= 500, attempt < maxRetries else { throw error }
      try await Task.sleep(for: .seconds(retryDelay * pow(2, Double(attempt))))
      attempt += 1
    }
  }

  static func content(from data: Data) throws -> String {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let choices = json["choices"] as? [[String: Any]],
          let message = choices.first?["message"] as? [String: Any],
          let content = message["content"] as? String else { throw CloudError.invalidResponse }
    return repairMojibake(content.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  /// Gemini a veces escribe algún carácter con doble codificación: "dÃ­a" en lugar de "día" (los bytes
  /// UTF-8 leídos como Latin-1 o Windows-1252). Solo se deshacen las secuencias que empiezan como las de
  /// ese fallo (Â, Ã, â, ð) y que, releídas como UTF-8, son válidas: "NÃO" o "AQUÍ…" no se tocan.
  static func repairMojibake(_ text: String) -> String {
    let scalars = Array(text.unicodeScalars)
    guard scalars.contains(where: { mojibakeLeads[$0.value] != nil }) else { return text }
    var repaired = String.UnicodeScalarView()
    var index = 0
    while index < scalars.count {
      if let length = mojibakeLeads[scalars[index].value], index + length <= scalars.count {
        let bytes = scalars[index..<index + length].compactMap(latinByte)
        if bytes.count == length, bytes.dropFirst().allSatisfy({ (0x80...0xBF).contains($0) }),
           let decoded = String(bytes: bytes, encoding: .utf8) {
          repaired.append(contentsOf: decoded.unicodeScalars)
          index += length
          continue
        }
      }
      repaired.append(scalars[index])
      index += 1
    }
    return String(repaired)
  }

  /// Primer carácter de la secuencia rota → bytes UTF-8 que ocupa (Â Ã: 2; â: 3; ð: 4).
  private static let mojibakeLeads: [UInt32: Int] = [0xC2: 2, 0xC3: 2, 0xE2: 3, 0xF0: 4]

  /// Byte que representa el carácter en Latin-1 o, si no está ahí, en Windows-1252.
  private static func latinByte(_ scalar: Unicode.Scalar) -> UInt8? {
    scalar.value <= 0xFF ? UInt8(scalar.value) : windows1252[scalar.value]
  }

  private static let windows1252: [UInt32: UInt8] = [
    0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87,
    0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C, 0x017D: 0x8E, 0x2018: 0x91,
    0x2019: 0x92, 0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97, 0x02DC: 0x98,
    0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B, 0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F,
  ]

  /// Repara cada cadena de un JSON: ahí la doble codificación llega a veces como escapes
  /// (`dÃ­a`) que solo se ven al leerlo. Sin nada que reparar, devuelve los mismos datos.
  static func repairingJSONStrings(_ data: Data) -> Data {
    guard let object = try? JSONSerialization.jsonObject(with: data) else { return data }
    var changed = false
    func repair(_ value: Any) -> Any {
      switch value {
      case let text as String:
        let fixed = repairMojibake(text)
        if fixed != text { changed = true }
        return fixed
      case let list as [Any]: return list.map(repair)
      case let dictionary as [String: Any]: return dictionary.mapValues(repair)
      default: return value
      }
    }
    let repaired = repair(object)
    guard changed, let result = try? JSONSerialization.data(withJSONObject: repaired) else { return data }
    return result
  }

  /// Gemini a veces envuelve el error en una lista: `[{"error": {...}}]`.
  static func errorMessage(from data: Data) -> String {
    let json = try? JSONSerialization.jsonObject(with: data)
    let object = (json as? [[String: Any]])?.first ?? (json as? [String: Any])
    if let message = (object?["error"] as? [String: Any])?["message"] as? String { return message }
    return String(decoding: data.prefix(300), as: UTF8.self)
  }

  /// Quita ```json … ``` y texto alrededor del objeto JSON.
  static func extractJSON(_ content: String) -> String {
    guard let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}"), start < end else { return content }
    return String(content[start...end])
  }
}
