import AppKit
import Observation
import SinteclaCore

/// La regla, en píxeles de la imagen: una guía que no sale en la imagen copiada.
struct CaptureRuler: Equatable {
  var from: CGPoint
  var to: CGPoint
  var measure: RulerMeasure { RulerMeasure(from: from, to: to) }
}

/// Estado del editor de una captura (spec «Capturas» §3): las anotaciones, la herramienta, el estilo, el zoom y el
/// color bajo el cursor.
@MainActor @Observable
final class CaptureEditorModel {
  let image: CGImage
  let pixels: ImagePixels?
  private(set) var document: AnnotationDocument
  private(set) var tool: AnnotationTool = .arrow
  /// El color de las herramientas (rojo de fábrica) y el del Subrayador (amarillo).
  private(set) var color: AnnotationColor = .red
  private(set) var highlighterColor: AnnotationColor = .yellow
  private(set) var width: AnnotationWidth = .medium
  /// 1 es el 100 %: un píxel de la captura por píxel de la pantalla.
  var zoom: Double = 1
  /// `#RRGGBB` bajo el cursor.
  var hoverHex: String?
  var ruler: CaptureRuler?
  /// El marco de Recortar mientras se ajusta, en píxeles de la captura entera.
  var cropFrame: CGRect?
  /// La herramienta de antes de Recortar: se vuelve a ella al recortar o al cancelar.
  @ObservationIgnored private var toolBeforeCrop: AnnotationTool = .arrow
  /// Cada cambio de las anotaciones: el editor vuelve a copiar la captura.
  @ObservationIgnored var onChange: (() -> Void)?

  init(image: CGImage, scale: CGFloat) {
    self.image = image
    pixels = ImagePixels(image)
    document = AnnotationDocument(scale: scale)
  }

  var imageSize: CGSize { CGSize(width: image.width, height: image.height) }

  /// Lo que enseña el lienzo, en píxeles de la captura: la captura entera mientras se recorta; si no, el recorte.
  var shownRect: CGRect {
    tool == .crop ? CGRect(origin: .zero, size: imageSize) : document.visibleRect(in: imageSize)
  }

  /// El tamaño de lo que se copia: el del recorte, si lo hay.
  var pixelSize: String {
    let area = document.visibleRect(in: imageSize)
    return "\(Int(area.width)) × \(Int(area.height))"
  }

  /// El estilo de lo siguiente que se dibuje.
  var style: AnnotationStyle {
    AnnotationStyle(color: tool == .highlighter ? highlighterColor : color, width: width)
  }

  var selected: Annotation? { document.selection.flatMap { document.annotation($0) } }

  /// Lo que marca la barra: el estilo de la elegida o el de la herramienta.
  var shownStyle: AnnotationStyle { selected?.style ?? style }

  func choose(_ tool: AnnotationTool) {
    if tool == .crop, self.tool != .crop { toolBeforeCrop = self.tool }
    self.tool = tool
    ruler = nil
    // Recortar empieza con el marco en la zona que se ve ahora.
    cropFrame = tool == .crop ? document.visibleRect(in: imageSize) : nil
    if tool != .select { document.select(nil) }
  }

  /// Intro con Recortar: el lienzo se queda con el marco. ⌘Z lo deshace.
  func applyCrop() {
    guard let frame = cropFrame else { return }
    let size = imageSize
    edit { $0.setCrop(frame, in: size) }
    choose(toolBeforeCrop)
  }

  /// Esc con Recortar: quita el marco sin recortar.
  func cancelCrop() {
    choose(toolBeforeCrop)
  }

  /// Con una anotación elegida, se lo cambia a ella; y queda para lo siguiente de su clase.
  func choose(_ color: AnnotationColor) {
    let highlighter = selected.map { if case .highlighter = $0.shape { true } else { false } } ?? (tool == .highlighter)
    if highlighter { highlighterColor = color } else { self.color = color }
    if let selected { edit { $0.setStyle(AnnotationStyle(color: color, width: selected.style.width), of: selected.id) } }
  }

  func choose(_ width: AnnotationWidth) {
    self.width = width
    if let selected { edit { $0.setStyle(AnnotationStyle(color: selected.style.color, width: width), of: selected.id) } }
  }

  func select(_ id: Int?) {
    document.select(id)
  }

  /// Todo cambio de las anotaciones o del recorte pasa por aquí.
  func edit(_ change: (inout AnnotationDocument) -> Void) {
    let before = (document.annotations, document.crop)
    change(&document)
    if document.annotations != before.0 || document.crop != before.1 { onChange?() }
  }
}

/// Zoom del editor: ⌘0, ⌘1, ⌘+ y ⌘−.
enum CaptureZoom {
  case fit, actual, zoomIn, zoomOut
}

/// Un asa del marco de Recortar: −1, 0 o 1 en cada eje (0 es el centro del lado).
private struct CropHandle: Equatable {
  let x: Int
  let y: Int

  static let all = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)].map { CropHandle(x: $0.0, y: $0.1) }

  func point(in frame: CGRect) -> CGPoint {
    CGPoint(x: frame.midX + CGFloat(x) * frame.width / 2, y: frame.midY + CGFloat(y) * frame.height / 2)
  }

  /// El marco con esta asa arrastrada.
  func resize(_ frame: CGRect, by delta: CGVector) -> CGRect {
    var minX = frame.minX, maxX = frame.maxX, minY = frame.minY, maxY = frame.maxY
    if x < 0 { minX += delta.dx } else if x > 0 { maxX += delta.dx }
    if y < 0 { minY += delta.dy } else if y > 0 { maxY += delta.dy }
    return CGRect(x: min(minX, maxX), y: min(minY, maxY), width: abs(maxX - minX), height: abs(maxY - minY))
  }
}

/// El lienzo del editor: la captura y sus anotaciones, con el ratón y el teclado de cada herramienta (spec «Capturas»
/// §3.2). Mide en puntos lo que la captura en píxeles: con el zoom al 100 %, un píxel por píxel de la pantalla.
@MainActor
final class CaptureCanvasView: NSView, NSTextFieldDelegate {
  let model: CaptureEditorModel
  var onCopy: (() -> Void)?
  /// ⌘S (false) y ⇧⌘S (true, pregunta dónde).
  var onSave: ((Bool) -> Void)?
  var onCopyColor: ((String) -> Void)?
  var onZoom: ((CaptureZoom) -> Void)?
  var onClose: (() -> Void)?

  private enum Drag {
    case drawing(AnnotationShape)
    case moving(id: Int, offset: CGVector)
    case measuring
    /// Un marco nuevo de Recortar.
    case newCrop
    /// Un asa del marco (o, sin asa, el marco entero) desde como estaba.
    case cropping(handle: CropHandle?, from: CGRect)
  }

  private var drag: Drag?
  private var dragStart = CGPoint.zero
  /// El texto que se escribe: nuevo (`id` nil) o uno que ya estaba.
  private var editing: (field: NSTextField, id: Int?, origin: CGPoint)?
  private var scale: CGFloat { model.document.scale }

  init(model: CaptureEditorModel) {
    self.model = model
    let scale = model.document.scale, area = model.shownRect
    super.init(frame: NSRect(x: 0, y: 0, width: area.width / scale, height: area.height / scale))
    observe()
  }

  required init?(coder: NSCoder) { nil }

  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  /// Cualquier cambio del modelo (también desde la barra) se ve en el lienzo.
  private func observe() {
    withObservationTracking {
      _ = (model.document, model.tool, model.ruler, model.zoom, model.color, model.highlighterColor, model.width,
           model.cropFrame)
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.fitToShownArea()
        self.needsDisplay = true
        self.window?.invalidateCursorRects(for: self)
        self.restyleField()
        // Tras un clic en la barra, el teclado vuelve al lienzo (salvo si se está escribiendo un texto).
        if self.editing == nil, self.window?.firstResponder !== self { self.window?.makeFirstResponder(self) }
        self.observe()
      }
    }
  }

  /// El lienzo mide lo que enseña: el recorte o, mientras se recorta, la captura entera.
  private func fitToShownArea() {
    let area = model.shownRect
    let size = NSSize(width: area.width / scale, height: area.height / scale)
    if frame.size != size { setFrameSize(size) }
  }

  // MARK: - Dibujo

  override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let area = model.shownRect
    context.saveGState()
    // En píxeles de la captura entera, con la esquina de lo que se enseña en el origen del lienzo.
    context.scaleBy(x: 1 / scale, y: 1 / scale)
    context.translateBy(x: -area.minX, y: -area.minY)
    context.saveGState()
    // El contexto va de arriba abajo y la imagen se dibuja de abajo arriba: se le da la vuelta solo a ella.
    context.translateBy(x: 0, y: model.imageSize.height)
    context.scaleBy(x: 1, y: -1)
    context.interpolationQuality = model.zoom > 1.5 ? .none : .high
    context.draw(model.image, in: CGRect(origin: .zero, size: model.imageSize))
    context.restoreGState()

    let shown = shownDocument
    AnnotationRenderer.draw(shown, image: model.image, in: context, hiding: editing?.id)
    // Un pixel de pantalla, sea cual sea el zoom.
    let hairline = scale / max(model.zoom, 0.05)
    if let id = shown.selection, editing == nil, let box = shown.bounds(of: id) {
      context.setStrokeColor(NSColor.controlAccentColor.cgColor)
      context.setLineWidth(1.5 * hairline)
      context.setLineDash(phase: 0, lengths: [4 * hairline, 3 * hairline])
      context.stroke(box.insetBy(dx: -4 * scale, dy: -4 * scale))
      context.setLineDash(phase: 0, lengths: [])
    }
    if let ruler = model.ruler { drawRuler(ruler, hairline: hairline, in: context) }
    if model.tool == .crop, let frame = model.cropFrame { drawCropFrame(frame, hairline: hairline, in: context) }
    context.restoreGState()
  }

  /// Las anotaciones con lo que se está arrastrando: el trazo nuevo o la elegida en su sitio nuevo.
  private var shownDocument: AnnotationDocument {
    var document = model.document
    switch drag {
    case .drawing(let shape)?: document.add(shape, style: model.style)
    case .moving(let id, let offset)?: document.move(id, by: offset)
    default: break
    }
    return document
  }

  private func drawRuler(_ ruler: CaptureRuler, hairline: CGFloat, in context: CGContext) {
    let color = NSColor.systemPink.cgColor
    context.setStrokeColor(color)
    context.setFillColor(color)
    context.setLineWidth(1.5 * hairline)
    context.move(to: ruler.from)
    context.addLine(to: ruler.to)
    context.strokePath()
    for end in [ruler.from, ruler.to] {
      context.fillEllipse(in: CGRect(x: end.x - 3 * hairline, y: end.y - 3 * hairline, width: 6 * hairline,
                                     height: 6 * hairline))
    }
    // La medida, junto al final de la regla.
    drawLabel(ruler.measure.label, at: CGPoint(x: ruler.to.x + 10 * hairline, y: ruler.to.y + 10 * hairline),
              hairline: hairline, in: context)
  }

  /// Fuera del marco, la captura se oscurece. El marco lleva sus ocho asas y su tamaño en píxeles.
  private func drawCropFrame(_ frame: CGRect, hairline: CGFloat, in context: CGContext) {
    context.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor)
    context.addRect(CGRect(origin: .zero, size: model.imageSize))
    context.addRect(frame)
    context.fillPath(using: .evenOdd)
    context.setStrokeColor(NSColor.white.cgColor)
    context.setLineWidth(1.5 * hairline)
    context.stroke(frame)
    for handle in CropHandle.all {
      let center = handle.point(in: frame)
      let box = CGRect(x: center.x - 4 * hairline, y: center.y - 4 * hairline, width: 8 * hairline, height: 8 * hairline)
      context.setFillColor(NSColor.white.cgColor)
      context.fill(box)
      context.setStrokeColor(NSColor.black.withAlphaComponent(0.4).cgColor)
      context.setLineWidth(hairline)
      context.stroke(box)
    }
    let above = frame.minY - 26 * hairline
    drawLabel("\(Int(frame.width)) × \(Int(frame.height))",
              at: CGPoint(x: frame.minX, y: above >= 0 ? above : frame.minY + 6 * hairline), hairline: hairline, in: context)
  }

  /// Una etiqueta de tamaño fijo en pantalla (texto blanco sobre negro), con la esquina de arriba a la izquierda en
  /// `origin`.
  private func drawLabel(_ string: String, at origin: CGPoint, hairline: CGFloat, in context: CGContext) {
    let font = NSFont.monospacedDigitSystemFont(ofSize: 12 * hairline, weight: .semibold)
    let text = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: NSColor.white])
    let size = text.size()
    let pad = 6 * hairline
    let box = CGRect(x: origin.x, y: origin.y, width: size.width + pad * 2, height: size.height + pad)
    context.setFillColor(NSColor.black.withAlphaComponent(0.75).cgColor)
    context.addPath(CGPath(roundedRect: box, cornerWidth: 5 * hairline, cornerHeight: 5 * hairline, transform: nil))
    context.fillPath()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    text.draw(at: CGPoint(x: box.minX + pad, y: box.minY + pad / 2))
    NSGraphicsContext.restoreGraphicsState()
  }

  // MARK: - Ratón

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    trackingAreas.forEach(removeTrackingArea)
    addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                                   owner: self))
  }

  override func resetCursorRects() {
    let cursor: NSCursor = switch model.tool {
    case .select: .arrow
    case .text: .iBeam
    default: .crosshair
    }
    addCursorRect(visibleRect, cursor: cursor)
  }

  /// Del ratón a píxeles de la captura entera.
  private func imagePoint(_ event: NSEvent) -> CGPoint {
    let point = convert(event.locationInWindow, from: nil), area = model.shownRect
    return CGPoint(x: point.x * scale + area.minX, y: point.y * scale + area.minY)
  }

  override func mouseMoved(with event: NSEvent) {
    updateHover(imagePoint(event))
  }

  private func updateHover(_ point: CGPoint) {
    model.hoverHex = model.pixels?.hex(x: Int(point.x.rounded(.down)), y: Int(point.y.rounded(.down)))
  }

  override func mouseDown(with event: NSEvent) {
    let point = imagePoint(event)
    dragStart = point
    // Doble clic sobre un texto: se edita, con cualquier herramienta.
    if event.clickCount == 2, let id = model.document.hit(point), case .text(let text, let origin)? =
      model.document.annotation(id)?.shape {
      endTextEditing()
      beginText(at: origin, id: id, text: text)
      return
    }
    // Un clic fuera del texto que se escribe lo termina.
    if editing != nil {
      endTextEditing()
      return
    }
    window?.makeFirstResponder(self)
    switch model.tool {
    case .select:
      let id = model.document.hit(point)
      model.select(id)
      drag = id.map { .moving(id: $0, offset: .zero) }
    case .arrow: drag = .drawing(.arrow(from: point, to: point))
    case .rectangle: drag = .drawing(.rectangle(CGRect(origin: point, size: .zero)))
    case .pen: drag = .drawing(.pen([point]))
    case .highlighter: drag = .drawing(.highlighter([point]))
    case .pixelate: drag = .drawing(.pixelate(CGRect(origin: point, size: .zero)))
    case .text: beginText(at: point, id: nil, text: "")
    case .step:
      let style = model.style
      model.edit { $0.add(.step(at: point), style: style) }
    case .ruler:
      model.ruler = CaptureRuler(from: point, to: point)
      drag = .measuring
    case .crop:
      startCropDrag(at: point)
    }
    needsDisplay = true
  }

  /// Sobre un asa, la ajusta; dentro de un marco ya ajustado, lo mueve; si no, empieza uno nuevo.
  private func startCropDrag(at point: CGPoint) {
    let frame = model.cropFrame ?? model.shownRect
    let reach = 8 * scale / max(model.zoom, 0.05)
    if let handle = CropHandle.all.first(where: {
      let center = $0.point(in: frame)
      return hypot(center.x - point.x, center.y - point.y) <= reach
    }) {
      drag = .cropping(handle: handle, from: frame)
    } else if frame.contains(point), frame != model.document.visibleRect(in: model.imageSize) {
      drag = .cropping(handle: nil, from: frame)
    } else {
      drag = .newCrop
      model.cropFrame = CGRect(origin: point, size: .zero)
    }
  }

  override func mouseDragged(with event: NSEvent) {
    let point = imagePoint(event)
    let box = CGRect(x: min(dragStart.x, point.x), y: min(dragStart.y, point.y), width: abs(point.x - dragStart.x),
                     height: abs(point.y - dragStart.y))
    let full = CGRect(origin: .zero, size: model.imageSize)
    switch drag {
    case .drawing(.arrow(let from, _))?: drag = .drawing(.arrow(from: from, to: point))
    case .drawing(.rectangle)?: drag = .drawing(.rectangle(box))
    case .drawing(.pixelate)?: drag = .drawing(.pixelate(box))
    case .newCrop?: model.cropFrame = box.intersection(full)
    case .cropping(let handle, let from)?:
      let delta = CGVector(dx: point.x - dragStart.x, dy: point.y - dragStart.y)
      if let handle {
        model.cropFrame = handle.resize(from, by: delta).intersection(full)
      } else {
        // Se mueve entero, sin salirse de la captura.
        model.cropFrame = CGRect(x: min(max(from.minX + delta.dx, 0), full.width - from.width),
                                 y: min(max(from.minY + delta.dy, 0), full.height - from.height),
                                 width: from.width, height: from.height)
      }
    case .drawing(.pen(let points))?: drag = .drawing(.pen(points + [point]))
    case .drawing(.highlighter(let points))?: drag = .drawing(.highlighter(points + [point]))
    case .moving(let id, _)?: drag = .moving(id: id, offset: CGVector(dx: point.x - dragStart.x, dy: point.y - dragStart.y))
    case .measuring?: model.ruler?.to = point
    default: break
    }
    updateHover(point)
    needsDisplay = true
  }

  override func mouseUp(with event: NSEvent) {
    let style = model.style
    switch drag {
    case .drawing(let shape)? where !shape.isTooSmall(scale: scale):
      model.edit { $0.add(shape, style: style) }
    case .moving(let id, let offset)?:
      model.edit { $0.move(id, by: offset) }
    case .newCrop?, .cropping?:
      // Un clic sin arrastrar no deja un marco de nada: vuelve a la zona que se ve.
      if let frame = model.cropFrame, min(frame.width, frame.height) < 4 * scale {
        model.cropFrame = model.document.visibleRect(in: model.imageSize)
      }
    default: break
    }
    drag = nil
    needsDisplay = true
  }

  // MARK: - Teclado

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 36 where model.tool == .crop, 76 where model.tool == .crop:  // Intro: recorta
      model.applyCrop()
    case 53 where model.tool == .crop:  // Esc: quita el marco sin recortar
      model.cancelCrop()
    case 53:  // Esc: suelta la elegida o cierra
      if model.document.selection != nil { model.select(nil) } else { onClose?() }
    case 51, 117:  // ⌫ y ⌦
      if let id = model.document.selection { model.edit { $0.delete(id) } }
    case 48:  // Tab: el color bajo el cursor
      if let hex = model.hoverHex { onCopyColor?(hex) }
    default:
      let modifiers = event.modifierFlags.intersection([.command, .control, .option])
      guard modifiers.isEmpty, let tool = AnnotationTool.tool(forKey: event.charactersIgnoringModifiers ?? "") else {
        super.keyDown(with: event)
        return
      }
      model.choose(tool)
    }
    needsDisplay = true
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard window?.firstResponder === self, event.modifierFlags.contains(.command) else {
      return super.performKeyEquivalent(with: event)
    }
    let shift = event.modifierFlags.contains(.shift)
    switch event.charactersIgnoringModifiers?.lowercased() {
    case "z": model.edit { shift ? $0.redo() : $0.undo() }
    case "c": onCopy?()
    case "s": onSave?(shift)
    case "0": onZoom?(.fit)
    case "1": onZoom?(.actual)
    case "+", "=": onZoom?(.zoomIn)
    case "-": onZoom?(.zoomOut)
    case "w": onClose?()
    default: return super.performKeyEquivalent(with: event)
    }
    needsDisplay = true
    return true
  }

  // MARK: - Texto

  /// Un campo de texto encima del lienzo, con la letra y el color con que se dibujará.
  private func beginText(at origin: CGPoint, id: Int?, text: String) {
    let field = NSTextField(string: text)
    field.isBordered = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.usesSingleLineMode = true
    field.cell?.wraps = false
    field.cell?.isScrollable = true
    field.delegate = self
    addSubview(field)
    editing = (field, id, origin)
    if let id { model.select(id) }  // así el color y el grosor de la barra se le aplican
    restyleField()
    window?.makeFirstResponder(field)
    needsDisplay = true
  }

  private func restyleField() {
    guard let (field, id, origin) = editing else { return }
    let style = id.flatMap { model.document.annotation($0)?.style } ?? model.style
    field.font = .boldSystemFont(ofSize: style.width.fontSize)
    field.textColor = NSColor(cgColor: style.color.cgColor)
    field.sizeToFit()
    // El campo deja 2 puntos a la izquierda del texto: así la letra queda donde se dibujará.
    let area = model.shownRect
    field.frame = NSRect(x: (origin.x - area.minX) / scale - 2, y: (origin.y - area.minY) / scale,
                         width: max(field.frame.width + 12, 40), height: field.frame.height)
  }

  /// Termina el texto: el nuevo se añade y el que ya estaba se cambia (vacío, se borra).
  private func endTextEditing() {
    guard let (field, id, origin) = editing else { return }
    editing = nil
    let text = field.stringValue
    let style = model.style
    field.delegate = nil
    field.removeFromSuperview()
    window?.makeFirstResponder(self)
    if let id {
      model.edit { $0.setText(text, of: id) }
    } else if !AnnotationShape.text(text, at: origin).isTooSmall(scale: scale) {
      model.edit { $0.add(.text(text, at: origin), style: style) }
    }
    needsDisplay = true
  }

  func controlTextDidChange(_ notification: Notification) {
    restyleField()
  }

  func controlTextDidEndEditing(_ notification: Notification) {
    endTextEditing()
  }

  /// Intro y Esc terminan el texto.
  func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
    guard selector == #selector(NSResponder.insertNewline(_:)) || selector == #selector(NSResponder.cancelOperation(_:))
    else { return false }
    endTextEditing()
    return true
  }
}
