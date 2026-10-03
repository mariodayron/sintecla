import CoreGraphics
import Foundation

/// Lo que suena (spec «La isla» §3.2 y §4). `elapsed` es el punto en `timestamp`: el actual se calcula con
/// `position(at:)`, sin preguntar cada segundo.
public struct NowPlaying: Equatable, Sendable {
  public var title: String
  public var artist: String
  public var album: String
  /// 0 si no se sabe.
  public var duration: TimeInterval
  public var elapsed: TimeInterval
  public var timestamp: Date
  public var isPlaying: Bool
  /// La app que suena.
  public var pid: Int32?
  /// Cambia cuando cambia la carátula.
  public var artworkID: String?

  public init(title: String, artist: String = "", album: String = "", duration: TimeInterval = 0,
              elapsed: TimeInterval = 0, timestamp: Date, isPlaying: Bool, pid: Int32? = nil, artworkID: String? = nil) {
    self.title = title
    self.artist = artist
    self.album = album
    self.duration = duration
    self.elapsed = elapsed
    self.timestamp = timestamp
    self.isPlaying = isPlaying
    self.pid = pid
    self.artworkID = artworkID
  }

  /// El punto de la canción ahora: avanza si suena y nunca pasa de la duración.
  public func position(at now: Date) -> TimeInterval {
    let position = elapsed + (isPlaying ? max(0, now.timeIntervalSince(timestamp)) : 0)
    return min(max(0, position), duration > 0 ? duration : .infinity)
  }

  /// De 0 a 1; 0 si no se sabe la duración.
  public func progress(at now: Date) -> Double {
    duration > 0 ? position(at: now) / duration : 0
  }

  /// «1:08», o «1:02:05» con horas.
  public static func clock(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds.rounded(.down)))
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
      : String(format: "%d:%02d", s / 60, s % 60)
  }
}

/// Una línea del ayudante de música.
public enum NowPlayingUpdate: Equatable, Sendable {
  /// No suena nada.
  case nothing
  /// `artwork`: la carátula, solo cuando cambia.
  case track(NowPlaying, artwork: Data?)

  private struct Line: Decodable {
    var empty: Bool?
    var playing: Bool?
    var title: String?
    var artist: String?
    var album: String?
    var duration: Double?
    var elapsed: Double?
    var timestamp: Double?
    var pid: Int32?
    var artworkID: String?
    var artwork: String?
  }

  /// Ejemplo: `{"playing":true,"title":"…","artist":"…","duration":195,"elapsed":17.7,"timestamp":1791054000.5,
  /// "pid":1463,"artworkID":"…","artwork":"<base64>"}` o `{"empty":true}`. Una línea rota da nil.
  public static func parse(_ text: String) -> NowPlayingUpdate? {
    guard let data = text.data(using: .utf8), let line = try? JSONDecoder().decode(Line.self, from: data) else {
      return nil
    }
    if line.empty == true { return .nothing }
    guard let title = line.title, let timestamp = line.timestamp else { return nil }
    let track = NowPlaying(title: title, artist: line.artist ?? "", album: line.album ?? "",
                           duration: line.duration ?? 0, elapsed: line.elapsed ?? 0,
                           timestamp: Date(timeIntervalSince1970: timestamp), isPlaying: line.playing ?? false,
                           pid: line.pid, artworkID: line.artworkID)
    return .track(track, artwork: line.artwork.flatMap { Data(base64Encoded: $0) })
  }
}

/// Cuándo se enseña la música (spec «La isla» §3.2): sonando, o en pausa hace menos de 5 minutos.
public struct MusicPresence: Equatable, Sendable {
  public static var pausedLinger: TimeInterval { 300 }
  private var pausedSince: Date?

  public init() {}

  /// Con cada cambio de lo que suena. La pausa cuenta desde que se ve por primera vez.
  public mutating func update(_ track: NowPlaying?, at now: Date) {
    guard let track, !track.isPlaying else {
      pausedSince = nil
      return
    }
    if pausedSince == nil { pausedSince = now }
  }

  public func isShown(_ track: NowPlaying?, at now: Date) -> Bool {
    guard let track else { return false }
    if track.isPlaying { return true }
    guard let pausedSince else { return true }
    return now.timeIntervalSince(pausedSince) < Self.pausedLinger
  }
}

/// Pausar la música al escuchar y reanudarla al terminar, solo si la pausó Sintecla (spec «La isla» §3.4).
public struct MusicPauser: Equatable, Sendable {
  public enum Command: Equatable, Sendable {
    case pause, play
  }

  private var pausedByUs = false

  public init() {}

  /// Empieza a escuchar. En reunión no se toca la música.
  public mutating func listeningStarted(mode: HotkeyMode, musicPlaying: Bool) -> Command? {
    guard mode != .meeting, musicPlaying else { return nil }
    pausedByUs = true
    return .pause
  }

  /// Si la música vuelve a sonar mientras tanto, la puso el usuario: al terminar no se toca.
  public mutating func musicChanged(isPlaying: Bool) {
    if isPlaying { pausedByUs = false }
  }

  /// Termina de escuchar (o se cancela).
  public mutating func listeningEnded() -> Command? {
    defer { pausedByUs = false }
    return pausedByUs ? .play : nil
  }
}

/// El color de la onda: el principal de la carátula, subido de brillo para que se vea sobre negro. Una carátula sin
/// color (gris, blanco o negro) da blanco.
public struct ArtworkTint: Equatable, Sendable {
  public let red: Double
  public let green: Double
  public let blue: Double

  public static let white = ArtworkTint(red: 1, green: 1, blue: 1)

  public init(red: Double, green: Double, blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
  }

  /// Se reduce a 16 × 16 y se hace la media de los píxeles con color.
  public init(of image: CGImage) {
    let side = 16
    var bytes = [UInt8](repeating: 0, count: side * side * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
      guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                    bytesPerRow: side * 4, space: space,
                                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
      context.interpolationQuality = .medium
      context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
      return true
    }
    guard drawn else {
      self = .white
      return
    }
    var sum = (r: 0.0, g: 0.0, b: 0.0), count = 0.0
    for index in stride(from: 0, to: bytes.count, by: 4) {
      let r = Double(bytes[index]) / 255, g = Double(bytes[index + 1]) / 255, b = Double(bytes[index + 2]) / 255
      let high = max(r, g, b), low = min(r, g, b)
      // Solo los píxeles con color y no casi negros.
      guard high > 0.15, (high - low) / high > 0.25 else { continue }
      sum = (sum.r + r, sum.g + g, sum.b + b)
      count += 1
    }
    // Menos de un 10 % de píxeles con color: blanco.
    guard count >= Double(side * side) * 0.1 else {
      self = .white
      return
    }
    let mean = (r: sum.r / count, g: sum.g / count, b: sum.b / count)
    let scale = 1 / max(mean.r, mean.g, mean.b)
    self.init(red: mean.r * scale, green: mean.g * scale, blue: mean.b * scale)
  }
}
