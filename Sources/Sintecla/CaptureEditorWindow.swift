import AppKit
import SinteclaCore
import SwiftUI
import UniformTypeIdentifiers

/// La barra del editor (spec «Capturas» §3.1 y «Editor de capturas completo» §6): Copiar, Guardar y Fijar, las
/// herramientas, el estilo y, a la derecha, el color bajo el cursor, el tamaño y el zoom.
struct CaptureEditorBar: View {
  let model: CaptureEditorModel
  var onCopy: () -> Void
  var onSave: () -> Void
  var onPin: () -> Void
  var onZoom: (CaptureZoom) -> Void

  var body: some View {
    HStack(spacing: 12) {
      HStack(spacing: 4) {
        actionButton("doc.on.doc", help: "Copiar (⌘C). Cada cambio ya se copia solo", action: onCopy)
        actionButton("square.and.arrow.down", help: "Guardar (⌘S). ⇧⌘S: Guardar como…", action: onSave)
        actionButton("pin", help: "Fijar en pantalla (⌘P)", action: onPin)
      }
      HStack(spacing: 2) {
        ForEach(AnnotationTool.allCases, id: \.self) { tool in
          barButton(symbol: tool.symbol, chosen: model.tool == tool, help: "\(tool.title) (\(tool.key))") {
            model.choose(tool)
          }
        }
      }
      HStack(spacing: 6) {
        ForEach(AnnotationColor.allCases, id: \.self) { color in
          Button { model.choose(color) } label: {
            Circle()
              .fill(Color(cgColor: color.cgColor))
              .overlay(Circle().strokeBorder(.secondary.opacity(0.5), lineWidth: 1))
              .frame(width: 16, height: 16)
              .padding(3)
              .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: model.shownStyle.color == color ? 2 : 0))
          }
          .buttonStyle(.plain)
          .help(color.name)
        }
      }
      HStack(spacing: 2) {
        ForEach(AnnotationWidth.allCases, id: \.self) { width in
          barButton(chosen: model.shownStyle.width == width, help: width.name) {
            model.choose(width)
          } label: {
            Capsule().frame(width: 16, height: width.line + 1)
          }
        }
      }
      Spacer(minLength: 8)
      Text(model.hoverHex ?? "#——————")
        .font(.system(.callout, design: .monospaced))
        .foregroundStyle(.secondary)
        .help("Color bajo el cursor: Tab lo copia")
      Text(model.pixelSize)
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
        .help("Tamaño de la captura en píxeles")
      Menu("\(Int((model.zoom * 100).rounded())) %") {
        Button("Ajustar a la ventana (⌘0)") { onZoom(.fit) }
        Button("100 % (⌘1)") { onZoom(.actual) }
        Button("Acercar (⌘+)") { onZoom(.zoomIn) }
        Button("Alejar (⌘−)") { onZoom(.zoomOut) }
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
    }
    .padding(.horizontal, 12)
    .frame(height: 44)
    .focusable(false)
  }

  private func actionButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
    Button(action: action) { Image(systemName: symbol).font(.system(size: 14)).frame(width: 22, height: 20) }
      .buttonStyle(.bordered)
      .help(help)
  }

  private func barButton(symbol: String, chosen: Bool, help: String, action: @escaping () -> Void) -> some View {
    barButton(chosen: chosen, help: help, action: action) { Image(systemName: symbol).font(.system(size: 14)) }
  }

  private func barButton(chosen: Bool, help: String, action: @escaping () -> Void,
                         @ViewBuilder label: () -> some View) -> some View {
    Button(action: action) {
      label()
        .frame(width: 28, height: 28)
        .foregroundStyle(chosen ? Color.white : Color.primary)
        .background(chosen ? Color.accentColor : .clear, in: .rect(cornerRadius: 7))
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(help)
  }
}

/// Centra la captura cuando cabe entera en la ventana.
final class CenteringClipView: NSClipView {
  override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
    var rect = super.constrainBoundsRect(proposedBounds)
    guard let document = documentView else { return rect }
    if rect.width > document.frame.width { rect.origin.x = (document.frame.width - rect.width) / 2 }
    if rect.height > document.frame.height { rect.origin.y = (document.frame.height - rect.height) / 2 }
    return rect
  }
}

/// La ventana del editor. macOS no deja que Sintecla pase al frente desde un atajo global (activación cooperativa):
/// como panel que no activa la app, sale delante de la app que se usa y toma el teclado igualmente.
final class CaptureEditorPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

/// Una ventana por captura (spec «Capturas» §3): el lienzo con la barra y el portapapeles siempre al día (§3.3).
@MainActor
final class CaptureEditor: NSObject, NSWindowDelegate {
  static let barHeight: CGFloat = 44
  /// Tras el último cambio, lo que se espera antes de volver a copiar.
  static let copyDelay = Duration.milliseconds(500)

  var onNotice: ((String, String) -> Void)?
  var onClose: ((CaptureEditor) -> Void)?

  private let model: CaptureEditorModel
  private let original: Data
  /// Cuándo se hizo la captura: da el nombre del archivo.
  private let captured = Date()
  /// La carpeta de capturas, de los ajustes.
  private let folder: () -> URL
  private let window: NSWindow
  private let scrollView = NSScrollView()
  private let canvas: CaptureCanvasView
  private var pendingCopy: Task<Void, Never>?
  /// Cuenta las copias: si una copia termina después de otra más nueva, no pisa el portapapeles.
  private var copies = 0
  /// La captura fijada en pantalla; mientras está, el editor se oculta.
  private var pinned: PinnedCapture?

  init(shot: ScreenCapture.Shot, scale: CGFloat, folder: @escaping () -> URL) {
    model = CaptureEditorModel(image: shot.image, scale: scale)
    original = shot.png
    self.folder = folder
    canvas = CaptureCanvasView(model: model)
    window = CaptureEditorPanel(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                                styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel],
                                backing: .buffered, defer: false)
    super.init()
    window.hidesOnDeactivate = false
    window.title = "Captura · \(model.pixelSize)"
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 1000, height: 320)
    window.delegate = self

    scrollView.contentView = CenteringClipView()
    scrollView.documentView = canvas
    scrollView.hasHorizontalScroller = true
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.allowsMagnification = true
    scrollView.minMagnification = 0.05
    scrollView.maxMagnification = 16
    scrollView.backgroundColor = .underPageBackgroundColor
    let bar = NSHostingView(rootView: CaptureEditorBar(model: model, onCopy: { [weak self] in self?.copyNow() },
                                                      onSave: { [weak self] in self?.save(asking: false) },
                                                      onPin: { [weak self] in self?.pin() },
                                                      onZoom: { [weak self] in self?.zoom($0) }))
    let content = NSView()
    for view in [bar, scrollView] as [NSView] {
      view.translatesAutoresizingMaskIntoConstraints = false
      content.addSubview(view)
    }
    NSLayoutConstraint.activate([
      bar.topAnchor.constraint(equalTo: content.topAnchor),
      bar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
      bar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
      bar.heightAnchor.constraint(equalToConstant: Self.barHeight),
      scrollView.topAnchor.constraint(equalTo: bar.bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
    ])
    window.contentView = content

    model.onChange = { [weak self] in self?.changed() }
    canvas.onCopy = { [weak self] in self?.copyNow() }
    canvas.onSave = { [weak self] asking in self?.save(asking: asking) }
    canvas.onPin = { [weak self] in self?.pin() }
    canvas.onCopyColor = { [weak self] hex in
      ScreenCapture.copyText(hex)
      self?.onNotice?(CaptureNotice.color(hex), "eyedropper")
    }
    canvas.onZoom = { [weak self] in self?.zoom($0) }
    canvas.onClose = { [weak self] in self?.window.performClose(nil) }
    NotificationCenter.default.addObserver(self, selector: #selector(magnified),
                                           name: NSScrollView.didEndLiveMagnifyNotification, object: scrollView)
  }

  /// Del tamaño de la captura, hasta el 85 % de la pantalla del ratón, y al 100 % si cabe.
  func show() {
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let size = NSSize(width: min(max(canvas.frame.width, window.minSize.width), visible.width * 0.85),
                      height: min(max(canvas.frame.height + Self.barHeight, window.minSize.height), visible.height * 0.85))
    window.setContentSize(size)
    window.setFrameOrigin(NSPoint(x: visible.midX - window.frame.width / 2, y: visible.midY - window.frame.height / 2))
    DockPresence.show(for: self)
    window.orderFrontRegardless()
    window.makeKey()
    window.makeFirstResponder(canvas)
    window.contentView?.layoutSubtreeIfNeeded()
    zoom(.fit)
  }

  // MARK: - Zoom

  func zoom(_ command: CaptureZoom) {
    let visible = scrollView.contentView.bounds
    let center = NSPoint(x: visible.midX, y: visible.midY)
    switch command {
    case .fit:
      let available = scrollView.contentSize
      let fit = min(available.width / canvas.frame.width, available.height / canvas.frame.height, 1)
      scrollView.setMagnification(fit, centeredAt: NSPoint(x: canvas.frame.midX, y: canvas.frame.midY))
    case .actual: scrollView.setMagnification(1, centeredAt: center)
    case .zoomIn: scrollView.setMagnification(scrollView.magnification * 1.25, centeredAt: center)
    case .zoomOut: scrollView.setMagnification(scrollView.magnification / 1.25, centeredAt: center)
    }
    model.zoom = scrollView.magnification
  }

  @objc private func magnified() {
    model.zoom = scrollView.magnification
  }

  // MARK: - Portapapeles

  /// Cada cambio: el título (un recorte cambia el tamaño) y la copia automática.
  private func changed() {
    window.title = "Captura · \(model.pixelSize)"
    scheduleCopy()
  }

  /// Medio segundo después del último cambio, la captura anotada vuelve al portapapeles, sin aviso.
  private func scheduleCopy() {
    pendingCopy?.cancel()
    pendingCopy = Task { [weak self] in
      try? await Task.sleep(for: Self.copyDelay)
      guard !Task.isCancelled else { return }
      self?.copy(notify: false)
    }
  }

  /// ⌘C y el botón Copiar: al momento y con aviso.
  private func copyNow() {
    copy(notify: true)
  }

  /// A tamaño real, fuera del hilo principal: pintar y comprimir una captura Retina lleva un momento.
  private func copy(notify: Bool) {
    pendingCopy?.cancel()
    pendingCopy = nil
    copies += 1
    let number = copies, image = model.image, document = model.document, original = original
    Task {
      let data = await Task.detached(priority: .userInitiated) { Self.export(image, document, original: original) }.value
      guard number == copies, let data else { return }
      ScreenCapture.copyImage(png: data.png, tiff: data.tiff)
      if notify { onNotice?(CaptureNotice.copied, CaptureController.imageSymbol) }
    }
  }

  // MARK: - Fijar

  /// ⌘P y Fijar: la captura, tal como está, flota donde estaba el lienzo y el editor se oculta.
  private func pin() {
    guard pinned == nil, let image = AnnotationRenderer.render(model.image, model.document) else { return }
    let onScreen = window.convertToScreen(canvas.convert(canvas.bounds, to: nil))
    let capture = PinnedCapture(image: image, scale: model.document.scale, frame: onScreen)
    capture.onReopen = { [weak self] in self?.unpin() }
    capture.onClose = { [weak self] in
      self?.unpin(reopen: false)
      self?.window.close()
    }
    pinned = capture
    window.orderOut(nil)
    DockPresence.hide(for: self)  // mientras solo haya capturas fijadas, Sintecla no sale en el Dock
    capture.show()
  }

  /// Doble clic en la captura fijada: vuelve el editor, como estaba.
  private func unpin(reopen: Bool = true) {
    pinned?.close()
    pinned = nil
    guard reopen else { return }
    DockPresence.show(for: self)
    window.orderFrontRegardless()
    window.makeKey()
  }

  // MARK: - Guardar

  /// ⌘S: al momento, en la carpeta de capturas. ⇧⌘S: la ventana de guardar de macOS, con el nombre ya puesto.
  private func save(asking: Bool) {
    let folder = folder()
    let url = CaptureFiles.freeURL(in: folder, for: captured)
    guard asking else {
      write(to: url)
      return
    }
    let panel = NSSavePanel()
    panel.nameFieldStringValue = url.lastPathComponent
    panel.directoryURL = folder
    panel.allowedContentTypes = [.png]
    panel.beginSheetModal(for: window) { [weak self] response in
      guard response == .OK, let chosen = panel.url else { return }
      self?.write(to: chosen)
    }
  }

  /// La PNG de lo que se ve (anotada y recortada), fuera del hilo principal. La pastilla dice dónde quedó.
  private func write(to url: URL) {
    let image = model.image, document = model.document, original = original
    Task {
      let png = await Task.detached(priority: .userInitiated) { Self.export(image, document, original: original)?.png }.value
      guard let png, (try? png.write(to: url, options: .atomic)) != nil else {
        onNotice?(CaptureNotice.saveFailed, "exclamationmark.triangle")
        return
      }
      onNotice?(CaptureNotice.saved(FileManager.default.displayName(atPath: url.deletingLastPathComponent().path)),
                "square.and.arrow.down")
    }
  }

  /// PNG y TIFF de la captura con sus anotaciones. Sin anotaciones, la PNG de la captura tal cual.
  nonisolated static func export(_ image: CGImage, _ document: AnnotationDocument, original: Data)
    -> (png: Data, tiff: Data?)? {
    guard !document.annotations.isEmpty else {
      return (original, NSBitmapImageRep(cgImage: image).tiffRepresentation)
    }
    guard let rendered = AnnotationRenderer.render(image, document), let png = AnnotationRenderer.png(rendered) else {
      return nil
    }
    return (png, NSBitmapImageRep(cgImage: rendered).tiffRepresentation)
  }

  func windowWillClose(_ notification: Notification) {
    // Un cambio de hace menos de medio segundo aún no estaba copiado.
    if pendingCopy != nil { copy(notify: false) }
    NotificationCenter.default.removeObserver(self)
    DockPresence.hide(for: self)
    onClose?(self)
  }
}
