import AppKit
import CoreImage.CIFilterBuiltins
import IOKit.ps
import Observation
import SinteclaCore
import SystemConfiguration

/// Módulo Mando: enciende y apaga el servidor, y le da lo que enseña el móvil (batería y lo que suena). Se enciende
/// a mano (barra de menús, Inicio o su página): mientras está encendido, cualquiera con el enlace en la misma Wi-Fi
/// mueve el Mac.
@MainActor @Observable
final class RemoteController {
  static let shared = RemoteController()

  enum State: Equatable {
    case off
    case starting
    case on
    case failed(String)
  }

  private(set) var state = State.off
  /// Móviles conectados ahora.
  private(set) var clients = 0
  @ObservationIgnored private var settings: AppSettings?
  @ObservationIgnored private let server = RemoteServer()
  @ObservationIgnored private let control = RemoteControl()
  /// La música la lee el ayudante de la isla; si la isla está apagada, lo arranca el Mando mientras dure.
  @ObservationIgnored private var startedMusic = false

  var isOn: Bool { state == .on || state == .starting }
  var port: UInt16 { Remote.defaultPort }

  /// Lo llama Sintecla al arrancar. Al apagar el módulo, se apaga el servidor; con «Encender al abrir Sintecla», se
  /// enciende solo.
  func configure(settings: AppSettings) {
    self.settings = settings
    control.captureFolder = { settings.captureFolderURL }
    server.key = { settings.remoteKey }
    server.onAction = { [weak self] in self?.control.perform($0) }
    server.onClientsChange = { [weak self] in self?.clients = $0 }
    server.status = { Self.battery() }
    server.nowPlaying = { Self.nowPlaying() }
    server.artwork = { Self.artworkJPEG() }
    if settings.remoteAlwaysOn { start() }
    watchModule()
  }

  private func watchModule() {
    guard let settings else { return }
    withObservationTracking {
      _ = settings.moduleRemote
      _ = settings.remoteAlwaysOn
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self, let settings = self.settings else { return }
        if !settings.moduleRemote { self.stop() } else if settings.remoteAlwaysOn, !self.isOn { self.start() }
        self.watchModule()
      }
    }
  }

  func toggle() {
    isOn ? stop() : start()
  }

  func start() {
    guard let settings, settings.moduleRemote, !isOn else { return }
    state = .starting
    let music = NowPlayingClient.shared
    if music.status == .stopped {
      music.start()
      startedMusic = true
    }
    server.start(port: port) { [weak self] error in
      guard let self else { return }
      switch error {
      case nil: self.state = .on
      case .portInUse?:
        self.state = .failed("El puerto \(self.port) está ocupado. ¿Está abierto MacRemote? Ciérralo y vuelve a probar.")
        self.stopMusic()
      case .failed(let reason)?:
        self.state = .failed("No se pudo encender: \(reason)")
        self.stopMusic()
      }
    }
  }

  func stop() {
    server.stop()
    stopMusic()
    if state != .off { state = .off }
    clients = 0
  }

  /// Un enlace nuevo: los móviles que ya estaban dejan de funcionar hasta que escaneen el QR nuevo.
  func newLink() {
    settings?.remoteKey = Remote.newKey()
    if isOn {
      stop()
      start()
    }
  }

  private func stopMusic() {
    guard startedMusic else { return }
    startedMusic = false
    if settings?.moduleIsland != true { NowPlayingClient.shared.stop() }
  }

  // MARK: Enlaces

  /// El enlace con el nombre del Mac en la red (`.local`), el que va en el QR.
  var link: String { Remote.link(host: Self.localHostName, port: port, key: settings?.remoteKey ?? "") }
  /// Por si el móvil no encuentra el nombre: con la IP.
  var ipLink: String? { Self.localIP.map { Remote.link(host: $0, port: port, key: settings?.remoteKey ?? "") } }

  static var localHostName: String {
    (SCDynamicStoreCopyLocalHostName(nil) as String?).map { $0 + ".local" } ?? ProcessInfo.processInfo.hostName
  }

  /// La primera IPv4 de la Wi-Fi o de la red.
  static var localIP: String? {
    var list: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&list) == 0, let first = list else { return nil }
    defer { freeifaddrs(list) }
    var candidates: [(name: String, ip: String)] = []
    for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
      let entry = pointer.pointee
      guard let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
            entry.ifa_flags & UInt32(IFF_UP) != 0, entry.ifa_flags & UInt32(IFF_LOOPBACK) == 0 else { continue }
      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0,
                        NI_NUMERICHOST) == 0 else { continue }
      candidates.append((String(cString: entry.ifa_name), String(cString: host)))
    }
    return (candidates.first { $0.name == "en0" } ?? candidates.first { $0.name.hasPrefix("en") })?.ip
  }

  /// El QR del enlace, nítido (sin suavizar al ampliarlo).
  static func qrCode(for text: String, side: CGFloat) -> NSImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    let scale = (side * 2 / output.extent.width).rounded(.down)
    let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
    return NSImage(cgImage: cgImage, size: NSSize(width: side, height: side))
  }

  // MARK: Lo que pide el móvil

  private static func battery() -> [String: Any] {
    let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let sources = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]
    for source in sources {
      guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
            info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
            let percent = info[kIOPSCurrentCapacityKey] as? Int else { continue }
      return ["battery": percent, "charging": info[kIOPSIsChargingKey] as? Bool ?? false]
    }
    return ["battery": "--", "charging": false]
  }

  private static func nowPlaying() -> [String: Any] {
    let music = NowPlayingClient.shared
    guard let track = music.track, track.isPlaying else {
      return ["playing": false, "title": "", "artist": "", "artwork": "", "app": ""]
    }
    let app = track.pid.flatMap { NSRunningApplication(processIdentifier: $0)?.localizedName } ?? ""
    let artwork = music.artwork == nil ? "" : "/artwork?v=\(abs((track.title + track.artist).hashValue))"
    return ["playing": true, "title": track.title, "artist": track.artist, "artwork": artwork, "app": app]
  }

  private static func artworkJPEG() -> Data? {
    guard let image = NowPlayingClient.shared.artwork, let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
    return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
  }
}
