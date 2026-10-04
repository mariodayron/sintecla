import AppKit
import SinteclaCore
import SwiftUI

/// La fila del estante en la isla desplegada (spec «Estante y avisos» §3.2): cada archivo con su miniatura y su nombre;
/// se saca arrastrándolo, se abre con doble clic y se quita con la ✕. «Vaciar» a la derecha.
struct ShelfRow: View {
  let store: ShelfStore
  let drag: ShelfDragSource
  var onDragStart: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 4) {
          ForEach(store.items) { item in
            ShelfCell(item: item, thumbnail: store.thumbnails[item.id], store: store, drag: drag,
                      onDragStart: onDragStart)
          }
        }
      }
      Button("Vaciar") { store.clear() }
        .buttonStyle(.plain)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.white.opacity(0.55))
        .padding(.leading, 4)
    }
    .frame(height: 66)
  }
}

private struct ShelfCell: View {
  let item: ShelfItem
  let thumbnail: NSImage?
  let store: ShelfStore
  let drag: ShelfDragSource
  var onDragStart: () -> Void
  @State private var hovering = false

  var body: some View {
    VStack(spacing: 3) {
      Group {
        if let thumbnail {
          Image(nsImage: thumbnail).resizable().scaledToFit()
        } else {
          Image(systemName: "doc").resizable().scaledToFit().padding(6)
        }
      }
      .frame(width: 38, height: 38)
      Text(item.name)
        .font(.system(size: 9.5))
        .lineLimit(1)
        .truncationMode(.middle)
        .foregroundStyle(.white.opacity(0.85))
    }
    .frame(width: 62)
    .padding(.vertical, 4)
    .background(.white.opacity(hovering ? 0.12 : 0), in: .rect(cornerRadius: 8))
    .overlay {
      FileDragArea(onDrag: { event, view in
        guard let url = store.url(of: item) else { return store.refresh() }
        onDragStart()
        drag.begin(item: item.id, url: url, image: thumbnail, event: event, from: view)
      }, onDoubleClick: { store.open(item) }, onHover: { hovering = $0 })
    }
    .overlay(alignment: .topTrailing) {
      if hovering {
        Button { store.remove(item.id) } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 13))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.black, .white.opacity(0.85))
        }
        .buttonStyle(.plain)
        .help("Quitar del estante")
        .offset(x: 2, y: -2)
      }
    }
    .help(item.name)
  }
}

/// Lo de AppKit de cada archivo: empezar el arrastre, el doble clic y el ratón encima.
private struct FileDragArea: NSViewRepresentable {
  var onDrag: (NSEvent, NSView) -> Void
  var onDoubleClick: () -> Void
  var onHover: (Bool) -> Void

  func makeNSView(context: Context) -> DragAreaView {
    DragAreaView()
  }

  func updateNSView(_ view: DragAreaView, context: Context) {
    view.onDrag = onDrag
    view.onDoubleClick = onDoubleClick
    view.onHover = onHover
  }

  final class DragAreaView: NSView {
    var onDrag: ((NSEvent, NSView) -> Void)?
    var onDoubleClick: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    private var down: NSEvent?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
      super.updateTrackingAreas()
      trackingAreas.forEach(removeTrackingArea)
      addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                     owner: self))
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }

    override func mouseDown(with event: NSEvent) {
      down = event
      if event.clickCount == 2 { onDoubleClick?() }
    }

    /// El arrastre empieza al moverse unos puntos con el botón pulsado.
    override func mouseDragged(with event: NSEvent) {
      guard let down else { return }
      let start = down.locationInWindow, now = event.locationInWindow
      guard hypot(now.x - start.x, now.y - start.y) > 3 else { return }
      self.down = nil
      onHover?(false)
      onDrag?(down, self)
    }

    override func mouseUp(with event: NSEvent) {
      down = nil
    }
  }
}

/// El arrastre hacia fuera del estante (spec «Estante y avisos» §3.3). Vive en el controlador, no en la vista: la isla
/// puede recogerse mientras se arrastra. Al acabar dice si se soltó en algún sitio y si se mantenía ⌥.
@MainActor
final class ShelfDragSource: NSObject, NSDraggingSource {
  var onEnd: ((UUID, _ dropped: Bool, _ keep: Bool) -> Void)?
  private var item: UUID?

  func begin(item: UUID, url: URL, image: NSImage?, event: NSEvent, from view: NSView) {
    self.item = item
    let dragging = NSDraggingItem(pasteboardWriter: url as NSURL)
    let side: CGFloat = 38
    let origin = view.convert(event.locationInWindow, from: nil)
    dragging.setDraggingFrame(NSRect(x: origin.x - side / 2, y: origin.y - side / 2, width: side, height: side),
                              contents: image ?? NSWorkspace.shared.icon(forFile: url.path))
    view.beginDraggingSession(with: [dragging], event: event, source: self)
  }

  nonisolated func draggingSession(_ session: NSDraggingSession,
                                   sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    context == .outsideApplication ? [.copy, .move, .link, .generic] : []
  }

  nonisolated func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint,
                                   operation: NSDragOperation) {
    let keep = NSEvent.modifierFlags.contains(.option)
    MainActor.assumeIsolated {
      guard let item else { return }
      self.item = nil
      onEnd?(item, !operation.isEmpty, keep)
    }
  }
}
