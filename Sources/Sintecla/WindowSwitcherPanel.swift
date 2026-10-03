import AppKit
import Observation
import SinteclaCore
import SwiftUI

/// Lo que enseña el selector: las ventanas, la marcada, las miniaturas que van llegando y el tamaño de las tarjetas.
@MainActor @Observable
final class SwitcherModel {
  var windows: [SwitcherWindow] = []
  var selected: Int?
  var thumbnails: [Int: CGImage] = [:]
  /// Ancho de cada tarjeta, en puntos: 200, o menos si no caben (spec «Alt-Tab» §5).
  var cardWidth: CGFloat = 200
  /// Tarjetas por fila: hasta 6.
  var columns = 1
}

/// El panel de cristal con una tarjeta por ventana (spec «Alt-Tab» §5).
struct WindowSwitcherView: View {
  let model: SwitcherModel
  var onHover: (Int) -> Void
  var onClick: (Int) -> Void

  var body: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(model.cardWidth), spacing: 12), count: model.columns),
              spacing: 12) {
      ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
        card(window, chosen: model.selected == index)
          .onHover { if $0 { onHover(index) } }
          .onTapGesture { onClick(index) }
      }
    }
    .padding(16)
    .glassEffect(.regular, in: .rect(cornerRadius: 28))
    .padding(6)
  }

  private func card(_ window: SwitcherWindow, chosen: Bool) -> some View {
    let icon = NSRunningApplication(processIdentifier: window.pid)?.icon ?? NSImage(named: NSImage.applicationIconName)!
    return VStack(alignment: .leading, spacing: 6) {
      ZStack {
        if let thumbnail = model.thumbnails[window.id] {
          Image(decorative: thumbnail, scale: 2).resizable().aspectRatio(contentMode: .fit)
            .clipShape(.rect(cornerRadius: 6))
        } else {
          Image(nsImage: icon).resizable().frame(width: 64, height: 64)
        }
      }
      .frame(width: model.cardWidth - 16, height: (model.cardWidth - 16) * 0.66)
      HStack(spacing: 6) {
        Image(nsImage: icon).resizable().frame(width: 16, height: 16)
        Text(window.label).font(.callout).lineLimit(1).truncationMode(.tail)
      }
    }
    .padding(8)
    .frame(width: model.cardWidth)
    .background(chosen ? Color.accentColor.opacity(0.22) : .clear, in: .rect(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: chosen ? 2 : 0))
    .opacity(window.isMinimized ? 0.55 : 1)
    .contentShape(.rect)
  }
}

/// Panel por encima de todo que no activa Sintecla: la app de delante sigue siendo la que era hasta que se salta.
@MainActor
final class WindowSwitcherPanel {
  let model = SwitcherModel()
  var onHover: ((Int) -> Void)?
  var onClick: ((Int) -> Void)?
  private let panel: NSPanel
  private var hosting: FirstMouseHostingView<WindowSwitcherView>!

  init() {
    panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200), styleMask: [.nonactivatingPanel, .borderless],
                    backing: .buffered, defer: false)
    panel.level = .popUpMenu
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false  // el cristal ya lleva su sombra
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    hosting = FirstMouseHostingView(rootView: WindowSwitcherView(
      model: model, onHover: { [weak self] in self?.onHover?($0) }, onClick: { [weak self] in self?.onClick?($0) }))
    panel.contentView = hosting
  }

  /// Hasta 6 tarjetas por fila de 200 puntos; si no caben en el 80 % de la pantalla del ratón, se encogen.
  func layout(count: Int) {
    let visible = screenUnderMouse()?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
    let columns = max(1, min(6, count))
    let rows = CGFloat((count + columns - 1) / columns)
    let byWidth = (visible.width * 0.8 - 44 - 12 * CGFloat(columns - 1)) / CGFloat(columns)
    // Alto de una tarjeta: la miniatura (0,66 del ancho) y la línea del título.
    let byHeight = ((visible.height * 0.8 - 44 - 12 * (rows - 1)) / rows - 40) / 0.66
    model.columns = columns
    model.cardWidth = max(80, min(200, byWidth, byHeight))
  }

  func show() {
    hosting.layoutSubtreeIfNeeded()
    let size = hosting.fittingSize
    guard let visible = screenUnderMouse()?.visibleFrame else { return }
    panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2, width: size.width,
                          height: size.height), display: true)
    panel.orderFrontRegardless()
  }

  func hide() {
    panel.orderOut(nil)
  }

  private func screenUnderMouse() -> NSScreen? {
    let mouse = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
  }
}
