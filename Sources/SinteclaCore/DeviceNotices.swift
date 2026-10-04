import Foundation

/// La batería de unos AirPods; lo que no da dato (el estuche cerrado) va a nil.
public struct AirPodsBattery: Equatable, Sendable {
  public var left: Int?
  public var right: Int?
  public var `case`: Int?

  public init(left: Int? = nil, right: Int? = nil, case: Int? = nil) {
    self.left = left
    self.right = right
    self.case = `case`
  }

  public var isEmpty: Bool { left == nil && right == nil && self.case == nil }

  /// Un auricular (no el estuche) al 10 % o menos.
  public var isLow: Bool { [left, right].contains { ($0 ?? 100) <= AirPodsNotices.lowLevel } }
}

/// Unos AirPods conectados, según `system_profiler SPBluetoothDataType -json` (spec «Estante y avisos» §4.3).
public struct AirPodsDevice: Equatable, Sendable {
  public var name: String
  public var address: String
  public var battery: AirPodsBattery

  public init(name: String, address: String, battery: AirPodsBattery) {
    self.name = name
    self.address = address
    self.battery = battery
  }

  /// Los auriculares de Apple conectados (fabricante 0x004C y tipo auriculares), con lo que haya de batería.
  public static func parse(systemProfiler data: Data) -> [AirPodsDevice] {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let sections = root["SPBluetoothDataType"] as? [[String: Any]] else { return [] }
    var devices: [AirPodsDevice] = []
    for section in sections {
      for entry in section["device_connected"] as? [[String: Any]] ?? [] {
        for (name, value) in entry {
          guard let info = value as? [String: Any],
                (info["device_vendorID"] as? String)?.lowercased() == "0x004c",
                info["device_minorType"] as? String == "Headphones" else { continue }
          let battery = AirPodsBattery(left: level(info["device_batteryLevelLeft"]),
                                       right: level(info["device_batteryLevelRight"]),
                                       case: level(info["device_batteryLevelCase"]))
          devices.append(AirPodsDevice(name: name, address: info["device_address"] as? String ?? "",
                                       battery: battery))
        }
      }
    }
    return devices.sorted { $0.name < $1.name }
  }

  /// «64 %» (con espacio duro o sin él) → 64.
  private static func level(_ value: Any?) -> Int? {
    guard let text = value as? String else { return nil }
    return Int(text.prefix { $0.isNumber })
  }
}

/// El estado de la carga del Mac (spec «Estante y avisos» §4.3).
public struct PowerState: Equatable, Sendable {
  public var percent: Int
  public var pluggedIn: Bool
  public var charging: Bool
  /// Lo que queda con la batería; nil mientras macOS lo calcula.
  public var minutesLeft: Int?

  public init(percent: Int, pluggedIn: Bool, charging: Bool, minutesLeft: Int? = nil) {
    self.percent = percent
    self.pluggedIn = pluggedIn
    self.charging = charging
    self.minutesLeft = minutesLeft
  }
}

/// Un aviso de la isla que no es de Sintecla (spec «Estante y avisos» §4.1).
public enum DeviceNotice: Equatable, Sendable {
  /// Al enchufar; `charging` a false si macOS no carga (Optimizar carga o al 100 %).
  case pluggedIn(percent: Int, charging: Bool)
  case unplugged(percent: Int, minutesLeft: Int?)
  case lowBattery(percent: Int)
  case airPods(name: String, battery: AirPodsBattery)
  case airPodsLow(name: String, battery: AirPodsBattery)

  public enum Tint: Sendable { case plain, green, red }

  /// Los de batería baja no se descartan aunque esperen (§4.2).
  public var isUrgent: Bool {
    switch self {
    case .lowBattery, .airPodsLow: true
    default: false
    }
  }

  public var symbol: String {
    switch self {
    case .pluggedIn(_, let charging): charging ? "bolt.fill" : "powerplug.fill"
    case .unplugged(let percent, _): Self.batterySymbol(percent)
    case .lowBattery: "battery.0percent"
    case .airPods, .airPodsLow: "airpods.pro"
    }
  }

  public var tint: Tint {
    switch self {
    case .pluggedIn(_, true): .green
    case .lowBattery, .airPodsLow: .red
    default: .plain
    }
  }

  public var text: String {
    switch self {
    case .pluggedIn(let percent, let charging): "\(charging ? "Cargando" : "Enchufado") · \(percent) %"
    case .unplugged(let percent, let minutes):
      minutes.map { "\(percent) % · \(Self.duration($0))" } ?? "\(percent) %"
    case .lowBattery(let percent): "Batería baja · \(percent) %"
    case .airPods(let name, _): name
    case .airPodsLow(let name, _): "\(name) · batería baja"
    }
  }

  /// La batería de los AirPods, para los anillos; nil en los avisos del Mac.
  public var airPods: AirPodsBattery? {
    switch self {
    case .airPods(_, let battery), .airPodsLow(_, let battery): battery
    default: nil
    }
  }

  /// 380 → «6 h 20 min»; 45 → «45 min»; 120 → «2 h».
  public static func duration(_ minutes: Int) -> String {
    let hours = minutes / 60, rest = minutes % 60
    if hours == 0 { return "\(rest) min" }
    return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
  }

  private static func batterySymbol(_ percent: Int) -> String {
    switch percent {
    case ..<13: "battery.0percent"
    case ..<38: "battery.25percent"
    case ..<63: "battery.50percent"
    case ..<88: "battery.75percent"
    default: "battery.100percent"
    }
  }
}

/// Qué aviso toca con cada cambio de la carga (spec «Estante y avisos» §4.1).
public struct PowerNotices: Sendable {
  /// Avisos de batería baja, sin cargador.
  public static let thresholds = [20, 10]
  private var last: PowerState?
  private var warned: Set<Int> = []

  public init() {}

  /// El primer estado no avisa: es el punto de partida.
  public mutating func update(_ state: PowerState) -> [DeviceNotice] {
    defer { last = state }
    guard let last else {
      if !state.pluggedIn { markWarned(below: state.percent) }
      return []
    }
    if state.pluggedIn {
      warned.removeAll()
      return last.pluggedIn ? [] : [.pluggedIn(percent: state.percent, charging: state.charging)]
    }
    if last.pluggedIn {
      markWarned(below: state.percent)
      return [.unplugged(percent: state.percent, minutesLeft: state.minutesLeft)]
    }
    let crossed = Self.thresholds.filter { state.percent <= $0 && !warned.contains($0) }
    guard !crossed.isEmpty else { return [] }
    markWarned(below: state.percent)
    return [.lowBattery(percent: state.percent)]
  }

  private mutating func markWarned(below percent: Int) {
    for threshold in Self.thresholds where percent <= threshold { warned.insert(threshold) }
  }
}

/// Avisos de los AirPods (spec «Estante y avisos» §4.1): al conectarlos y con batería baja, una vez por conexión.
public struct AirPodsNotices: Sendable {
  public static let lowLevel = 10
  /// Las direcciones conectadas y si ya avisaron de batería baja.
  private var connected: [String: Bool] = [:]

  public init() {}

  /// Los que ya estaban al arrancar: sin aviso.
  public mutating func known(_ device: AirPodsDevice) {
    connected[device.address] = device.battery.isLow
  }

  public mutating func connected(_ device: AirPodsDevice) -> [DeviceNotice] {
    connected[device.address] = device.battery.isLow
    return [device.battery.isLow ? .airPodsLow(name: device.name, battery: device.battery)
                                 : .airPods(name: device.name, battery: device.battery)]
  }

  /// Cada minuto, mientras siguen conectados.
  public mutating func batteryChanged(_ device: AirPodsDevice) -> [DeviceNotice] {
    guard let warned = connected[device.address], !warned, device.battery.isLow else { return [] }
    connected[device.address] = true
    return [.airPodsLow(name: device.name, battery: device.battery)]
  }

  public mutating func disconnected(address: String) {
    connected[address] = nil
  }

  public func isConnected(address: String) -> Bool { connected[address] != nil }
}

/// La cola de avisos (spec «Estante y avisos» §4.2): uno detrás de otro, 3 s cada uno; si Sintecla está ocupada,
/// esperan, y pasados 10 s se descartan salvo los de batería baja.
public struct NoticeQueue: Sendable {
  public static let duration: TimeInterval = 3
  public static let maxWait: TimeInterval = 10

  private var pending: [(notice: DeviceNotice, at: Date)] = []
  public private(set) var current: DeviceNotice?
  private var until: Date?

  public init() {}

  public var isEmpty: Bool { current == nil && pending.isEmpty }

  public mutating func push(_ notices: [DeviceNotice], at now: Date) {
    pending += notices.map { ($0, now) }
  }

  /// Al llegar un aviso, al acabar uno y al cambiar Sintecla. Devuelve si cambió `current`.
  @discardableResult
  public mutating func tick(at now: Date, busy: Bool) -> Bool {
    let before = current
    if let until, now >= until {
      current = nil
      self.until = nil
    }
    if current == nil, !busy {
      pending.removeAll { !$0.notice.isUrgent && now.timeIntervalSince($0.at) > Self.maxWait }
      if !pending.isEmpty {
        current = pending.removeFirst().notice
        until = now + Self.duration
      }
    }
    return current != before
  }

  /// Cuándo hay que volver a mirar (cuando acaba el aviso de ahora).
  public var nextTick: Date? { until }
}
