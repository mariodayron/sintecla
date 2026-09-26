# Sintecla — Editor de capturas completo (0.11.0) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que el editor de capturas sustituya a Shottr del todo, con cuatro cosas nuevas:
- **Pixelar** (B) zonas;
- **Recortar** (C) con un marco e Intro, sin perder la captura;
- **Guardar**: ⌘S en la carpeta de capturas y ⇧⌘S «Guardar como…»;
- **Fijar** la captura flotando encima de todo (⌘P).

**Architecture:**
- **En el núcleo, con tests:**
  - `AnnotationShape.pixelate`, que `AnnotationRenderer` dibuja a partir de la captura;
  - `AnnotationDocument.crop`, dentro de deshacer y rehacer, y `render` sale recortado;
  - `CaptureFiles`: el nombre del archivo.
- **En la app:**
  - el lienzo: Pixelar y el marco de Recortar;
  - el editor: Guardar y Fijar;
  - `PinnedCapture`: un panel flotante que no activa Sintecla;
  - `AppSettings.captureFolder`, en la página Capturas.

**Tech Stack:** Lo de siempre:
- Swift 6.3 de las Command Line Tools, en modo de lenguaje 5;
- SwiftPM, Swift Testing, SwiftUI y AppKit;
- CoreGraphics en el núcleo.

**Especificación:** `docs/superpowers/specs/2026-09-26-capturas-editor-design.md`.

**Punto de partida:** la rama `capturas-editor` (sale de `main` en la 0.10.0, con la especificación):

```bash
git checkout capturas-editor
```

## Global Constraints

- **Todo lo de antes sigue vigente:**
  - macOS 26.0 o superior, Apple Silicon.
  - Sin Xcode ni dependencias externas; modo de lenguaje 5.
  - Tests con `swift run sintecla-tests` (**nunca `swift test`**).
  - Textos visibles en español.
  - La release compila sin avisos.
- **Herramientas, en este orden:** Seleccionar V · Flecha A · Texto T · Rectángulo R · Lápiz P · Subrayador H · Pasos N · **Pixelar B** · Regla M · **Recortar C**.
- **Pixelar:**
  - cuadros de 8, 12 o 18 puntos según el grosor, con el color medio de la captura;
  - siempre debajo de las anotaciones;
  - el color no le afecta.
- **Recortar:**
  - Intro aplica y Esc quita el marco;
  - ⌘Z deshace;
  - las anotaciones, el hit test y el color bajo el cursor siguen en píxeles de la captura entera.
- **Guardar:**
  - PNG, a UserDefaults `captureFolder` (el Escritorio de fábrica);
  - nombre «Captura 2026-09-26 a las 10.42.13.png», con la hora de la captura; si ya existe, « 2», « 3»…;
  - avisos: «Guardada en <carpeta>» y «No se pudo guardar».
- **Fijar:**
  - nivel flotante, en todos los escritorios, sin activar Sintecla;
  - escala del 20 % al 400 % sin mover la esquina de arriba;
  - doble clic vuelve al editor; Esc o ⌘W la cierran, y con ella el editor.
- **Versión:** 0.11.0 (build 12).
- **Commits:** en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `capturas-editor`: compiló, pasó los tests en cada tarea y el árbol final quedó idéntico al del prototipo.

- **293 tests** (53 suites) en verde: los 280 de antes y 13 nuevos. La release compila sin avisos.
- **El lienzo, dibujado fuera de pantalla** con una captura de 2560 × 1440:
  - al recortar, fuera del marco se oscurece; se ven las ocho asas y el tamaño «1500 × 700»;
  - con Intro, el lienzo y el título pasan a 1500 × 700, y ⌘Z vuelve a 2560 × 1440;
  - el texto pixelado con el grosor grueso no se lee, y una flecha encima sigue viéndose.
- **Fijar,** probado con la app en segundo plano:
  - la captura fijada queda en el nivel flotante;
  - Sintecla sale del Dock mientras solo está ella;
  - con doble clic vuelve el editor y Sintecla vuelve al Dock.
- **La barra** mide 994 puntos, así que la ventana tiene un mínimo de 1000.
- **Sin probar en la app** (lo comprueba la Tarea 8):
  - la ventana de guardar como hoja del panel;
  - el ratón sobre las asas;
  - la rueda y el pellizco en la captura fijada.

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| Añadir las herramientas al núcleo antes que al lienzo rompería la compilación de la app a medias | `AnnotationTool.pixelate` y `.crop` entran en la Tarea 4, junto con el lienzo |
| `draw(_:in:hiding:)` sin la imagen no puede pixelar, pero el lienzo de la 0.10.0 lo llama así | `image: CGImage? = nil`: compila en cada tarea, y el lienzo pasa la imagen en la Tarea 4 |
| Una flecha creada antes que el pixelado quedaría tapada | `draw` pinta primero todas las zonas pixeladas |
| Recortar borrando la imagen impediría deshacer | El recorte es un rectángulo en `AnnotationDocument`; deshacer guarda anotaciones y recorte juntos (`Snapshot`) |
| Un clic sin arrastrar con Recortar dejaría un marco de nada | Al soltar, un marco de menos de 4 puntos vuelve a la zona que se ve |
| En el arnés de pruebas, `orderOut` no oculta ninguna ventana (tampoco una normal): no hay bucle de eventos de la app | No afecta a la app. La aceptación lo comprueba |

**Decisiones de este plan que la spec no fijaba:**
- La ventana del editor pasa de un mínimo de 880 a **1000 puntos** (la spec decía «unos 960»).
- Al recortar o cancelar, se vuelve a la **herramienta de antes** de Recortar.
- La captura fijada **no se sale de la pantalla**: si no cabe, se encoge al 90 % de la pantalla.

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/AnnotationDocument.swift`, `Sources/SinteclaCore/AnnotationRenderer.swift`, `Sources/SinteclaCoreTests/AnnotationPixelateTests.swift` | Pixelar | 1 |
| Los mismos del núcleo y `Sources/SinteclaCoreTests/AnnotationCropTests.swift` | Recortar | 2 |
| `Sources/SinteclaCore/CaptureFiles.swift`, `Sources/SinteclaCore/CaptureNotice.swift`, `Sources/SinteclaCoreTests/CaptureFilesTests.swift` | Nombre del archivo y avisos | 3 |
| `Sources/SinteclaCore/AnnotationDocument.swift`, `Sources/SinteclaCoreTests/AnnotationDocumentTests.swift`, `Sources/Sintecla/CaptureCanvas.swift`, `Sources/Sintecla/CaptureEditorWindow.swift` | Herramientas B y C en el lienzo | 4 |
| `Sources/Sintecla/AppSettings.swift`, `Sources/Sintecla/CapturesPage.swift`, `Sources/Sintecla/MainWindow.swift`, `Sources/Sintecla/CaptureCanvas.swift`, `Sources/Sintecla/CaptureEditorWindow.swift`, `Sources/Sintecla/CaptureController.swift` | Guardar | 5 |
| `Sources/Sintecla/PinnedCapture.swift`, `Sources/Sintecla/CaptureCanvas.swift`, `Sources/Sintecla/CaptureEditorWindow.swift` | Fijar | 6 |
| `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`, `Sources/SinteclaCoreTests/SmokeTests.swift`, `README.md`, `docs/superpowers/specs/2026-09-23-sintecla-design.md` | 0.11.0 | 7 |

---

### Task 1: Pixelar en el núcleo

**Files:**
- Modify: `Sources/SinteclaCore/AnnotationDocument.swift` y `Sources/SinteclaCore/AnnotationRenderer.swift`
- Test: `Sources/SinteclaCoreTests/AnnotationPixelateTests.swift`

**Interfaces:**
- Consumes: `AnnotationDocument`, `AnnotationGeometry` y `AnnotationRenderer` (0.10.0).
- Produces: `AnnotationShape.pixelate(CGRect)`; `AnnotationWidth.pixelBlock` (8, 12 y 18 pt); `AnnotationRenderer.draw(_ document:image:in:hiding:)` (con `image: CGImage? = nil`) y `pixelate(_:block:image:in:)`.

Pixelar es una anotación más, pero se dibuja a partir de la captura: `draw` recibe la imagen (opcional, para que el lienzo de la 0.10.0 siga compilando) y pinta todas las zonas pixeladas antes que el resto de anotaciones.

- [ ] **Step 1: Tests del pixelado**

Crear `Sources/SinteclaCoreTests/AnnotationPixelateTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import SinteclaCore

@Suite struct AnnotationPixelateTests {
  /// Rayas verticales de un píxel, negras y blancas: un patrón fino que el pixelado vuelve liso.
  static func stripes(width: Int = 240, height: Int = 120) -> CGImage? {
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
    for x in stride(from: 0, to: width, by: 2) { context.fill(CGRect(x: x, y: 0, width: 1, height: height)) }
    return context.makeImage()
  }

  /// La captura de rayas con las anotaciones, leída píxel a píxel.
  private func exported(_ document: AnnotationDocument) throws -> ImagePixels {
    let image = try #require(Self.stripes())
    let rendered = try #require(AnnotationRenderer.render(image, document))
    return try #require(ImagePixels(rendered))
  }

  /// Cuadros de 12 px (grosor medio a escala 1): la zona de 96 × 48 son 8 × 4 cuadros justos.
  private let zone = CGRect(x: 24, y: 24, width: 96, height: 48)

  @Test func eachBlockIsOneFlatColor() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.pixelate(zone), style: AnnotationStyle())
    let pixels = try exported(document)
    let block = Set((36..<48).flatMap { x in (24..<36).map { y in pixels.hex(x: x, y: y) } })
    #expect(block.count == 1)
    let hex = try #require(block.first ?? nil)
    let gray = try #require(Int(hex.dropFirst().prefix(2), radix: 16))
    #expect((0x40...0xC0).contains(gray))  // ni negro ni blanco: la media de las rayas
  }

  @Test func outsideTheZoneTheCaptureIsUntouched() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.pixelate(zone), style: AnnotationStyle())
    let pixels = try exported(document)
    #expect(pixels.hex(x: 10, y: 10) == "#000000")
    #expect(pixels.hex(x: 11, y: 10) == "#FFFFFF")
    #expect(pixels.hex(x: 130, y: 50) == "#000000")
  }

  @Test func annotationsStayOnTopEvenIfDrawnBefore() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.arrow(from: CGPoint(x: 0, y: 60), to: CGPoint(x: 200, y: 60)), style: AnnotationStyle(width: .thick))
    document.add(.pixelate(zone), style: AnnotationStyle())
    let pixels = try exported(document)
    #expect(pixels.hex(x: 60, y: 60) == "#FF3B30")
  }

  @Test func biggerWidthMeansBiggerBlocks() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.pixelate(CGRect(x: 0, y: 0, width: 72, height: 72)), style: AnnotationStyle(width: .thick))
    let pixels = try exported(document)
    #expect(Set((0..<18).map { pixels.hex(x: $0, y: 5) }).count == 1)  // cuadros de 18 px
    #expect([AnnotationWidth.thin, .medium, .thick].map(\.pixelBlock) == [8, 12, 18])
  }

  @Test func pixelateIsAnAnnotationLikeTheOthers() {
    var document = AnnotationDocument(scale: 2)
    let id = document.add(.pixelate(zone), style: AnnotationStyle())
    #expect(document.hit(CGPoint(x: 60, y: 40)) == id)  // se toca por dentro
    #expect(document.hit(CGPoint(x: 200, y: 100)) == nil)
    document.move(id, by: CGVector(dx: 10, dy: 0))
    #expect(document.annotation(id)?.shape == .pixelate(zone.offsetBy(dx: 10, dy: 0)))
    #expect(AnnotationShape.pixelate(CGRect(x: 0, y: 0, width: 3, height: 3)).isTooSmall(scale: 1))
    document.undo()
    #expect(document.annotation(id)?.shape == .pixelate(zone))
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: type 'AnnotationShape' has no member 'pixelate'`.

- [ ] **Step 3: La forma `pixelate` y el tamaño de sus cuadros**

En `Sources/SinteclaCore/AnnotationDocument.swift`, cambiar:

```swift
  public var stepRadius: CGFloat { [11, 14, 19][rawValue] }
```

por:

```swift
  public var stepRadius: CGFloat { [11, 14, 19][rawValue] }
  /// Lado de los cuadros de Pixelar.
  public var pixelBlock: CGFloat { [8, 12, 18][rawValue] }
```

Y cambiar:

```swift
  case rectangle(CGRect)
```

por:

```swift
  case rectangle(CGRect)
  /// Zona de la captura tapada con cuadros. El color no le afecta; el grosor da el tamaño de los cuadros.
  case pixelate(CGRect)
```

Y cambiar:

```swift
    case .rectangle(let rect): return .rectangle(rect.offsetBy(dx: offset.dx, dy: offset.dy))
```

por:

```swift
    case .rectangle(let rect): return .rectangle(rect.offsetBy(dx: offset.dx, dy: offset.dy))
    case .pixelate(let rect): return .pixelate(rect.offsetBy(dx: offset.dx, dy: offset.dy))
```

Y cambiar:

```swift
    case .rectangle(let rect): return max(abs(rect.width), abs(rect.height)) < minimum
```

por:

```swift
    case .rectangle(let rect), .pixelate(let rect): return max(abs(rect.width), abs(rect.height)) < minimum
```

Y cambiar:

```swift
    case .rectangle(let rect): return rect.standardized.insetBy(dx: -half, dy: -half)
```

por:

```swift
    case .rectangle(let rect): return rect.standardized.insetBy(dx: -half, dy: -half)
    case .pixelate(let rect): return rect.standardized
```

Y cambiar:

```swift
      return outer.contains(point) && (inner.isNull || !inner.contains(point))
```

por:

```swift
      return outer.contains(point) && (inner.isNull || !inner.contains(point))
    case .pixelate(let rect):
      // Se toca por dentro: es una zona llena.
      return rect.standardized.insetBy(dx: -2 * scale, dy: -2 * scale).contains(point)
```

- [ ] **Step 4: Pixelar al dibujar, por debajo de las anotaciones**

En `Sources/SinteclaCore/AnnotationRenderer.swift`, cambiar:

```swift
  /// En un contexto en píxeles de la imagen con el origen arriba a la izquierda (y hacia abajo). `hiding`: la que se
  /// está escribiendo, que dibuja el campo de texto.
  public static func draw(_ document: AnnotationDocument, in context: CGContext, hiding hidden: Int? = nil) {
    for annotation in document.annotations where annotation.id != hidden {
      draw(annotation, number: document.stepNumber(of: annotation.id), scale: document.scale, in: context)
    }
  }
```

por:

```swift
  /// En un contexto en píxeles de la imagen con el origen arriba a la izquierda (y hacia abajo). `image`: la captura,
  /// para pixelar (sin ella, las zonas pixeladas no se dibujan). `hiding`: la que se está escribiendo, que dibuja el
  /// campo de texto.
  public static func draw(_ document: AnnotationDocument, image: CGImage? = nil, in context: CGContext,
                          hiding hidden: Int? = nil) {
    let shown = document.annotations.filter { $0.id != hidden }
    // Lo pixelado tapa solo la captura: va debajo de todas las anotaciones, se crearan antes o después.
    if let image {
      for annotation in shown {
        guard case .pixelate(let rect) = annotation.shape else { continue }
        pixelate(rect, block: annotation.style.width.pixelBlock * document.scale, image: image, in: context)
      }
    }
    for annotation in shown {
      draw(annotation, number: document.stepNumber(of: annotation.id), scale: document.scale, in: context)
    }
  }
```

Y cambiar:

```swift
    case .rectangle(let rect):
      context.stroke(rect.standardized)
```

por:

```swift
    case .rectangle(let rect):
      context.stroke(rect.standardized)
    case .pixelate:
      break  // lo dibuja draw(_:image:in:hiding:), que tiene la captura
```

Y cambiar:

```swift
    draw(document, in: context)
    return context.makeImage()
```

por:

```swift
    draw(document, image: image, in: context)
    return context.makeImage()
```

Y cambiar:

```swift
  private static func stroke(_ points: [CGPoint], in context: CGContext) {
```

por:

```swift
  /// Cada cuadro, del color medio de esa parte de la captura: la zona se reduce y se vuelve a ampliar sin suavizar.
  static func pixelate(_ rect: CGRect, block: CGFloat, image: CGImage, in context: CGContext) {
    let area = rect.standardized.integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard !area.isEmpty, block > 0, let part = image.cropping(to: area) else { return }
    let columns = max(1, Int((area.width / block).rounded(.up))), rows = max(1, Int((area.height / block).rounded(.up)))
    let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
    guard let small = CGContext(data: nil, width: columns, height: rows, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
    small.interpolationQuality = .high
    small.draw(part, in: CGRect(x: 0, y: 0, width: columns, height: rows))
    guard let blocks = small.makeImage() else { return }
    context.saveGState()
    defer { context.restoreGState() }
    context.interpolationQuality = .none
    // El contexto va de arriba abajo y una imagen se dibuja de abajo arriba: se le da la vuelta solo a ella.
    context.translateBy(x: area.minX, y: area.maxY)
    context.scaleBy(x: 1, y: -1)
    context.draw(blocks, in: CGRect(x: 0, y: 0, width: area.width, height: area.height))
  }

  private static func stroke(_ points: [CGPoint], in context: CGContext) {
```

- [ ] **Step 5: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 285 tests in 51 suites passed`.

- [ ] **Step 6: Commit**

```bash
git add Sources/SinteclaCore/AnnotationDocument.swift Sources/SinteclaCore/AnnotationRenderer.swift Sources/SinteclaCoreTests/AnnotationPixelateTests.swift
git commit -m 'feat: pixelar zonas de la captura en el núcleo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: Recortar en el núcleo

**Files:**
- Modify: `Sources/SinteclaCore/AnnotationDocument.swift` y `Sources/SinteclaCore/AnnotationRenderer.swift`
- Test: `Sources/SinteclaCoreTests/AnnotationCropTests.swift`

**Interfaces:**
- Consumes: La Tarea 1.
- Produces: `AnnotationDocument.crop: CGRect?`, `setCrop(_ rect: CGRect?, in size: CGSize)` y `visibleRect(in:) -> CGRect`; deshacer y rehacer guardan anotaciones y recorte juntos; `AnnotationRenderer.render(_:_:)` sale recortado.

El recorte es un rectángulo sobre la captura entera, dentro de deshacer y rehacer. Las anotaciones, el hit test y el color bajo el cursor siguen en píxeles de la captura entera; solo la exportación y el lienzo miran el recorte.

- [ ] **Step 1: Tests del recorte**

Crear `Sources/SinteclaCoreTests/AnnotationCropTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import SinteclaCore

@Suite struct AnnotationCropTests {
  private let size = CGSize(width: 400, height: 200)

  /// Mitad de arriba azul y mitad de abajo blanca.
  static func twoHalves() -> CGImage? {
    guard let context = CGContext(data: nil, width: 400, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 400, height: 100))  // abajo (el contexto va de abajo arriba)
    context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 100, width: 400, height: 100))  // arriba
    return context.makeImage()
  }

  private func exported(_ document: AnnotationDocument) throws -> ImagePixels {
    let image = try #require(Self.twoHalves())
    let rendered = try #require(AnnotationRenderer.render(image, document))
    return try #require(ImagePixels(rendered))
  }

  @Test func exportHasTheSizeAndContentOfTheCrop() throws {
    var document = AnnotationDocument(scale: 1)
    document.add(.rectangle(CGRect(x: 110, y: 160, width: 50, height: 20)), style: AnnotationStyle(width: .thick))
    document.setCrop(CGRect(x: 100, y: 150, width: 100, height: 50), in: size)
    let bottom = try exported(document)
    #expect(bottom.width == 100 && bottom.height == 50)
    #expect(bottom.hex(x: 50, y: 2) == "#FFFFFF")  // de la mitad de abajo
    #expect(bottom.hex(x: 10, y: 20) == "#FF3B30")  // el borde izquierdo del rectángulo, en x = 110 − 100
    document.setCrop(CGRect(x: 0, y: 0, width: 100, height: 50), in: size)
    #expect(try exported(document).hex(x: 50, y: 25) == "#0000FF")  // de la mitad de arriba
  }

  @Test func undoBringsBackTheWholeCapture() throws {
    var document = AnnotationDocument(scale: 1)
    document.setCrop(CGRect(x: 10, y: 10, width: 50, height: 40), in: size)
    #expect(document.visibleRect(in: size) == CGRect(x: 10, y: 10, width: 50, height: 40))
    document.undo()
    #expect(document.crop == nil)
    #expect(try exported(document).width == 400)
    document.redo()
    #expect(try exported(document).width == 50)
  }

  @Test func annotationsOutsideTheCropAreKept() {
    var document = AnnotationDocument(scale: 1)
    let id = document.add(.arrow(from: CGPoint(x: 300, y: 20), to: CGPoint(x: 380, y: 20)), style: AnnotationStyle())
    document.setCrop(CGRect(x: 0, y: 100, width: 100, height: 100), in: size)
    #expect(document.annotations.map(\.id) == [id])
    #expect(document.hit(CGPoint(x: 340, y: 20)) == id)  // en píxeles de la captura entera
  }

  @Test func cropIsClampedToTheCapture() {
    var document = AnnotationDocument(scale: 1)
    document.setCrop(CGRect(x: -20, y: 150, width: 500, height: 100), in: size)
    #expect(document.crop == CGRect(x: 0, y: 150, width: 400, height: 50))
    document.setCrop(CGRect(x: 0, y: 150, width: 400, height: 50), in: size)  // el mismo: no es un cambio
    document.undo()
    #expect(document.crop == nil)
    #expect(!document.canUndo)
    document.setCrop(CGRect(origin: .zero, size: size), in: size)  // la captura entera no es un recorte
    #expect(document.crop == nil && !document.canUndo)
  }

  @Test func undoingAnAnnotationKeepsTheCrop() {
    var document = AnnotationDocument(scale: 1)
    document.setCrop(CGRect(x: 0, y: 0, width: 100, height: 100), in: size)
    document.add(.step(at: CGPoint(x: 50, y: 50)), style: AnnotationStyle())
    document.undo()
    #expect(document.annotations.isEmpty)
    #expect(document.crop == CGRect(x: 0, y: 0, width: 100, height: 100))
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: value of type 'AnnotationDocument' has no member 'setCrop'`.

- [ ] **Step 3: El recorte en el documento, dentro de deshacer y rehacer**

En `Sources/SinteclaCore/AnnotationDocument.swift`, cambiar:

```swift
  public private(set) var selection: Int?
  private var nextID = 1
  private var undoStack: [[Annotation]] = []
  private var redoStack: [[Annotation]] = []
```

por:

```swift
  public private(set) var selection: Int?
  /// El recorte, en píxeles de la captura entera; nil es la captura entera. La captura no se toca: deshacer lo quita.
  public private(set) var crop: CGRect?
  private var nextID = 1
  /// Lo que se deshace y se rehace: las anotaciones y el recorte, juntos.
  private struct Snapshot: Equatable, Sendable {
    var annotations: [Annotation]
    var crop: CGRect?
  }
  private var undoStack: [Snapshot] = []
  private var redoStack: [Snapshot] = []
  private var snapshot: Snapshot { Snapshot(annotations: annotations, crop: crop) }
```

Y cambiar:

```swift
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
```

por:

```swift
  /// Recorta a `rect` (se ajusta a la captura, de tamaño `size`). La captura entera o nada quitan el recorte.
  public mutating func setCrop(_ rect: CGRect?, in size: CGSize) {
    let full = CGRect(origin: .zero, size: size)
    let clamped = rect.map { $0.standardized.integral.intersection(full) }
    let crop = clamped.flatMap { $0.isEmpty || $0 == full ? nil : $0 }
    guard crop != self.crop else { return }
    undoStack.append(snapshot)
    redoStack.removeAll()
    self.crop = crop
  }

  /// Lo que se ve de la captura (de tamaño `size`): el recorte o la captura entera.
  public func visibleRect(in size: CGSize) -> CGRect {
    crop ?? CGRect(origin: .zero, size: size)
  }

  public mutating func undo() {
    guard let previous = undoStack.popLast() else { return }
    redoStack.append(snapshot)
    restore(previous)
  }

  public mutating func redo() {
    guard let next = redoStack.popLast() else { return }
    undoStack.append(snapshot)
    restore(next)
  }

  private mutating func restore(_ state: Snapshot) {
    annotations = state.annotations
    crop = state.crop
    select(selection)
  }
```

Y cambiar:

```swift
  private mutating func change(_ body: (inout [Annotation]) -> Void) {
    undoStack.append(annotations)
    redoStack.removeAll()
```

por:

```swift
  private mutating func change(_ body: (inout [Annotation]) -> Void) {
    undoStack.append(snapshot)
    redoStack.removeAll()
```

- [ ] **Step 4: Exportar solo la zona recortada**

En `Sources/SinteclaCore/AnnotationRenderer.swift`, cambiar:

```swift
  /// La captura con sus anotaciones, con los píxeles de la captura y su espacio de color.
  public static func render(_ image: CGImage, _ document: AnnotationDocument) -> CGImage? {
    let width = image.width, height = image.height
    let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    draw(document, image: image, in: context)
```

por:

```swift
  /// La captura con sus anotaciones, recortada, con los píxeles de la captura y su espacio de color.
  public static func render(_ image: CGImage, _ document: AnnotationDocument) -> CGImage? {
    let full = CGSize(width: image.width, height: image.height)
    let area = document.visibleRect(in: full)
    let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(data: nil, width: Int(area.width), height: Int(area.height), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    // La captura entera, desplazada para que la zona recortada caiga en el lienzo (este contexto va de abajo arriba).
    context.draw(image, in: CGRect(x: -area.minX, y: area.maxY - full.height, width: full.width, height: full.height))
    context.translateBy(x: 0, y: area.height)
    context.scaleBy(x: 1, y: -1)
    context.translateBy(x: -area.minX, y: -area.minY)
    draw(document, image: image, in: context)
```

- [ ] **Step 5: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 290 tests in 52 suites passed`.

- [ ] **Step 6: Commit**

```bash
git add Sources/SinteclaCore/AnnotationDocument.swift Sources/SinteclaCore/AnnotationRenderer.swift Sources/SinteclaCoreTests/AnnotationCropTests.swift
git commit -m 'feat: recortar la captura sin perderla en el núcleo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: El nombre del archivo y los avisos de guardar

**Files:**
- Create: `Sources/SinteclaCore/CaptureFiles.swift`
- Modify: `Sources/SinteclaCore/CaptureNotice.swift`
- Test: `Sources/SinteclaCoreTests/CaptureFilesTests.swift`

**Interfaces:**
- Consumes: Nada de otras tareas.
- Produces: `CaptureFiles.name(for: Date, timeZone:) -> String` y `freeURL(in: URL, for: Date, timeZone:, exists:) -> URL`; `CaptureNotice.saved(_ folder: String)` y `saveFailed`.

- [ ] **Step 1: Tests del nombre y los avisos**

Crear `Sources/SinteclaCoreTests/CaptureFilesTests.swift`:

```swift
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct CaptureFilesTests {
  private let madrid = TimeZone(identifier: "Europe/Madrid")!

  private func date() throws -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = madrid
    return try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 10, minute: 42, second: 13)))
  }

  @Test func nameLikeMacOS() throws {
    #expect(CaptureFiles.name(for: try date(), timeZone: madrid) == "Captura 2026-09-26 a las 10.42.13.png")
  }

  @Test func freeNameWhenOneAlreadyExists() throws {
    let folder = URL(fileURLWithPath: "/tmp/capturas", isDirectory: true)
    let taken: Set<String> = ["Captura 2026-09-26 a las 10.42.13.png", "Captura 2026-09-26 a las 10.42.13 2.png"]
    let exists: (URL) -> Bool = { taken.contains($0.lastPathComponent) }
    #expect(CaptureFiles.freeURL(in: folder, for: try date(), timeZone: madrid, exists: { _ in false }).lastPathComponent
            == "Captura 2026-09-26 a las 10.42.13.png")
    let url = CaptureFiles.freeURL(in: folder, for: try date(), timeZone: madrid, exists: exists)
    #expect(url.lastPathComponent == "Captura 2026-09-26 a las 10.42.13 3.png")
    #expect(url.deletingLastPathComponent().path == "/tmp/capturas")
  }

  @Test func saveNotices() {
    #expect(CaptureNotice.saved("Escritorio") == "Guardada en Escritorio")
    #expect(CaptureNotice.saveFailed == "No se pudo guardar")
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find 'CaptureFiles' in scope`.

- [ ] **Step 3: `CaptureFiles`**

Crear `Sources/SinteclaCore/CaptureFiles.swift`:

```swift
import Foundation

/// Los archivos de las capturas guardadas (spec «Editor de capturas completo» §4).
public enum CaptureFiles {
  /// «Captura 2026-09-26 a las 10.42.13.png», con la fecha y la hora de la captura, como las de macOS.
  public static func name(for date: Date, timeZone: TimeZone = .current) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd 'a las' HH.mm.ss"
    return "Captura \(formatter.string(from: date)).png"
  }

  /// En `folder`, con ese nombre o, si ya existe, con « 2», « 3»…
  public static func freeURL(in folder: URL, for date: Date, timeZone: TimeZone = .current,
                             exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL {
    let base = String(name(for: date, timeZone: timeZone).dropLast(".png".count))
    var url = folder.appendingPathComponent(base + ".png")
    var number = 2
    while exists(url) {
      url = folder.appendingPathComponent("\(base) \(number).png")
      number += 1
    }
    return url
  }
}
```

- [ ] **Step 4: Los avisos de guardar**

En `Sources/SinteclaCore/CaptureNotice.swift`, cambiar:

```swift
  /// Tab en el editor: el color bajo el cursor.
```

por:

```swift
  /// ⌘S en el editor: el nombre de la carpeta donde se guardó.
  public static func saved(_ folder: String) -> String { "Guardada en \(folder)" }
  public static let saveFailed = "No se pudo guardar"

  /// Tab en el editor: el color bajo el cursor.
```

- [ ] **Step 5: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 293 tests in 53 suites passed`.

- [ ] **Step 6: Commit**

```bash
git add Sources/SinteclaCore/CaptureFiles.swift Sources/SinteclaCore/CaptureNotice.swift Sources/SinteclaCoreTests/CaptureFilesTests.swift
git commit -m 'feat: nombre de archivo y avisos para guardar capturas

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 4: El lienzo con Pixelar y Recortar

**Files:**
- Modify: `Sources/SinteclaCore/AnnotationDocument.swift` (las herramientas) y Test: `Sources/SinteclaCoreTests/AnnotationDocumentTests.swift`
- Modify: `Sources/Sintecla/CaptureCanvas.swift` y `Sources/Sintecla/CaptureEditorWindow.swift` (el título)

**Interfaces:**
- Consumes: Las Tareas 1 y 2; `CaptureEditorModel`, `CaptureCanvasView` y `CaptureEditor` (0.10.0).
- Produces: `AnnotationTool.pixelate` (B) y `.crop` (C); `CaptureEditorModel.cropFrame`, `imageSize`, `shownRect`, `applyCrop()`, `cancelCrop()`; `pixelSize` con el tamaño del recorte; el lienzo mide `shownRect`.

Las herramientas nuevas entran aquí, y no en el núcleo antes, porque el `switch` del lienzo sobre `AnnotationTool` no compilaría a medias. Mientras está Recortar, el lienzo enseña la captura entera con el marco; con las demás, solo el recorte.

- [ ] **Step 1: Test: las teclas B y C**

En `Sources/SinteclaCoreTests/AnnotationDocumentTests.swift`, cambiar:

```swift
    #expect(AnnotationTool.allCases.map(\.key).joined() == "VATRPHNM")
```

por:

```swift
    #expect(AnnotationTool.allCases.map(\.key).joined() == "VATRPHNBMC")
    #expect(AnnotationTool.tool(forKey: "b") == .pixelate)
    #expect(AnnotationTool.tool(forKey: "C") == .crop)
```

- [ ] **Step 2: Ver que falla**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: type 'AnnotationTool?' has no member 'pixelate'`.

- [ ] **Step 3: Pixelar y Recortar en las herramientas**

En `Sources/SinteclaCore/AnnotationDocument.swift`, cambiar:

```swift
  case select, arrow, text, rectangle, pen, highlighter, step, ruler
```

por:

```swift
  case select, arrow, text, rectangle, pen, highlighter, step, pixelate, ruler, crop
```

Y cambiar:

```swift
    case .step: "N"
    case .ruler: "M"
```

por:

```swift
    case .step: "N"
    case .pixelate: "B"
    case .ruler: "M"
    case .crop: "C"
```

Y cambiar:

```swift
    case .step: "Pasos"
    case .ruler: "Regla"
```

por:

```swift
    case .step: "Pasos"
    case .pixelate: "Pixelar"
    case .ruler: "Regla"
    case .crop: "Recortar"
```

Y cambiar:

```swift
    case .step: "1.circle"
    case .ruler: "ruler"
```

por:

```swift
    case .step: "1.circle"
    case .pixelate: "checkerboard.rectangle"
    case .ruler: "ruler"
    case .crop: "crop"
```

- [ ] **Step 4: Ver que pasa**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 293 tests in 53 suites passed`.

- [ ] **Step 5: El lienzo: Pixelar, el marco de Recortar y el tamaño de lo que se enseña**

En `Sources/Sintecla/CaptureCanvas.swift`, cambiar:

```swift
  var ruler: CaptureRuler?
  /// Cada cambio de las anotaciones: el editor vuelve a copiar la captura.
```

por:

```swift
  var ruler: CaptureRuler?
  /// El marco de Recortar mientras se ajusta, en píxeles de la captura entera.
  var cropFrame: CGRect?
  /// La herramienta de antes de Recortar: se vuelve a ella al recortar o al cancelar.
  @ObservationIgnored private var toolBeforeCrop: AnnotationTool = .arrow
  /// Cada cambio de las anotaciones: el editor vuelve a copiar la captura.
```

Y cambiar:

```swift
  var pixelSize: String { "\(image.width) × \(image.height)" }
```

por:

```swift
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
```

Y cambiar:

```swift
  func choose(_ tool: AnnotationTool) {
    self.tool = tool
    ruler = nil
    if tool != .select { document.select(nil) }
  }
```

por:

```swift
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
```

Y cambiar:

```swift
  /// Todo cambio de las anotaciones pasa por aquí.
  func edit(_ change: (inout AnnotationDocument) -> Void) {
    let before = document.annotations
    change(&document)
    if document.annotations != before { onChange?() }
  }
```

por:

```swift
  /// Todo cambio de las anotaciones o del recorte pasa por aquí.
  func edit(_ change: (inout AnnotationDocument) -> Void) {
    let before = (document.annotations, document.crop)
    change(&document)
    if document.annotations != before.0 || document.crop != before.1 { onChange?() }
  }
```

Y cambiar:

```swift
/// El lienzo del editor: la captura y sus anotaciones
```

por:

```swift
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

/// El lienzo del editor: la captura y sus anotaciones
```

Y cambiar:

```swift
    case moving(id: Int, offset: CGVector)
    case measuring
  }
```

por:

```swift
    case moving(id: Int, offset: CGVector)
    case measuring
    /// Un marco nuevo de Recortar.
    case newCrop
    /// Un asa del marco (o, sin asa, el marco entero) desde como estaba.
    case cropping(handle: CropHandle?, from: CGRect)
  }
```

Y cambiar:

```swift
    let scale = model.document.scale
    super.init(frame: NSRect(x: 0, y: 0, width: CGFloat(model.image.width) / scale,
                             height: CGFloat(model.image.height) / scale))
    observe()
```

por:

```swift
    let scale = model.document.scale, area = model.shownRect
    super.init(frame: NSRect(x: 0, y: 0, width: area.width / scale, height: area.height / scale))
    observe()
```

Y cambiar:

```swift
      _ = (model.document, model.tool, model.ruler, model.zoom, model.color, model.highlighterColor, model.width)
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.needsDisplay = true
```

por:

```swift
      _ = (model.document, model.tool, model.ruler, model.zoom, model.color, model.highlighterColor, model.width,
           model.cropFrame)
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.fitToShownArea()
        self.needsDisplay = true
```

Y cambiar:

```swift
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
```

por:

```swift
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
```

Y cambiar:

```swift
    if let ruler = model.ruler { drawRuler(ruler, hairline: hairline, in: context) }
    context.restoreGState()
  }
```

por:

```swift
    if let ruler = model.ruler { drawRuler(ruler, hairline: hairline, in: context) }
    if model.tool == .crop, let frame = model.cropFrame { drawCropFrame(frame, hairline: hairline, in: context) }
    context.restoreGState()
  }
```

Y cambiar:

```swift
    // La medida, en una etiqueta de tamaño fijo en pantalla junto al final de la regla.
    let font = NSFont.monospacedDigitSystemFont(ofSize: 12 * hairline, weight: .semibold)
    let text = NSAttributedString(string: ruler.measure.label,
                                  attributes: [.font: font, .foregroundColor: NSColor.white])
    let size = text.size()
    let pad = 6 * hairline
    let box = CGRect(x: ruler.to.x + 10 * hairline, y: ruler.to.y + 10 * hairline, width: size.width + pad * 2,
                     height: size.height + pad)
```

por:

```swift
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
```

Y cambiar:

```swift
  /// Del ratón a píxeles de la imagen.
  private func imagePoint(_ event: NSEvent) -> CGPoint {
    let point = convert(event.locationInWindow, from: nil)
    return CGPoint(x: point.x * scale, y: point.y * scale)
  }
```

por:

```swift
  /// Del ratón a píxeles de la captura entera.
  private func imagePoint(_ event: NSEvent) -> CGPoint {
    let point = convert(event.locationInWindow, from: nil), area = model.shownRect
    return CGPoint(x: point.x * scale + area.minX, y: point.y * scale + area.minY)
  }
```

Y cambiar:

```swift
    case .highlighter: drag = .drawing(.highlighter([point]))
    case .text: beginText(at: point, id: nil, text: "")
```

por:

```swift
    case .highlighter: drag = .drawing(.highlighter([point]))
    case .pixelate: drag = .drawing(.pixelate(CGRect(origin: point, size: .zero)))
    case .text: beginText(at: point, id: nil, text: "")
```

Y cambiar:

```swift
    case .ruler:
      model.ruler = CaptureRuler(from: point, to: point)
      drag = .measuring
    }
    needsDisplay = true
  }
```

por:

```swift
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
```

Y cambiar:

```swift
    let point = imagePoint(event)
    switch drag {
    case .drawing(.arrow(let from, _))?: drag = .drawing(.arrow(from: from, to: point))
    case .drawing(.rectangle)?:
      drag = .drawing(.rectangle(CGRect(x: min(dragStart.x, point.x), y: min(dragStart.y, point.y),
                                        width: abs(point.x - dragStart.x), height: abs(point.y - dragStart.y))))
```

por:

```swift
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
```

Y cambiar:

```swift
    case .moving(let id, let offset)?:
      model.edit { $0.move(id, by: offset) }
    default: break
    }
    drag = nil
```

por:

```swift
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
```

Y cambiar:

```swift
    switch event.keyCode {
    case 53:  // Esc: suelta la elegida o cierra
```

por:

```swift
    switch event.keyCode {
    case 36 where model.tool == .crop, 76 where model.tool == .crop:  // Intro: recorta
      model.applyCrop()
    case 53 where model.tool == .crop:  // Esc: quita el marco sin recortar
      model.cancelCrop()
    case 53:  // Esc: suelta la elegida o cierra
```

Y cambiar:

```swift
    // El campo deja 2 puntos a la izquierda del texto: así la letra queda donde se dibujará.
    field.frame = NSRect(x: origin.x / scale - 2, y: origin.y / scale, width: max(field.frame.width + 12, 40),
                         height: field.frame.height)
```

por:

```swift
    // El campo deja 2 puntos a la izquierda del texto: así la letra queda donde se dibujará.
    let area = model.shownRect
    field.frame = NSRect(x: (origin.x - area.minX) / scale - 2, y: (origin.y - area.minY) / scale,
                         width: max(field.frame.width + 12, 40), height: field.frame.height)
```

- [ ] **Step 6: El título sigue al recorte**

En `Sources/Sintecla/CaptureEditorWindow.swift`, cambiar:

```swift
    model.onChange = { [weak self] in self?.scheduleCopy() }
```

por:

```swift
    model.onChange = { [weak self] in self?.changed() }
```

Y cambiar:

```swift
  /// Medio segundo después del último cambio, la captura anotada vuelve al portapapeles, sin aviso.
```

por:

```swift
  /// Cada cambio: el título (un recorte cambia el tamaño) y la copia automática.
  private func changed() {
    window.title = "Captura · \(model.pixelSize)"
    scheduleCopy()
  }

  /// Medio segundo después del último cambio, la captura anotada vuelve al portapapeles, sin aviso.
```

- [ ] **Step 7: Compilar la release (sin avisos)**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build of product' | tail -3
```

Esperado: `Build of product 'Sintecla' complete!`.

Si sale alguna línea `warning:`, corrígela antes de seguir.

- [ ] **Step 8: Commit**

```bash
git add Sources/SinteclaCore/AnnotationDocument.swift Sources/SinteclaCoreTests/AnnotationDocumentTests.swift Sources/Sintecla/CaptureCanvas.swift Sources/Sintecla/CaptureEditorWindow.swift
git commit -m 'feat: pixelar y recortar en el editor de capturas

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 5: Guardar

**Files:**
- Modify: `Sources/Sintecla/AppSettings.swift` (`captureFolder`), `Sources/Sintecla/CapturesPage.swift` y `Sources/Sintecla/MainWindow.swift`
- Modify: `Sources/Sintecla/CaptureCanvas.swift` (⌘S), `Sources/Sintecla/CaptureEditorWindow.swift` (Guardar y Guardar como…) y `Sources/Sintecla/CaptureController.swift` (la carpeta)

**Interfaces:**
- Consumes: `CaptureFiles` y `CaptureNotice.saved(_:)`, `saveFailed` (Tarea 3); la Tarea 4.
- Produces: `AppSettings.captureFolder` (UserDefaults `captureFolder`, el Escritorio de fábrica) y `captureFolderURL`; `CapturesPage(settings:)`; `CaptureCanvasView.onSave: ((Bool) -> Void)?`; `CaptureEditor(shot:scale:folder:)`; `CaptureEditorBar(model:onCopy:onSave:onZoom:)`.

- [ ] **Step 1: `AppSettings.captureFolder`**

En `Sources/Sintecla/AppSettings.swift`, cambiar:

```swift
  var moduleCaptures: Bool { didSet { defaults.set(moduleCaptures, forKey: "moduleCaptures") } }
```

por:

```swift
  var moduleCaptures: Bool { didSet { defaults.set(moduleCaptures, forKey: "moduleCaptures") } }
  /// Dónde guarda ⌘S las capturas (spec «Editor de capturas completo» §4). De fábrica, el Escritorio.
  var captureFolder: String { didSet { defaults.set(captureFolder, forKey: "captureFolder") } }
```

Y cambiar:

```swift
      "finderCut": false, "moduleDictation": true, "moduleMeetings": true, "moduleCaptures": false,
    ])
```

por:

```swift
      "finderCut": false, "moduleDictation": true, "moduleMeetings": true, "moduleCaptures": false,
      "captureFolder": Self.desktop,
    ])
```

Y cambiar:

```swift
    moduleCaptures = defaults.bool(forKey: "moduleCaptures")
```

por:

```swift
    moduleCaptures = defaults.bool(forKey: "moduleCaptures")
    captureFolder = defaults.string(forKey: "captureFolder") ?? Self.desktop
```

Y cambiar:

```swift
  /// Qué módulos están encendidos. Finder es el interruptor `finderCut` de la 0.9.0.
```

por:

```swift
  static let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path
    ?? NSHomeDirectory() + "/Desktop"

  var captureFolderURL: URL { URL(fileURLWithPath: captureFolder, isDirectory: true) }

  /// Qué módulos están encendidos. Finder es el interruptor `finderCut` de la 0.9.0.
```

- [ ] **Step 2: La carpeta en la página Capturas**

En `Sources/Sintecla/CapturesPage.swift`, cambiar:

```swift
struct CapturesPage: View {
  @State private var permission
```

por:

```swift
struct CapturesPage: View {
  @Bindable var settings: AppSettings
  @State private var permission
```

Y cambiar:

```swift
      if macOSShortcuts {
```

por:

```swift
      Section("Carpeta de las capturas") {
        LabeledContent("⌘S guarda en") {
          Text(FileManager.default.displayName(atPath: settings.captureFolder))
        }
        Button("Elegir carpeta…", action: chooseFolder)
        Text("En el editor, ⌘S guarda al momento aquí y ⇧⌘S pregunta dónde.")
          .font(.caption).foregroundStyle(.secondary)
      }
      if macOSShortcuts {
```

Y cambiar:

```swift
      macOSShortcuts = ScreenCapture.macOSShortcutsActive
    }
  }
}
```

por:

```swift
      macOSShortcuts = ScreenCapture.macOSShortcutsActive
    }
  }

  private func chooseFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.directoryURL = settings.captureFolderURL
    panel.prompt = "Elegir"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    settings.captureFolder = url.path
  }
}
```

- [ ] **Step 3: La página recibe los ajustes**

En `Sources/Sintecla/MainWindow.swift`, cambiar:

```swift
    case .captures: CapturesPage()
```

por:

```swift
    case .captures: CapturesPage(settings: settings)
```

- [ ] **Step 4: ⌘S y ⇧⌘S en el lienzo**

En `Sources/Sintecla/CaptureCanvas.swift`, cambiar:

```swift
  var onCopy: (() -> Void)?
  var onCopyColor
```

por:

```swift
  var onCopy: (() -> Void)?
  /// ⌘S (false) y ⇧⌘S (true, pregunta dónde).
  var onSave: ((Bool) -> Void)?
  var onCopyColor
```

Y cambiar:

```swift
    case "c": onCopy?()
```

por:

```swift
    case "c": onCopy?()
    case "s": onSave?(shift)
```

- [ ] **Step 5: Guardar y Guardar como… en el editor, y los botones de la izquierda**

En `Sources/Sintecla/CaptureEditorWindow.swift`, cambiar:

```swift
import AppKit
import SinteclaCore
import SwiftUI
```

por:

```swift
import AppKit
import SinteclaCore
import SwiftUI
import UniformTypeIdentifiers
```

Y cambiar:

```swift
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
```

por:

```swift
/// La barra del editor (spec «Capturas» §3.1 y «Editor de capturas completo» §6): Copiar y Guardar, las herramientas,
/// el estilo y, a la derecha, el color bajo el cursor, el tamaño y el zoom.
struct CaptureEditorBar: View {
  let model: CaptureEditorModel
  var onCopy: () -> Void
  var onSave: () -> Void
  var onZoom: (CaptureZoom) -> Void

  var body: some View {
    HStack(spacing: 12) {
      HStack(spacing: 4) {
        actionButton("doc.on.doc", help: "Copiar (⌘C). Cada cambio ya se copia solo", action: onCopy)
        actionButton("square.and.arrow.down", help: "Guardar (⌘S). ⇧⌘S: Guardar como…", action: onSave)
      }
```

Y cambiar:

```swift
  private func barButton(symbol: String, chosen: Bool, help: String, action: @escaping () -> Void) -> some View {
```

por:

```swift
  private func actionButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
    Button(action: action) { Image(systemName: symbol).font(.system(size: 14)).frame(width: 22, height: 20) }
      .buttonStyle(.bordered)
      .help(help)
  }

  private func barButton(symbol: String, chosen: Bool, help: String, action: @escaping () -> Void) -> some View {
```

Y cambiar:

```swift
  private let model: CaptureEditorModel
  private let original: Data
```

por:

```swift
  private let model: CaptureEditorModel
  private let original: Data
  /// Cuándo se hizo la captura: da el nombre del archivo.
  private let captured = Date()
  /// La carpeta de capturas, de los ajustes.
  private let folder: () -> URL
```

Y cambiar:

```swift
  init(shot: ScreenCapture.Shot, scale: CGFloat) {
    model = CaptureEditorModel(image: shot.image, scale: scale)
    original = shot.png
```

por:

```swift
  init(shot: ScreenCapture.Shot, scale: CGFloat, folder: @escaping () -> URL) {
    model = CaptureEditorModel(image: shot.image, scale: scale)
    original = shot.png
    self.folder = folder
```

Y cambiar:

```swift
    let bar = NSHostingView(rootView: CaptureEditorBar(model: model, onCopy: { [weak self] in self?.copyNow() },
                                                      onZoom: { [weak self] in self?.zoom($0) }))
```

por:

```swift
    let bar = NSHostingView(rootView: CaptureEditorBar(model: model, onCopy: { [weak self] in self?.copyNow() },
                                                      onSave: { [weak self] in self?.save(asking: false) },
                                                      onZoom: { [weak self] in self?.zoom($0) }))
```

Y cambiar:

```swift
    canvas.onCopy = { [weak self] in self?.copyNow() }
```

por:

```swift
    canvas.onCopy = { [weak self] in self?.copyNow() }
    canvas.onSave = { [weak self] asking in self?.save(asking: asking) }
```

Y cambiar:

```swift
  /// PNG y TIFF de la captura con sus anotaciones.
```

por:

```swift
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

  /// PNG y TIFF de la captura con sus anotaciones.
```

- [ ] **Step 6: El editor sabe la carpeta de capturas**

En `Sources/Sintecla/CaptureController.swift`, cambiar:

```swift
    let editor = CaptureEditor(shot: shot, scale: ScreenCapture.scaleUnderMouse)
```

por:

```swift
    let editor = CaptureEditor(shot: shot, scale: ScreenCapture.scaleUnderMouse,
                               folder: { [settings] in settings.captureFolderURL })
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

Esperado: `Test run with 293 tests in 53 suites passed`.

- [ ] **Step 9: Commit**

```bash
git add Sources/Sintecla/AppSettings.swift Sources/Sintecla/CapturesPage.swift Sources/Sintecla/MainWindow.swift Sources/Sintecla/CaptureCanvas.swift Sources/Sintecla/CaptureEditorWindow.swift Sources/Sintecla/CaptureController.swift
git commit -m 'feat: guardar capturas con ⌘S y Guardar como…

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 6: Fijar en pantalla

**Files:**
- Create: `Sources/Sintecla/PinnedCapture.swift`
- Modify: `Sources/Sintecla/CaptureCanvas.swift` (⌘P) y `Sources/Sintecla/CaptureEditorWindow.swift` (Fijar, ocultarse y volver)

**Interfaces:**
- Consumes: `AnnotationRenderer.render(_:_:)` (recortado, Tarea 2); `DockPresence` (0.10.0); la Tarea 5.
- Produces: `PinnedCapture(image:scale:frame:)` con `show()`, `close()`, `onReopen` y `onClose`; `PinnedPanel`; `PinnedImageView`; `CaptureCanvasView.onPin`; `CaptureEditorBar(model:onCopy:onSave:onPin:onZoom:)`.

La captura fijada es un panel que no activa Sintecla (como el editor desde la 0.10.0), a nivel flotante y en todos los escritorios. El editor se oculta y deja de contar para el Dock; vuelve con doble clic.

- [ ] **Step 1: La captura fijada**

Crear `Sources/Sintecla/PinnedCapture.swift`:

```swift
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
```

- [ ] **Step 2: ⌘P en el lienzo**

En `Sources/Sintecla/CaptureCanvas.swift`, cambiar:

```swift
  var onSave: ((Bool) -> Void)?
```

por:

```swift
  var onSave: ((Bool) -> Void)?
  /// ⌘P: fijar la captura en pantalla.
  var onPin: (() -> Void)?
```

Y cambiar:

```swift
    case "s": onSave?(shift)
```

por:

```swift
    case "s": onSave?(shift)
    case "p": onPin?()
```

- [ ] **Step 3: Fijar en el editor: el botón, ocultarse y volver**

En `Sources/Sintecla/CaptureEditorWindow.swift`, cambiar:

```swift
/// La barra del editor (spec «Capturas» §3.1 y «Editor de capturas completo» §6): Copiar y Guardar, las herramientas,
/// el estilo y, a la derecha, el color bajo el cursor, el tamaño y el zoom.
```

por:

```swift
/// La barra del editor (spec «Capturas» §3.1 y «Editor de capturas completo» §6): Copiar, Guardar y Fijar, las
/// herramientas, el estilo y, a la derecha, el color bajo el cursor, el tamaño y el zoom.
```

Y cambiar:

```swift
  var onSave: () -> Void
  var onZoom: (CaptureZoom) -> Void
```

por:

```swift
  var onSave: () -> Void
  var onPin: () -> Void
  var onZoom: (CaptureZoom) -> Void
```

Y cambiar:

```swift
        actionButton("square.and.arrow.down", help: "Guardar (⌘S). ⇧⌘S: Guardar como…", action: onSave)
```

por:

```swift
        actionButton("square.and.arrow.down", help: "Guardar (⌘S). ⇧⌘S: Guardar como…", action: onSave)
        actionButton("pin", help: "Fijar en pantalla (⌘P)", action: onPin)
```

Y cambiar:

```swift
  /// Cuenta las copias: si una copia termina después de otra más nueva, no pisa el portapapeles.
  private var copies = 0
```

por:

```swift
  /// Cuenta las copias: si una copia termina después de otra más nueva, no pisa el portapapeles.
  private var copies = 0
  /// La captura fijada en pantalla; mientras está, el editor se oculta.
  private var pinned: PinnedCapture?
```

Y cambiar:

```swift
    window.minSize = NSSize(width: 880, height: 320)
```

por:

```swift
    window.minSize = NSSize(width: 1000, height: 320)
```

Y cambiar:

```swift
                                                      onSave: { [weak self] in self?.save(asking: false) },
```

por:

```swift
                                                      onSave: { [weak self] in self?.save(asking: false) },
                                                      onPin: { [weak self] in self?.pin() },
```

Y cambiar:

```swift
    canvas.onSave = { [weak self] asking in self?.save(asking: asking) }
```

por:

```swift
    canvas.onSave = { [weak self] asking in self?.save(asking: asking) }
    canvas.onPin = { [weak self] in self?.pin() }
```

Y cambiar:

```swift
  // MARK: - Guardar
```

por:

```swift
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
```

- [ ] **Step 4: Compilar la release (sin avisos)**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build of product' | tail -3
```

Esperado: `Build of product 'Sintecla' complete!`.

- [ ] **Step 5: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 293 tests in 53 suites passed`.

- [ ] **Step 6: Commit**

```bash
git add Sources/Sintecla/PinnedCapture.swift Sources/Sintecla/CaptureCanvas.swift Sources/Sintecla/CaptureEditorWindow.swift
git commit -m 'feat: fijar la captura flotando en pantalla

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 7: Versión 0.11.0, README y spec principal

**Files:**
- Modify: `Sources/SinteclaCoreTests/SmokeTests.swift`, `Sources/SinteclaCore/AppInfo.swift` y `Resources/Info.plist`
- Modify: `README.md` y `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§7)

**Interfaces:**
- Consumes: Todo lo anterior.
- Produces: La versión 0.11.0 (build 12), instalada.

La línea «Estado» de la spec principal y la etiqueta `v0.11.0` se ponen al cerrar la versión, cuando el usuario lo pida.

- [ ] **Step 1: El test de la versión**

En `Sources/SinteclaCoreTests/SmokeTests.swift`, cambiar:

```swift
#expect(AppInfo.version == "0.10.0")
```

por:

```swift
#expect(AppInfo.version == "0.11.0")
```

- [ ] **Step 2: Ver que falla**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA el test con `Expectation failed: (AppInfo.version → "0.10.0") == "0.11.0"`.

- [ ] **Step 3: `AppInfo.version`**

En `Sources/SinteclaCore/AppInfo.swift`, cambiar:

```swift
public static let version = "0.10.0"
```

por:

```swift
public static let version = "0.11.0"
```

- [ ] **Step 4: `Info.plist`**

En `Resources/Info.plist`, cambiar:

```xml
  <key>CFBundleShortVersionString</key><string>0.10.0</string>
  <key>CFBundleVersion</key><string>11</string>
```

por:

```xml
  <key>CFBundleShortVersionString</key><string>0.11.0</string>
  <key>CFBundleVersion</key><string>12</string>
```

- [ ] **Step 5: Ver que pasa**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 293 tests in 53 suites passed`.

- [ ] **Step 6: README: pixelar, recortar, guardar y fijar**

En `README.md`, cambiar:

```text
(flecha, texto, rectángulo, lápiz, subrayador, pasos numerados, regla y color bajo el cursor). Cada cambio se vuelve a copiar solo.
```

por:

```text
(flecha, texto, rectángulo, lápiz, subrayador, pasos numerados, pixelar, regla, recortar y color bajo el cursor). Cada cambio se vuelve a copiar solo; ⌘S la guarda en archivo y ⌘P la deja flotando encima de todo.
```

Y cambiar:

```text
En el editor, cada herramienta tiene su tecla (V, A, T, R, P, H, N y M), `Tab` copia el color bajo el cursor y `⌘Z` deshace.
```

por:

```text
En el editor, cada herramienta tiene su tecla (V, A, T, R, P, H, N, B, M y C), `Tab` copia el color bajo el cursor, `⌘Z` deshace, `⌘S` guarda (`⇧⌘S`, Guardar como…) y `⌘P` fija la captura en pantalla.
```

Y cambiar:

```text
- **Las capturas no se guardan en disco**: van al portapapeles, y el archivo temporal de macOS se borra al leerlo.
```

por:

```text
- **Las capturas solo se guardan en disco si pulsas ⌘S** (en la carpeta que elijas en la página Capturas). Si no, van al portapapeles, y el archivo temporal de macOS se borra al leerlo.
```

- [ ] **Step 7: Spec principal (§7): el editor completo**

En `docs/superpowers/specs/2026-09-23-sintecla-design.md`, cambiar:

```text
una ventana por captura, con Copiar, las herramientas (Seleccionar, Flecha, Texto, Rectángulo, Lápiz, Subrayador, Pasos y Regla), 6 colores, 3 grosores, el color bajo el cursor, el tamaño y el zoom. La captura anotada vuelve sola al portapapeles medio segundo después de cada cambio. Mientras hay un editor abierto, Sintecla sale en el Dock.
```

por:

```text
una ventana por captura, con Copiar, las herramientas (Seleccionar, Flecha, Texto, Rectángulo, Lápiz, Subrayador, Pasos y Regla), 6 colores, 3 grosores, el color bajo el cursor, el tamaño y el zoom. La captura anotada vuelve sola al portapapeles medio segundo después de cada cambio. Mientras hay un editor abierto, Sintecla sale en el Dock. Desde la 0.11.0 (ver `2026-09-26-capturas-editor-design.md`): Pixelar y Recortar (se deshace), Guardar (⌘S en la carpeta de capturas, ⇧⌘S Guardar como…) y Fijar (⌘P: la captura flota encima de todo; doble clic vuelve al editor).
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
git commit -m 'feat: versión 0.11.0 con el editor de capturas completo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

- [ ] **Step 10: Instalar la versión nueva**

Run:

```bash
scripts/build-app.sh
```

Esperado: `✅ Instalada en /Applications/Sintecla.app`. Los permisos se conservan.

---
### Task 8: Aceptación a mano

**Files:**
- —

**Interfaces:**
- Consumes: La app instalada (Tarea 7).
- Produces: Nada nuevo. Con todo ✓, la 0.11.0 se cierra cuando el usuario lo pida: `capturas-editor` a `main`, etiqueta `v0.11.0`, la línea «Estado» de la spec principal y, si lo pide, el push.

La hace el usuario (spec §8.2), con el módulo Capturas encendido.

- [ ] **Step 1: Checklist. Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | Pixelar (B) sobre un correo o un número; una flecha encima | No se lee; la flecha se ve. Con el grosor grueso, cuadros más grandes |
| 2 | Seleccionar la zona pixelada, moverla, ⌫ y ⌘Z | Se mueve, se borra y vuelve |
| 3 | Recortar (C): arrastrar un marco, ajustarlo con las asas y moverlo; Intro | El lienzo se queda con esa zona y el título dice su tamaño |
| 4 | ⌘Z tras recortar; C otra vez y Esc | Vuelve la captura entera; Esc quita el marco sin recortar |
| 5 | Tras recortar, esperar un segundo y pegar en Notas sin ⌘C | Sale recortada |
| 6 | ⌘S dos veces | Dos archivos en el Escritorio: «Captura … .png» y «Captura … 2.png»; la pastilla dice «Guardada en Escritorio» |
| 7 | Página Capturas → «Elegir carpeta…» otra carpeta; ⌘S | Se guarda en la nueva |
| 8 | ⇧⌘S | La ventana de guardar de macOS, con el nombre puesto |
| 9 | ⌘P (o Fijar) con otra app delante | La captura flota encima, el editor desaparece y la otra app sigue con el teclado |
| 10 | Arrastrar la captura fijada; rueda o pellizcar | Se mueve; cambia de tamaño sin mover la esquina de arriba |
| 11 | Doble clic en la captura fijada | Vuelve el editor, como estaba (⌘Z sigue funcionando) |
| 12 | Fijar otra vez, clic en ella y Esc | Se cierra, y su editor también |
| 13 | Dos capturas fijadas a la vez, cambiando de escritorio | Las dos siguen encima, en todos los escritorios |
| 14 | Lo de la 0.10.0 (herramientas, copia automática, ⇧⌘2, ⇧⌘1), dictado, Finder y Reuniones | Como antes |

---
## Autorrevisión frente a la especificación

| Requisito (spec «Editor de capturas completo») | Dónde |
|---|---|
| §2 Pixelar: B, cuadros por grosor, solo la captura y debajo de las anotaciones, anotación normal, clic sin arrastrar | Tareas 1 y 4 |
| §3 Recortar: C, marco con asas y tamaño, Intro y Esc, lienzo y título, copia automática, deshacer, anotaciones de fuera conservadas | Tareas 2 y 4 |
| §4 Guardar: ⌘S a la carpeta de capturas (Escritorio, página Capturas), nombre con la hora de la captura y sufijo, ⇧⌘S, avisos | Tareas 3 y 5 |
| §5 Fijar: ⌘P y botón, flota sin activar, mismo sitio y tamaño, mover, escalar 20–400 %, doble clic, Esc y ⌘W, varias, Dock | Tarea 6 |
| §6 Barra: Copiar, Guardar y Fijar como iconos; diez herramientas | Tareas 4 a 6 |
| §7 Piezas y 0.11.0 (build 12), README y spec principal | Tareas 1 a 7 |
| §8.1 Tests: pixelar, recortar, nombre, avisos, herramientas | Tareas 1 a 4 |
| §8.2 Aceptación | Tarea 8 |

**Consistencia de tipos revisada:**
- `AnnotationShape.pixelate` y `AnnotationWidth.pixelBlock` (Tarea 1) los usa el lienzo (Tarea 4).
- `AnnotationDocument.setCrop(_:in:)` y `visibleRect(in:)` (Tarea 2) los usan `CaptureEditorModel.applyCrop`, `shownRect` y `pixelSize` (Tarea 4).
- `CaptureFiles.freeURL(in:for:)` y `CaptureNotice.saved(_:)` y `saveFailed` (Tarea 3) los usa `CaptureEditor.save` (Tarea 5).
- `CaptureEditorBar(model:onCopy:onSave:onZoom:)` (Tarea 5) pasa a `(model:onCopy:onSave:onPin:onZoom:)` en la Tarea 6.
- `CaptureEditor(shot:scale:folder:)` (Tarea 5) lo crea `CaptureController.openEditor`.
