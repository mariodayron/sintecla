import CoreGraphics
import CoreText
import Foundation

/// Herramientas del editor de capturas (spec «Capturas» §3.1), en el orden de la barra.
public enum AnnotationTool: String, CaseIterable, Sendable {
  case select, arrow, text, rectangle, pen, highlighter, step, ruler

  /// La tecla que la elige en el editor.
  public var key: String {
    switch self {
    case .select: "V"
    case .arrow: "A"
    case .text: "T"
    case .rectangle: "R"
    case .pen: "P"
    case .highlighter: "H"
    case .step: "N"
    case .ruler: "M"
    }
  }

  public var title: String {
    switch self {
    case .select: "Seleccionar"
    case .arrow: "Flecha"
    case .text: "Texto"
    case .rectangle: "Rectángulo"
    case .pen: "Lápiz"
    case .highlighter: "Subrayador"
    case .step: "Pasos"
    case .ruler: "Regla"
    }
  }

  public var symbol: String {
    switch self {
    case .select: "cursorarrow"
    case .arrow: "arrow.up.right"
    case .text: "textformat"
    case .rectangle: "rectangle"
    case .pen: "pencil.tip"
    case .highlighter: "highlighter"
    case .step: "1.circle"
    case .ruler: "ruler"
    }
  }

  /// La herramienta de una tecla, sin distinguir mayúsculas; nil si no es de ninguna.
  public static func tool(forKey key: String) -> AnnotationTool? {
    allCases.first { $0.key == key.uppercased() }
  }
}

/// Los seis colores de la barra. El rojo es el de fábrica; el Subrayador empieza en amarillo.
public enum AnnotationColor: String, CaseIterable, Sendable {
  case red, yellow, green, blue, black, white

  public var name: String {
    switch self {
    case .red: "Rojo"
    case .yellow: "Amarillo"
    case .green: "Verde"
    case .blue: "Azul"
    case .black: "Negro"
    case .white: "Blanco"
    }
  }

  /// En sRGB, de 0 a 255.
  public var rgb: (red: Int, green: Int, blue: Int) {
    switch self {
    case .red: (255, 59, 48)
    case .yellow: (255, 204, 0)
    case .green: (52, 199, 89)
    case .blue: (0, 122, 255)
    case .black: (0, 0, 0)
    case .white: (255, 255, 255)
    }
  }

  public var cgColor: CGColor {
    CGColor(srgbRed: CGFloat(rgb.red) / 255, green: CGFloat(rgb.green) / 255, blue: CGFloat(rgb.blue) / 255, alpha: 1)
  }

  /// El color del número de un paso dibujado con este color.
  public var contrast: AnnotationColor { self == .yellow || self == .white ? .black : .white }
}

/// Los tres grosores. Las medidas van en puntos de pantalla; en la imagen se multiplican por la escala de la captura.
public enum AnnotationWidth: Int, CaseIterable, Sendable {
  case thin, medium, thick

  public var name: String {
    switch self {
    case .thin: "Fino"
    case .medium: "Medio"
    case .thick: "Grueso"
    }
  }

  public var line: CGFloat { [2, 4, 7][rawValue] }
  public var highlighter: CGFloat { [12, 20, 30][rawValue] }
  public var fontSize: CGFloat { [16, 22, 32][rawValue] }
  public var stepRadius: CGFloat { [11, 14, 19][rawValue] }
}

public struct AnnotationStyle: Equatable, Sendable {
  public var color: AnnotationColor
  public var width: AnnotationWidth

  public init(color: AnnotationColor = .red, width: AnnotationWidth = .medium) {
    self.color = color
    self.width = width
  }
}

/// Lo que se dibuja, en píxeles de la imagen con el origen arriba a la izquierda.
public enum AnnotationShape: Equatable, Sendable {
  case arrow(from: CGPoint, to: CGPoint)
  case rectangle(CGRect)
  case pen([CGPoint])
  case highlighter([CGPoint])
  /// `at` es la esquina de arriba a la izquierda del texto.
  case text(String, at: CGPoint)
  /// `at` es el centro del círculo.
  case step(at: CGPoint)

  public func offset(by offset: CGVector) -> AnnotationShape {
    func move(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x + offset.dx, y: point.y + offset.dy) }
    switch self {
    case .arrow(let from, let to): return .arrow(from: move(from), to: move(to))
    case .rectangle(let rect): return .rectangle(rect.offsetBy(dx: offset.dx, dy: offset.dy))
    case .pen(let points): return .pen(points.map(move))
    case .highlighter(let points): return .highlighter(points.map(move))
    case .text(let text, let origin): return .text(text, at: move(origin))
    case .step(let center): return .step(at: move(center))
    }
  }

  /// Un clic sin arrastrar no deja flechas, rectángulos ni trazos: miden menos de 4 puntos.
  public func isTooSmall(scale: CGFloat) -> Bool {
    let minimum = 4 * scale
    switch self {
    case .arrow(let from, let to): return hypot(to.x - from.x, to.y - from.y) < minimum
    case .rectangle(let rect): return max(abs(rect.width), abs(rect.height)) < minimum
    case .pen(let points), .highlighter(let points):
      let box = AnnotationGeometry.box(points)
      return max(box.width, box.height) < minimum
    case .text(let text, _): return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .step: return false
    }
  }
}

public struct Annotation: Equatable, Identifiable, Sendable {
  /// Orden de creación: los pasos se numeran por él.
  public let id: Int
  public var shape: AnnotationShape
  public var style: AnnotationStyle
}

/// Las anotaciones de una captura (spec «Capturas» §3.2 y §4): añadir, elegir, mover, borrar, cambiar el estilo,
/// deshacer y rehacer, numerar los pasos y tocar (hit test). Cada cambio es un paso de deshacer.
public struct AnnotationDocument: Equatable, Sendable {
  /// Píxeles de la imagen por punto de pantalla (2 en una captura Retina).
  public let scale: CGFloat
  /// En orden de creación, que es también el orden de dibujo: la última queda encima.
  public private(set) var annotations: [Annotation] = []
  /// La anotación elegida con Seleccionar. Elegir no es un cambio: no se deshace.
  public private(set) var selection: Int?
  private var nextID = 1
  private var undoStack: [[Annotation]] = []
  private var redoStack: [[Annotation]] = []

  public init(scale: CGFloat = 1) {
    self.scale = scale
  }

  public var canUndo: Bool { !undoStack.isEmpty }
  public var canRedo: Bool { !redoStack.isEmpty }

  public func annotation(_ id: Int) -> Annotation? {
    annotations.first { $0.id == id }
  }

  @discardableResult
  public mutating func add(_ shape: AnnotationShape, style: AnnotationStyle) -> Int {
    let id = nextID
    nextID += 1
    change { $0.append(Annotation(id: id, shape: shape, style: style)) }
    return id
  }

  public mutating func select(_ id: Int?) {
    selection = id.flatMap { annotation($0) == nil ? nil : $0 }
  }

  public mutating func move(_ id: Int, by offset: CGVector) {
    guard offset.dx != 0 || offset.dy != 0 else { return }
    update(id) { $0.shape = $0.shape.offset(by: offset) }
  }

  public mutating func delete(_ id: Int) {
    guard annotation(id) != nil else { return }
    change { $0.removeAll { $0.id == id } }
    if selection == id { selection = nil }
  }

  public mutating func setStyle(_ style: AnnotationStyle, of id: Int) {
    update(id) { $0.style = style }
  }

  /// Termina de editar un texto. Vacío, se borra.
  public mutating func setText(_ text: String, of id: Int) {
    guard case .text(_, let origin)? = annotation(id)?.shape else { return }
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      delete(id)
    } else {
      update(id) { $0.shape = .text(text, at: origin) }
    }
  }

  public mutating func undo() {
    guard let previous = undoStack.popLast() else { return }
    redoStack.append(annotations)
    annotations = previous
    select(selection)
  }

  public mutating func redo() {
    guard let next = redoStack.popLast() else { return }
    undoStack.append(annotations)
    annotations = next
    select(selection)
  }

  /// 1, 2, 3… por orden de creación entre los pasos que quedan; nil si no es un paso.
  public func stepNumber(of id: Int) -> Int? {
    let steps = annotations.filter { if case .step = $0.shape { true } else { false } }
    return steps.firstIndex { $0.id == id }.map { $0 + 1 }
  }

  /// La anotación de más arriba que toca el punto, con un margen de 6 puntos.
  public func hit(_ point: CGPoint) -> Int? {
    annotations.last { AnnotationGeometry.hits($0, point, scale: scale) }?.id
  }

  /// El recuadro que ocupa en la imagen (para marcar la elegida).
  public func bounds(of id: Int) -> CGRect? {
    annotation(id).map { AnnotationGeometry.bounds($0, scale: scale) }
  }

  private mutating func update(_ id: Int, _ body: (inout Annotation) -> Void) {
    guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
    var changed = annotations[index]
    body(&changed)
    guard changed != annotations[index] else { return }
    change { $0[index] = changed }
  }

  private mutating func change(_ body: (inout [Annotation]) -> Void) {
    undoStack.append(annotations)
    redoStack.removeAll()
    body(&annotations)
  }
}

/// La regla (spec «Capturas» §3.2): distancia en píxeles de la imagen. Es una guía, no una anotación.
public struct RulerMeasure: Equatable, Sendable {
  public let total: Int
  public let horizontal: Int
  public let vertical: Int

  public init(from: CGPoint, to: CGPoint) {
    let dx = abs(to.x - from.x), dy = abs(to.y - from.y)
    total = Int(hypot(dx, dy).rounded())
    horizontal = Int(dx.rounded())
    vertical = Int(dy.rounded())
  }

  public var label: String { "\(total) px · ↔ \(horizontal) · ↕ \(vertical)" }
}

/// Medidas compartidas por el dibujo y el hit test, en píxeles de la imagen.
enum AnnotationGeometry {
  static func lineWidth(_ annotation: Annotation, scale: CGFloat) -> CGFloat {
    if case .highlighter = annotation.shape { return annotation.style.width.highlighter * scale }
    return annotation.style.width.line * scale
  }

  static func stepRadius(_ style: AnnotationStyle, scale: CGFloat) -> CGFloat {
    style.width.stepRadius * scale
  }

  /// En puntos, como el campo donde se escribe: a otro tamaño, la letra del sistema cambia de ancho.
  static func textFont(_ style: AnnotationStyle) -> CTFont {
    CTFontCreateUIFontForLanguage(.emphasizedSystem, style.width.fontSize, nil)
      ?? CTFontCreateWithName("Helvetica-Bold" as CFString, style.width.fontSize, nil)
  }

  static func textLine(_ text: String, font: CTFont, color: CGColor) -> CTLine {
    let attributes: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key(kCTFontAttributeName as String): font,
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
    ]
    return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
  }

  /// Recuadro del texto en píxeles de la imagen y su línea base en puntos (desde arriba).
  static func textFrame(_ text: String, at origin: CGPoint, style: AnnotationStyle, scale: CGFloat)
    -> (frame: CGRect, ascent: CGFloat) {
    let line = textLine(text, font: textFont(style), color: style.color.cgColor)
    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
    let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
    return (CGRect(x: origin.x, y: origin.y, width: width * scale, height: (ascent + descent) * scale), ascent)
  }

  static func box(_ points: [CGPoint]) -> CGRect {
    guard let first = points.first else { return .null }
    return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
  }

  static func bounds(_ annotation: Annotation, scale: CGFloat) -> CGRect {
    let half = lineWidth(annotation, scale: scale) / 2
    switch annotation.shape {
    case .arrow(let from, let to):
      let head = arrowHead(lineWidth: lineWidth(annotation, scale: scale), scale: scale)
      return box([from, to]).insetBy(dx: -head / 2, dy: -head / 2)
    case .rectangle(let rect): return rect.standardized.insetBy(dx: -half, dy: -half)
    case .pen(let points), .highlighter(let points): return box(points).insetBy(dx: -half, dy: -half)
    case .text(let text, let origin): return textFrame(text, at: origin, style: annotation.style, scale: scale).frame
    case .step(let center):
      let radius = stepRadius(annotation.style, scale: scale)
      return CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
  }

  static func hits(_ annotation: Annotation, _ point: CGPoint, scale: CGFloat) -> Bool {
    let tolerance = 6 * scale + lineWidth(annotation, scale: scale) / 2
    switch annotation.shape {
    case .arrow(let from, let to):
      return distance(point, from, to) <= tolerance
    case .rectangle(let rect):
      let outer = rect.standardized.insetBy(dx: -tolerance, dy: -tolerance)
      let inner = rect.standardized.insetBy(dx: tolerance, dy: tolerance)
      return outer.contains(point) && (inner.isNull || !inner.contains(point))
    case .pen(let points), .highlighter(let points):
      guard let first = points.first else { return false }
      if points.count == 1 { return hypot(point.x - first.x, point.y - first.y) <= tolerance }
      return zip(points, points.dropFirst()).contains { distance(point, $0, $1) <= tolerance }
    case .text, .step:
      return bounds(annotation, scale: scale).insetBy(dx: -2 * scale, dy: -2 * scale).contains(point)
    }
  }

  /// Largo de la punta de una flecha.
  static func arrowHead(lineWidth: CGFloat, scale: CGFloat) -> CGFloat {
    lineWidth * 3 + 8 * scale
  }

  /// Distancia de un punto al segmento a–b.
  static func distance(_ point: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = b.x - a.x, dy = b.y - a.y
    let length = dx * dx + dy * dy
    guard length > 0 else { return hypot(point.x - a.x, point.y - a.y) }
    let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / length))
    return hypot(point.x - (a.x + t * dx), point.y - (a.y + t * dy))
  }
}
