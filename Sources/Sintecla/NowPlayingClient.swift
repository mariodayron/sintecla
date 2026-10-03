import AppKit
import Observation
import SinteclaCore

/// Habla con el ayudante de música (spec «La isla» §4): lo arranca dentro de `/usr/bin/perl`, lee lo que suena y le
/// manda las órdenes. Si se cae, lo relanza con espera creciente. Hay uno solo para toda la app.
@MainActor @Observable
final class NowPlayingClient {
  static let shared = NowPlayingClient()

  enum Status: Equatable {
    case stopped
    case starting
    /// Ya ha dicho algo: la música funciona en este macOS.
    case ready
    /// No arranca o no responde.
    case unavailable
  }

  private(set) var status = Status.stopped
  private(set) var track: NowPlaying?
  private(set) var artwork: NSImage?
  /// El color de la onda, sacado de la carátula.
  private(set) var tint = ArtworkTint.white
  /// Con cada cambio de lo que suena (para `MusicPauser`).
  var onChange: ((NowPlaying?) -> Void)?

  private var process: Process?
  private var input: FileHandle?
  private var buffer = Data()
  private var retryDelay: TimeInterval = 1
  private var retryTask: Task<Void, Never>?
  private var wanted = false

  /// La biblioteca y el script, dentro de la app (`build-app.sh` los mete). Con `swift run` no están.
  private static var files: (library: URL, script: URL)? {
    guard let library = Bundle.main.url(forResource: "NowPlaying", withExtension: "dylib"),
          let script = Bundle.main.url(forResource: "now-playing", withExtension: "pl") else { return nil }
    return (library, script)
  }

  func start() {
    wanted = true
    guard process == nil else { return }
    launch()
  }

  func stop() {
    wanted = false
    retryTask?.cancel()
    process?.terminate()
    process = nil
    input = nil
    status = .stopped
    publish(nil, artwork: nil)
  }

  enum Command: String {
    case play, pause, toggle, next, previous
  }

  func send(_ command: Command) {
    write(command.rawValue)
  }

  func seek(to seconds: TimeInterval) {
    write(String(format: "seek %.2f", seconds))
  }

  private func write(_ line: String) {
    try? input?.write(contentsOf: Data((line + "\n").utf8))
  }

  private func launch() {
    guard let files = Self.files else {
      status = .unavailable
      return
    }
    if status != .ready { status = .starting }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
    process.arguments = [files.script.path, files.library.path]
    let output = Pipe(), input = Pipe()
    process.standardOutput = output
    process.standardInput = input
    process.standardError = FileHandle.nullDevice
    output.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      // Vacío: el ayudante ha cerrado su salida; sin esto, se volvería a llamar sin parar.
      guard !data.isEmpty else {
        handle.readabilityHandler = nil
        return
      }
      Task { @MainActor in self?.received(data) }
    }
    process.terminationHandler = { [weak self] _ in
      Task { @MainActor in self?.ended() }
    }
    do {
      try process.run()
    } catch {
      status = .unavailable
      return
    }
    self.process = process
    self.input = input.fileHandleForWriting
  }

  private func received(_ data: Data) {
    buffer.append(data)
    while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
      let line = String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self)
      buffer.removeSubrange(buffer.startIndex...newline)
      guard let update = NowPlayingUpdate.parse(line) else { continue }
      status = .ready
      retryDelay = 1
      switch update {
      case .nothing: publish(nil, artwork: nil)
      case .track(let track, let data): publish(track, artwork: data)
      }
    }
  }

  private func publish(_ track: NowPlaying?, artwork data: Data?) {
    // El ayudante manda la carátula solo cuando cambia: sin datos y con el mismo `artworkID`, sigue la que había.
    // Sin carátula y con la misma canción (Spotify la quita en pausa), también sigue.
    if let data, let image = NSImage(data: data) {
      artwork = image
      tint = image.cgImage(forProposedRect: nil, context: nil, hints: nil).map(ArtworkTint.init(of:)) ?? .white
    } else if track?.artworkID == nil, !Self.sameSong(track, self.track) {
      artwork = nil
      tint = .white
    }
    guard track != self.track else { return }
    self.track = track
    onChange?(track)
  }

  private static func sameSong(_ a: NowPlaying?, _ b: NowPlaying?) -> Bool {
    guard let a, let b else { return false }
    return a.title == b.title && a.artist == b.artist && a.album == b.album
  }

  /// El ayudante ha terminado: si no era a propósito, se relanza con espera creciente (1, 2, 4… hasta 60 s).
  private func ended() {
    process = nil
    input = nil
    buffer.removeAll()
    guard wanted else { return }
    if status != .ready { status = .unavailable }
    publish(nil, artwork: nil)
    let delay = retryDelay
    retryDelay = min(60, retryDelay * 2)
    retryTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay))
      guard let self, !Task.isCancelled, self.wanted, self.process == nil else { return }
      self.launch()
    }
  }
}
