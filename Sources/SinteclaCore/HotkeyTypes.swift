import Foundation

/// Modo que activa cada atajo.
public enum HotkeyMode: String, Codable, Sendable, CaseIterable {
  case dictation, translation, ask, notes, meeting
}

/// Cómo se graba: manteniendo la tecla base o manos libres.
public enum RecordingStyle: String, Codable, Sendable {
  case hold, handsFree
}

/// Tecla base de todos los atajos. `both`: 🌐 o ⌥ derecha, la que se pulse primero (hay teclados
/// externos, como algunos Logitech, que no mandan su tecla Fn al Mac).
public enum BaseKey: String, Codable, Sendable, CaseIterable {
  case fn, rightOption, both
}

/// Modificadores que forman combinaciones con la tecla base.
public enum ComboModifier: String, Hashable, Sendable {
  case shift, control, option, command
}

/// Eventos de teclado ya traducidos (sin depender de CGEvent).
public enum HotkeyEvent: Equatable, Sendable {
  case baseDown(at: TimeInterval)
  case baseUp(at: TimeInterval)
  /// Modificadores pulsados ahora mismo, sin contar la tecla base.
  case modifiers(Set<ComboModifier>, at: TimeInterval)
  case space(at: TimeInterval)
  case escape(at: TimeInterval)
  case otherKey(at: TimeInterval)
  /// Lo envía un temporizador para decidir "mantener" sin esperar a soltar.
  case tick(at: TimeInterval)
}

/// Lo que la app debe hacer en respuesta a un evento.
public enum HotkeyAction: Equatable, Sendable {
  /// Empezar a capturar audio (pre-roll) sin mostrar nada todavía.
  case arm
  case startRecording(HotkeyMode, RecordingStyle)
  case finishRecording
  /// Descartar el audio capturado.
  case cancel
  case toggleMeeting
  /// El evento de teclado actual no debe llegar a la app activa.
  case swallowKey
  /// Se pulsó un atajo mientras se procesaba: aviso breve.
  case busyFeedback
}
