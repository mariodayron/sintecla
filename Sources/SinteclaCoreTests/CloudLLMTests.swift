import Foundation
import Testing
@testable import SinteclaCore

/// Sustituye a internet: cada petición la contesta `handler`.
final class StubURLProtocol: URLProtocol {
  nonisolated(unsafe) static var handler: ((URLRequest, Data) -> (Int, String))?
  nonisolated(unsafe) static var bodies: [Data] = []

  static func session() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func stopLoading() {}

  override func startLoading() {
    let body = request.httpBody ?? Self.read(request.httpBodyStream)
    Self.bodies.append(body)
    let (status, text) = Self.handler?(request, body) ?? (500, "")
    let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(text.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  /// URLSession entrega el cuerpo como stream a los URLProtocol.
  static func read(_ stream: InputStream?) -> Data {
    guard let stream else { return Data() }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
      let n = stream.read(&buffer, maxLength: buffer.count)
      if n <= 0 { break }
      data.append(buffer, count: n)
    }
    return data
  }
}

func chatReply(_ content: String) -> String {
  let json = try! JSONSerialization.data(withJSONObject: ["choices": [["message": ["role": "assistant", "content": content]]]])
  return String(decoding: json, as: UTF8.self)
}

@Suite(.serialized) struct CloudTextModelTests {
  func model(key: String = "clave-de-prueba") -> CloudTextModel {
    StubURLProtocol.bodies = []
    let m = CloudTextModel(config: CloudConfig(apiKey: key), session: StubURLProtocol.session())
    m.retryDelay = 0.01
    return m
  }

  func lastBody() -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: StubURLProtocol.bodies.last ?? Data())) as? [String: Any] ?? [:]
  }

  @Test func sendsOpenAIChatRequestAndReadsContent() async throws {
    var seen: URLRequest?
    StubURLProtocol.handler = { request, _ in
      seen = request
      return (200, chatReply("  Hola  "))
    }
    let reply = try await model().complete(instructions: "Sé breve", prompt: "Saluda")
    #expect(reply == "Hola")
    #expect(seen?.url?.absoluteString == "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")
    #expect(seen?.value(forHTTPHeaderField: "Authorization") == "Bearer clave-de-prueba")
    let body = lastBody()
    #expect(body["model"] as? String == "gemini-3.5-flash-lite")
    #expect(body["reasoning_effort"] as? String == "minimal")
    let messages = body["messages"] as? [[String: String]]
    #expect(messages == [["role": "system", "content": "Sé breve"], ["role": "user", "content": "Saluda"]])
    #expect(body["response_format"] == nil)
  }

  @Test func requestsJSONSchemaAndStripsFences() async throws {
    StubURLProtocol.handler = { _, _ in (200, chatReply("```json\n{\"sitio\": \"youtube\"}\n```")) }
    let data = try await model().completeJSON(instructions: "i", prompt: "p", schemaName: "accion",
                                              schema: #"{"type":"object","properties":{"sitio":{"type":"string"}}}"#)
    #expect(String(decoding: data, as: UTF8.self) == #"{"sitio": "youtube"}"#)
    let format = lastBody()["response_format"] as? [String: Any]
    #expect(format?["type"] as? String == "json_schema")
    let schema = format?["json_schema"] as? [String: Any]
    #expect(schema?["name"] as? String == "accion")
    #expect((schema?["schema"] as? [String: Any])?["type"] as? String == "object")
  }

  @Test func retriesRateLimitsThenSucceeds() async throws {
    var calls = 0
    StubURLProtocol.handler = { _, _ in
      calls += 1
      return calls < 3 ? (429, #"{"error":{"message":"quota"}}"#) : (200, chatReply("ok"))
    }
    #expect(try await model().complete(instructions: "i", prompt: "p") == "ok")
    #expect(calls == 3)
  }

  @Test func givesUpAfterTwoRetries() async {
    var calls = 0
    StubURLProtocol.handler = { _, _ in
      calls += 1
      return (503, #"{"error":{"message":"overloaded"}}"#)
    }
    await #expect(throws: CloudError.http(status: 503, message: "overloaded")) {
      try await model().complete(instructions: "i", prompt: "p")
    }
    #expect(calls == 3)
  }

  @Test func doesNotRetryAuthErrorsAndReadsListWrappedMessage() async {
    var calls = 0
    StubURLProtocol.handler = { _, _ in
      calls += 1
      return (400, #"[{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}]"#)
    }
    do {
      _ = try await model().complete(instructions: "i", prompt: "p")
      Issue.record("debería fallar")
    } catch let error as CloudError {
      #expect(error == .http(status: 400, message: "API key not valid. Please pass a valid API key."))
      #expect(error.userMessage == "Gemini rechaza la clave (Ajustes → IA)")
    } catch {
      Issue.record("error inesperado: \(error)")
    }
    #expect(calls == 1)
  }

  @Test func missingKeyFailsWithoutCallingTheNetwork() async {
    StubURLProtocol.handler = { _, _ in (200, chatReply("no debería llegar")) }
    await #expect(throws: CloudError.missingKey) {
      try await model(key: "  ").complete(instructions: "i", prompt: "p")
    }
    #expect(StubURLProtocol.bodies.isEmpty)
  }

  @Test func malformedReplyIsInvalidResponse() async {
    StubURLProtocol.handler = { _, _ in (200, #"{"choices":[]}"#) }
    await #expect(throws: CloudError.invalidResponse) {
      try await model().complete(instructions: "i", prompt: "p")
    }
  }

  /// Visto en unas notas reales: "antes del dÃ­a diez" y "se valorarÃ­a" (1 de cada ~40 respuestas).
  @Test func repairsDoubleEncodedText() async throws {
    StubURLProtocol.handler = { _, _ in (200, chatReply("Antes del d\u{C3}\u{AD}a diez se valorar\u{C3}\u{AD}a")) }
    #expect(try await model().complete(instructions: "i", prompt: "p") == "Antes del día diez se valoraría")
  }

  @Test func repairsDoubleEncodingEscapedInsideJSON() async throws {
    StubURLProtocol.handler = { _, _ in
      (200, chatReply(#"{"resumen": "antes del dÃ­a diez", "tareas": ["pedir el camiÃ³n"]}"#))
    }
    let data = try await model().completeJSON(instructions: "i", prompt: "p", schemaName: "notas", schema: #"{"type":"object"}"#)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(object?["resumen"] as? String == "antes del día diez")
    #expect(object?["tareas"] as? [String] == ["pedir el camión"])
  }

  @Test func repairsOnlyDoubleEncodedSequences() {
    #expect(CloudTextModel.repairMojibake("Â¿QuÃ© tal, EspaÃ±a? Ã‘OÃ‘O â€œbienâ€\u{9D} ðŸ˜€") == "¿Qué tal, España? ÑOÑO “bien” 😀")
    let correct = "¿Qué tal? «Sí», NÃO SÃO, 10 € — “AQUÍ…” pâté ñandú"
    #expect(CloudTextModel.repairMojibake(correct) == correct)
  }
}
