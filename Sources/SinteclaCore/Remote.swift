import CryptoKit
import Foundation

/// Módulo Mando: el móvil como trackpad y mando del Mac, desde el navegador (antes MacRemote, un script de Python).
/// Aquí va lo que se puede probar sin red: leer peticiones HTTP, las tramas de WebSocket, las órdenes del móvil y la
/// llave de acceso.
public enum Remote {
  public static let defaultPort: UInt16 = 8080
  /// La cookie que guarda la llave en el móvil, tras abrir el enlace del QR.
  public static let cookieName = "sintecla_mando"

  /// Una llave nueva: 24 caracteres sin ambigüedades (sin 0/O ni 1/l).
  public static func newKey() -> String {
    let alphabet = Array("abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    return String((0..<24).map { _ in alphabet.randomElement()! })
  }

  /// El enlace que abre el móvil (el del QR): con la llave, que el servidor guarda después en una cookie.
  public static func link(host: String, port: UInt16, key: String) -> String {
    "http://\(host):\(port)/?k=\(key)"
  }

  /// La cabecera `Sec-WebSocket-Accept` para una `Sec-WebSocket-Key` (RFC 6455 §4.2.2).
  public static func webSocketAccept(key: String) -> String {
    let digest = Insecure.SHA1.hash(data: Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8))
    return Data(digest).base64EncodedString()
  }
}

/// Una petición HTTP del móvil: método, ruta, consulta, cabeceras (en minúsculas) y cuerpo.
public struct RemoteRequest: Equatable, Sendable {
  public var method: String
  public var path: String
  public var query: [String: String]
  public var headers: [String: String]
  public var body: Data

  /// La cabecera y, si `Content-Length` lo dice, el cuerpo completo. nil si aún falta algo por llegar.
  public static func parse(_ data: Data) -> RemoteRequest? {
    guard let end = data.range(of: Data("\r\n\r\n".utf8)),
          let head = String(data: data[data.startIndex..<end.lowerBound], encoding: .utf8) else { return nil }
    var lines = head.components(separatedBy: "\r\n")
    let parts = lines.removeFirst().split(separator: " ")
    guard parts.count >= 2 else { return nil }
    var headers: [String: String] = [:]
    for line in lines {
      guard let colon = line.firstIndex(of: ":") else { continue }
      headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
    }
    let length = Int(headers["content-length"] ?? "") ?? 0
    let body = data[end.upperBound...]
    guard body.count >= length else { return nil }
    let target = String(parts[1])
    let components = URLComponents(string: target)
    var query: [String: String] = [:]
    for item in components?.queryItems ?? [] { query[item.name] = item.value ?? "" }
    return RemoteRequest(method: String(parts[0]), path: components?.path ?? target, query: query, headers: headers,
                         body: Data(body.prefix(length)))
  }

  /// Lo que trae la cabecera `Cookie`.
  public var cookies: [String: String] {
    var result: [String: String] = [:]
    for pair in (headers["cookie"] ?? "").split(separator: ";") {
      let item = pair.split(separator: "=", maxSplits: 1)
      guard item.count == 2 else { continue }
      result[item[0].trimmingCharacters(in: .whitespaces)] = String(item[1]).trimmingCharacters(in: .whitespaces)
    }
    return result
  }

  public var isWebSocketUpgrade: Bool {
    headers["upgrade"]?.lowercased() == "websocket" && headers["sec-websocket-key"] != nil
  }

  /// Con la llave en el enlace (`?k=`) o en la cookie.
  public func isAuthorized(key: String) -> Bool {
    guard !key.isEmpty else { return false }
    return query["k"] == key || cookies[Remote.cookieName] == key
  }
}

/// Una trama de WebSocket (RFC 6455 §5.2). Del móvil llegan enmascaradas; las de Sintecla salen sin máscara.
public struct WebSocketFrame: Equatable, Sendable {
  public enum Opcode: UInt8, Sendable {
    case continuation = 0, text = 1, binary = 2, close = 8, ping = 9, pong = 10
  }

  public var opcode: Opcode
  public var payload: Data

  public init(opcode: Opcode, payload: Data) {
    self.opcode = opcode
    self.payload = payload
  }

  /// La primera trama completa de `data` y cuántos bytes ocupa, o nil si aún no ha llegado entera.
  public static func decode(_ data: Data) -> (frame: WebSocketFrame, length: Int)? {
    let bytes = [UInt8](data.prefix(14))
    guard bytes.count >= 2 else { return nil }
    let opcode = Opcode(rawValue: bytes[0] & 0x0F) ?? .binary
    let masked = bytes[1] & 0x80 != 0
    var length = Int(bytes[1] & 0x7F)
    var offset = 2
    if length == 126 {
      guard bytes.count >= 4 else { return nil }
      length = Int(bytes[2]) << 8 | Int(bytes[3])
      offset = 4
    } else if length == 127 {
      guard bytes.count >= 10 else { return nil }
      length = bytes[2..<10].reduce(0) { $0 << 8 | Int($1) }
      offset = 10
    }
    let mask: [UInt8] = masked ? Array(bytes.dropFirst(offset).prefix(4)) : []
    if masked {
      guard mask.count == 4 else { return nil }
      offset += 4
    }
    guard length >= 0, data.count >= offset + length else { return nil }
    var payload = [UInt8](data.dropFirst(offset).prefix(length))
    if masked {
      for index in payload.indices { payload[index] ^= mask[index & 3] }
    }
    return (WebSocketFrame(opcode: opcode, payload: Data(payload)), offset + length)
  }

  /// Una trama final, sin máscara.
  public func encoded() -> Data {
    var data = Data([0x80 | opcode.rawValue])
    switch payload.count {
    case ..<126: data.append(UInt8(payload.count))
    case ..<65_536: data.append(contentsOf: [126, UInt8(payload.count >> 8), UInt8(payload.count & 0xFF)])
    default:
      data.append(127)
      data.append(contentsOf: (0..<8).reversed().map { UInt8((payload.count >> ($0 * 8)) & 0xFF) })
    }
    data.append(payload)
    return data
  }
}

/// Lo que pide el móvil (el mismo JSON que usaba MacRemote).
public enum RemoteAction: Equatable, Sendable {
  case move(dx: Double, dy: Double)
  case click(right: Bool, double: Bool)
  /// En píxeles del dedo; hacia abajo, positivo.
  case scroll(dy: Double)
  case volume(Int)
  case type(String)
  case media(Media)
  case fullScreen
  case tab(Tab)
  case system(SystemAction)
  case app(String)
  case open(URL)
  /// 0 lo apaga.
  case sleepTimer(minutes: Int)

  public enum Media: String, Sendable { case playPause = "play", forward10, backward10 }
  public enum Tab: String, Sendable { case next, prev, close }
  public enum SystemAction: String, Sendable {
    case sleep = "lock", spotlight, brightnessUp = "bright_up", brightnessDown = "bright_down", screenshot
  }

  /// Las apps que se pueden abrir desde el móvil.
  public static let apps = ["Safari", "Spotify", "Finder", "Música", "Music"]

  public static func decode(_ data: Data) -> RemoteAction? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let type = json["type"] as? String else { return nil }
    switch type {
    case "move":
      guard let dx = number(json["dx"]), let dy = number(json["dy"]) else { return nil }
      return .move(dx: dx, dy: dy)
    case "click":
      return .click(right: json["btn"] as? String == "right", double: json["double"] as? Bool ?? false)
    case "scroll":
      return number(json["dy"]).map { .scroll(dy: $0) }
    case "volume":
      return number(json["value"]).map { .volume(min(100, max(0, Int($0)))) }
    case "type":
      guard let text = json["text"] as? String, !text.isEmpty else { return nil }
      return .type(text)
    case "media":
      return (json["action"] as? String).flatMap(Media.init(rawValue:)).map { .media($0) }
    case "key":
      return json["name"] as? String == "fullscreen" ? .fullScreen : nil
    case "tab":
      return (json["action"] as? String).flatMap(Tab.init(rawValue:)).map { .tab($0) }
    case "system":
      return (json["action"] as? String).flatMap(SystemAction.init(rawValue:)).map { .system($0) }
    case "app":
      guard let name = json["name"] as? String, apps.contains(name) else { return nil }
      return .app(name)
    case "open":
      guard let text = json["url"] as? String, let url = URL(string: text),
            ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
      return .open(url)
    case "timer":
      return number(json["minutes"]).map { .sleepTimer(minutes: max(0, Int($0))) }
    default:
      return nil
    }
  }

  /// Números que llegan como número o como texto (el deslizador del volumen manda "50").
  private static func number(_ value: Any?) -> Double? {
    if let value = value as? Double { return value }
    if let value = value as? Int { return Double(value) }
    if let value = value as? String { return Double(value) }
    return nil
  }

  /// Las líneas de rueda para un desplazamiento del dedo (como MacRemote: una línea cada 5 píxeles, al revés).
  public static func scrollLines(_ dy: Double) -> Int32 {
    Int32((-dy / 5).rounded(.towardZero))
  }
}
