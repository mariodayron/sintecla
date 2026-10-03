import AppKit
import Observation
import SinteclaCore
import SwiftUI

/// Lo que enseña la vista del Dock: las ventanas de la app, la marcada, las miniaturas que van llegando y cómo van las
/// tarjetas.
@MainActor @Observable
final class DockPreviewModel {
  var windows: [SwitcherWindow] = []
  var selected: Int?
  var thumbnails: [Int: CGImage] = [:]
  var cardWidth = DockPreview.cardWidth
  /// En columna si el Dock está a un lado; en fila si está abajo.
  var vertical = false
}

/// La vista de cristal con una tarjeta por ventana (spec «Vistas del Dock» §5).
struct DockPreviewView: View {
  let model: DockPreviewModel
  var onHover: (Int) -> Void
  var onClick: (Int) -> Void
  var onClose: (Int) -> Void
  var onMinimize: (Int) -> Void
  var onQuit: (Int) -> Void

  var body: some View {
    let layout = model.vertical ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
    layout {
      ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
        WindowCard(window: window, thumbnail: model.thumbnails[window.id], width: model.cardWidth,
                   chosen: model.selected == index, onClose: { onClose(index) }, onMinimize: { onMinimize(index) },
                   onQuit: { onQuit(index) })
          .onHover { if $0 { onHover(index) } }
          .onTapGesture { onClick(index) }
      }
    }
    .padding(12)
    .glassEffect(.regular, in: .rect(cornerRadius: 22))
    .padding(6)
  }
}

/// Panel por encima del Dock que no activa Sintecla: la app de delante sigue siendo la que era.
@MainActor
final class DockPreviewPanel {
  let model = DockPreviewModel()
  var onClick: ((Int) -> Void)?
  var onClose: ((Int) -> Void)?
  var onMinimize: ((Int) -> Void)?
  var onQuit: ((Int) -> Void)?
  private let panel: NSPanel
  private var hosting: FirstMouseHostingView<DockPreviewView>!

  init() {
    panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200), styleMask: [.nonactivatingPanel, .borderless],
                    backing: .buffered, defer: false)
    panel.level = .popUpMenu
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false  // el cristal ya lleva su sombra
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    hosting = FirstMouseHostingView(rootView: DockPreviewView(
      model: model,
      onHover: { [weak self] in self?.model.selected = $0 },
      onClick: { [weak self] in self?.onClick?($0) },
      onClose: { [weak self] in self?.onClose?($0) },
      onMinimize: { [weak self] in self?.onMinimize?($0) },
      onQuit: { [weak self] in self?.onQuit?($0) }))
    panel.contentView = hosting
  }

  var isVisible: Bool { panel.isVisible }
  var frame: CGRect { panel.frame }

  /// Tarjetas de 240 puntos; si no caben en el 80 % de la pantalla a lo largo del Dock, se encogen.
  func layout(count: Int, edge: DockEdge, screen: CGRect) {
    model.vertical = edge != .bottom
    let count = CGFloat(max(1, count))
    let free = (model.vertical ? screen.height : screen.width) * 0.8 - 36 - 10 * (count - 1)
    // En columna manda el alto de la tarjeta: la miniatura (0,66 del ancho) más el título, unos 32 puntos.
    let width = model.vertical ? (free / count - 32) / 0.66 : free / count
    model.cardWidth = max(80, min(DockPreview.cardWidth, width))
  }

  /// `screen`: la parte útil de la pantalla del icono (sin la barra de menús ni el Dock).
  func show(icon: CGRect, edge: DockEdge, screen: CGRect) {
    hosting.layoutSubtreeIfNeeded()
    let frame = DockPreviewPlacement.frame(panel: hosting.fittingSize, icon: icon, edge: edge, screen: screen)
    panel.setFrame(frame, display: true)
    panel.orderFrontRegardless()
  }

  func hide() {
    panel.orderOut(nil)
  }
}
