import AppKit
import Observation
import SinteclaCore
import SwiftUI

/// Estado de la pastilla flotante.
@MainActor @Observable
final class OverlayModel {
  enum Phase: Equatable {
    case hidden
    case listening(HotkeyMode)
    case processing(HotkeyMode)
    case done
    /// Error o aviso que pide atención (triángulo).
    case message(String)
    /// Aviso de que algo salió bien, con su propio icono (p. ej. el diccionario).
    case notice(String, symbol: String)
  }

  var phase: Phase = .hidden
  var level: Float = 0
  /// Notas y reuniones: cuándo empezó la grabación (cronómetro) y lo último reconocido.
  var startedAt: Date?
  var liveText = ""
}

/// Solo blanco, negro y transparente (elección del usuario): el color lo pone el cristal, no la interfaz.
///
/// Pastilla de Liquid Glass: una gota con el icono del modo y una cápsula con el nivel de voz, el cronómetro y el
/// estado. Las dos piezas viven en un `GlassEffectContainer`: al cambiar de estado se estiran, se funden o se separan.
struct OverlayView: View {
  let model: OverlayModel
  @Namespace private var glass

  static let panelSize = NSSize(width: 440, height: 72)
  /// Icono de los avisos del diccionario ("Aprendido…", "Añadido al diccionario…").
  static let dictionarySymbol = "character.book.closed"

  var body: some View {
    GlassEffectContainer(spacing: 14) {
      HStack(spacing: 6) {
        if model.phase != .hidden {
          icon
            .glassEffect(.clear, in: .circle)
            .glassEffectID("icono", in: glass)
          if let label {
            capsule(label)
              .glassEffect(.clear, in: .capsule)
              .glassEffectID("capsula", in: glass)
          }
        }
      }
    }
    .animation(.spring(response: 0.38, dampingFraction: 0.78), value: model.phase)
    .frame(width: Self.panelSize.width, height: Self.panelSize.height)
  }

  private var icon: some View {
    Group {
      if case .processing = model.phase {
        ProgressView().controlSize(.small)
      } else {
        Image(systemName: symbol)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.primary)
          .contentTransition(.symbolEffect(.replace))
      }
    }
    .frame(width: 24, height: 24)
    .padding(12)
  }

  private func capsule(_ label: String) -> some View {
    HStack(spacing: 10) {
      if case .listening = model.phase {
        LevelBars(level: model.level)
      }
      if case .listening(let mode) = model.phase, mode == .notes || mode == .meeting, let startedAt = model.startedAt {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
          Text(Self.clock(context.date.timeIntervalSince(startedAt)))
            .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
        }
      }
      Text(label)
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .lineLimit(1)
        .truncationMode(.head)
        .contentTransition(.opacity)
    }
    .padding(.horizontal, 18)
    .frame(height: 48)
  }

  static func icon(for mode: HotkeyMode) -> String {
    switch mode {
    case .dictation: "mic.fill"
    case .translation: "globe"
    case .ask: "sparkles"
    case .notes: "note.text"
    case .meeting: "record.circle.fill"
    }
  }

  static func clock(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
      : String(format: "%02d:%02d", s / 60, s % 60)
  }

  private var symbol: String {
    switch model.phase {
    case .listening(let mode): Self.icon(for: mode)
    case .processing: "ellipsis"
    case .done: "checkmark"
    case .message: "exclamationmark.triangle.fill"
    case .notice(_, let symbol): symbol
    case .hidden: "mic"
    }
  }

  /// Texto de la cápsula; nil = solo la gota (al terminar, la cápsula se funde en ella).
  private var label: String? {
    switch model.phase {
    case .listening(.notes): model.liveText.isEmpty ? "Tomando notas… (Esc cancela)" : model.liveText
    case .listening(.meeting): model.liveText.isEmpty ? "Reunión" : model.liveText
    case .listening(.translation): "Escuchando para traducir…"
    case .listening(.ask): "Pide o pregunta… (Esc cancela)"
    case .listening: "Escuchando… (Esc cancela)"
    case .processing(.translation): "Traduciendo…"
    case .processing(.ask): "Pensando…"
    case .processing(.notes): "Organizando notas…"
    case .processing(.meeting): "Preparando el acta…"
    case .processing: "Procesando…"
    case .done: nil
    case .message(let text): text
    case .notice(let text, _): text
    case .hidden: nil
    }
  }

}

struct LevelBars: View {
  let level: Float
  private let weights: [Float] = [0.5, 0.8, 1, 0.8, 0.5]

  var body: some View {
    HStack(spacing: 2.5) {
      ForEach(0..<weights.count, id: \.self) { i in
        Capsule()
          .fill(.primary)
          .frame(width: 3.5, height: CGFloat(5 + 15 * min(1, level * weights[i])))
      }
    }
    .frame(height: 20)
    .animation(.easeOut(duration: 0.08), value: level)
  }
}

/// Panel sin foco (no roba el cursor a la app donde escribes) y en todos los escritorios.
@MainActor
final class OverlayPanel {
  private let panel: NSPanel
  private let size = OverlayView.panelSize

  init(model: OverlayModel) {
    panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                    styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
    panel.isFloatingPanel = true
    panel.level = .statusBar
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    panel.contentView = NSHostingView(rootView: OverlayView(model: model))
  }

  private var hideWork: DispatchWorkItem?

  func show() {
    hideWork?.cancel()
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    guard let visible = screen?.visibleFrame else { return }
    panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.minY + 18,
                          width: size.width, height: size.height), display: true)
    panel.orderFrontRegardless()
  }

  /// Espera a que el cristal termine de encogerse (la fase ya es `.hidden`) antes de quitar el panel.
  func hide() {
    hideWork?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.panel.orderOut(nil) }
    hideWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
  }
}
