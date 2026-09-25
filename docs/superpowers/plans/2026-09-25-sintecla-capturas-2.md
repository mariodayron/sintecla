# Sintecla — El editor de capturas y la 0.10.0 (plan de Capturas 2) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tras ⇧⌘3 o ⇧⌘4 se abre un editor por captura para anotarla, y la captura anotada está siempre en el portapapeles, sin pulsar ⌘C:
- herramientas: flecha, texto, rectángulo, lápiz, subrayador, pasos numerados, regla y color bajo el cursor;
- con la 0.10.0 se entregan los módulos y las capturas.

**Architecture:**
- **En el núcleo (`SinteclaCore`), puro y con tests:**
  - `AnnotationDocument`: las anotaciones en píxeles de la imagen, con el origen arriba a la izquierda. Añadir, elegir, mover, borrar, cambiar el estilo, deshacer y rehacer, numerar los pasos, tocar (hit test) y la regla (`RulerMeasure`);
  - `AnnotationRenderer`: dibuja las anotaciones en un `CGContext` y exporta la captura anotada a tamaño real (PNG);
  - `ImagePixels`: el `#RRGGBB` de un píxel.
- **En la app:**
  - `CaptureCanvasView` (el lienzo, un `NSView`) con `CaptureEditorModel` (`@Observable`): el ratón y el teclado de cada herramienta;
  - `CaptureEditor` (la ventana):
    - la barra, en SwiftUI;
    - el zoom, con un `NSScrollView`;
    - la copia automática medio segundo después de cada cambio, fuera del hilo principal.
  - `CaptureController` abre un editor después de copiar la captura.
  - `DockPresence` deja Sintecla en el Dock mientras haya ventanas abiertas.

**Tech Stack:** Lo de siempre:
- Swift 6.3 de las Command Line Tools, en modo de lenguaje 5;
- SwiftPM, Swift Testing, SwiftUI y AppKit;
- además, CoreGraphics, CoreText e ImageIO en el núcleo.

**Especificación:** `docs/superpowers/specs/2026-09-25-capturas-design.md` (§3, §4, §5 y §8, plan 2).

**Punto de partida:** la rama `modulos`, con el plan de Capturas 1 hecho y aceptado:

```bash
git checkout modulos
```

## Global Constraints

- **Todo lo de antes sigue vigente:**
  - macOS 26.0 o superior, Apple Silicon.
  - Sin Xcode ni dependencias externas; todos los targets en `.swiftLanguageMode(.v5)`.
  - Tests con `swift run sintecla-tests` (**nunca `swift test`**).
  - Textos visibles en español.
  - La release compila sin avisos.
- **Coordenadas:** en píxeles de la imagen, con el origen arriba a la izquierda. Los grosores y las letras van en puntos, multiplicados por la escala de la captura (2 en Retina).
- **Herramientas y sus teclas:**

  | Herramienta | Tecla |
  |---|---|
  | Seleccionar | V |
  | Flecha (la elegida al abrir) | A |
  | Texto | T |
  | Rectángulo | R |
  | Lápiz | P |
  | Subrayador | H |
  | Pasos | N |
  | Regla | M |

- **Estilo:**
  - seis colores: rojo (de fábrica), amarillo (de fábrica en el Subrayador), verde, azul, negro y blanco;
  - tres grosores: fino, medio (de fábrica) y grueso.
- **Portapapeles:**
  - la captura se copia al capturar;
  - tras cada cambio se vuelve a copiar, 0,5 s después del último, a tamaño real y sin aviso;
  - ⌘C y Copiar copian al momento, con «Captura copiada»;
  - al cerrar, se copia el último cambio si aún no se había copiado;
  - Tab copia el color bajo el cursor, con «Color copiado: #RRGGBB».
- **La regla** no sale en la imagen copiada. Se borra al empezar otra medida o al cambiar de herramienta.
- **Teclado del editor:**
  - ⌘Z y ⇧⌘Z deshacen y rehacen; ⌫ borra la elegida;
  - Esc termina el texto que se escribe; si no, suelta la elegida; si no, cierra;
  - ⌘0 ajusta, ⌘1 pone el 100 %, ⌘+ y ⌘− acercan y alejan, y también se puede pellizcar;
  - ⌘W cierra.
- **Versión:** 0.10.0 (build 11).
- **Commits:** en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código de este plan se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `modulos`: compiló, pasó los tests en cada tarea y el árbol final quedó idéntico al del prototipo.

- **280 tests** (50 suites) en verde: los 263 de antes y 17 nuevos. La release compila sin avisos.
- **La ventana del editor, dibujada fuera de pantalla** con una captura de prueba de 2560 × 1440:
  - la flecha, el rectángulo, el texto, los pasos, el subrayador, el lápiz, el marco de la elegida y la regla con su medida se ven bien;
  - la barra mide 871 puntos, así que la ventana tiene un mínimo de 880.
- **La exportación** de esa captura con 8 anotaciones tarda 33 ms. Sale sin la regla y sin el marco de la elegida.
- **El texto dibujado cae donde estaba el campo** en el que se escribe, con un punto de diferencia como mucho, en los tres grosores.
- **Sin probar en la app** (lo comprueba la aceptación de la Tarea 6):
  - que la ventana pase delante desde un atajo global, con la activación cooperativa de macOS;
  - el ratón, el teclado y el pellizco en la ventana de verdad.

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| Un `#require` dentro de otro no compila («recursive expansion of macro») | Los tests usan el ayudante `exported(_:gray:)` |
| La letra del sistema cambia de ancho con el tamaño. Dibujada a 32 px (16 pt × 2), CoreText la sacaba más ancha que el campo donde se escribe, y al terminar el texto saltaba | El texto se mide y se dibuja en puntos y luego se escala (`AnnotationGeometry.textFont(_:)`, sin escala) |
| Un `CGContext` de mapa de bits va de abajo arriba | `render` dibuja la captura y después le da la vuelta al contexto. Un test mira un píxel de arriba |
| Pintar y comprimir una captura Retina en el hilo principal frenaría el editor | `CaptureEditor.copy` exporta en un `Task.detached`. Un contador evita que una copia vieja pise una nueva |
| Tras un clic en la barra SwiftUI, el teclado podría quedarse fuera del lienzo | El lienzo recupera el foco con cada cambio del modelo, salvo mientras se escribe un texto |
| Cerrar la ventana justo después de un cambio perdería la última copia | `windowWillClose` copia si quedaba una pendiente. La tarea de copia retiene el editor hasta terminar |
| Al cerrar la ventana principal, Sintecla salía del Dock aunque hubiera un editor abierto | `DockPresence` cuenta las ventanas abiertas |

**Decisiones de este plan que la spec no fijaba:**
- El editor abre con la **Flecha** elegida.
- **Tab** también avisa en la pastilla: «Color copiado: #151515».
- Con un editor abierto, Sintecla sale en el **Dock y con ⌘Tab**, como con la ventana principal.
- Un **clic sin arrastrar** (menos de 4 puntos) no deja flechas, rectángulos ni trazos.
- El editor abre al **100 %** si la captura cabe en el 85 % de la pantalla; si no, ajustada a la ventana.
- **El dibujo y la exportación van en el núcleo** (`AnnotationRenderer`) y no en la ventana, para poder probarlos.
- Con el **zoom por encima del 150 %** la captura se ve sin suavizar: se ven los píxeles.

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/AnnotationDocument.swift`, `Sources/SinteclaCoreTests/AnnotationDocumentTests.swift` | Herramientas, colores, grosores, anotaciones, deshacer, pasos, hit test y regla | 1 |
| `Sources/SinteclaCore/AnnotationRenderer.swift`, `Sources/SinteclaCore/CaptureNotice.swift`, `Sources/SinteclaCoreTests/AnnotationRendererTests.swift` | Dibujo, exportación a PNG, color de un píxel y el aviso del color | 2 |
| `Sources/Sintecla/CaptureCanvas.swift` | El estado del editor y el lienzo: ratón, teclado, texto y regla | 3 |
| `Sources/Sintecla/CaptureEditorWindow.swift`, `Sources/Sintecla/Windows.swift`, `Sources/Sintecla/MainWindow.swift`, `Sources/Sintecla/ScreenCapture.swift`, `Sources/Sintecla/CaptureController.swift`, `Sources/Sintecla/CapturesPage.swift` | La ventana, la barra, el zoom, la copia automática, el Dock y abrir el editor tras capturar | 4 |
| `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`, `Sources/SinteclaCoreTests/SmokeTests.swift`, `README.md`, `docs/superpowers/specs/2026-09-23-sintecla-design.md` | La 0.10.0 y su documentación | 5 |

---

### Task 1: Las anotaciones en el núcleo

**Files:**
- Create: `Sources/SinteclaCore/AnnotationDocument.swift`
- Test: `Sources/SinteclaCoreTests/AnnotationDocumentTests.swift`

**Interfaces:**
- Consumes: Nada de otras tareas (CoreGraphics y CoreText).
- Produces: `AnnotationTool` (`.select`, `.arrow`, `.text`, `.rectangle`, `.pen`, `.highlighter`, `.step`, `.ruler`; `key`, `title`, `symbol`, `static tool(forKey:) -> AnnotationTool?`); `AnnotationColor` (`name`, `rgb`, `cgColor`, `contrast`); `AnnotationWidth` (`name`, `line`, `highlighter`, `fontSize`, `stepRadius`); `AnnotationStyle(color:width:)`; `AnnotationShape` (`.arrow(from:to:)`, `.rectangle(CGRect)`, `.pen([CGPoint])`, `.highlighter([CGPoint])`, `.text(String, at:)`, `.step(at:)`; `offset(by:)`, `isTooSmall(scale:)`); `Annotation` (`id`, `shape`, `style`); `AnnotationDocument(scale:)` con `annotations`, `selection`, `add(_:style:) -> Int`, `select(_:)`, `move(_:by:)`, `delete(_:)`, `setStyle(_:of:)`, `setText(_:of:)`, `undo()`, `redo()`, `stepNumber(of:)`, `hit(_:) -> Int?`, `bounds(of:) -> CGRect?`; `RulerMeasure(from:to:)` con `total`, `horizontal`, `vertical` y `label`; `AnnotationGeometry` (interno: grosores, letra, recuadros, hit test).

Todo en píxeles de la imagen, con el origen arriba a la izquierda (como se ve la captura). Cada cambio es un paso de deshacer; elegir no lo es.

- [ ] **Step 1: Tests: añadir, mover, borrar, deshacer, pasos, hit test, regla y estilo**

Crear `Sources/SinteclaCoreTests/AnnotationDocumentTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import SinteclaCore

@Suite struct AnnotationDocumentTests {
  private let red = AnnotationStyle()
  private func arrow(_ x: CGFloat = 100) -> AnnotationShape {
    .arrow(from: CGPoint(x: x, y: 100), to: CGPoint(x: x + 200, y: 100))
  }

  @Test func addMoveAndDelete() {
    var document = AnnotationDocument(scale: 2)
    let id = document.add(arrow(), style: red)
    document.move(id, by: CGVector(dx: 10, dy: 5))
    #expect(document.annotation(id)?.shape == .arrow(from: CGPoint(x: 110, y: 105), to: CGPoint(x: 310, y: 105)))
    document.select(id)
    document.delete(id)
    #expect(document.annotations.isEmpty)
    #expect(document.selection == nil)
  }

  @Test func undoAndRedoSeveralInARow() {
    var document = AnnotationDocument()
    let first = document.add(arrow(0), style: red)
    document.add(arrow(300), style: red)
    document.move(first, by: CGVector(dx: 0, dy: 50))
    document.undo()
    document.undo()
    #expect(document.annotations.map(\.id) == [first])
    #expect(document.annotation(first)?.shape == arrow(0))
    document.redo()
    #expect(document.annotations.count == 2)
    #expect(document.canRedo)
    document.add(.step(at: .zero), style: red)  // un cambio nuevo borra lo que se podía rehacer
    #expect(!document.canRedo)
    document.undo()
    document.undo()
    document.undo()
    #expect(document.annotations.isEmpty)
    #expect(!document.canUndo)
  }

  @Test func undoDropsASelectionThatNoLongerExists() {
    var document = AnnotationDocument()
    let id = document.add(arrow(), style: red)
    document.select(id)
    document.undo()
    #expect(document.selection == nil)
  }

  @Test func stepsRenumberWhenOneIsDeleted() {
    var document = AnnotationDocument()
    let one = document.add(.step(at: CGPoint(x: 10, y: 10)), style: red)
    document.add(arrow(), style: red)
    let two = document.add(.step(at: CGPoint(x: 50, y: 10)), style: red)
    let three = document.add(.step(at: CGPoint(x: 90, y: 10)), style: red)
    #expect([one, two, three].map { document.stepNumber(of: $0) } == [1, 2, 3])
    document.delete(two)
    #expect(document.stepNumber(of: three) == 2)
    document.undo()
    #expect(document.stepNumber(of: two) == 2)
    #expect(document.stepNumber(of: three) == 3)
    #expect(document.stepNumber(of: 2) == nil)  // la flecha no es un paso
  }

  @Test func arrowIsHitNearItsLineOnly() {
    var document = AnnotationDocument(scale: 2)
    let id = document.add(arrow(), style: red)
    #expect(document.hit(CGPoint(x: 200, y: 110)) == id)  // a 10 px: el margen es 6 pt × 2 más medio trazo (4 px)
    #expect(document.hit(CGPoint(x: 200, y: 150)) == nil)
    #expect(document.hit(CGPoint(x: 330, y: 100)) == nil)  // más allá de la punta
  }

  @Test func topmostAnnotationWinsAndRectanglesAreHitOnTheBorder() {
    var document = AnnotationDocument()
    document.add(arrow(), style: red)
    let box = document.add(.rectangle(CGRect(x: 150, y: 50, width: 100, height: 100)), style: red)
    #expect(document.hit(CGPoint(x: 150, y: 100)) == box)  // borde izquierdo, encima de la flecha
    #expect(document.hit(CGPoint(x: 200, y: 75)) == nil)  // dentro, lejos del borde
  }

  @Test func changingTheStyleOfTheSelectedOneCanBeUndone() {
    var document = AnnotationDocument()
    let id = document.add(arrow(), style: red)
    document.select(id)
    document.setStyle(AnnotationStyle(color: .blue, width: .thick), of: id)
    #expect(document.annotation(id)?.style == AnnotationStyle(color: .blue, width: .thick))
    document.undo()
    #expect(document.annotation(id)?.style == red)
    #expect(document.selection == id)
  }

  @Test func textIsEditedAndEmptyTextIsDeleted() {
    var document = AnnotationDocument()
    let id = document.add(.text("Hola", at: CGPoint(x: 5, y: 5)), style: red)
    document.setText("Hola", of: id)
    document.undo()  // sin cambios no hay paso de deshacer: se deshace el añadido
    #expect(document.annotations.isEmpty)
    document.redo()
    document.setText("Adiós", of: id)
    #expect(document.annotation(id)?.shape == .text("Adiós", at: CGPoint(x: 5, y: 5)))
    document.setText("  ", of: id)
    #expect(document.annotation(id) == nil)
  }

  @Test func rulerMeasuresTotalHorizontalAndVertical() {
    let measure = RulerMeasure(from: CGPoint(x: 10, y: 410), to: CGPoint(x: 310, y: 10))
    #expect(measure == RulerMeasure(from: CGPoint(x: 310, y: 10), to: CGPoint(x: 10, y: 410)))
    #expect([measure.total, measure.horizontal, measure.vertical] == [500, 300, 400])
    #expect(measure.label == "500 px · ↔ 300 · ↕ 400")
  }

  @Test func clicksWithoutDraggingLeaveNothing() {
    #expect(AnnotationShape.arrow(from: .zero, to: CGPoint(x: 5, y: 0)).isTooSmall(scale: 2))
    #expect(!AnnotationShape.arrow(from: .zero, to: CGPoint(x: 9, y: 0)).isTooSmall(scale: 2))
    #expect(AnnotationShape.pen([CGPoint(x: 1, y: 1)]).isTooSmall(scale: 1))
    #expect(!AnnotationShape.rectangle(CGRect(x: 0, y: 0, width: -30, height: 1)).isTooSmall(scale: 2))
    #expect(!AnnotationShape.step(at: .zero).isTooSmall(scale: 2))
  }

  @Test func toolsKeysAndColors() {
    #expect(AnnotationTool.allCases.map(\.key).joined() == "VATRPHNM")
    #expect(AnnotationTool.tool(forKey: "a") == .arrow)
    #expect(AnnotationTool.tool(forKey: "M") == .ruler)
    #expect(AnnotationTool.tool(forKey: "x") == nil)
    #expect(AnnotationColor.allCases.map(\.name) == ["Rojo", "Amarillo", "Verde", "Azul", "Negro", "Blanco"])
    #expect(AnnotationColor.yellow.contrast == .black)
    #expect(AnnotationColor.red.contrast == .white)
    #expect(AnnotationStyle() == AnnotationStyle(color: .red, width: .medium))
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find 'AnnotationStyle' in scope`.

- [ ] **Step 3: `AnnotationDocument` y sus tipos**

Crear `Sources/SinteclaCore/AnnotationDocument.swift`:

```swift
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
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 274 tests in 49 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/AnnotationDocument.swift Sources/SinteclaCoreTests/AnnotationDocumentTests.swift
git commit -m 'feat: anotaciones del editor de capturas en el núcleo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: Dibujo, exportación y color de un píxel

**Files:**
- Create: `Sources/SinteclaCore/AnnotationRenderer.swift`
- Modify: `Sources/SinteclaCore/CaptureNotice.swift` (`color(_:)`)
- Test: `Sources/SinteclaCoreTests/AnnotationRendererTests.swift`

**Interfaces:**
- Consumes: `AnnotationDocument`, `AnnotationGeometry` y los tipos de la Tarea 1; `TextRecognizer.recognize(_:)` (plan de Capturas 1) en un test.
- Produces: `AnnotationRenderer.draw(_ document:in:hiding:)`, `draw(_ annotation:number:scale:in:)`, `render(_ image: CGImage, _ document:) -> CGImage?`, `png(_:) -> Data?`; `ImagePixels(_ image:)` con `width`, `height` y `hex(x:y:) -> String?`; `CaptureNotice.color(_:)`.

El dibujo va en el núcleo para poder probarlo sin ventana: la exportación se lee píxel a píxel y el texto dibujado se comprueba con el OCR de Vision.

- [ ] **Step 1: Tests: exportación, PNG, subrayador, texto al derecho, pasos y colores**

Crear `Sources/SinteclaCoreTests/AnnotationRendererTests.swift`:

```swift
import CoreGraphics
import ImageIO
import Testing
@testable import SinteclaCore

@Suite struct AnnotationRendererTests {
  /// Una captura en sRGB de un solo color.
  static func blank(width: Int = 400, height: Int = 200, gray: CGFloat = 1) -> CGImage? {
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.setFillColor(CGColor(srgbRed: gray, green: gray, blue: gray, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
  }

  /// La captura anotada, leída píxel a píxel.
  private func exported(_ document: AnnotationDocument, gray: CGFloat = 1) throws -> ImagePixels {
    let image = try #require(Self.blank(gray: gray))
    let rendered = try #require(AnnotationRenderer.render(image, document))
    return try #require(ImagePixels(rendered))
  }

  @Test func exportKeepsThePixelsAndDrawsFromTheTop() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.rectangle(CGRect(x: 50, y: 20, width: 200, height: 40)), style: AnnotationStyle(width: .thick))
    let pixels = try exported(document)
    #expect(pixels.width == 400 && pixels.height == 200)
    #expect(pixels.hex(x: 150, y: 20) == "#FF3B30")  // borde de arriba, a 20 px del borde superior
    #expect(pixels.hex(x: 50, y: 40) == "#FF3B30")
    #expect(pixels.hex(x: 150, y: 40) == "#FFFFFF")  // dentro
    #expect(pixels.hex(x: 150, y: 180) == "#FFFFFF")  // si se dibujara al revés, estaría aquí
  }

  @Test func pngHasTheSizeOfTheCapture() throws {
    let image = try #require(Self.blank(width: 123, height: 45))
    let rendered = try #require(AnnotationRenderer.render(image, AnnotationDocument()))
    let png = try #require(AnnotationRenderer.png(rendered))
    let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
    let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(decoded.width == 123 && decoded.height == 45)
  }

  @Test func highlighterLetsWhatIsBelowShowThrough() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.highlighter([CGPoint(x: 20, y: 100), CGPoint(x: 380, y: 100)]), style: AnnotationStyle(color: .yellow))
    let white = try exported(document), black = try exported(document, gray: 0)
    let hex = try #require(white.hex(x: 200, y: 100))
    let blue = try #require(Int(hex.suffix(2), radix: 16))
    #expect((60...220).contains(blue))  // ni blanco (FF) ni amarillo lleno (00)
    #expect(black.hex(x: 200, y: 100) == "#000000")  // el texto negro sigue negro
  }

  @Test func textIsDrawnTheRightWayUp() async throws {
    var document = AnnotationDocument(scale: 2)
    document.add(.text("Hola mundo", at: CGPoint(x: 40, y: 60)), style: AnnotationStyle(color: .black, width: .thick))
    let blank = try #require(Self.blank(width: 900, height: 240))
    let image = try #require(AnnotationRenderer.render(blank, document))
    guard case .text(let text) = try await TextRecognizer.recognize(image) else {
      Issue.record("el OCR no lee el texto dibujado")
      return
    }
    #expect(text.contains("Hola mundo"))
  }

  @Test func stepIsACircleOfItsColor() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.step(at: CGPoint(x: 100, y: 100)), style: AnnotationStyle(color: .blue))
    let pixels = try exported(document)
    #expect(pixels.hex(x: 100 - 11, y: 100) == "#007AFF")  // radio medio: 14
    #expect(pixels.hex(x: 100 - 20, y: 100) == "#FFFFFF")
  }

  @Test func pixelColorsAsHex() throws {
    let context = try #require(CGContext(data: nil, width: 2, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(srgbRed: 0x15 / 255, green: 0x15 / 255, blue: 0x15 / 255, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    context.setFillColor(CGColor(srgbRed: 1, green: 0x80 / 255, blue: 0, alpha: 1))
    context.fill(CGRect(x: 1, y: 0, width: 1, height: 1))
    let image = try #require(context.makeImage())
    let pixels = try #require(ImagePixels(image))
    #expect(pixels.hex(x: 0, y: 0) == "#151515")
    #expect(pixels.hex(x: 1, y: 0) == "#FF8000")
    #expect(pixels.hex(x: 2, y: 0) == nil)
    #expect(pixels.hex(x: 0, y: -1) == nil)
    #expect(CaptureNotice.color("#151515") == "Color copiado: #151515")
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find type 'ImagePixels' in scope`.

- [ ] **Step 3: `AnnotationRenderer` e `ImagePixels`**

Crear `Sources/SinteclaCore/AnnotationRenderer.swift`:

```swift
import CoreGraphics
import CoreText
import Foundation
import ImageIO

/// Dibuja las anotaciones del editor de capturas y exporta la captura anotada a tamaño real (spec «Capturas» §3.3).
public enum AnnotationRenderer {
  /// En un contexto en píxeles de la imagen con el origen arriba a la izquierda (y hacia abajo). `hiding`: la que se
  /// está escribiendo, que dibuja el campo de texto.
  public static func draw(_ document: AnnotationDocument, in context: CGContext, hiding hidden: Int? = nil) {
    for annotation in document.annotations where annotation.id != hidden {
      draw(annotation, number: document.stepNumber(of: annotation.id), scale: document.scale, in: context)
    }
  }

  public static func draw(_ annotation: Annotation, number: Int?, scale: CGFloat, in context: CGContext) {
    context.saveGState()
    defer { context.restoreGState() }
    let color = annotation.style.color.cgColor
    let width = AnnotationGeometry.lineWidth(annotation, scale: scale)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineWidth(width)
    context.setStrokeColor(color)
    context.setFillColor(color)
    switch annotation.shape {
    case .arrow(let from, let to):
      drawArrow(from: from, to: to, width: width, scale: scale, in: context)
    case .rectangle(let rect):
      context.stroke(rect.standardized)
    case .pen(let points):
      stroke(points, in: context)
    case .highlighter(let points):
      // Semitransparente y multiplicado: lo de debajo se sigue leyendo.
      context.setBlendMode(.multiply)
      context.setStrokeColor(color.copy(alpha: 0.45) ?? color)
      stroke(points, in: context)
    case .text(let text, let origin):
      let (_, ascent) = AnnotationGeometry.textFrame(text, at: origin, style: annotation.style, scale: scale)
      let line = AnnotationGeometry.textLine(text, font: AnnotationGeometry.textFont(annotation.style), color: color)
      context.translateBy(x: origin.x, y: origin.y)
      context.scaleBy(x: scale, y: scale)
      context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
      context.textPosition = CGPoint(x: 0, y: ascent)
      CTLineDraw(line, context)
    case .step(let center):
      let radius = AnnotationGeometry.stepRadius(annotation.style, scale: scale)
      context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
      guard let number else { return }
      let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, radius * 1.15, nil)
        ?? CTFontCreateWithName("Helvetica-Bold" as CFString, radius * 1.15, nil)
      let line = AnnotationGeometry.textLine(String(number), font: font, color: annotation.style.color.contrast.cgColor)
      let glyphs = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
      context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
      context.textPosition = CGPoint(x: center.x - glyphs.midX, y: center.y + glyphs.midY)
      CTLineDraw(line, context)
    }
  }

  /// La captura con sus anotaciones, con los píxeles de la captura y su espacio de color.
  public static func render(_ image: CGImage, _ document: AnnotationDocument) -> CGImage? {
    let width = image.width, height = image.height
    let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    draw(document, in: context)
    return context.makeImage()
  }

  public static func png(_ image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination) ? data as Data : nil
  }

  private static func stroke(_ points: [CGPoint], in context: CGContext) {
    guard let first = points.first else { return }
    context.move(to: first)
    // Un solo punto: un trazo de largo cero, que con la punta redonda es un círculo.
    points.count == 1 ? context.addLine(to: first) : context.addLines(between: points)
    context.strokePath()
  }

  private static func drawArrow(from: CGPoint, to: CGPoint, width: CGFloat, scale: CGFloat, in context: CGContext) {
    let dx = to.x - from.x, dy = to.y - from.y
    let length = hypot(dx, dy)
    guard length > 0 else { return }
    let head = min(length, AnnotationGeometry.arrowHead(lineWidth: width, scale: scale))
    let ux = dx / length, uy = dy / length
    let base = CGPoint(x: to.x - ux * head, y: to.y - uy * head)
    // La línea entra un poco en la punta para que no quede hueco.
    context.move(to: from)
    context.addLine(to: CGPoint(x: base.x + ux * head * 0.3, y: base.y + uy * head * 0.3))
    context.strokePath()
    let half = head * 0.55
    context.move(to: to)
    context.addLine(to: CGPoint(x: base.x - uy * half, y: base.y + ux * half))
    context.addLine(to: CGPoint(x: base.x + uy * half, y: base.y - ux * half))
    context.closePath()
    context.fillPath()
  }
}

/// Los colores de una captura, en sRGB, para el color bajo el cursor (spec «Capturas» §3.1).
public struct ImagePixels {
  public let width: Int
  public let height: Int
  private let bytes: [UInt8]

  public init?(_ image: CGImage) {
    let width = image.width, height = image.height
    guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
      guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: space,
                                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else { return nil }
    self.width = width
    self.height = height
    self.bytes = bytes
  }

  /// `#RRGGBB` del píxel (x, y), con el origen arriba a la izquierda; nil fuera de la imagen.
  public func hex(x: Int, y: Int) -> String? {
    guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
    let index = (y * width + x) * 4
    return String(format: "#%02X%02X%02X", bytes[index], bytes[index + 1], bytes[index + 2])
  }
}
```

- [ ] **Step 4: El aviso del color**

En `Sources/SinteclaCore/CaptureNotice.swift`, cambiar:

```swift
  public static func codes(_ codes: [RecognizedCode]) -> String {
```

por:

```swift
  /// Tab en el editor: el color bajo el cursor.
  public static func color(_ hex: String) -> String { "Color copiado: \(hex)" }

  public static func codes(_ codes: [RecognizedCode]) -> String {
```

- [ ] **Step 5: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 280 tests in 50 suites passed`.

- [ ] **Step 6: Commit**

```bash
git add Sources/SinteclaCore/AnnotationRenderer.swift Sources/SinteclaCore/CaptureNotice.swift Sources/SinteclaCoreTests/AnnotationRendererTests.swift
git commit -m 'feat: dibujo y exportación de la captura anotada

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: El lienzo del editor

**Files:**
- Create: `Sources/Sintecla/CaptureCanvas.swift`

**Interfaces:**
- Consumes: Las Tareas 1 y 2.
- Produces: `CaptureRuler(from:to:)` con `measure`; `CaptureEditorModel(image:scale:)` (`@Observable`) con `image`, `pixels`, `document`, `tool`, `color`, `highlighterColor`, `width`, `zoom`, `hoverHex`, `ruler`, `onChange`, `pixelSize`, `style`, `selected`, `shownStyle`, `choose(_: AnnotationTool)`, `choose(_: AnnotationColor)`, `choose(_: AnnotationWidth)`, `select(_:)`, `edit(_:)`; `CaptureZoom` (`.fit`, `.actual`, `.zoomIn`, `.zoomOut`); `CaptureCanvasView(model:)` con `onCopy`, `onCopyColor`, `onZoom` y `onClose`.

Aún no lo usa nadie: la ventana llega en la Tarea 4. Todo cambio de las anotaciones pasa por `CaptureEditorModel.edit`, que avisa con `onChange` (para la copia automática). Lo que se arrastra (un trazo nuevo o la elegida al moverla) se dibuja sobre una copia del documento y solo entra en él al soltar: así cada gesto es un paso de deshacer.

- [ ] **Step 1: El estado del editor y el lienzo**

Crear `Sources/Sintecla/CaptureCanvas.swift`:

```swift
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
  /// Cada cambio de las anotaciones: el editor vuelve a copiar la captura.
  @ObservationIgnored var onChange: (() -> Void)?

  init(image: CGImage, scale: CGFloat) {
    self.image = image
    pixels = ImagePixels(image)
    document = AnnotationDocument(scale: scale)
  }

  var pixelSize: String { "\(image.width) × \(image.height)" }

  /// El estilo de lo siguiente que se dibuje.
  var style: AnnotationStyle {
    AnnotationStyle(color: tool == .highlighter ? highlighterColor : color, width: width)
  }

  var selected: Annotation? { document.selection.flatMap { document.annotation($0) } }

  /// Lo que marca la barra: el estilo de la elegida o el de la herramienta.
  var shownStyle: AnnotationStyle { selected?.style ?? style }

  func choose(_ tool: AnnotationTool) {
    self.tool = tool
    ruler = nil
    if tool != .select { document.select(nil) }
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

  /// Todo cambio de las anotaciones pasa por aquí.
  func edit(_ change: (inout AnnotationDocument) -> Void) {
    let before = document.annotations
    change(&document)
    if document.annotations != before { onChange?() }
  }
}

/// Zoom del editor: ⌘0, ⌘1, ⌘+ y ⌘−.
enum CaptureZoom {
  case fit, actual, zoomIn, zoomOut
}

/// El lienzo del editor: la captura y sus anotaciones, con el ratón y el teclado de cada herramienta (spec «Capturas»
/// §3.2). Mide en puntos lo que la captura en píxeles: con el zoom al 100 %, un píxel por píxel de la pantalla.
@MainActor
final class CaptureCanvasView: NSView, NSTextFieldDelegate {
  let model: CaptureEditorModel
  var onCopy: (() -> Void)?
  var onCopyColor: ((String) -> Void)?
  var onZoom: ((CaptureZoom) -> Void)?
  var onClose: (() -> Void)?

  private enum Drag {
    case drawing(AnnotationShape)
    case moving(id: Int, offset: CGVector)
    case measuring
  }

  private var drag: Drag?
  private var dragStart = CGPoint.zero
  /// El texto que se escribe: nuevo (`id` nil) o uno que ya estaba.
  private var editing: (field: NSTextField, id: Int?, origin: CGPoint)?
  private var scale: CGFloat { model.document.scale }

  init(model: CaptureEditorModel) {
    self.model = model
    let scale = model.document.scale
    super.init(frame: NSRect(x: 0, y: 0, width: CGFloat(model.image.width) / scale,
                             height: CGFloat(model.image.height) / scale))
    observe()
  }

  required init?(coder: NSCoder) { nil }

  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  /// Cualquier cambio del modelo (también desde la barra) se ve en el lienzo.
  private func observe() {
    withObservationTracking {
      _ = (model.document, model.tool, model.ruler, model.zoom, model.color, model.highlighterColor, model.width)
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.needsDisplay = true
        self.window?.invalidateCursorRects(for: self)
        self.restyleField()
        // Tras un clic en la barra, el teclado vuelve al lienzo (salvo si se está escribiendo un texto).
        if self.editing == nil, self.window?.firstResponder !== self { self.window?.makeFirstResponder(self) }
        self.observe()
      }
    }
  }

  // MARK: - Dibujo

  override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.saveGState()
    // El contexto va de arriba abajo y la imagen se dibuja de abajo arriba: se le da la vuelta solo a ella.
    context.translateBy(x: 0, y: bounds.height)
    context.scaleBy(x: 1, y: -1)
    context.interpolationQuality = model.zoom > 1.5 ? .none : .high
    context.draw(model.image, in: bounds)
    context.restoreGState()

    context.saveGState()
    context.scaleBy(x: 1 / scale, y: 1 / scale)
    let shown = shownDocument
    AnnotationRenderer.draw(shown, in: context, hiding: editing?.id)
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
    // La medida, en una etiqueta de tamaño fijo en pantalla junto al final de la regla.
    let font = NSFont.monospacedDigitSystemFont(ofSize: 12 * hairline, weight: .semibold)
    let text = NSAttributedString(string: ruler.measure.label,
                                  attributes: [.font: font, .foregroundColor: NSColor.white])
    let size = text.size()
    let pad = 6 * hairline
    let box = CGRect(x: ruler.to.x + 10 * hairline, y: ruler.to.y + 10 * hairline, width: size.width + pad * 2,
                     height: size.height + pad)
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

  /// Del ratón a píxeles de la imagen.
  private func imagePoint(_ event: NSEvent) -> CGPoint {
    let point = convert(event.locationInWindow, from: nil)
    return CGPoint(x: point.x * scale, y: point.y * scale)
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
    case .text: beginText(at: point, id: nil, text: "")
    case .step:
      let style = model.style
      model.edit { $0.add(.step(at: point), style: style) }
    case .ruler:
      model.ruler = CaptureRuler(from: point, to: point)
      drag = .measuring
    }
    needsDisplay = true
  }

  override func mouseDragged(with event: NSEvent) {
    let point = imagePoint(event)
    switch drag {
    case .drawing(.arrow(let from, _))?: drag = .drawing(.arrow(from: from, to: point))
    case .drawing(.rectangle)?:
      drag = .drawing(.rectangle(CGRect(x: min(dragStart.x, point.x), y: min(dragStart.y, point.y),
                                        width: abs(point.x - dragStart.x), height: abs(point.y - dragStart.y))))
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
    default: break
    }
    drag = nil
    needsDisplay = true
  }

  // MARK: - Teclado

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
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
    field.frame = NSRect(x: origin.x / scale - 2, y: origin.y / scale, width: max(field.frame.width + 12, 40),
                         height: field.frame.height)
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
```

- [ ] **Step 2: Compilar la release (sin avisos)**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build of product' | tail -3
```

Esperado: `Build of product 'Sintecla' complete!`.

Si sale alguna línea `warning:`, corrígela antes de seguir.

- [ ] **Step 3: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 280 tests in 50 suites passed`.

- [ ] **Step 4: Commit**

```bash
git add Sources/Sintecla/CaptureCanvas.swift
git commit -m 'feat: lienzo del editor de capturas con sus herramientas

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 4: La ventana del editor y la copia automática

**Files:**
- Create: `Sources/Sintecla/CaptureEditorWindow.swift`
- Modify: `Sources/Sintecla/Windows.swift` (`DockPresence`) y `Sources/Sintecla/MainWindow.swift` (la usa)
- Modify: `Sources/Sintecla/ScreenCapture.swift` (`scaleUnderMouse`, `copyImage(png:tiff:)`)
- Modify: `Sources/Sintecla/CaptureController.swift` (abre el editor) y `Sources/Sintecla/CapturesPage.swift` (el texto de los atajos)

**Interfaces:**
- Consumes: Las Tareas 1 a 3; `ScreenCapture.Shot`, `copyText(_:)` y `CaptureController.imageSymbol` (plan de Capturas 1).
- Produces: `CaptureEditor(shot:scale:)` con `show()`, `zoom(_:)`, `onNotice`, `onClose` y `static export(_:_:original:)`; `CaptureEditorBar`; `CenteringClipView`; `DockPresence.show(for:)` y `hide(for:)`; `ScreenCapture.scaleUnderMouse` y `copyImage(png:tiff:)`.

Tras esta tarea, ⇧⌘3 y ⇧⌘4 abren el editor. La captura sigue copiándose al capturar, como en el plan 1.

- [ ] **Step 1: `DockPresence`: Sintecla en el Dock mientras haya ventanas**

En `Sources/Sintecla/Windows.swift`, cambiar:

```swift
  static func present(_ window: NSWindow) {
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }
}
```

por:

```swift
  static func present(_ window: NSWindow) {
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }
}

/// Sintecla sale en el Dock (y con ⌘Tab) mientras tiene abierta la ventana principal o algún editor de capturas.
@MainActor
enum DockPresence {
  private static var owners: Set<ObjectIdentifier> = []

  static func show(for owner: AnyObject) {
    owners.insert(ObjectIdentifier(owner))
    NSApp.setActivationPolicy(.regular)
  }

  static func hide(for owner: AnyObject) {
    owners.remove(ObjectIdentifier(owner))
    if owners.isEmpty { NSApp.setActivationPolicy(.accessory) }
  }
}
```

- [ ] **Step 2: La ventana principal usa `DockPresence`**

En `Sources/Sintecla/MainWindow.swift`, cambiar:

```swift
/// La ventana principal. Mientras está abierta, Sintecla aparece en el Dock; al cerrarla vuelve a vivir solo en la
/// barra de menú.
```

por:

```swift
/// La ventana principal. Mientras está abierta, Sintecla aparece en el Dock; al cerrarla (sin editores de capturas
/// abiertos) vuelve a vivir solo en la barra de menú.
```

Y cambiar:

```swift
    NSApp.setActivationPolicy(.regular)
    NSApp.activate()
    window?.makeKeyAndOrderFront(nil)
```

por:

```swift
    DockPresence.show(for: self)
    NSApp.activate()
    window?.makeKeyAndOrderFront(nil)
```

Y cambiar:

```swift
  func windowWillClose(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }
```

por:

```swift
  func windowWillClose(_ notification: Notification) {
    DockPresence.hide(for: self)
  }
```

- [ ] **Step 3: `ScreenCapture`: la escala de la pantalla y copiar PNG y TIFF ya hechos**

En `Sources/Sintecla/ScreenCapture.swift`, cambiar:

```swift
  /// En PNG y en TIFF, para que la acepten todas las apps.
  static func copyImage(_ shot: Shot) {
    let item = NSPasteboardItem()
    item.setData(shot.png, forType: .png)
    if let tiff = NSBitmapImageRep(data: shot.png)?.tiffRepresentation { item.setData(tiff, forType: .tiff) }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects([item])
  }
```

por:

```swift
  /// Píxeles por punto de la pantalla del ratón (2 en Retina): el editor mide los grosores y las letras en puntos.
  static var scaleUnderMouse: CGFloat {
    let mouse = NSEvent.mouseLocation
    return (NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main)?.backingScaleFactor ?? 2
  }

  /// En PNG y en TIFF, para que la acepten todas las apps.
  static func copyImage(_ shot: Shot) {
    copyImage(png: shot.png, tiff: NSBitmapImageRep(data: shot.png)?.tiffRepresentation)
  }

  static func copyImage(png: Data, tiff: Data?) {
    let item = NSPasteboardItem()
    item.setData(png, forType: .png)
    if let tiff { item.setData(tiff, forType: .tiff) }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects([item])
  }
```

- [ ] **Step 4: La ventana: barra, zoom y copia automática**

Crear `Sources/Sintecla/CaptureEditorWindow.swift`:

```swift
import AppKit
import SinteclaCore
import SwiftUI

/// La barra del editor (spec «Capturas» §3.1): Copiar, las herramientas, el estilo y, a la derecha, el color bajo el
/// cursor, el tamaño y el zoom.
struct CaptureEditorBar: View {
  let model: CaptureEditorModel
  var onCopy: () -> Void
  var onZoom: (CaptureZoom) -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onCopy) { Label("Copiar", systemImage: "doc.on.doc") }
        .buttonStyle(.bordered)
        .help("Copiar (⌘C). Cada cambio ya se copia solo")
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
  private let window: NSWindow
  private let scrollView = NSScrollView()
  private let canvas: CaptureCanvasView
  private var pendingCopy: Task<Void, Never>?
  /// Cuenta las copias: si una copia termina después de otra más nueva, no pisa el portapapeles.
  private var copies = 0

  init(shot: ScreenCapture.Shot, scale: CGFloat) {
    model = CaptureEditorModel(image: shot.image, scale: scale)
    original = shot.png
    canvas = CaptureCanvasView(model: model)
    window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                      styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    super.init()
    window.title = "Captura · \(model.pixelSize)"
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 880, height: 320)
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

    model.onChange = { [weak self] in self?.scheduleCopy() }
    canvas.onCopy = { [weak self] in self?.copyNow() }
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
    NSApp.activate()
    // Si macOS no deja pasar Sintecla al frente (se usa otra app), la ventana sale encima igualmente.
    window.orderFrontRegardless()
    window.makeKeyAndOrderFront(nil)
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
```

- [ ] **Step 5: `CaptureController`: ⇧⌘3 y ⇧⌘4 abren un editor**

En `Sources/Sintecla/CaptureController.swift`, cambiar:

```swift
  /// Una captura cada vez: mientras está la cruz de macOS, otro atajo no hace nada.
  private var busy = false
```

por:

```swift
  /// Una captura cada vez: mientras está la cruz de macOS, otro atajo no hace nada.
  private var busy = false
  /// Los editores abiertos, uno por captura.
  private var editors: [CaptureEditor] = []
```

Y cambiar:

```swift
      ScreenCapture.copyImage(shot)
      onNotice?(CaptureNotice.copied, Self.imageSymbol)
```

por:

```swift
      ScreenCapture.copyImage(shot)
      onNotice?(CaptureNotice.copied, Self.imageSymbol)
      openEditor(shot)
```

Y cambiar:

```swift
  /// Traductores: Apple y, de respaldo, Gemini.
```

por:

```swift
  private func openEditor(_ shot: ScreenCapture.Shot) {
    let editor = CaptureEditor(shot: shot, scale: ScreenCapture.scaleUnderMouse)
    editor.onNotice = { [weak self] text, symbol in self?.onNotice?(text, symbol) }
    editor.onClose = { [weak self] closed in self?.editors.removeAll { $0 === closed } }
    editors.append(editor)
    editor.show()
  }

  /// Traductores: Apple y, de respaldo, Gemini.
```

- [ ] **Step 6: La página Capturas lo cuenta**

En `Sources/Sintecla/CapturesPage.swift`, cambiar:

```swift
        Text("⇧⌘3 y ⇧⌘4 copian la captura al portapapeles. ⇧⌘2
```

por:

```swift
        Text("⇧⌘3 y ⇧⌘4 copian la captura al portapapeles y la abren en el editor para anotarla. ⇧⌘2
```

- [ ] **Step 7: Compilar la release (sin avisos)**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build of product' | tail -3
```

Esperado: `Build of product 'Sintecla' complete!`.

- [ ] **Step 8: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 280 tests in 50 suites passed`.

- [ ] **Step 9: Commit**

```bash
git add Sources/Sintecla/Windows.swift Sources/Sintecla/MainWindow.swift Sources/Sintecla/ScreenCapture.swift Sources/Sintecla/CaptureEditorWindow.swift Sources/Sintecla/CaptureController.swift Sources/Sintecla/CapturesPage.swift
git commit -m 'feat: editor de capturas tras ⇧⌘3 y ⇧⌘4, con copia automática

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 5: Versión 0.10.0, README y spec principal

**Files:**
- Modify: `Sources/SinteclaCoreTests/SmokeTests.swift`, `Sources/SinteclaCore/AppInfo.swift` y `Resources/Info.plist`
- Modify: `README.md` y `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§7)

**Interfaces:**
- Consumes: Todo lo anterior.
- Produces: La versión 0.10.0 (build 11), instalada.

La línea «Estado» de la spec principal y la etiqueta `v0.10.0` se ponen al cerrar la versión, cuando el usuario lo pida.

- [ ] **Step 1: El test de la versión**

En `Sources/SinteclaCoreTests/SmokeTests.swift`, cambiar:

```swift
#expect(AppInfo.version == "0.9.0")
```

por:

```swift
#expect(AppInfo.version == "0.10.0")
```

- [ ] **Step 2: Ver que falla**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA el test con `Expectation failed: (AppInfo.version → "0.9.0") == "0.10.0"`.

- [ ] **Step 3: `AppInfo.version`**

En `Sources/SinteclaCore/AppInfo.swift`, cambiar:

```swift
public static let version = "0.9.0"
```

por:

```swift
public static let version = "0.10.0"
```

- [ ] **Step 4: `Info.plist`**

En `Resources/Info.plist`, cambiar:

```xml
  <key>CFBundleShortVersionString</key><string>0.9.0</string>
  <key>CFBundleVersion</key><string>10</string>
```

por:

```xml
  <key>CFBundleShortVersionString</key><string>0.10.0</string>
  <key>CFBundleVersion</key><string>11</string>
```

- [ ] **Step 5: Ver que pasa**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 280 tests in 50 suites passed`.

- [ ] **Step 6: README: módulos, Finder, Capturas y los sitios nuevos de los ajustes**

En `README.md`, cambiar:

```text
| **Herramientas** | Utilidades de Windows o de apps de pago, cada una con su interruptor y apagadas de fábrica. Por ahora, cortar y pegar archivos en Finder con ⌘X y ⌘V. Si ya usas otra app que cambia ⌘X en Finder, deja esta apagada. |
| **Y además** | Historial, estadísticas, atajos configurables, modo susurro y tecla ⌥ derecha para teclados sin 🌐. |
```

por:

```text
| **Finder** | Cortar y pegar archivos con ⌘X y ⌘V, como en Windows. Si ya usas otra app que cambia ⌘X en Finder, déjalo apagado. |
| **Capturas** | ⇧⌘3 captura la pantalla y ⇧⌘4 una zona o una ventana: van al portapapeles y se abren en un editor para anotarlas (flecha, texto, rectángulo, lápiz, subrayador, pasos numerados, regla y color bajo el cursor). Cada cambio se vuelve a copiar solo. ⇧⌘2 copia el texto de cualquier zona de la pantalla o el contenido de un QR; ⇧⌘1, además, lo traduce o responde preguntas sobre él. |
| **Y además** | Historial, estadísticas, atajos configurables, modo susurro y tecla ⌥ derecha para teclados sin 🌐. |

Dictado, Reuniones, Finder y Capturas son **módulos**: se encienden y se apagan en la página **Módulos** de la ventana de Sintecla, y uno apagado desaparece del menú y deja de funcionar. Finder y Capturas vienen apagados.
```

Y cambiar:

```text
4. **Audio del sistema**: solo para las reuniones; se pide la primera vez que grabas una.

Después, desde el icono de la barra de menú → **Abrir Sintecla…**:

- **Ajustes → IA**: pega tu clave de Gemini (se guarda en el Llavero del Mac, no en ningún archivo).
- **Ajustes → General → Tecla base**: si tu teclado externo no manda la tecla 🌐 al Mac (pasa con algunos Logitech), elige «⌥ derecha» o «Las dos».
```

por:

```text
4. **Audio del sistema**: solo para las reuniones; se pide la primera vez que grabas una.
5. **Grabación de pantalla**: solo para Capturas; se da en su página. Después hay que salir de Sintecla y volver a abrirla.

Después, desde el icono de la barra de menú → **Abrir Sintecla…** (abre en Inicio, con una tarjeta por módulo; pulsa la de Dictado):

- **Dictado → IA**: pega tu clave de Gemini (se guarda en el Llavero del Mac, no en ningún archivo).
- **Dictado → Atajos e idioma → Tecla base**: si tu teclado externo no manda la tecla 🌐 al Mac (pasa con algunos Logitech), elige «⌥ derecha» o «Las dos».
```

Y cambiar:

```text
Las teclas que acompañan a 🌐 se cambian en **Ajustes → General → Atajos**.
```

por:

```text
Las teclas que acompañan a 🌐 se cambian en **Dictado → Atajos e idioma**.

Con el módulo Capturas encendido: `⇧⌘3` pantalla, `⇧⌘4` zona o ventana, `⇧⌘2` texto y `⇧⌘1` texto con traducir y preguntar. En el editor, cada herramienta tiene su tecla (V, A, T, R, P, H, N y M), `Tab` copia el color bajo el cursor y `⌘Z` deshace.
```

Y cambiar:

```text
Se apaga en **Ajustes → IA → «Ordenar el dictado con Gemini»**;
```

por:

```text
Se apaga en **Dictado → IA → «Ordenar el dictado con Gemini»**;
```

Y cambiar:

```text
- **Solo va a Gemini**, y solo si pones una clave: el dictado (salvo que lo apagues), Ask Anything, las notas, las actas de reuniones, la traducción cuando falla la de Apple y «Aprender de mi historial» (únicamente al pulsar ese botón).
```

por:

```text
- **Solo va a Gemini**, y solo si pones una clave: el dictado (salvo que lo apagues), Ask Anything, las notas, las actas de reuniones, la traducción cuando falla la de Apple, «Aprender de mi historial» (únicamente al pulsar ese botón) y, en Capturas, el texto de la tarjeta de ⇧⌘1 al pulsar Preguntar o Traducir.
- **Las capturas no se guardan en disco**: van al portapapeles, y el archivo temporal de macOS se borra al leerlo.
```

Y cambiar:

```text
Y quita Sintecla de Ajustes del Sistema → Privacidad y seguridad (Accesibilidad, Micrófono…).
```

por:

```text
Y quita Sintecla de Ajustes del Sistema → Privacidad y seguridad (Accesibilidad, Micrófono, Grabación de pantalla…).
```

- [ ] **Step 7: Spec principal (§7): menú por bloques, ventana por módulos y el editor**

En `docs/superpowers/specs/2026-09-23-sintecla-design.md`, cambiar:

```text
- **Barra de menú** (icono: la «onda que escribe» del icono de la app, en reposo / grabando, sin color; ver `2026-09-24-icono-design.md`): Estado · Micrófono en uso (el que elige macOS; solo informativo) · Idioma de dictado (es/en) · Modo susurro ✓ · Traducir a ▸ · ● Grabar reunión / ■ Detener reunión (N min) · Reuniones pendientes (N)… (solo si hay) · Pegar último resultado · Notas sin procesar (N)… (solo si hay) · Abrir Sintecla… (⌘O) · Historial… · Ajustes… (⌘,) · Permisos… · Salir. Historial y Ajustes abren su sección de la ventana Sintecla.
```

por:

```text
- **Barra de menú** (icono: la «onda que escribe» del icono de la app, en reposo / grabando, sin color; ver `2026-09-24-icono-design.md`): desde la 0.10.0, por bloques, con una cabecera por módulo encendido (ver `2026-09-25-bateria-modulos-design.md` §3.2). Arriba: Estado · Micrófono en uso (el que elige macOS; solo informativo) · Revisar permisos… (solo si faltan). **Dictado:** Idioma de dictado ▸ · Traducir a ▸ · Modo susurro ✓ · Pegar último resultado · Añadir selección al diccionario · Notas sin procesar (N)… (solo si hay) · Historial…. **Reuniones:** ● Grabar reunión / ■ Detener reunión (N min) · Reuniones pendientes (N)… (solo si hay). **Capturas:** las cuatro acciones con sus atajos. Pie: Abrir Sintecla… (⌘O) · Ajustes… (⌘,) · Salir. Historial y Ajustes abren su sitio de la ventana Sintecla.
```

Y cambiar:

```text
- **Ventana Sintecla** (menú "Abrir Sintecla…"): barra lateral de cristal con **Reuniones** (lista y botón «Grabar reunión»), **Historial**, **Estadísticas** y **Ajustes**: General (inicio de sesión, sonidos, susurro, idioma de dictado, "Traducir a", tecla base, editor de atajos y, en Reuniones, "Guardar el audio") · Diccionario · Tonos · IA (clave de Gemini con Guardar/Borrar —se guarda en el Llavero—, modelo configurable —por defecto `gemini-3.5-flash-lite`—, "Probar conexión", "Mi estilo") · Herramientas (desde la 0.9.0; cortar y pegar archivos en Finder, ver `2026-09-25-herramientas-finder-design.md`). Con la ventana abierta, Sintecla sale en el Dock y tiene menú Edición (⌘C/⌘V en los campos). Los permisos siguen en el asistente ("Permisos…" en el menú).
```

por:

```text
- **Ventana Sintecla** (menú "Abrir Sintecla…"), por módulos desde la 0.10.0 (ver `2026-09-25-bateria-modulos-design.md` §3.1): abre en **Inicio**, con una tarjeta por módulo encendido y su resumen, y debajo **General** (inicio de sesión, sonidos, permisos) y **Módulos** (un interruptor por módulo: Dictado, Reuniones, Finder y Capturas; los dos últimos, apagados de fábrica). Al pulsar una tarjeta se entra en el módulo, con su barra lateral de cristal: **Dictado** (Historial · Estadísticas · Diccionario · Tonos · IA —clave de Gemini con Guardar/Borrar, que se guarda en el Llavero; modelo configurable, por defecto `gemini-3.5-flash-lite`; "Probar conexión"; "Mi estilo"— · Atajos e idioma —susurro, idioma de dictado, "Traducir a", tecla base y editor de atajos—), **Reuniones** (lista, botón «Grabar reunión» y "Guardar el audio"), **Finder** (cortar y pegar archivos, ver `2026-09-25-herramientas-finder-design.md`) y **Capturas** (permiso de Grabación de pantalla y atajos, ver `2026-09-25-capturas-design.md`). Con la ventana abierta, Sintecla sale en el Dock y tiene menú Edición (⌘C/⌘V en los campos). Los permisos siguen en el asistente ("Revisar permisos…" en el menú).
- **Editor de capturas** (desde la 0.10.0, tras ⇧⌘3 o ⇧⌘4): una ventana por captura, con Copiar, las herramientas (Seleccionar, Flecha, Texto, Rectángulo, Lápiz, Subrayador, Pasos y Regla), 6 colores, 3 grosores, el color bajo el cursor, el tamaño y el zoom. La captura anotada vuelve sola al portapapeles medio segundo después de cada cambio. Mientras hay un editor abierto, Sintecla sale en el Dock.
```

- [ ] **Step 8: Compilar la release (sin avisos)**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build of product' | tail -3
```

Esperado: `Build of product 'Sintecla' complete!`.

- [ ] **Step 9: Commit**

```bash
git add Sources/SinteclaCoreTests/SmokeTests.swift Sources/SinteclaCore/AppInfo.swift Resources/Info.plist README.md docs/superpowers/specs/2026-09-23-sintecla-design.md
git commit -m 'feat: versión 0.10.0 con módulos y capturas

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

- [ ] **Step 10: Instalar la versión nueva**

Run:

```bash
scripts/build-app.sh
```

Esperado: `✅ Instalada en /Applications/Sintecla.app`. Los permisos se conservan.

---
### Task 6: Aceptación a mano

**Files:**
- —

**Interfaces:**
- Consumes: La app instalada (Tarea 5).
- Produces: Nada nuevo. Con todo ✓, la 0.10.0 se cierra cuando el usuario lo pida: rama `modulos` a `main`, etiqueta `v0.10.0` y la línea «Estado» de la spec principal.

La hace el usuario (spec §5.2), con el módulo Capturas encendido, el permiso dado y cualquier otra app de capturas cerrada.

- [ ] **Step 1: Checklist. Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | ⇧⌘3 | La pastilla dice «Captura copiada» y se abre el editor, «Captura · W × H», al 100 % o ajustado. Sintecla sale en el Dock |
| 2 | ⇧⌘3 con otra app delante (por ejemplo, escribiendo en Notas) | El editor sale delante y toma el teclado (prueba la tecla R). Si no lo toma hasta hacer clic, anótalo |
| 3 | ⇧⌘4: una zona | Otro editor, con la zona |
| 4 | Flecha (A), Rectángulo (R) y Lápiz (P) | Se dibujan al arrastrar. Un clic sin arrastrar no deja nada |
| 5 | Subrayador (H) sobre un texto de la captura | Amarillo semitransparente; el texto se sigue leyendo |
| 6 | Texto (T): clic, escribir e Intro; otro terminado con un clic fuera; doble clic sobre uno | El texto no salta al terminar; el doble clic lo vuelve a editar |
| 7 | Pasos (N): tres clics; con Seleccionar (V), elegir el 2 y pulsar ⌫ | 1, 2 y 3; después, 1 y 2 |
| 8 | Seleccionar (V): elegir una anotación, arrastrarla y cambiarle el color y el grosor | Se mueve y cambia |
| 9 | ⌘Z varias veces y ⇧⌘Z | Deshace y rehace de uno en uno |
| 10 | Regla (M): medir algo; luego pegar en Notas | Enseña «N px · ↔ … · ↕ …». En la imagen pegada no sale |
| 11 | Tras un cambio, esperar un segundo y pegar en Notas, sin ⌘C | La versión anotada, a tamaño real |
| 12 | ⌘C o el botón Copiar | Copia al momento, con «Captura copiada» |
| 13 | Ratón sobre un color, Tab y pegar | El `#RRGGBB` de la barra; la pastilla dice «Color copiado: …» |
| 14 | ⌘0, ⌘1, ⌘+, ⌘− y pellizcar | El zoom cambia y la barra lo dice |
| 15 | Esc con una anotación elegida; Esc otra vez | La suelta; después cierra la ventana. Sin editores ni ventana principal, Sintecla sale del Dock |
| 16 | Dos capturas seguidas | Dos ventanas, cada una con su captura |
| 17 | ⇧⌘2, ⇧⌘1, el menú, dictado, Finder y Reuniones | Como antes |

---
## Autorrevisión frente a la especificación (plan de Capturas 2)

| Requisito (spec «Capturas») | Dónde |
|---|---|
| §3.1 Una ventana por captura, «Captura · W × H»; barra con Copiar, las ocho herramientas, 6 colores, 3 grosores, color bajo el cursor, tamaño y zoom | Tareas 1 y 4 |
| §3.2 Flecha, Rectángulo y Lápiz al arrastrar; Subrayador semitransparente y amarillo de fábrica; Texto con Intro, clic fuera y doble clic; Pasos que se renumeran; Seleccionar (elegir, mover, ⌫, estilo); Regla que no sale; ⌘Z y ⇧⌘Z; zoom; Esc | Tareas 1 a 4 |
| §3.3 Copia al capturar, tras cada cambio (0,5 s, tamaño real, sin aviso), ⌘C y Copiar con aviso, nada más al cerrar, Tab copia el color | Tareas 2 y 4 |
| §4 `AnnotationDocument` en el núcleo; `CaptureEditorWindow` en la app; `AppInfo`, `Info.plist` y `SmokeTests` a la 0.10.0 (build 11); README y spec principal | Tareas 1 a 5 |
| §5.1 Tests de `AnnotationDocument`: añadir, mover y borrar; deshacer y rehacer seguidos; renumerar pasos; hit test de una flecha; regla; estilo de la elegida; texto del color | Tareas 1 y 2 |
| §5.2 Aceptación con el editor | Tarea 6 |
| §8 El editor y después la 0.10.0 con los módulos, el README y la spec principal | Tareas 1 a 5 |

**Consistencia de tipos revisada:**
- `AnnotationDocument`, `AnnotationStyle` y `AnnotationShape` (Tarea 1) los usan `AnnotationRenderer` (Tarea 2), `CaptureEditorModel` y `CaptureCanvasView` (Tarea 3) y `CaptureEditor.export` (Tarea 4).
- `AnnotationGeometry.textFont(_:)` y `textFrame(_:at:style:scale:)` (Tarea 1) los usa el dibujo del texto (Tarea 2). El campo del lienzo (Tarea 3) usa la misma letra en puntos: `.boldSystemFont(ofSize: style.width.fontSize)`.
- `ImagePixels.hex(x:y:)` (Tarea 2) da `hoverHex` (Tarea 3), y `CaptureNotice.color(_:)` (Tarea 2) es el aviso de Tab (Tarea 4).
- `CaptureZoom` y los avisos del lienzo (`onCopy`, `onCopyColor`, `onZoom`, `onClose`, Tarea 3) los conecta `CaptureEditor` (Tarea 4).
- `ScreenCapture.copyImage(png:tiff:)` y `scaleUnderMouse` (Tarea 4) los usan `CaptureEditor.copy` y `CaptureController.openEditor`.
