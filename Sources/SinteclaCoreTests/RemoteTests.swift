import Foundation
import Testing
@testable import SinteclaCore

@Suite struct RemoteTests {
  // MARK: HTTP

  @Test func readsTheRequestLineHeadersQueryAndCookies() throws {
    let raw = Data("GET /?k=abc HTTP/1.1\r\nHost: mac.local:8080\r\nCookie: a=1; sintecla_mando=xyz\r\n\r\n".utf8)
    let request = try #require(RemoteRequest.parse(raw))
    #expect(request.method == "GET")
    #expect(request.path == "/")
    #expect(request.query == ["k": "abc"])
    #expect(request.headers["host"] == "mac.local:8080")
    #expect(request.cookies == ["a": "1", "sintecla_mando": "xyz"])
  }

  @Test func waitsForTheWholeHeaderAndBody() {
    #expect(RemoteRequest.parse(Data("GET / HTTP/1.1\r\nHost: x\r\n".utf8)) == nil)
    let partial = Data("POST /action HTTP/1.1\r\nContent-Length: 10\r\n\r\n{\"a\":".utf8)
    #expect(RemoteRequest.parse(partial) == nil)
    let full = Data("POST /action HTTP/1.1\r\nContent-Length: 6\r\n\r\n{\"a\":1}".utf8)
    #expect(RemoteRequest.parse(full)?.body == Data("{\"a\":1".utf8))
  }

  @Test func onlyTheKeyInTheLinkOrTheCookieOpensIt() throws {
    let withQuery = try #require(RemoteRequest.parse(Data("GET /?k=llave HTTP/1.1\r\n\r\n".utf8)))
    let withCookie = try #require(RemoteRequest.parse(Data("GET /ws HTTP/1.1\r\nCookie: sintecla_mando=llave\r\n\r\n".utf8)))
    let without = try #require(RemoteRequest.parse(Data("GET /status HTTP/1.1\r\n\r\n".utf8)))
    let wrong = try #require(RemoteRequest.parse(Data("GET /?k=otra HTTP/1.1\r\n\r\n".utf8)))
    #expect(withQuery.isAuthorized(key: "llave"))
    #expect(withCookie.isAuthorized(key: "llave"))
    #expect(!without.isAuthorized(key: "llave"))
    #expect(!wrong.isAuthorized(key: "llave"))
    #expect(!without.isAuthorized(key: ""))
  }

  @Test func recognisesTheWebSocketUpgrade() throws {
    let raw = "GET /ws HTTP/1.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
    let request = try #require(RemoteRequest.parse(Data(raw.utf8)))
    #expect(request.isWebSocketUpgrade)
    // El ejemplo del RFC 6455.
    #expect(Remote.webSocketAccept(key: "dGhlIHNhbXBsZSBub25jZQ==") == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
  }

  @Test func theLinkCarriesTheKey() {
    #expect(Remote.link(host: "mac.local", port: 8080, key: "abc") == "http://mac.local:8080/?k=abc")
    let key = Remote.newKey()
    #expect(key.count == 24)
    #expect(!key.contains("0") && !key.contains("O") && !key.contains("l"))
    #expect(Remote.newKey() != key)
  }

  @Test func theManifestOpensTheAppWithTheKey() throws {
    let data = Remote.manifest(key: "abc")
    let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(json["start_url"] as? String == "/?k=abc")
    #expect(json["display"] as? String == "standalone")
    #expect(json["short_name"] as? String == "Mando")
  }

  // MARK: WebSocket

  @Test func decodesAMaskedTextFrame() throws {
    // «Hello» enmascarado, del RFC 6455 §5.7.
    let data = Data([0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58])
    let (frame, length) = try #require(WebSocketFrame.decode(data))
    #expect(frame == WebSocketFrame(opcode: .text, payload: Data("Hello".utf8)))
    #expect(length == 11)
    #expect(WebSocketFrame.decode(data.prefix(8)) == nil)
  }

  @Test func encodesAndDecodesLongFrames() throws {
    for size in [5, 200, 70_000] {
      let frame = WebSocketFrame(opcode: .binary, payload: Data(repeating: 7, count: size))
      let encoded = frame.encoded()
      let decoded = try #require(WebSocketFrame.decode(encoded + Data([0x81])))
      #expect(decoded.frame == frame)
      #expect(decoded.length == encoded.count)
    }
  }

  @Test func closeFrame() {
    #expect(WebSocketFrame.decode(Data([0x88, 0x00]))?.frame.opcode == .close)
  }

  // MARK: Órdenes

  private func action(_ json: String) -> RemoteAction? { RemoteAction.decode(Data(json.utf8)) }

  @Test func readsTheTrackpad() {
    #expect(action(#"{"type":"move","dx":3.5,"dy":-2}"#) == .move(dx: 3.5, dy: -2))
    #expect(action(#"{"type":"click","btn":"left","double":true}"#) == .click(right: false, double: true))
    #expect(action(#"{"type":"click","btn":"right"}"#) == .click(right: true, double: false))
    #expect(action(#"{"type":"scroll","dy":12}"#) == .scroll(dy: 12))
    #expect(RemoteAction.scrollLines(12) == -2)
    #expect(RemoteAction.scrollLines(-4) == 0)
  }

  @Test func readsTheButtons() {
    #expect(action(#"{"type":"volume","value":"55"}"#) == .volume(55))
    #expect(action(#"{"type":"volume","value":150}"#) == .volume(100))
    #expect(action(#"{"type":"type","text":"hola"}"#) == .type("hola"))
    #expect(action(#"{"type":"type","text":""}"#) == nil)
    #expect(action(#"{"type":"media","action":"play"}"#) == .media(.playPause))
    #expect(action(#"{"type":"media","action":"forward10"}"#) == .media(.forward10))
    #expect(action(#"{"type":"key","name":"fullscreen"}"#) == .fullScreen)
    #expect(action(#"{"type":"tab","action":"close"}"#) == .tab(.close))
    #expect(action(#"{"type":"system","action":"lock"}"#) == .system(.sleep))
    #expect(action(#"{"type":"system","action":"bright_up"}"#) == .system(.brightnessUp))
    #expect(action(#"{"type":"timer","minutes":30}"#) == .sleepTimer(minutes: 30))
  }

  @Test func onlyKnownAppsAndWebLinks() {
    #expect(action(#"{"type":"app","name":"Spotify"}"#) == .app("Spotify"))
    #expect(action(#"{"type":"app","name":"Terminal"}"#) == nil)
    #expect(action(#"{"type":"open","url":"https://youtube.com"}"#) == .open(URL(string: "https://youtube.com")!))
    #expect(action(#"{"type":"open","url":"file:///etc/passwd"}"#) == nil)
    #expect(action(#"{"type":"nada"}"#) == nil)
    #expect(action("no es json") == nil)
  }
}
