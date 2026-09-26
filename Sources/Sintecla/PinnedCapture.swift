import AppKit

/// Una captura fijada (spec «Editor de capturas completo» §5): flota encima de las ventanas y en todos los escritorios,
/// sin activar Sintecla. Arrastrar la mueve, la rueda o pellizcar la escalan, doble clic vuelve al editor y Esc o ⌘W
/// la cierran.
@MainActor
final class PinnedCapture {
  /// Escala mínima y máxima respecto al tamaño real (un píxel de la captura por píxel de la pantalla).
  static let zoomRange: ClosedRange<CGFloat> = 0.2...4

  var onReopen: (() -> Void)?
  var onClose: (() -> Void)?

  private let panel: PinnedPanel
  /// El tamaño real en puntos.
  private let naturalSize: NSSize
  private var zoom: CGFloat

  /// `frame`: dónde estaba el lienzo en la pantalla; si no cabe, se encoge sin mover la esquina de arriba.
  init(image: CGImage, scale: CGFloat, frame: NSRect) {
    naturalSize = NSSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
    let screen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
    let visible = screen?.visibleFrame ?? frame
    let fit = min(frame.width / naturalSize.width, visible.width * 0.9 / naturalSize.width,
                  visible.height * 0.9 / naturalSize.height)
    zoom = min(max(fit, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
    let size = NSSize(width: naturalSize.width * zoom, height: naturalSize.height * zoom)
    let top = min(frame.maxY, visible.maxY)
    let left = min(max(frame.minX, visible.minX), visible.maxX - size.width)
    panel = PinnedPanel(contentRect: NSRect(x: left, y: top - size.height, width: size.width, height: size.height),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.hidesOnDeactivate = false
    panel.hasShadow = true
    panel.isReleasedWhenClosed = false
    let view = PinnedImageView(image: image)
    view.onScale = { [weak self] factor in self?.scale(by: factor) }
    view.onReopen = { [weak self] in self?.onReopen?() }
    view.onClose = { [weak self] in self?.onClose?() }
    panel.contentView = view
  }

  func show() {
    panel.orderFrontRegardless()
  }

  func close() {
    panel.orderOut(nil)
  }

  /// Sin mover la esquina de arriba a la izquierda.
  private func scale(by factor: CGFloat) {
    zoom = min(max(zoom * factor, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
    let frame = panel.frame
    let size = NSSize(width: naturalSize.width * zoom, height: naturalSize.height * zoom)
    panel.setFrame(NSRect(x: frame.minX, y: frame.maxY - size.height, width: size.width, height: size.height),
                   display: true)
  }
}

/// Toma el teclado al hacer clic en ella (para Esc y ⌘W) sin activar Sintecla.
final class PinnedPanel: NSPanel {
  override var canBecomeKey: Bool { true }
}

/// La imagen de la captura fijada y lo que se hace con el ratón y el teclado.
final class PinnedImageView: NSView {
  var onScale: ((CGFloat) -> Void)?
  var onReopen: (() -> Void)?
  var onClose: (() -> Void)?
  private let image: CGImage

  init(image: CGImage) {
    self.image = image
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) { nil }

  override var acceptsFirstResponder: Bool { true }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.interpolationQuality = .high
    context.draw(image, in: bounds)
    context.setStrokeColor(NSColor.black.withAlphaComponent(0.25).cgColor)
    context.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))
  }

  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    if event.clickCount == 2 {
      onReopen?()
    } else {
      window?.performDrag(with: event)
    }
  }

  override func scrollWheel(with event: NSEvent) {
    let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.01 : event.scrollingDeltaY * 0.05
    onScale?(1 + max(min(delta, 0.5), -0.5))
  }

  override func magnify(with event: NSEvent) {
    onScale?(1 + event.magnification)
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 { onClose?() } else { super.keyDown(with: event) }  // 53 = Esc
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "w" else {
      return super.performKeyEquivalent(with: event)
    }
    onClose?()
    return true
  }
}
