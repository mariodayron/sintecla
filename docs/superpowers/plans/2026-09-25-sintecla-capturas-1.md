# Sintecla — Capturas sin editor (0.10.0, plan de Capturas 1) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** El módulo Capturas, todavía sin editor:
- ⇧⌘3 (pantalla) y ⇧⌘4 (zona o ventana) copian la captura al portapapeles;
- ⇧⌘2 copia el texto de una zona, o el contenido de un QR;
- ⇧⌘1 hace lo mismo y además abre una tarjeta para traducir o preguntar;
- el módulo tiene su página (permiso y atajos), su tarjeta en Inicio y su bloque en el menú.

**Architecture:**
- **En el núcleo (`SinteclaCore`), puro y con tests:**
  - `CaptureShortcut`: de la tecla a la acción;
  - `TextRecognizer`: OCR y códigos con Vision de Apple, con las filas en orden;
  - `CaptureNotice`: los avisos de la pastilla;
  - `CaptureAssistant`: traducir y preguntar, con respaldo;
  - `Module.captures`: el módulo.
- **En la app:**
  - `ScreenCapture` lanza `screencapture` de macOS a un archivo temporal que se borra al leerlo, y comprueba el permiso;
  - `CaptureController` va del atajo a la captura, al portapapeles y a la pastilla o la tarjeta;
  - `CaptureTextCardPanel` es la tarjeta de ⇧⌘1;
  - `EventTap` le pasa las teclas después de Finder.

**Tech Stack:** Lo de siempre:
- Swift 6.3 de las Command Line Tools, en modo de lenguaje 5;
- SwiftPM, Swift Testing, SwiftUI y AppKit;
- además, Vision (OCR y códigos), NaturalLanguage (idioma del texto), CoreImage (QR de los tests) y `/usr/sbin/screencapture`.

**Especificación:** `docs/superpowers/specs/2026-09-25-capturas-design.md` (§2, §4, §5 y §8, plan 1).

**Punto de partida:** la rama `modulos` (módulos hechos y aceptados; especificación de Capturas):

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
- **Módulo «Capturas»:** UserDefaults `moduleCaptures`, **apagado de fábrica**. Va el cuarto en Módulos, tras Dictado, Reuniones y Finder.
- **Atajos:**

  | Atajo | Código de tecla | Acción |
  |---|---|---|
  | ⇧⌘1 | 18 | Texto con la tarjeta |
  | ⇧⌘2 | 19 | Texto |
  | ⇧⌘3 | 20 | Pantalla |
  | ⇧⌘4 | 21 | Zona o ventana |

  - Solo con ⇧⌘ y ninguna otra modificadora, y con el módulo encendido.
  - Van en la cadena del `EventTap` después de los atajos de dictado y de Finder.
- **Captura:** `/usr/sbin/screencapture -x`, a `<temporal>/Sintecla-capturas/<uuid>.png`, que se borra al leerlo.
  - `-D <n>` para la pantalla bajo el ratón, con 1 para la principal, en el orden de `CGGetActiveDisplayList`.
  - `-i` para la cruz de macOS.
- **Portapapeles:**
  - las imágenes en PNG y en TIFF;
  - el texto, como texto;
  - los códigos, su contenido, uno por línea, y van **antes** que el texto.
- **OCR:** `VNRecognizeTextRequest` preciso, `es-ES` y `en-US`, con corrección de idioma. Las filas se forman si dos cajas se solapan más de la mitad de la más baja.
- **Avisos:**
  - «Captura copiada»;
  - «Texto copiado · N palabras» (en singular, «1 palabra»);
  - «QR copiado: …» o «Código copiado: …», con el contenido cortado a 40 caracteres y «…»;
  - «N códigos copiados» si hay varios;
  - «No hay texto en esa zona»;
  - «Falta el permiso de Grabación de pantalla».
  - Con la pastilla grabando o procesando, no salen.
- **Tarjeta de ⇧⌘1:**
  - **Traducir:** del español al idioma de «Traducir a» (si es el español, al inglés); de cualquier otro, al español. Primero Apple y, de respaldo, Gemini.
  - **Preguntar:** primero Gemini y, de respaldo, Apple (temperatura 0,4).
  - **Esc** la cierra.
- **Versión:** sigue en 0.9.0. La 0.10.0 se pone con el editor (plan de Capturas 2).
- **Commits:** en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código de este plan se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `modulos`: compiló, pasó los tests en cada tarea y el árbol final quedó idéntico al del prototipo.

- **263 tests** (48 suites) en verde: los 245 de antes y 18 nuevos. La release compila sin avisos.
- **Vision funciona en el ejecutable de tests,** sin la app:
  - lee «Configuración: añadir 3 términos», con las tildes, en una imagen dibujada con CoreText;
  - lee `https://example.com` en un QR generado con CoreImage;
  - no encuentra nada en una imagen en blanco.
- **En el Mac del usuario, los atajos de captura de macOS 28 a 31 (⇧⌘3, ⇧⌘4 y sus variantes con ⌃) están desactivados.** ⇧⌘5 sigue activo y no se usa.
- **Sin probar en la app** (lo comprueba la aceptación de la Tarea 7):
  - que el permiso de Grabación de pantalla de Sintecla valga para el `screencapture` que lanza;
  - que `-D` numere las pantallas como `CGGetActiveDisplayList`;
  - que la tarjeta, un `NSPanel` que no activa la app, reciba el teclado.

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| La tarjeta de Ask Anything nunca toma el foco: en ella no se podría escribir la pregunta ni editar el texto | `KeyablePanel` (`canBecomeKey`) sin activar la app. Esc se atiende en `sendEvent`, antes que el `TextEditor`, que usaría Esc para autocompletar (Tarea 6) |
| Con el módulo sin el caso `.captures`, los `switch` de la app no compilarían a medias | El caso entra en la Tarea 4, junto con su página y la tarjeta de Inicio. Las Tareas 1 a 3 solo tocan el núcleo |
| El `FakeTranslator` de los tests ya existe (`TranslationTests.swift`) | `CaptureAssistantTests` lo reutiliza |
| Vision puede devolver el mismo QR dos veces | `TextRecognizer` quita los contenidos repetidos |
| Una segunda captura mientras está la cruz de macOS | `CaptureController.busy`: una cada vez |

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/CaptureShortcut.swift`, `Sources/SinteclaCoreTests/CaptureShortcutTests.swift` | `CaptureAction` y de la tecla a la acción | 1 |
| `Sources/SinteclaCore/TextRecognizer.swift`, `Sources/SinteclaCore/CaptureNotice.swift`, `Sources/SinteclaCoreTests/TextRecognizerTests.swift` | OCR, códigos, filas y avisos | 2 |
| `Sources/SinteclaCore/CaptureAssistant.swift`, `Sources/SinteclaCoreTests/CaptureAssistantTests.swift` | Traducir y preguntar | 3 |
| `Sources/SinteclaCore/Modules.swift`, `Sources/SinteclaCoreTests/ModulesTests.swift`, `Sources/Sintecla/AppSettings.swift`, `Sources/Sintecla/ScreenCapture.swift`, `Sources/Sintecla/CapturesPage.swift`, `Sources/Sintecla/HomeView.swift`, `Sources/Sintecla/MainWindow.swift` | El módulo, el permiso, la captura y el portapapeles, la página y la tarjeta de Inicio | 4 |
| `Sources/Sintecla/CaptureController.swift`, `Sources/Sintecla/DictationController.swift`, `Sources/Sintecla/MenuBar.swift`, `Sources/Sintecla/AppDelegate.swift` | Atajos, captura al portapapeles, OCR y el bloque del menú | 5 |
| `Sources/Sintecla/CaptureTextCard.swift`, `Sources/Sintecla/CaptureController.swift` | La tarjeta de ⇧⌘1 | 6 |

---

### Task 1: Los atajos de Capturas

**Files:**
- Create: `Sources/SinteclaCore/CaptureShortcut.swift`
- Test: `Sources/SinteclaCoreTests/CaptureShortcutTests.swift`

**Interfaces:**
- Consumes: `ComboModifier` (`Sources/SinteclaCore/HotkeyTypes.swift`).
- Produces: `CaptureAction` (`.screen`, `.area`, `.text`, `.textCard`; `CaseIterable` en ese orden; `key`, `shortcut` («⇧⌘3»), `title`); `CaptureShortcut.action(keyCode: Int64, modifiers: Set<ComboModifier>) -> CaptureAction?`; `CaptureShortcut.summary`.

De la pulsación a la acción, sin AppKit. La app (Tarea 5) solo la consulta.

- [ ] **Step 1: Tests de los atajos**

Crear `Sources/SinteclaCoreTests/CaptureShortcutTests.swift`:

```swift
import Testing
@testable import SinteclaCore

@Suite struct CaptureShortcutTests {
  @Test func shiftCommandOneToFour() {
    #expect(CaptureShortcut.action(keyCode: 18, modifiers: [.shift, .command]) == .textCard)
    #expect(CaptureShortcut.action(keyCode: 19, modifiers: [.shift, .command]) == .text)
    #expect(CaptureShortcut.action(keyCode: 20, modifiers: [.shift, .command]) == .screen)
    #expect(CaptureShortcut.action(keyCode: 21, modifiers: [.shift, .command]) == .area)
  }

  @Test func otherKeysOrModifiersDoNothing() {
    #expect(CaptureShortcut.action(keyCode: 20, modifiers: [.command]) == nil)
    #expect(CaptureShortcut.action(keyCode: 20, modifiers: [.shift, .command, .control]) == nil)
    #expect(CaptureShortcut.action(keyCode: 20, modifiers: [.shift, .command, .option]) == nil)
    #expect(CaptureShortcut.action(keyCode: 23, modifiers: [.shift, .command]) == nil)  // ⇧⌘5 es de macOS
    #expect(CaptureShortcut.action(keyCode: 7, modifiers: [.shift, .command]) == nil)
  }

  @Test func labelsForMenuAndPage() {
    #expect(CaptureAction.screen.shortcut == "⇧⌘3")
    #expect(CaptureAction.textCard.shortcut == "⇧⌘1")
    #expect(CaptureAction.allCases.map(\.title) == ["Capturar pantalla", "Capturar zona o ventana", "Copiar texto",
                                                    "Texto con traducir y preguntar"])
    #expect(CaptureAction.area.key == "4")
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find 'CaptureShortcut' in scope`.

- [ ] **Step 3: `CaptureAction` y `CaptureShortcut`**

Crear `Sources/SinteclaCore/CaptureShortcut.swift`:

```swift
/// Lo que hace cada atajo del módulo Capturas (spec «Capturas» §2.2).
public enum CaptureAction: String, CaseIterable, Sendable {
  case screen, area, text, textCard

  /// La tecla que acompaña a ⇧⌘.
  public var key: String {
    switch self {
    case .screen: "3"
    case .area: "4"
    case .text: "2"
    case .textCard: "1"
    }
  }

  public var shortcut: String { "⇧⌘" + key }

  public var title: String {
    switch self {
    case .screen: "Capturar pantalla"
    case .area: "Capturar zona o ventana"
    case .text: "Copiar texto"
    case .textCard: "Texto con traducir y preguntar"
    }
  }
}

public enum CaptureShortcut {
  /// ⇧⌘1 a ⇧⌘4 (códigos de tecla 18 a 21), con ⇧⌘ y ninguna otra modificadora; nil con cualquier otra pulsación.
  public static func action(keyCode: Int64, modifiers: Set<ComboModifier>) -> CaptureAction? {
    guard modifiers == [.shift, .command] else { return nil }
    switch keyCode {
    case 18: return .textCard
    case 19: return .text
    case 20: return .screen
    case 21: return .area
    default: return nil
    }
  }

  /// Resumen para la tarjeta de Inicio.
  public static let summary = "⇧⌘4 zona · ⇧⌘2 texto"
}
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 248 tests in 45 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/CaptureShortcut.swift Sources/SinteclaCoreTests/CaptureShortcutTests.swift
git commit -m 'feat: atajos ⇧⌘1 a ⇧⌘4 del módulo Capturas

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: Texto y códigos de una imagen, y los avisos

**Files:**
- Create: `Sources/SinteclaCore/TextRecognizer.swift`
- Create: `Sources/SinteclaCore/CaptureNotice.swift`
- Test: `Sources/SinteclaCoreTests/TextRecognizerTests.swift`

**Interfaces:**
- Consumes: `TextMetrics.wordCount(_:)` (ya existe).
- Produces: `RecognizedLine(text:box:)`, `RecognizedCode(payload:isQR:)`, `RecognizedContent` (`.codes`, `.text`, `.nothing`; `copiedText: String?`); `TextRecognizer.recognize(_ image: CGImage) async throws -> RecognizedContent`, `content(codes:lines:)`, `compose(lines:)`; `CaptureNotice.copied`, `noText`, `noPermission`, `text(_:)`, `codes(_:)`.

Vision trabaja en coordenadas normalizadas con el origen abajo a la izquierda: «arriba» es `midY` mayor. Los tests con Vision de verdad dibujan su propia imagen (CoreText) o generan un QR (CoreImage): no hace falta la pantalla.

- [ ] **Step 1: Tests: filas, códigos, Vision de verdad y avisos**

Crear `Sources/SinteclaCoreTests/TextRecognizerTests.swift`:

```swift
import CoreGraphics
import CoreImage
import CoreText
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct TextRecognizerTests {
  /// Caja en coordenadas normalizadas de Vision (origen abajo a la izquierda).
  private func line(_ text: String, x: Double, y: Double, width: Double = 0.2, height: Double = 0.04) -> RecognizedLine {
    RecognizedLine(text: text, box: CGRect(x: x, y: y, width: width, height: height))
  }

  @Test func rowsFromTopToBottomAndLeftToRight() {
    let lines = [
      line("segunda", x: 0.1, y: 0.50),
      line("derecha", x: 0.6, y: 0.80),
      line("izquierda", x: 0.1, y: 0.81),  // misma fila que «derecha» (se solapan)
      line("tercera", x: 0.1, y: 0.20),
    ]
    #expect(TextRecognizer.compose(lines: lines) == "izquierda derecha\nsegunda\ntercera")
  }

  @Test func barelyTouchingLinesAreDifferentRows() {
    let lines = [line("arriba", x: 0.1, y: 0.53), line("abajo", x: 0.5, y: 0.50)]  // se solapan 0,01 de 0,04
    #expect(TextRecognizer.compose(lines: lines) == "arriba\nabajo")
  }

  @Test func codesGoBeforeText() {
    let code = RecognizedCode(payload: "https://example.com", isQR: true)
    #expect(TextRecognizer.content(codes: [code], lines: [line("hola", x: 0, y: 0)]) == .codes([code]))
    #expect(TextRecognizer.content(codes: [], lines: [line("hola", x: 0, y: 0)]) == .text("hola"))
    #expect(TextRecognizer.content(codes: [], lines: [line("  ", x: 0, y: 0)]) == .nothing)
    #expect(RecognizedContent.codes([code, RecognizedCode(payload: "123", isQR: false)]).copiedText == "https://example.com\n123")
  }

  @Test func readsSpanishTextWithVision() async throws {
    let image = try #require(Self.render("Configuración: añadir 3 términos"))
    let content = try await TextRecognizer.recognize(image)
    guard case .text(let text) = content else { Issue.record("sin texto: \(content)"); return }
    #expect(text.contains("Configuración"))
    #expect(text.contains("términos"))
  }

  @Test func readsAQRCodeWithVision() async throws {
    let image = try #require(Self.qr("https://example.com"))
    #expect(try await TextRecognizer.recognize(image) == .codes([RecognizedCode(payload: "https://example.com", isQR: true)]))
  }

  @Test func blankImageHasNothing() async throws {
    let image = try #require(Self.render(""))
    #expect(try await TextRecognizer.recognize(image) == .nothing)
  }

  /// Texto negro sobre blanco, a 48 pt, como en una captura.
  static func render(_ text: String) -> CGImage? {
    let width = 1400, height = 200
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let font = CTFontCreateWithName("Helvetica" as CFString, 48, nil)
    let attributes: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key(kCTFontAttributeName as String): font,
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1),
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    context.textPosition = CGPoint(x: 40, y: 80)
    CTLineDraw(line, context)
    return context.makeImage()
  }

  static func qr(_ payload: String) -> CGImage? {
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(Data(payload.utf8), forKey: "inputMessage")
    guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)) else { return nil }
    let padded = output.transformed(by: CGAffineTransform(translationX: 60, y: 60))
      .composited(over: CIImage(color: .white).cropped(to: output.extent.insetBy(dx: -60, dy: -60).offsetBy(dx: 60, dy: 60)))
    return CIContext().createCGImage(padded, from: padded.extent)
  }
}

@Suite struct CaptureNoticeTests {
  @Test func textWithWordCount() {
    #expect(CaptureNotice.text("hola") == "Texto copiado · 1 palabra")
    #expect(CaptureNotice.text("Configuración: añadir 3 términos\nsegunda línea") == "Texto copiado · 6 palabras")
  }

  @Test func codesShowTheirContentCut() {
    #expect(CaptureNotice.codes([RecognizedCode(payload: "https://example.com", isQR: true)]) == "QR copiado: https://example.com")
    #expect(CaptureNotice.codes([RecognizedCode(payload: "8412345678905", isQR: false)]) == "Código copiado: 8412345678905")
    let long = String(repeating: "a", count: 50)
    #expect(CaptureNotice.codes([RecognizedCode(payload: long, isQR: true)]) == "QR copiado: " + String(repeating: "a", count: 40) + "…")
    #expect(CaptureNotice.codes([RecognizedCode(payload: "a", isQR: true), RecognizedCode(payload: "b", isQR: false)])
            == "2 códigos copiados")
  }

  @Test func fixedNotices() {
    #expect(CaptureNotice.copied == "Captura copiada")
    #expect(CaptureNotice.noText == "No hay texto en esa zona")
    #expect(CaptureNotice.noPermission == "Falta el permiso de Grabación de pantalla")
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find type 'RecognizedLine' in scope`.

- [ ] **Step 3: `TextRecognizer`: OCR y códigos con Vision**

Crear `Sources/SinteclaCore/TextRecognizer.swift`:

```swift
import CoreGraphics
import Foundation
import Vision

/// Una línea que ha leído el OCR, con su caja en coordenadas normalizadas de Vision (origen abajo a la izquierda).
public struct RecognizedLine: Equatable, Sendable {
  public var text: String
  public var box: CGRect

  public init(text: String, box: CGRect) {
    self.text = text
    self.box = box
  }
}

/// El contenido de un QR o de un código de barras.
public struct RecognizedCode: Equatable, Sendable {
  public var payload: String
  public var isQR: Bool

  public init(payload: String, isQR: Bool) {
    self.payload = payload
    self.isQR = isQR
  }
}

/// Lo que hay en una zona de la pantalla (spec «Capturas» §2.4): códigos, texto o nada.
public enum RecognizedContent: Equatable, Sendable {
  case codes([RecognizedCode])
  case text(String)
  case nothing

  /// Lo que se copia al portapapeles: los códigos, uno por línea, o el texto.
  public var copiedText: String? {
    switch self {
    case .codes(let codes): codes.map(\.payload).joined(separator: "\n")
    case .text(let text): text
    case .nothing: nil
    }
  }
}

/// OCR y lectura de códigos con Vision de Apple, en español e inglés.
public enum TextRecognizer {
  public static func recognize(_ image: CGImage) async throws -> RecognizedContent {
    try await Task.detached(priority: .userInitiated) {
      let textRequest = VNRecognizeTextRequest()
      textRequest.recognitionLevel = .accurate
      textRequest.recognitionLanguages = ["es-ES", "en-US"]
      textRequest.usesLanguageCorrection = true
      let codeRequest = VNDetectBarcodesRequest()
      try VNImageRequestHandler(cgImage: image).perform([textRequest, codeRequest])
      let lines = (textRequest.results ?? []).compactMap { observation in
        observation.topCandidates(1).first.map { RecognizedLine(text: $0.string, box: observation.boundingBox) }
      }
      var codes: [RecognizedCode] = []
      for observation in codeRequest.results ?? [] {
        guard let payload = observation.payloadStringValue, !codes.contains(where: { $0.payload == payload }) else { continue }
        codes.append(RecognizedCode(payload: payload, isQR: observation.symbology == .qr))
      }
      return content(codes: codes, lines: lines)
    }.value
  }

  /// Si hay códigos, van ellos; si no, el texto; si no hay nada legible, nada.
  public static func content(codes: [RecognizedCode], lines: [RecognizedLine]) -> RecognizedContent {
    if !codes.isEmpty { return .codes(codes) }
    let text = compose(lines: lines).trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? .nothing : .text(text)
  }

  /// Filas de arriba abajo; en cada fila, los trozos de izquierda a derecha unidos por un espacio.
  public static func compose(lines: [RecognizedLine]) -> String {
    var rows: [[RecognizedLine]] = []
    for line in lines.sorted(by: { $0.box.midY > $1.box.midY }) {
      if let index = rows.firstIndex(where: { sameRow($0[0].box, line.box) }) {
        rows[index].append(line)
      } else {
        rows.append([line])
      }
    }
    return rows.map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
      .joined(separator: "\n")
  }

  /// Misma fila si se solapan en vertical más de la mitad de la más baja.
  static func sameRow(_ a: CGRect, _ b: CGRect) -> Bool {
    let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
    return overlap > 0.5 * min(a.height, b.height)
  }
}
```

- [ ] **Step 4: `CaptureNotice`: los avisos de la pastilla**

Crear `Sources/SinteclaCore/CaptureNotice.swift`:

```swift
/// Los avisos de la pastilla del módulo Capturas (spec «Capturas» §2).
public enum CaptureNotice {
  public static let copied = "Captura copiada"
  public static let noText = "No hay texto en esa zona"
  public static let noPermission = "Falta el permiso de Grabación de pantalla"
  /// Largo máximo del contenido de un código en el aviso.
  static let maxPayload = 40

  public static func text(_ text: String) -> String {
    let words = TextMetrics.wordCount(text)
    return "Texto copiado · \(words) \(words == 1 ? "palabra" : "palabras")"
  }

  public static func codes(_ codes: [RecognizedCode]) -> String {
    guard codes.count == 1, let code = codes.first else { return "\(codes.count) códigos copiados" }
    let payload = code.payload.count > maxPayload ? String(code.payload.prefix(maxPayload)) + "…" : code.payload
    return (code.isQR ? "QR copiado: " : "Código copiado: ") + payload
  }
}
```

- [ ] **Step 5: Ver que pasan (los de Vision tardan unos segundos)**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 257 tests in 47 suites passed`.

- [ ] **Step 6: Commit**

```bash
git add Sources/SinteclaCore/TextRecognizer.swift Sources/SinteclaCore/CaptureNotice.swift Sources/SinteclaCoreTests/TextRecognizerTests.swift
git commit -m 'feat: texto y códigos de una imagen con Vision

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: Traducir y preguntar sobre el texto

**Files:**
- Create: `Sources/SinteclaCore/CaptureAssistant.swift`
- Test: `Sources/SinteclaCoreTests/CaptureAssistantTests.swift`

**Interfaces:**
- Consumes: `Translating`, `TranslationLanguage.resolve(target:source:)`, `TextModel`; en los tests, `FakeTranslator`, `FakeModel` y `FailingModel` (ya existen).
- Produces: `CaptureAssistant(translators: [Translating], models: [TextModel])`; `static languages(for: String, preferred: TranslationLanguage) -> (source, target)`; `translate(_:preferred:) async -> String?`; `ask(_ question: String, about text: String) async -> String?`.

Recibe los traductores y los modelos ya en orden: la app (Tarea 6) decide cuáles hay (con o sin clave de Gemini, con o sin Apple Intelligence).

- [ ] **Step 1: Tests de traducir y preguntar**

Crear `Sources/SinteclaCoreTests/CaptureAssistantTests.swift`:

```swift
import Testing
@testable import SinteclaCore

@Suite struct CaptureAssistantTests {
  @Test func spanishGoesToTheChosenLanguageAndTheRestToSpanish() {
    let spanish = "Configuración de la cuenta: añade tu correo y la contraseña nueva"
    let english = "Please add your email address and the new password to the account settings"
    let french = "Veuillez ajouter votre adresse e-mail et le nouveau mot de passe"
    #expect(CaptureAssistant.languages(for: spanish, preferred: .en) == (.es, .en))
    #expect(CaptureAssistant.languages(for: spanish, preferred: .fr) == (.es, .fr))
    #expect(CaptureAssistant.languages(for: spanish, preferred: .es) == (.es, .en))  // al mismo idioma no se traduce
    #expect(CaptureAssistant.languages(for: english, preferred: .en) == (.en, .es))
    #expect(CaptureAssistant.languages(for: french, preferred: .en) == (.fr, .es))
  }

  @Test func translatesWithTheFallbackIfTheFirstFails() async {
    let failing = FakeTranslator { _, _ in nil }
    let fallback = FakeTranslator { text, to in "[→\(to.rawValue)] \(text)" }
    let assistant = CaptureAssistant(translators: [failing, fallback], models: [])
    let text = "Please add your email address and the new password"
    #expect(await assistant.translate(text, preferred: .en) == "[→es] \(text)")
  }

  @Test func emptyTranslationCountsAsFailure() async {
    let empty = FakeTranslator { _, _ in "  " }
    #expect(await CaptureAssistant(translators: [empty], models: []).translate("hello world", preferred: .en) == nil)
  }

  @Test func asksTheFallbackModelAndSendsTextAndQuestion() async {
    let answer = FakeModel { prompt in prompt.contains("«Pago pendiente: 42 €»") && prompt.contains("¿Qué debo?") ? "42 euros" : "?" }
    let assistant = CaptureAssistant(translators: [], models: [FailingModel(), answer])
    #expect(await assistant.ask("¿Qué debo?", about: "Pago pendiente: 42 €") == "42 euros")
  }

  @Test func noModelNoAnswer() async {
    #expect(await CaptureAssistant(translators: [], models: [FailingModel()]).ask("¿Qué es?", about: "x") == nil)
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find 'CaptureAssistant' in scope`.

- [ ] **Step 3: `CaptureAssistant`**

Crear `Sources/SinteclaCore/CaptureAssistant.swift`:

```swift
import Foundation
import NaturalLanguage

/// Traducir y preguntar sobre el texto de una captura: la tarjeta de ⇧⌘1 (spec «Capturas» §2.5).
public struct CaptureAssistant: Sendable {
  /// En orden: Apple y, de respaldo, Gemini.
  public let translators: [Translating]
  /// En orden: Gemini y, de respaldo, Apple.
  public let models: [TextModel]

  static let askInstructions = """
    Responde en español, breve y claro, a la pregunta de la persona sobre el texto que ha copiado de su pantalla. \
    Básate en ese texto; si no basta, dilo. Sin saludos ni despedidas.
    """
  static let maxAnswerTokens = 600

  public init(translators: [Translating], models: [TextModel]) {
    self.translators = translators
    self.models = models
  }

  /// Un texto en español va al idioma de «Traducir a» (o al inglés, si también es el español); cualquier otro, al español.
  public static func languages(for text: String, preferred: TranslationLanguage) -> (source: TranslationLanguage, target: TranslationLanguage) {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    let source = recognizer.dominantLanguage.flatMap { TranslationLanguage(rawValue: String($0.rawValue.prefix(2))) } ?? .en
    return source == .es ? (.es, TranslationLanguage.resolve(target: preferred, source: .es)) : (source, .es)
  }

  /// nil si ningún traductor lo consigue.
  public func translate(_ text: String, preferred: TranslationLanguage) async -> String? {
    let (source, target) = Self.languages(for: text, preferred: preferred)
    for translator in translators {
      guard let output = try? await translator.translate(text, from: source, to: target) else { continue }
      let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    return nil
  }

  /// nil si ningún modelo responde.
  public func ask(_ question: String, about text: String) async -> String? {
    let prompt = "Texto:\n«\(text)»\n\nPregunta: \(question)"
    for model in models {
      guard let output = try? await model.complete(instructions: Self.askInstructions, prompt: prompt,
                                                   maxTokens: Self.maxAnswerTokens) else { continue }
      let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    return nil
  }
}
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 262 tests in 48 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/CaptureAssistant.swift Sources/SinteclaCoreTests/CaptureAssistantTests.swift
git commit -m 'feat: traducir y preguntar sobre el texto de una captura

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 4: El módulo Capturas, su página y el permiso

**Files:**
- Modify: `Sources/SinteclaCore/Modules.swift` y Test: `Sources/SinteclaCoreTests/ModulesTests.swift`
- Modify: `Sources/Sintecla/AppSettings.swift` (`moduleCaptures`)
- Create: `Sources/Sintecla/ScreenCapture.swift`
- Create: `Sources/Sintecla/CapturesPage.swift`
- Modify: `Sources/Sintecla/HomeView.swift` (tarjeta de Inicio) y `Sources/Sintecla/MainWindow.swift` (página)

**Interfaces:**
- Consumes: `CaptureAction`, `CaptureShortcut.summary` (Tarea 1) y `CaptureNotice.noPermission` (Tarea 2).
- Produces: `Module.captures`, `ModulePage.captures`, `ModuleSwitches.captures` (con `captures: Bool = false` en el `init`); `AppSettings.moduleCaptures`; `ScreenCapture` (`hasPermission`, `requestPermission()`, `openPermissionSettings()`, `openKeyboardShortcuts()`, `macOSShortcutsActive`, `capture(_ kind: Kind) async -> Shot?`, `copyImage(_:)`, `copyText(_:)`, `displayUnderMouse()`); `CapturesPage()`.

Tras esta tarea, el módulo se puede encender en Módulos y su página enseña el permiso y los atajos. Los atajos aún no hacen nada: llegan en la Tarea 5.

- [ ] **Step 1: Tests: el módulo Capturas, apagado salvo que se diga**

En `Sources/SinteclaCoreTests/ModulesTests.swift`, cambiar:

```swift
  let allOn = ModuleSwitches(dictation: true, meetings: true, finder: true)
```

por:

```swift
  let allOn = ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true)
```

Y cambiar:

```swift
    #expect(Module.finder.pages == [.finderCut])
```

por:

```swift
    #expect(Module.finder.pages == [.finderCut])
    #expect(Module.captures.pages == [.captures])
```

Y cambiar:

```swift
    #expect(Module.allCases.map(\.name) == ["Dictado", "Reuniones", "Finder"])
```

por:

```swift
    #expect(Module.allCases.map(\.name) == ["Dictado", "Reuniones", "Finder", "Capturas"])
    #expect(ModulePage.captures.title == "Capturas")
```

Y cambiar:

```swift
    #expect(allOn.enabled == [.dictation, .meetings, .finder])
```

por:

```swift
    #expect(allOn.enabled == [.dictation, .meetings, .finder, .captures])
```

Y cambiar:

```swift
    #expect(switches[.dictation] && switches[.finder])
  }
```

por:

```swift
    #expect(switches[.dictation] && switches[.finder] && switches[.captures])
    switches[.captures] = false
    #expect(!switches.captures)
  }

  @Test func capturesIsOffUnlessSaid() {
    #expect(!ModuleSwitches(dictation: true, meetings: true, finder: true).captures)
  }
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: extra argument 'captures' in call`.

- [ ] **Step 3: `Module.captures`, su página y su interruptor**

En `Sources/SinteclaCore/Modules.swift`, cambiar:

```swift
  case dictation, meetings, finder

  public var name
```

por:

```swift
  case dictation, meetings, finder, captures

  public var name
```

Y cambiar:

```swift
    case .finder: "Finder"
    }
```

por:

```swift
    case .finder: "Finder"
    case .captures: "Capturas"
    }
```

Y cambiar:

```swift
    case .finder: "folder"
    }
```

por:

```swift
    case .finder: "folder"
    case .captures: "camera.viewfinder"
    }
```

Y cambiar:

```swift
    case .finder: "⌘X corta los archivos seleccionados y ⌘V los mueve a la carpeta abierta, como en Windows."
```

por:

```swift
    case .finder: "⌘X corta los archivos seleccionados y ⌘V los mueve a la carpeta abierta, como en Windows."
    case .captures: "⇧⌘3 pantalla, ⇧⌘4 zona, ⇧⌘2 texto y ⇧⌘1 texto con traducir y preguntar. Necesita el permiso de "
      + "Grabación de pantalla."
```

Y cambiar:

```swift
  case finderCut

  public var module: Module {
```

por:

```swift
  case finderCut
  case captures

  public var module: Module {
```

Y cambiar:

```swift
    case .finderCut: .finder
    }
```

por:

```swift
    case .finderCut: .finder
    case .captures: .captures
    }
```

Y cambiar:

```swift
    case .finderCut: "Cortar y pegar"
    }
```

por:

```swift
    case .finderCut: "Cortar y pegar"
    case .captures: "Capturas"
    }
```

Y cambiar:

```swift
    case .finderCut: "scissors"
    }
```

por:

```swift
    case .finderCut: "scissors"
    case .captures: "camera.viewfinder"
    }
```

Y cambiar:

```swift
  public var finder: Bool

  public init(dictation: Bool, meetings: Bool, finder: Bool) {
    self.dictation = dictation
    self.meetings = meetings
    self.finder = finder
  }
```

por:

```swift
  public var finder: Bool
  public var captures: Bool

  public init(dictation: Bool, meetings: Bool, finder: Bool, captures: Bool = false) {
    self.dictation = dictation
    self.meetings = meetings
    self.finder = finder
    self.captures = captures
  }
```

Y cambiar:

```swift
      case .finder: finder
      }
    }
```

por:

```swift
      case .finder: finder
      case .captures: captures
      }
    }
```

Y cambiar:

```swift
      case .finder: finder = newValue
      }
```

por:

```swift
      case .finder: finder = newValue
      case .captures: captures = newValue
      }
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 263 tests in 48 suites passed`.

- [ ] **Step 5: `AppSettings.moduleCaptures`**

En `Sources/Sintecla/AppSettings.swift`, cambiar:

```swift
  var moduleMeetings: Bool { didSet { defaults.set(moduleMeetings, forKey: "moduleMeetings") } }
```

por:

```swift
  var moduleMeetings: Bool { didSet { defaults.set(moduleMeetings, forKey: "moduleMeetings") } }
  /// Módulo Capturas (spec «Capturas»), apagado por defecto.
  var moduleCaptures: Bool { didSet { defaults.set(moduleCaptures, forKey: "moduleCaptures") } }
```

Y cambiar:

```swift
      "finderCut": false, "moduleDictation": true, "moduleMeetings": true,
```

por:

```swift
      "finderCut": false, "moduleDictation": true, "moduleMeetings": true, "moduleCaptures": false,
```

Y cambiar:

```swift
    moduleMeetings = defaults.bool(forKey: "moduleMeetings")
```

por:

```swift
    moduleMeetings = defaults.bool(forKey: "moduleMeetings")
    moduleCaptures = defaults.bool(forKey: "moduleCaptures")
```

Y cambiar:

```swift
    get { ModuleSwitches(dictation: moduleDictation, meetings: moduleMeetings, finder: finderCut) }
```

por:

```swift
    get { ModuleSwitches(dictation: moduleDictation, meetings: moduleMeetings, finder: finderCut, captures: moduleCaptures) }
```

Y cambiar:

```swift
      if finderCut != newValue.finder { finderCut = newValue.finder }
```

por:

```swift
      if finderCut != newValue.finder { finderCut = newValue.finder }
      if moduleCaptures != newValue.captures { moduleCaptures = newValue.captures }
```

- [ ] **Step 6: `ScreenCapture`: `screencapture`, permiso, pantalla bajo el ratón y portapapeles**

Crear `Sources/Sintecla/ScreenCapture.swift`:

```swift
import AppKit
import CoreGraphics
import ImageIO

/// Capturas con la herramienta de macOS (`screencapture`), el permiso de Grabación de pantalla y el portapapeles
/// (spec «Capturas» §2.1 y §2.3).
@MainActor
enum ScreenCapture {
  struct Shot {
    let png: Data
    let image: CGImage
  }

  enum Kind {
    /// La pantalla donde está el ratón (⇧⌘3).
    case screenUnderMouse
    /// La cruz de macOS: zona, o ventana con Espacio (⇧⌘4, ⇧⌘2, ⇧⌘1).
    case interactive
  }

  static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

  /// La primera vez, macOS enseña su aviso y añade Sintecla a la lista de Grabación de pantalla.
  static func requestPermission() {
    _ = CGRequestScreenCaptureAccess()
  }

  static func openPermissionSettings() {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
  }

  static func openKeyboardShortcuts() {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
  }

  /// ⇧⌘3 o ⇧⌘4 siguen activos como atajos de captura de macOS (28 y 30 en `com.apple.symbolichotkeys`; si no
  /// aparecen, están como vienen de fábrica: activos).
  static var macOSShortcutsActive: Bool {
    let hotkeys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
    return ["28", "30"].contains { id in
      guard let entry = hotkeys[id] as? [String: Any] else { return true }
      return (entry["enabled"] as? Bool) ?? true
    }
  }

  /// nil si se cancela (Esc) o falla. El archivo temporal se borra al leerlo: las capturas no quedan en disco.
  static func capture(_ kind: Kind) async -> Shot? {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Sintecla-capturas", isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appendingPathComponent(UUID().uuidString + ".png")
    defer { try? FileManager.default.removeItem(at: file) }
    var arguments = ["-x"]  // sin el sonido de macOS: avisa la pastilla
    switch kind {
    case .screenUnderMouse: arguments += ["-D", String(displayUnderMouse())]
    case .interactive: arguments += ["-i"]
    }
    arguments.append(file.path)
    _ = await run("/usr/sbin/screencapture", arguments)
    guard let png = try? Data(contentsOf: file), !png.isEmpty,
          let source = CGImageSourceCreateWithData(png as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    return Shot(png: png, image: image)
  }

  /// Número de la pantalla bajo el ratón para `screencapture -D`: 1 es la principal, en el orden de CoreGraphics.
  static func displayUnderMouse() -> Int {
    let mouse = CGEvent(source: nil)?.location ?? .zero
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &displays, &count)
    return (displays.firstIndex { CGDisplayBounds($0).contains(mouse) } ?? 0) + 1
  }

  /// En PNG y en TIFF, para que la acepten todas las apps.
  static func copyImage(_ shot: Shot) {
    let item = NSPasteboardItem()
    item.setData(shot.png, forType: .png)
    if let tiff = NSBitmapImageRep(data: shot.png)?.tiffRepresentation { item.setData(tiff, forType: .tiff) }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects([item])
  }

  static func copyText(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }

  private static func run(_ path: String, _ arguments: [String]) async -> Bool {
    await withCheckedContinuation { continuation in
      let process = Process()
      process.executableURL = URL(fileURLWithPath: path)
      process.arguments = arguments
      process.terminationHandler = { continuation.resume(returning: $0.terminationStatus == 0) }
      do {
        try process.run()
      } catch {
        continuation.resume(returning: false)
      }
    }
  }
}
```

- [ ] **Step 7: La página Capturas**

Crear `Sources/Sintecla/CapturesPage.swift`:

```swift
import SinteclaCore
import SwiftUI

/// Capturas → Capturas (spec «Capturas» §2.1 y §2.2): el permiso, los atajos y el aviso si macOS aún usa ⇧⌘3 o ⇧⌘4.
struct CapturesPage: View {
  @State private var permission = ScreenCapture.hasPermission
  @State private var macOSShortcuts = ScreenCapture.macOSShortcutsActive
  private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

  var body: some View {
    Form {
      Section("Permiso") {
        LabeledContent("Grabación de pantalla") {
          Label(permission ? "Dado" : "Falta", systemImage: permission ? "checkmark.circle.fill" : "xmark.circle")
        }
        if !permission {
          HStack {
            Button("Dar permiso…") { ScreenCapture.requestPermission() }
            Button("Abrir Ajustes") { ScreenCapture.openPermissionSettings() }
          }
          Text("Sin él, macOS entrega capturas vacías. Después de darlo, sal de Sintecla y vuelve a abrirla.")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      Section("Atajos") {
        ForEach(CaptureAction.allCases, id: \.self) { action in
          LabeledContent(action.title, value: action.shortcut)
        }
        Text("⇧⌘3 y ⇧⌘4 copian la captura al portapapeles. ⇧⌘2 copia el texto de una zona o el contenido de un QR; "
             + "⇧⌘1, además, abre una tarjeta para traducirlo o preguntar. Mientras el módulo está encendido, estos "
             + "atajos no llegan a otras apps.")
          .font(.caption).foregroundStyle(.secondary)
      }
      if macOSShortcuts {
        Section {
          Label("macOS también usa ⇧⌘3 o ⇧⌘4: desactívalos en Ajustes → Teclado → Atajos de teclado → Capturas de "
                + "pantalla.", systemImage: "exclamationmark.triangle")
          Button("Abrir los atajos de teclado") { ScreenCapture.openKeyboardShortcuts() }
        }
      }
    }
    .formStyle(.grouped)
    .onReceive(timer) { _ in
      permission = ScreenCapture.hasPermission
      macOSShortcuts = ScreenCapture.macOSShortcutsActive
    }
  }
}
```

- [ ] **Step 8: La tarjeta de Capturas en Inicio**

En `Sources/Sintecla/HomeView.swift`, cambiar:

```swift
    case .finder:
      Text("⌘X corta y ⌘V mueve archivos en Finder").foregroundStyle(.secondary)
    }
```

por:

```swift
    case .finder:
      Text("⌘X corta y ⌘V mueve archivos en Finder").foregroundStyle(.secondary)
    case .captures:
      Text(CaptureShortcut.summary).foregroundStyle(.secondary)
      if !ScreenCapture.hasPermission {
        Label(CaptureNotice.noPermission, systemImage: "exclamationmark.triangle").font(.callout)
      }
    }
```

- [ ] **Step 9: La página en la ventana**

En `Sources/Sintecla/MainWindow.swift`, cambiar:

```swift
    case .finderCut: FinderCutPage()
```

por:

```swift
    case .finderCut: FinderCutPage()
    case .captures: CapturesPage()
```

- [ ] **Step 10: Compilar la release (sin avisos)**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build of product' | tail -3
```

Esperado: `Build of product 'Sintecla' complete!`.

Si sale alguna línea `warning:`, corrígela antes de seguir.

- [ ] **Step 11: Commit**

```bash
git add Sources/SinteclaCore/Modules.swift Sources/SinteclaCoreTests/ModulesTests.swift Sources/Sintecla/AppSettings.swift Sources/Sintecla/ScreenCapture.swift Sources/Sintecla/CapturesPage.swift Sources/Sintecla/HomeView.swift Sources/Sintecla/MainWindow.swift
git commit -m 'feat: módulo Capturas con su página y el permiso

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 5: Atajos, captura al portapapeles y texto

**Files:**
- Create: `Sources/Sintecla/CaptureController.swift` (sin la tarjeta)
- Modify: `Sources/Sintecla/DictationController.swift` (`onKeyDown`, avisos, `runCapture`, `onShowCaptures`)
- Modify: `Sources/Sintecla/MenuBar.swift` (bloque Capturas) y `Sources/Sintecla/AppDelegate.swift`

**Interfaces:**
- Consumes: Todo lo de las Tareas 1, 2 y 4. `EventTap.onKeyDown`, `FinderCutter` y `showToolNotice` (0.9.0).
- Produces: `CaptureController(settings:appleModel:)`, con `keyDown(keyCode:modifiers:) -> Bool`, `run(_ action: CaptureAction) async`, `onNotice: ((String, String) -> Void)?` y `onNeedsPermission`; `DictationController.runCapture(_:)` y `onShowCaptures`; `MenuActions.capture`; `showToolNotice(_:symbol:)`.

⇧⌘1 hace, de momento, lo mismo que ⇧⌘2. La tarjeta llega en la Tarea 6.

- [ ] **Step 1: `CaptureController`: del atajo al portapapeles y la pastilla**

Crear `Sources/Sintecla/CaptureController.swift`:

```swift
import AppKit
import SinteclaCore

/// Módulo Capturas (spec «Capturas» §2): de cada atajo a la captura, el portapapeles y la pastilla o la tarjeta.
@MainActor
final class CaptureController {
  static let imageSymbol = "camera.viewfinder"
  static let textSymbol = "text.viewfinder"
  static let codeSymbol = "qrcode.viewfinder"

  /// Aviso para la pastilla, con su símbolo.
  var onNotice: ((String, String) -> Void)?
  /// Falta el permiso de Grabación de pantalla: se abre la página Capturas.
  var onNeedsPermission: (() -> Void)?

  private let settings: AppSettings
  private let appleModel: AppleTextModel?
  /// Una captura cada vez: mientras está la cruz de macOS, otro atajo no hace nada.
  private var busy = false

  init(settings: AppSettings, appleModel: AppleTextModel?) {
    self.settings = settings
    self.appleModel = appleModel
  }

  /// Lo llama el `EventTap` con cada pulsación que no usan los atajos de dictado ni Finder. `true`: Sintecla se la queda.
  func keyDown(keyCode: Int64, modifiers: Set<ComboModifier>) -> Bool {
    guard settings.moduleCaptures, let action = CaptureShortcut.action(keyCode: keyCode, modifiers: modifiers) else {
      return false
    }
    Task { await run(action) }
    return true
  }

  func run(_ action: CaptureAction) async {
    guard !busy else { return }
    guard ScreenCapture.hasPermission else {
      onNotice?(CaptureNotice.noPermission, "exclamationmark.triangle")
      onNeedsPermission?()
      return
    }
    busy = true
    defer { busy = false }
    guard let shot = await ScreenCapture.capture(action == .screen ? .screenUnderMouse : .interactive) else { return }
    switch action {
    case .screen, .area:
      ScreenCapture.copyImage(shot)
      onNotice?(CaptureNotice.copied, Self.imageSymbol)
    case .text, .textCard:
      let content = (try? await TextRecognizer.recognize(shot.image)) ?? .nothing
      guard let text = content.copiedText else {
        onNotice?(CaptureNotice.noText, Self.textSymbol)
        return
      }
      ScreenCapture.copyText(text)
      if case .codes(let codes) = content {
        onNotice?(CaptureNotice.codes(codes), Self.codeSymbol)
      } else {
        onNotice?(CaptureNotice.text(text), Self.textSymbol)
      }
    }
  }
}
```

- [ ] **Step 2: `DictationController`: Capturas en la cadena de teclas, detrás de Finder, y sus avisos**

En `Sources/Sintecla/DictationController.swift`, cambiar:

```swift
  var onRecordingChange: ((Bool) -> Void)?
```

por:

```swift
  var onRecordingChange: ((Bool) -> Void)?
  /// Abrir la página Capturas (falta el permiso de Grabación de pantalla).
  var onShowCaptures: (() -> Void)?
```

Y cambiar:

```swift
  /// Herramientas: cortar y pegar archivos en Finder.
  private lazy var finderCutter = FinderCutter(settings: settings)
```

por:

```swift
  /// Herramientas: cortar y pegar archivos en Finder.
  private lazy var finderCutter = FinderCutter(settings: settings)
  /// Módulo Capturas.
  private lazy var captures = CaptureController(settings: settings, appleModel: appleModel)
```

Y cambiar:

```swift
    eventTap.onKeyDown = { [weak self] keyCode, modifiers in
      MainActor.assumeIsolated { self?.finderCutter.keyDown(keyCode: keyCode, modifiers: modifiers) ?? false }
    }
    finderCutter.onNotice = { [weak self] text in self?.showToolNotice(text) }
```

por:

```swift
    // Después de los atajos de dictado: primero Finder y luego Capturas.
    eventTap.onKeyDown = { [weak self] keyCode, modifiers in
      MainActor.assumeIsolated {
        guard let self else { return false }
        return self.finderCutter.keyDown(keyCode: keyCode, modifiers: modifiers)
          || self.captures.keyDown(keyCode: keyCode, modifiers: modifiers)
      }
    }
    finderCutter.onNotice = { [weak self] text in self?.showToolNotice(text, symbol: FinderCutter.symbol) }
    captures.onNotice = { [weak self] text, symbol in self?.showToolNotice(text, symbol: symbol) }
    captures.onNeedsPermission = { [weak self] in self?.onShowCaptures?() }
```

Y cambiar:

```swift
  func pasteLastResult() {
```

por:

```swift
  /// Menú → Capturas.
  func runCapture(_ action: CaptureAction) {
    Task { await captures.run(action) }
  }

  func pasteLastResult() {
```

Y cambiar:

```swift
  private func showToolNotice(_ text: String) {
    guard machine.state == .idle, session == nil else { return }
    show(.notice(text, symbol: FinderCutter.symbol))
  }
```

por:

```swift
  private func showToolNotice(_ text: String, symbol: String) {
    guard machine.state == .idle, session == nil else { return }
    show(.notice(text, symbol: symbol))
  }
```

- [ ] **Step 3: El bloque Capturas en el menú**

En `Sources/Sintecla/MenuBar.swift`, cambiar:

```swift
  var showPermissions: () -> Void
  var settingsChanged: () -> Void
}
```

por:

```swift
  var showPermissions: () -> Void
  var settingsChanged: () -> Void
  var capture: (CaptureAction) -> Void
}
```

Y cambiar:

```swift
    if modules.meetings { addMeetings(to: menu) }
```

por:

```swift
    if modules.meetings { addMeetings(to: menu) }
    if modules.captures { addCaptures(to: menu) }
```

Y cambiar:

```swift
  private func addMeetings(to menu: NSMenu) {
```

por:

```swift
  private func addCaptures(to menu: NSMenu) {
    menu.addItem(.separator())
    menu.addItem(.sectionHeader(title: "Capturas"))
    for action in CaptureAction.allCases {
      let item = ClosureMenuItem(action.title, key: action.key) { [weak self] in self?.actions.capture(action) }
      item.keyEquivalentModifierMask = [.shift, .command]
      menu.addItem(item)
    }
  }

  private func addMeetings(to menu: NSMenu) {
```

- [ ] **Step 4: `AppDelegate`: el menú y «falta el permiso» abren Capturas**

En `Sources/Sintecla/AppDelegate.swift`, cambiar:

```swift
      settingsChanged: { [weak self] in self?.controller.applySettings() }))
```

por:

```swift
      settingsChanged: { [weak self] in self?.controller.applySettings() },
      capture: { [weak self] in self?.controller.runCapture($0) }))
```

Y cambiar:

```swift
    controller.onRecordingChange = { [weak self] recording in self?.menuBar.setRecording(recording) }
```

por:

```swift
    controller.onRecordingChange = { [weak self] recording in self?.menuBar.setRecording(recording) }
    controller.onShowCaptures = { [weak self] in self?.mainWindow.show(.page(.captures)) }
```

- [ ] **Step 5: Compilar la release (sin avisos)**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build of product' | tail -3
```

Esperado: `Build of product 'Sintecla' complete!`.

- [ ] **Step 6: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 263 tests in 48 suites passed`.

- [ ] **Step 7: Commit**

```bash
git add Sources/Sintecla/CaptureController.swift Sources/Sintecla/DictationController.swift Sources/Sintecla/MenuBar.swift Sources/Sintecla/AppDelegate.swift
git commit -m 'feat: ⇧⌘3, ⇧⌘4 y ⇧⌘2 copian la captura o su texto

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 6: La tarjeta de ⇧⌘1

**Files:**
- Create: `Sources/Sintecla/CaptureTextCard.swift`
- Modify: `Sources/Sintecla/CaptureController.swift` (la tarjeta y los traductores y modelos)

**Interfaces:**
- Consumes: `CaptureAssistant` (Tarea 3); `CaptureController` (Tarea 5); `CardButton`, `FirstMouseHostingView` y `AskCardView.markdown` (Ask Anything); `AppSettings.cloudModel()` y `translationTarget`; `AppleTranslator`, `ModelTranslator`, `AppleTextModel`.
- Produces: `CaptureTextCardPanel(assistant:preferred:)`, con `show(_ text: String)`; `KeyablePanel`; `CaptureCardModel`; `CaptureTextCardView`.

La tarjeta **sí** toma el teclado (a diferencia de la de Ask Anything), sin activar Sintecla: hay que poder editar el texto y escribir la pregunta.

- [ ] **Step 1: La tarjeta: texto, Copiar, Traducir y Preguntar**

Crear `Sources/Sintecla/CaptureTextCard.swift`:

```swift
import AppKit
import Observation
import SinteclaCore
import SwiftUI

/// Estado de la tarjeta de ⇧⌘1.
@MainActor @Observable
final class CaptureCardModel {
  var text = ""
  var translation: String?
  var answer: String?
  var question = ""
  /// El campo de la pregunta está a la vista.
  var asking = false
  var working = false
  var problem: String?
  /// Lo último que se copió («texto», «traducción» o «respuesta»), para el «Copiado».
  var copied: String?
}

/// La tarjeta de ⇧⌘1 (spec «Capturas» §2.5): el texto (se puede editar), su traducción y la respuesta a una pregunta.
struct CaptureTextCardView: View {
  @Bindable var model: CaptureCardModel
  var onCopy: (String, String) -> Void
  var onTranslate: () -> Void
  var onAsk: () -> Void
  var onClose: () -> Void
  @FocusState private var questionFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: CaptureController.textSymbol)
          .font(.system(size: 14, weight: .semibold))
          .frame(width: 30, height: 30)
          .background(.quaternary, in: .circle)
        Text("Texto de la pantalla").font(.system(.headline, design: .rounded))
        Spacer(minLength: 8)
        Button(action: onClose) {
          Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
            .frame(width: 26, height: 26).background(.quaternary, in: .circle)
        }
        .buttonStyle(.plain)
        .help("Cerrar (Esc)")
      }
      TextEditor(text: $model.text)
        .font(.system(size: 14))
        .scrollContentBackground(.hidden)
        .padding(8)
        .frame(height: 120)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
      if let translation = model.translation { result("Traducción", translation, key: "traducción") }
      if model.asking {
        TextField("Pregunta sobre el texto (Intro para enviar)", text: $model.question)
          .textFieldStyle(.roundedBorder)
          .focused($questionFocused)
          .onSubmit(onAsk)
          .onAppear { questionFocused = true }
      }
      if let answer = model.answer { result("Respuesta", answer, key: "respuesta") }
      if let problem = model.problem { Text(problem).font(.callout).foregroundStyle(.secondary) }
      HStack(spacing: 8) {
        if model.working { ProgressView().controlSize(.small) }
        Spacer()
        CardButton(title: model.copied == "texto" ? "Copiado" : "Copiar",
                   symbol: model.copied == "texto" ? "checkmark" : "doc.on.doc", prominent: false) {
          onCopy(model.text, "texto")
        }
        CardButton(title: "Traducir", symbol: "translate", prominent: false, action: onTranslate)
        CardButton(title: "Preguntar", symbol: "sparkles", prominent: true, action: onAsk)
      }
    }
    .padding(16)
    .glassEffect(.regular, in: .rect(cornerRadius: 26))
    .padding(6)
    .frame(width: 492)
  }

  private func result(_ title: String, _ text: String, key: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(title).font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(.secondary)
        Spacer()
        Button(model.copied == key ? "Copiado" : "Copiar") { onCopy(text, key) }
          .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
      }
      ScrollView {
        Text(AskCardView.markdown(text)).font(.system(size: 14)).textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 160)
    }
  }
}

/// Panel que acepta el teclado sin activar Sintecla (para editar el texto y escribir la pregunta). Esc lo cierra.
final class KeyablePanel: NSPanel {
  override var canBecomeKey: Bool { true }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown, event.keyCode == 53 {  // 53 = Esc
      orderOut(nil)
      return
    }
    super.sendEvent(event)
  }
}

@MainActor
final class CaptureTextCardPanel {
  let model = CaptureCardModel()
  private let panel: KeyablePanel
  private var hosting: FirstMouseHostingView<CaptureTextCardView>!
  private let assistant: () -> CaptureAssistant
  private let preferred: () -> TranslationLanguage

  init(assistant: @escaping () -> CaptureAssistant, preferred: @escaping () -> TranslationLanguage) {
    self.assistant = assistant
    self.preferred = preferred
    panel = KeyablePanel(contentRect: NSRect(x: 0, y: 0, width: 492, height: 300),
                         styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
    panel.isFloatingPanel = true
    panel.level = .statusBar
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false  // el cristal ya lleva su sombra
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    hosting = FirstMouseHostingView(rootView: CaptureTextCardView(
      model: model,
      onCopy: { [weak self] text, key in self?.copy(text, key: key) },
      onTranslate: { [weak self] in self?.translate() },
      onAsk: { [weak self] in self?.ask() },
      onClose: { [weak self] in self?.close() }))
    panel.contentView = hosting
  }

  func show(_ text: String) {
    model.text = text
    model.translation = nil
    model.answer = nil
    model.question = ""
    model.asking = false
    model.working = false
    model.problem = nil
    model.copied = nil
    place()
    panel.makeKeyAndOrderFront(nil)
  }

  func close() {
    panel.orderOut(nil)
  }

  /// Abajo en el centro de la pantalla del ratón, encima de la pastilla; crece hacia arriba.
  private func place() {
    // SwiftUI aplica los cambios del modelo más tarde: sin forzar el layout se mediría el contenido anterior.
    hosting.layoutSubtreeIfNeeded()
    let size = hosting.fittingSize
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    guard let visible = screen?.visibleFrame else { return }
    panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.minY + 86, width: size.width, height: size.height),
                   display: true)
  }

  private func copy(_ text: String, key: String) {
    ScreenCapture.copyText(text)
    model.copied = key
  }

  private func translate() {
    let text = model.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, !model.working else { return }
    model.working = true
    model.problem = nil
    let assistant = assistant(), preferred = preferred()
    Task {
      let translation = await assistant.translate(text, preferred: preferred)
      model.translation = translation
      model.problem = translation == nil ? "No se pudo traducir" : nil
      model.working = false
      place()
    }
  }

  /// La primera vez abre el campo de la pregunta; con una pregunta escrita, la envía.
  private func ask() {
    guard model.asking else {
      model.asking = true
      place()
      return
    }
    let question = model.question.trimmingCharacters(in: .whitespacesAndNewlines)
    let text = model.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !question.isEmpty, !text.isEmpty, !model.working else { return }
    model.working = true
    model.problem = nil
    let assistant = assistant()
    Task {
      let answer = await assistant.ask(question, about: text)
      model.answer = answer
      model.problem = answer == nil ? "No hay respuesta: sin conexión y sin el modelo del Mac" : nil
      model.working = false
      place()
    }
  }
}
```

- [ ] **Step 2: ⇧⌘1 abre la tarjeta**

En `Sources/Sintecla/CaptureController.swift`, cambiar:

```swift
  /// Una captura cada vez
```

por:

```swift
  /// La tarjeta de ⇧⌘1.
  private lazy var card = CaptureTextCardPanel(assistant: { [unowned self] in self.assistant() },
                                                preferred: { [unowned self] in self.settings.translationTarget })
  /// Una captura cada vez
```

Y cambiar:

```swift
        onNotice?(CaptureNotice.text(text), Self.textSymbol)
      }
```

por:

```swift
        onNotice?(CaptureNotice.text(text), Self.textSymbol)
      }
      if action == .textCard { card.show(text) }
```

Y cambiar:

```swift
    }
  }
}
```

por:

```swift
    }
  }

  /// Traductores: Apple y, de respaldo, Gemini. Modelos para preguntar: Gemini y, de respaldo, Apple.
  private func assistant() -> CaptureAssistant {
    let cloud = settings.cloudModel()
    let apple: TextModel? = appleModel == nil ? nil : AppleTextModel(temperature: 0.4)
    let translators: [Translating] = [AppleTranslator()] + [cloud.map { ModelTranslator(model: $0) as Translating }].compactMap { $0 }
    return CaptureAssistant(translators: translators, models: [cloud as TextModel?, apple].compactMap { $0 })
  }
}
```

- [ ] **Step 3: Compilar la release (sin avisos)**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build of product' | tail -3
```

Esperado: `Build of product 'Sintecla' complete!`.

- [ ] **Step 4: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 263 tests in 48 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Sintecla/CaptureTextCard.swift Sources/Sintecla/CaptureController.swift
git commit -m 'feat: tarjeta de ⇧⌘1 para traducir o preguntar sobre el texto

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

- [ ] **Step 6: Instalar la versión nueva**

Run:

```bash
scripts/build-app.sh
```

Esperado: `✅ Instalada en /Applications/Sintecla.app`. El módulo viene apagado: se enciende en Módulos.

---
### Task 7: Aceptación a mano

**Files:**
- —

**Interfaces:**
- Consumes: La app instalada (Tarea 6).
- Produces: Nada nuevo. Con todo ✓, se sigue con el plan de Capturas 2 (el editor) en la misma rama.

La hace el usuario (spec §5.2, sin la parte del editor), con cualquier otra app de capturas cerrada.

- [ ] **Step 1: Checklist. Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | Módulos → encender Capturas; abrir su página | Permiso: «Falta» con «Dar permiso…» y «Abrir Ajustes». Los cuatro atajos a la vista |
| 2 | ⇧⌘4 sin el permiso | La pastilla dice «Falta el permiso de Grabación de pantalla» y se abre la página |
| 3 | Dar el permiso, salir de Sintecla y volver a abrirla | La página dice «Dado» |
| 4 | ⇧⌘3 y pegar en Notas | La pantalla del ratón, entera; la pastilla dice «Captura copiada» |
| 5 | ⇧⌘4: una zona; otra vez con Espacio, una ventana; otra vez, Esc | Las dos se pegan en Notas; Esc no hace nada |
| 6 | ⇧⌘2 sobre un párrafo y pegar | El texto con sus líneas; «Texto copiado · N palabras» |
| 7 | ⇧⌘2 sobre un QR (por ejemplo, uno en una web) | Se pega el enlace; «QR copiado: …» |
| 8 | ⇧⌘2 sobre una zona sin texto | «No hay texto en esa zona»; el portapapeles no cambia |
| 9 | ⇧⌘1 sobre un texto en inglés | La tarjeta con el texto; se puede editar; Traducir lo pasa al español; Preguntar abre el campo y, con Intro, responde; Copiar copia; Esc cierra |
| 10 | Menú → bloque Capturas | Las cuatro acciones con sus atajos; hacen lo mismo que los atajos |
| 11 | Con dos pantallas (si las hay): ⇧⌘3 con el ratón en la segunda | Se captura la segunda |
| 12 | Apagar Capturas y pulsar ⇧⌘1 a ⇧⌘4 | No hacen nada (llegan a la app de delante) |
| 13 | Dictado, Finder y el resto | Como antes |

---
## Autorrevisión frente a la especificación (plan de Capturas 1)

| Requisito (spec «Capturas») | Dónde |
|---|---|
| §2.1 Módulo apagado de fábrica; permiso con «Dar permiso…» y «Abrir Ajustes»; sin permiso, aviso y página; aviso si macOS usa ⇧⌘3 o ⇧⌘4 | Tareas 4 y 5 |
| §2.2 ⇧⌘1 a ⇧⌘4, solo con ⇧⌘ y con el módulo encendido; detrás del dictado y de Finder; bloque del menú; tarjeta de Inicio | Tareas 1, 4 y 5 |
| §2.3 `screencapture` a un archivo temporal que se borra; pantalla bajo el ratón; portapapeles en PNG y TIFF; «Captura copiada» | Tareas 4 y 5 |
| §2.4 OCR preciso en español e inglés; filas; códigos antes que el texto; avisos | Tarea 2 |
| §2.5 Tarjeta: texto editable, Copiar, Traducir (Apple → Gemini) y Preguntar (Gemini → Apple); Esc | Tareas 3 y 6 |
| §3 El editor | Plan de Capturas 2 (⇧⌘3 y ⇧⌘4 ya copian; el editor se abrirá ahí) |
| §5.1 Tests (atajos, filas, Vision de verdad, QR, avisos, módulos) | Tareas 1 a 4 |
| §5.2 Aceptación sin el editor | Tarea 7 |

**Decisión de este plan que la spec no fijaba:** con varios códigos en la zona, el aviso dice «N códigos copiados».

**Consistencia de tipos revisada:**
- `CaptureAction` (Tarea 1) la usan `CapturesPage` (Tarea 4), `CaptureController` y el menú (Tarea 5).
- `RecognizedContent.copiedText` y `CaptureNotice` (Tarea 2) los usa `CaptureController.run` (Tarea 5).
- `CaptureAssistant` (Tarea 3) lo construye `CaptureController.assistant()` y lo usa `CaptureTextCardPanel` (Tarea 6).
- `ScreenCapture.Shot` (`png`, `image`) sale de `capture(_:)` y lo usan `copyImage` y `TextRecognizer.recognize(shot.image)`.
