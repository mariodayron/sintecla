import CoreGraphics

/// Lo que hace una pulsación con el selector de ventanas (spec «Alt-Tab» §3).
public enum AltTabKey: Equatable, Sendable {
  /// ⌘Tab (o ⇧⌘Tab, hacia atrás) con el selector cerrado.
  case open(backward: Bool)
  case next
  case previous
  case cancel
}

public enum AltTabShortcut {
  /// Resumen para la tarjeta de Inicio.
  public static let summary = "⌘Tab por ventanas"

  /// Con el selector cerrado, solo ⌘Tab y ⇧⌘Tab. Abierto (⌘ pulsado): Tab, ⇧Tab, ← y → lo mueven y Esc lo cierra; el
  /// resto de teclas sigue llegando a la app (nil).
  public static func key(keyCode: Int64, modifiers: Set<ComboModifier>, isOpen: Bool) -> AltTabKey? {
    guard isOpen else {
      guard keyCode == 48 else { return nil }  // 48 = Tab
      if modifiers == [.command] { return .open(backward: false) }
      if modifiers == [.command, .shift] { return .open(backward: true) }
      return nil
    }
    switch keyCode {
    case 48: return modifiers.contains(.shift) ? .previous : .next
    case 124: return .next  // →
    case 123: return .previous  // ←
    case 53: return .cancel  // Esc
    default: return nil
    }
  }
}

/// Una ventana del selector. `id` es el número de ventana de macOS; las minimizadas, que no lo dan, llevan uno negativo.
public struct SwitcherWindow: Equatable, Sendable {
  public let id: Int
  public let pid: Int32
  public let appName: String
  public let title: String
  public let isMinimized: Bool
  /// Capa de macOS: 0 son las ventanas normales.
  public let layer: Int
  public let size: CGSize

  public init(id: Int, pid: Int32, appName: String, title: String, isMinimized: Bool, layer: Int, size: CGSize) {
    self.id = id
    self.pid = pid
    self.appName = appName
    self.title = title
    self.isMinimized = isMinimized
    self.layer = layer
    self.size = size
  }

  /// El título o, si no tiene, el nombre de la app.
  public var label: String {
    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? appName : title
  }
}

/// Qué ventanas salen y en qué orden (spec «Alt-Tab» §4).
public enum WindowSwitcherOrder {
  /// Lado mínimo, en puntos.
  static let minimumSide: CGFloat = 50

  /// `visible`: las del escritorio actual en el orden de macOS (de delante a atrás). `minimized`: van al final.
  public static func arrange(visible: [SwitcherWindow], minimized: [SwitcherWindow], ownPID: Int32,
                             agentPIDs: Set<Int32>) -> [SwitcherWindow] {
    (visible + minimized).filter {
      $0.pid != ownPID && !agentPIDs.contains($0.pid) && $0.layer == 0
        && $0.size.width >= minimumSide && $0.size.height >= minimumSide
    }
  }
}

/// La ventana marcada (spec «Alt-Tab» §3).
public struct SwitcherState: Equatable, Sendable {
  public let count: Int
  public private(set) var selected: Int?

  /// Empieza en la segunda (la anterior que se usó) o, hacia atrás, en la última. Con una sola, en ella.
  public init(count: Int, backward: Bool) {
    self.count = count
    switch count {
    case 0: selected = nil
    case 1: selected = 0
    default: selected = backward ? count - 1 : 1
    }
  }

  public mutating func next() {
    guard let selected else { return }
    self.selected = (selected + 1) % count
  }

  public mutating func previous() {
    guard let selected else { return }
    self.selected = (selected - 1 + count) % count
  }

  /// El ratón sobre una tarjeta.
  public mutating func mark(_ index: Int) {
    guard (0..<count).contains(index) else { return }
    selected = index
  }
}
