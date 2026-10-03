import AppKit
import Foundation
import Network
import SinteclaCore

/// El servidor del Mando en la Wi-Fi: la página del móvil, su WebSocket y las peticiones de estado. Sin la llave
/// (en el enlace del QR o en la cookie que deja), solo contesta «abre el enlace de Sintecla».
@MainActor
final class RemoteServer {
  var key: () -> String = { "" }
  var onAction: ((RemoteAction) -> Void)?
  /// Cuántos móviles tienen el WebSocket abierto.
  var onClientsChange: ((Int) -> Void)?
  /// Lo que pide `/status` y `/nowplaying`.
  var status: () -> [String: Any] = { [:] }
  var nowPlaying: () -> [String: Any] = { [:] }
  var artwork: () -> Data? = { nil }

  private var listener: NWListener?
  private var sockets: Set<ObjectIdentifier> = []
  private var connections: [ObjectIdentifier: RemoteConnection] = [:]

  enum StartError: Error { case portInUse, failed(String) }

  /// Escucha en todas las interfaces (el móvil llega por la Wi-Fi). `onReady` dice si arrancó o por qué no.
  func start(port: UInt16, onReady: @escaping (StartError?) -> Void) {
    stop()
    let tcp = NWProtocolTCP.Options()
    tcp.noDelay = true
    let parameters = NWParameters(tls: nil, tcp: tcp)
    parameters.allowLocalEndpointReuse = true
    guard let port = NWEndpoint.Port(rawValue: port), let listener = try? NWListener(using: parameters, on: port) else {
      return onReady(.failed("no se pudo abrir el puerto"))
    }
    self.listener = listener
    listener.newConnectionHandler = { [weak self] connection in
      Task { @MainActor in self?.accept(connection) }
    }
    listener.stateUpdateHandler = { [weak self] state in
      Task { @MainActor in
        switch state {
        case .ready: onReady(nil)
        case .failed(let error):
          if case .posix(.EADDRINUSE) = error { onReady(.portInUse) } else { onReady(.failed("\(error)")) }
          self?.stop()
        default: break
        }
      }
    }
    listener.start(queue: .main)
  }

  func stop() {
    listener?.cancel()
    listener = nil
    for connection in connections.values { connection.close() }
    connections.removeAll()
    sockets.removeAll()
    onClientsChange?(0)
  }

  private func accept(_ connection: NWConnection) {
    let remote = RemoteConnection(connection: connection)
    let id = ObjectIdentifier(remote)
    connections[id] = remote
    remote.onRequest = { [weak self, weak remote] request in
      guard let self, let remote else { return }
      self.handle(request, on: remote)
    }
    remote.onMessage = { [weak self] data in
      if let action = RemoteAction.decode(data) { self?.onAction?(action) }
    }
    remote.onClose = { [weak self] in
      guard let self else { return }
      self.connections[id] = nil
      if self.sockets.remove(id) != nil { self.onClientsChange?(self.sockets.count) }
    }
    remote.start()
  }

  private func handle(_ request: RemoteRequest, on connection: RemoteConnection) {
    let key = key()
    let authorized = request.isAuthorized(key: key)
    switch (request.method, request.path) {
    case ("GET", "/") where request.query["k"] == key && !key.isEmpty:
      // Deja la llave en una cookie y vuelve a la página sin ella en la dirección.
      connection.respond(status: "303 See Other", headers: [
        "Location": "/",
        "Set-Cookie": "\(Remote.cookieName)=\(key); Path=/; Max-Age=31536000; SameSite=Strict; HttpOnly",
      ])
    case ("GET", "/") where authorized:
      connection.respond(status: "200 OK", type: "text/html; charset=utf-8", body: Data(RemoteWebPage.html.utf8))
    case ("GET", "/ws") where authorized && request.isWebSocketUpgrade:
      connection.upgrade(key: request.headers["sec-websocket-key"] ?? "")
      sockets.insert(ObjectIdentifier(connection))
      onClientsChange?(sockets.count)
    case ("POST", "/action") where authorized:
      if let action = RemoteAction.decode(request.body) { onAction?(action) }
      connection.respond(status: "204 No Content")
    case ("GET", "/status") where authorized:
      connection.respond(json: status())
    case ("GET", "/nowplaying") where authorized:
      connection.respond(json: nowPlaying())
    case ("GET", "/artwork") where authorized:
      if let data = artwork() {
        connection.respond(status: "200 OK", type: "image/jpeg", body: data, headers: ["Cache-Control": "max-age=3600"])
      } else {
        connection.respond(status: "404 Not Found")
      }
    case ("GET", "/"):
      connection.respond(status: "403 Forbidden", type: "text/html; charset=utf-8", body: Data(Self.locked.utf8))
    default:
      connection.respond(status: authorized ? "404 Not Found" : "403 Forbidden")
    }
  }

  private static let locked = """
    <!DOCTYPE html><html lang="es"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1"><title>Sintecla · Mando</title>
    <style>body{font:17px -apple-system,system-ui;background:#000;color:#fff;display:flex;align-items:center;
    justify-content:center;min-height:90vh;text-align:center;padding:24px}p{color:#8e8e93}</style></head>
    <body><div><h2>Mando de Sintecla</h2><p>Escanea el QR de Sintecla (página Mando) para conectar este móvil.</p></div>
    </body></html>
    """
}

/// Una conexión del móvil: primero HTTP; si pide WebSocket, tramas hasta que se cierre.
@MainActor
private final class RemoteConnection {
  var onRequest: ((RemoteRequest) -> Void)?
  var onMessage: ((Data) -> Void)?
  var onClose: (() -> Void)?

  private let connection: NWConnection
  private var buffer = Data()
  private var isWebSocket = false
  private var closed = false

  init(connection: NWConnection) {
    self.connection = connection
  }

  func start() {
    connection.stateUpdateHandler = { [weak self] state in
      switch state {
      case .failed, .cancelled: Task { @MainActor in self?.finish() }
      default: break
      }
    }
    connection.start(queue: .main)
    receive()
  }

  func close() {
    connection.cancel()
  }

  private func finish() {
    guard !closed else { return }
    closed = true
    onClose?()
  }

  private func receive() {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
      Task { @MainActor in
        guard let self else { return }
        if let data, !data.isEmpty {
          self.buffer.append(data)
          self.process()
        }
        if complete || error != nil {
          self.connection.cancel()
          self.finish()
        } else if !self.closed {
          self.receive()
        }
      }
    }
  }

  private func process() {
    if isWebSocket {
      while let (frame, length) = WebSocketFrame.decode(buffer) {
        buffer.removeFirst(length)
        switch frame.opcode {
        case .text: onMessage?(frame.payload)
        case .ping: send(WebSocketFrame(opcode: .pong, payload: frame.payload).encoded())
        case .close:
          send(WebSocketFrame(opcode: .close, payload: Data()).encoded()) { [weak self] in self?.close() }
        default: break
        }
      }
    } else if let request = RemoteRequest.parse(buffer) {
      buffer.removeAll()
      onRequest?(request)
    } else if buffer.count > 1_000_000 {
      close()
    }
  }

  func upgrade(key: String) {
    isWebSocket = true
    let head = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
      + "Sec-WebSocket-Accept: \(Remote.webSocketAccept(key: key))\r\n\r\n"
    send(Data(head.utf8))
  }

  func respond(status: String, type: String? = nil, body: Data = Data(), headers: [String: String] = [:]) {
    var head = "HTTP/1.1 \(status)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n"
    if let type { head += "Content-Type: \(type)\r\n" }
    for (name, value) in ["Cache-Control": "no-store"].merging(headers, uniquingKeysWith: { $1 }) {
      head += "\(name): \(value)\r\n"
    }
    send(Data((head + "\r\n").utf8) + body) { [weak self] in self?.close() }
  }

  func respond(json: [String: Any]) {
    let body = (try? JSONSerialization.data(withJSONObject: json)) ?? Data("{}".utf8)
    respond(status: "200 OK", type: "application/json", body: body)
  }

  private func send(_ data: Data, then done: (() -> Void)? = nil) {
    connection.send(content: data, completion: .contentProcessed { _ in
      Task { @MainActor in done?() }
    })
  }
}
