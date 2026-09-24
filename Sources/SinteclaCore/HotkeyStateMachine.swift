import Foundation

/// Máquina de estados de los atajos. Lógica pura: recibe `HotkeyEvent`
/// y devuelve `HotkeyAction`; no sabe nada de CGEvent ni de audio.
public struct HotkeyStateMachine: Sendable {
  /// Por debajo de este tiempo la tecla base se "pulsó"; por encima, se "mantuvo".
  public static let tapThreshold: TimeInterval = 0.30

  public enum State: Equatable, Sendable {
    case idle
    case armed(since: TimeInterval, sawSpace: Bool)
    /// `baseDownAt` solo en manos libres: la base está pulsada de nuevo (posible fin).
    case recording(mode: HotkeyMode, style: RecordingStyle, baseDownAt: TimeInterval?, otherKeyWhileBaseDown: Bool)
    case busy
  }

  public private(set) var state: State = .idle
  public var baseKey: BaseKey
  /// Qué tecla acompaña a la base en cada modo (Ajustes → General).
  public var layout: HotkeyLayout
  private var modifiers: Set<ComboModifier> = []

  public init(baseKey: BaseKey = .fn, layout: HotkeyLayout = .defaults) {
    self.baseKey = baseKey
    self.layout = layout
  }

  public mutating func handle(_ event: HotkeyEvent) -> [HotkeyAction] {
    if case .modifiers(let current, _) = event {
      modifiers = current
      return []
    }
    switch state {
    case .idle:
      return handleIdle(event)
    case .armed(let since, let sawSpace):
      return handleArmed(event, since: since, sawSpace: sawSpace)
    case .recording(let mode, let style, let baseDownAt, let otherKey):
      return handleRecording(event, mode: mode, style: style, baseDownAt: baseDownAt, otherKeyWhileBaseDown: otherKey)
    case .busy:
      if case .baseDown = event { return [.busyFeedback] }
      return []
    }
  }

  /// La app lo llama al terminar de procesar (texto pegado o error).
  public mutating func processingFinished() {
    if state == .busy { state = .idle }
  }

  /// Vuelve a reposo pase lo que pase (p. ej. si el micro falla).
  public mutating func reset() {
    state = .idle
  }

  private mutating func handleIdle(_ event: HotkeyEvent) -> [HotkeyAction] {
    guard case .baseDown(let t) = event else { return [] }
    state = .armed(since: t, sawSpace: false)
    return [.arm]
  }

  private mutating func handleArmed(_ event: HotkeyEvent, since: TimeInterval, sawSpace: Bool) -> [HotkeyAction] {
    switch event {
    case .space where layout.usesSpace:
      state = .armed(since: since, sawSpace: true)
      return [.swallowKey]
    case .escape, .otherKey, .space:
      // Fn+←, Fn+Supr, ⌥der+2 (@)…: era un atajo del sistema, no un dictado.
      state = .idle
      return [.cancel]
    case .tick(let t):
      guard t - since >= Self.tapThreshold else { return [] }
      let mode = layout.mode(modifiers: modifiers, sawSpace: sawSpace, baseKey: baseKey)
      if mode == .meeting { return [] }  // la reunión actúa al soltar
      state = .recording(mode: mode, style: .hold, baseDownAt: nil, otherKeyWhileBaseDown: false)
      return [.startRecording(mode, .hold)]
    case .baseUp(let t):
      let mode = layout.mode(modifiers: modifiers, sawSpace: sawSpace, baseKey: baseKey)
      if mode == .meeting {
        state = .idle
        return [.cancel, .toggleMeeting]
      }
      if t - since < Self.tapThreshold {
        state = .recording(mode: mode, style: .handsFree, baseDownAt: nil, otherKeyWhileBaseDown: false)
        return [.startRecording(mode, .handsFree)]
      }
      // Soltó tras el umbral sin que llegara el tick: fue "mantener" y ya terminó.
      state = .busy
      return [.startRecording(mode, .hold), .finishRecording]
    case .baseDown, .modifiers:
      return []
    }
  }

  private mutating func handleRecording(_ event: HotkeyEvent, mode: HotkeyMode, style: RecordingStyle,
                                        baseDownAt: TimeInterval?, otherKeyWhileBaseDown: Bool) -> [HotkeyAction] {
    switch (style, event) {
    case (_, .escape):
      state = .idle
      return [.cancel, .swallowKey]
    case (.hold, .baseUp):
      state = .busy
      return [.finishRecording]
    case (.hold, .space) where layout.usesSpace:
      return [.swallowKey]
    case (.hold, .otherKey), (.hold, .space):
      state = .idle
      return [.cancel]
    case (.handsFree, .baseDown(let t)):
      state = .recording(mode: mode, style: style, baseDownAt: t, otherKeyWhileBaseDown: false)
      return []
    case (.handsFree, .otherKey), (.handsFree, .space):
      if baseDownAt != nil {
        state = .recording(mode: mode, style: style, baseDownAt: baseDownAt, otherKeyWhileBaseDown: true)
      }
      return []
    case (.handsFree, .baseUp):
      if baseDownAt != nil && !otherKeyWhileBaseDown {
        state = .busy
        return [.finishRecording]
      }
      state = .recording(mode: mode, style: style, baseDownAt: nil, otherKeyWhileBaseDown: false)
      return []
    default:
      return []
    }
  }
}
