import AppKit
import Observation
import SwiftUI

/// Estado de la tarjeta de respuesta de Ask Anything.
@MainActor @Observable
final class AskCardModel {
  var text = ""
  /// Lo que se pidió (la orden dictada), para ver qué entendió.
  var question = ""
  /// Respondió el modelo de Apple (sin Gemini).
  var local = false
  var isError = false
  var copied = false
}

struct AskCardView: View {
  let model: AskCardModel
  var onCopy: () -> Void
  var onInsert: () -> Void
  var onClose: () -> Void

  /// Una lámina de Liquid Glass (como las notificaciones de macOS 26) con la pregunta, la respuesta y los botones.
  /// Los botones son propios: los del sistema se ven apagados en un panel sin foco, y este panel nunca lo toma.
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: model.isError ? "exclamationmark.triangle.fill" : "sparkles")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.primary)
          .frame(width: 30, height: 30)
          .background(.quaternary, in: .circle)
        VStack(alignment: .leading, spacing: 1) {
          HStack(spacing: 6) {
            Text(model.isError ? "Ask Anything" : "Respuesta").font(.system(.headline, design: .rounded))
            if model.local {
              Text("local").font(.system(.caption2, design: .rounded).weight(.semibold))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(.quaternary, in: .capsule)
                .help("Sin Gemini: ha respondido el modelo del Mac")
            }
          }
          if !model.question.isEmpty {
            Text("«\(model.question)»").font(.system(.caption, design: .rounded)).foregroundStyle(.secondary)
              .lineLimit(1).truncationMode(.tail)
          }
        }
        Spacer(minLength: 8)
        Button(action: onClose) {
          Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
            .frame(width: 26, height: 26).background(.quaternary, in: .circle)
        }
        .buttonStyle(.plain)
        .help("Cerrar (Esc)")
      }
      ScrollView {
        Text(Self.markdown(model.text))
          .font(.system(size: 15))
          .lineSpacing(3)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 300)
      if !model.isError {
        HStack(spacing: 8) {
          Spacer()
          CardButton(title: model.copied ? "Copiado" : "Copiar", symbol: model.copied ? "checkmark" : "doc.on.doc",
                     prominent: false, action: onCopy)
          CardButton(title: "Insertar", symbol: "text.insert", prominent: true, action: onInsert)
        }
      }
    }
    .padding(16)
    .glassEffect(.regular, in: .rect(cornerRadius: 26))
    .padding(6)
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.copied)
    .frame(width: 492)
  }

  /// Negritas, cursivas, código y enlaces; los saltos de línea se respetan.
  static func markdown(_ text: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
  }
}

/// Botón en cápsula con colores fijos: no se apaga aunque el panel no tenga el foco.
struct CardButton: View {
  let title: String
  let symbol: String
  let prominent: Bool
  let action: () -> Void
  @State private var hovering = false
  @Environment(\.colorScheme) private var scheme

  /// Principal: blanco en modo oscuro y negro en modo claro (con el texto al revés).
  private var ink: Color { scheme == .dark ? .white : .black }
  private var paper: Color { scheme == .dark ? .black : .white }

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: symbol)
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(prominent ? paper : Color.primary)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(prominent ? AnyShapeStyle(ink) : AnyShapeStyle(.quaternary), in: .capsule)
        .brightness(hovering ? 0.06 : 0)
        .contentTransition(.symbolEffect(.replace))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

/// Acepta el primer clic aunque el panel no tenga el foco (si no, el primer clic se pierde).
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Panel que nunca toma el foco: el cursor sigue en tu app, así "Insertar" pega donde estabas.
@MainActor
final class AskCardPanel {
  let model = AskCardModel()
  var onInsert: ((String) -> Void)?
  private let panel: NSPanel
  private var hosting: FirstMouseHostingView<AskCardView>!

  init() {
    panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 492, height: 200),
                    styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
    panel.isFloatingPanel = true
    panel.level = .statusBar
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false  // el cristal ya lleva su sombra
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    hosting = FirstMouseHostingView(rootView: AskCardView(
      model: model,
      onCopy: { [weak self] in self?.copy() },
      onInsert: { [weak self] in self?.insert() },
      onClose: { [weak self] in self?.close() }))
    panel.contentView = hosting
  }

  var isVisible: Bool { panel.isVisible }

  func show(_ text: String, question: String = "", local: Bool = false, isError: Bool = false) {
    model.text = text
    model.question = question
    model.local = local
    model.isError = isError
    model.copied = false
    // SwiftUI aplica los cambios del modelo más tarde: sin forzar el layout se mediría el texto anterior.
    hosting.layoutSubtreeIfNeeded()
    let size = hosting.fittingSize
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    guard let visible = screen?.visibleFrame else { return }
    // Encima de la pastilla (que ocupa los 24 + 54 pt de abajo).
    panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.minY + 86,
                          width: size.width, height: size.height), display: true)
    panel.orderFrontRegardless()
  }

  func close() {
    panel.orderOut(nil)
  }

  private func copy() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(model.text, forType: .string)
    model.copied = true
  }

  private func insert() {
    let text = model.text
    close()
    onInsert?(text)
  }
}
