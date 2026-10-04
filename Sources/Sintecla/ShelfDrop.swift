import AppKit
import SinteclaCore

/// Sabe si se están arrastrando archivos desde otra app y dónde va el ratón (spec «Estante y avisos» §3.1): el
/// portapapeles de arrastre cambia al empezar cada arrastre, y el monitor global ve el ratón aunque lo lleve Finder.
/// Los arrastres que salen de Sintecla (sacar del estante) no llegan al monitor global.
@MainActor
final class FileDragWatcher {
  /// Cada movimiento con archivos (dónde va el ratón) y, al soltar el botón, nil.
  var onChange: ((NSPoint?) -> Void)?
  private let board = NSPasteboard(name: .drag)
  private var baseline: Int
  private var dragging = false
  private var monitor: Any?

  init() {
    baseline = board.changeCount
  }

  func start() {
    guard monitor == nil else { return }
    baseline = board.changeCount
    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
      let type = event.type
      MainActor.assumeIsolated { self?.handle(type) }
    }
  }

  func stop() {
    if let monitor { NSEvent.removeMonitor(monitor) }
    monitor = nil
    dragging = false
  }

  /// Tras soltar en la isla: este arrastre ya está atendido.
  func finish() {
    baseline = board.changeCount
    if dragging {
      dragging = false
      onChange?(nil)
    }
  }

  private func handle(_ type: NSEvent.EventType) {
    if type == .leftMouseUp {
      finish()
      return
    }
    if !dragging {
      guard board.changeCount != baseline, board.types?.contains(.fileURL) == true else { return }
      dragging = true
    }
    onChange?(NSEvent.mouseLocation)
  }
}

/// Recibe archivos arrastrados (la bandeja de la isla y la ventana sobre la muesca). Solo los acepta cuando
/// `accepting` es true.
final class FileDropView: NSView {
  var accepting = true
  var onEnter: (() -> Void)?
  var onDrop: (([URL]) -> Void)?

  override init(frame: NSRect) {
    super.init(frame: frame)
    registerForDraggedTypes([.fileURL])
  }

  required init?(coder: NSCoder) { nil }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard accepting else { return [] }
    onEnter?()
    return .copy
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    accepting ? .copy : []
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    guard accepting else { return false }
    let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                    options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    guard !urls.isEmpty else { return false }
    onDrop?(urls)
    return true
  }
}

/// La ventana invisible sobre la muesca real, por si el arrastre llega ahí antes de abrirse la bandeja (spec «Estante
/// y avisos» §3.1). Ahí no hay nada de la barra de menús, así que no tapa ningún clic.
@MainActor
final class ShelfDropWindow {
  private let panel: NSPanel
  let view = FileDropView(frame: .zero)

  init() {
    panel = NSPanel(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    panel.contentView = view
  }

  func show(over notch: CGRect) {
    if panel.frame != notch { panel.setFrame(notch, display: false) }
    if !panel.isVisible { panel.orderFrontRegardless() }
  }

  func hide() {
    panel.orderOut(nil)
  }
}
