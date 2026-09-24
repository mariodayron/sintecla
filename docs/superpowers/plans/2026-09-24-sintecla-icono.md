# Sintecla — Icono «onda que escribe» — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar a Sintecla su icono «onda que escribe» en claro (Finder, Dock, Ajustes del Sistema, Spotlight) y usar el mismo dibujo en la barra de menú en vez del micro.

**Architecture:** El núcleo `SinteclaCore` gana `BrandMark`: la geometría pura del dibujo, en un cuadrado unidad, con cuatro variantes (grande, pequeña, barra en reposo y grabando) y tests. La app añade `BrandMarkRenderer`, que la pinta con Quartz de dos formas:
- el icono de cristal claro, que `Sintecla --make-icon` escribe como PNG y `scripts/make-icon.sh` junta con `iconutil` en `Resources/AppIcon.icns`;
- la imagen plantilla de la barra de menú.

`build-app.sh` copia el `.icns` y el `Info.plist` lo declara.

**Tech Stack:** Lo de siempre (Swift 6.3 de las Command Line Tools en modo de lenguaje 5, SwiftPM, AppKit, Swift Testing). Además:
- Quartz (`CGContext`, degradados).
- `SwiftUI.RoundedRectangle(style: .continuous)` para el squircle de macOS.
- `NSBitmapImageRep` para escribir PNG.
- `iconutil`, que viene con macOS.

**Especificación:** `docs/superpowers/specs/2026-09-24-icono-design.md` (y la fila «Icono (0.5.1)» de §12 de la spec principal).

**Punto de partida:** la rama `icono`, que sale de `main` (`v0.5.0`) con la especificación del icono:

```bash
git checkout icono
```

## Global Constraints

- Todo lo de la F1–F4b sigue vigente:
  - macOS 26.0 o superior, Apple Silicon.
  - Sin Xcode ni dependencias externas; todos los targets en `.swiftLanguageMode(.v5)`.
  - Tests con `swift run sintecla-tests` (**nunca `swift test`**).
  - Bundle id `local.sintecla.app`; textos visibles en español; solo blanco, negro, grises y transparente.
- **Icono:**
  - Lienzo de 1024 con el squircle estándar de macOS: **824 × 824** centrado (margen **100**), esquinas continuas de radio **185,4**.
  - Relleno de `#FFFFFF` a `#E4E4E8`, brillo blanco del **35 %** arriba y borde por dentro blanco arriba y `#C8C8CE` abajo.
  - Dibujo en `#1C1C1E`. Variante pequeña cuando el lado es de **32 px o menos**.
- **Barra de menú:** imagen plantilla de **16 × 16 pt**. En reposo, las barras al **45 %**; grabando, enteras y más altas. Descripción de accesibilidad «Sintecla».
- El `.icns` va en git y solo se regenera si cambia el diseño.
- Versión **0.5.1** (build 6).
- Commits: en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código de este plan se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `icono`: compiló y pasó los tests en cada tarea, y el árbol final quedó idéntico al del prototipo, `AppIcon.icns` incluido.

- **173 tests** (36 suites) en verde: los 167 de la F4b y 6 nuevos. La release compila sin avisos.
- **PNG revisados** a 1024, 128, 32 y 16 px, sobre fondo claro y oscuro. A 16 px se reconoce: 3 barras y el cursor.
- **Cómo lo presenta macOS 26.** Se instaló una copia del prototipo en una carpeta de pruebas y se pidió su icono con `NSWorkspace.icon(forFile:)`. Sale **sin el marco gris** de icono antiguo, al mismo tamaño y con la misma forma que Notas.
- **La imagen de la barra**, pintada en barra clara y oscura, en reposo y grabando, se ve bien.
- `scripts/make-icon.sh` genera siempre el mismo `.icns`, byte a byte.

**Lo que no se pudo probar aquí** (queda para la aceptación, Tarea 4):
- El icono en Finder, Dock, Spotlight y Ajustes del Sistema de verdad, con sus cachés.
- La barra de menú de la app en marcha. No hay capturas de pantalla: la shell no tiene permiso de Grabación de pantalla, y no se toca.

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| `CGPath(roundedRect:)` hace esquinas circulares, no las continuas del squircle de macOS | `RoundedRectangle(cornerRadius:style: .continuous).path(in:).cgPath` (Tarea 2) |
| La geometría tiene el origen arriba y Quartz abajo | `y = rect.maxY - piece.maxY * rect.height` (Tarea 2) |
| En una imagen plantilla, el color se ignora | El 45 % del reposo va en el alfa de cada barra (Tarea 3) |
| A 16 px, cinco barras de 0,05 se funden en una mancha | Variante `.small` con 3 barras de 0,067 (Tarea 1) |
| Finder y el Dock siguen enseñando el icono viejo tras instalar | `touch` de la app al final de `build-app.sh` (Tarea 2) |
| Tras mover la carpeta del proyecto, `swift build` falla con `missing required module 'SwiftShims'` | Caché de módulos con rutas viejas: `rm -rf .build` |

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/BrandMark.swift` | Geometría del dibujo y sus variantes | 1 |
| `Sources/SinteclaCoreTests/BrandMarkTests.swift` | Tests del dibujo | 1 |
| `Sources/Sintecla/BrandMarkRenderer.swift` | Pintar el dibujo, el icono en PNG y la imagen de la barra | 2 |
| `Sources/Sintecla/DebugCommands.swift` | `--make-icon carpeta.iconset` | 2 |
| `scripts/make-icon.sh`, `Resources/AppIcon.icns` | Generar y guardar el icono | 2 |
| `Resources/Info.plist`, `scripts/build-app.sh` | `CFBundleIconFile`, copiar el `.icns` y `touch` | 2 |
| `Sources/Sintecla/MenuBar.swift` | La onda en la barra de menú | 3 |
| `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`, `Sources/SinteclaCoreTests/SmokeTests.swift` | Versión 0.5.1 | 3 |

---

### Task 1: El dibujo «onda que escribe»

**Files:**
- Create: `Sources/SinteclaCore/BrandMark.swift`
- Test: `Sources/SinteclaCoreTests/BrandMarkTests.swift`

**Interfaces:**
- Consumes: Nada nuevo.
- Produces: `enum BrandMark { enum Variant: CaseIterable, Sendable { case large, small, menuIdle, menuRecording }; struct Piece: Equatable, Sendable { x, y, width, height, opacity: Double; isCursor: Bool; maxX, maxY: Double }; static func pieces(_ variant: Variant) -> [Piece] }`. Coordenadas en un cuadrado unidad con el origen arriba a la izquierda.

Solo geometría: rectángulos de esquinas redondas con su opacidad. Las medidas de la variante grande y de la pequeña son las de la tabla de la spec (§2).

- [ ] **Step 1: Escribir los tests**

Crear `Sources/SinteclaCoreTests/BrandMarkTests.swift`:

```swift
import Testing
@testable import SinteclaCore

@Suite struct BrandMarkTests {
  @Test(arguments: BrandMark.Variant.allCases)
  func everyPieceFitsInTheUnitSquare(_ variant: BrandMark.Variant) {
    for piece in BrandMark.pieces(variant) {
      #expect(piece.x >= 0 && piece.y >= 0 && piece.maxX <= 1 && piece.maxY <= 1, "\(variant): \(piece)")
    }
  }

  @Test(arguments: BrandMark.Variant.allCases)
  func barsGoLeftOfTheCursorWithoutOverlapping(_ variant: BrandMark.Variant) {
    let pieces = BrandMark.pieces(variant)
    let bars = pieces.filter { !$0.isCursor }
    let cursorStart = pieces.filter(\.isCursor).map(\.x).min() ?? 0
    for (left, right) in zip(bars, bars.dropFirst()) {
      #expect(left.maxX < right.x, "\(variant)")
    }
    #expect(bars.last!.maxX < cursorStart, "\(variant)")
  }

  @Test(arguments: BrandMark.Variant.allCases)
  func theCursorIsAlwaysSolid(_ variant: BrandMark.Variant) {
    #expect(BrandMark.pieces(variant).filter(\.isCursor).allSatisfy { $0.opacity == 1 })
  }

  @Test func theLargeWaveDarkensTowardsTheCursor() {
    let opacities = BrandMark.pieces(.large).filter { !$0.isCursor }.map(\.opacity)
    #expect(opacities.count == 5)
    #expect(zip(opacities, opacities.dropFirst()).allSatisfy { $0 < $1 })
  }

  @Test func theSmallWaveHasThreeSolidBars() {
    let bars = BrandMark.pieces(.small).filter { !$0.isCursor }
    #expect(bars.count == 3)
    #expect(bars.allSatisfy { $0.opacity == 1 })
  }

  @Test func recordingLightsUpAndRaisesTheBars() {
    let idle = BrandMark.pieces(.menuIdle).filter { !$0.isCursor }
    let recording = BrandMark.pieces(.menuRecording).filter { !$0.isCursor }
    #expect(idle.count == recording.count)
    #expect(idle.allSatisfy { $0.opacity == 0.45 })
    #expect(recording.allSatisfy { $0.opacity == 1 })
    #expect(zip(idle, recording).allSatisfy { $0.height < $1.height })
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find 'BrandMark' in scope`.

- [ ] **Step 3: Geometría de las cuatro variantes**

Crear `Sources/SinteclaCore/BrandMark.swift`:

```swift
import Foundation

/// El dibujo de Sintecla, «onda que escribe»: las barras de una onda de voz que acaban en un cursor de texto.
/// Geometría en un cuadrado unidad (0–1, origen arriba a la izquierda), para el icono de la app y la barra de menú.
public enum BrandMark {
  public enum Variant: CaseIterable, Sendable {
    /// Icono de 64 px en adelante.
    case large
    /// Icono de 16 y 32 px: menos barras y más gruesas.
    case small
    /// Barra de menú, en reposo y grabando.
    case menuIdle, menuRecording
  }

  /// Rectángulo de esquinas redondas (radio = mitad del lado corto) con su opacidad.
  public struct Piece: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var opacity: Double
    public var isCursor: Bool

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
  }

  public static func pieces(_ variant: Variant) -> [Piece] {
    switch variant {
    case .large:
      bars(x: [0.183, 0.267, 0.350, 0.433, 0.517], width: 0.050, heights: [0.100, 0.233, 0.367, 0.200, 0.133],
           opacities: [0.40, 0.55, 0.70, 0.85, 1])
        + cursor(stemX: 0.683, stemWidth: 0.050, stemHeight: 0.500, serifX: 0.625, serifWidth: 0.167, serifHeight: 0.042,
                 serifY: [0.233, 0.725])
    case .small:
      bars(x: [0.267, 0.383, 0.500], width: 0.067, heights: [0.233, 0.400, 0.167], opacities: [1, 1, 1])
        + cursor(stemX: 0.683, stemWidth: 0.075, stemHeight: 0.567)
    case .menuIdle:
      bars(x: menuBarX, width: 0.11, heights: [0.20, 0.44, 0.69, 0.31], opacities: [0.45, 0.45, 0.45, 0.45]) + menuCursor
    case .menuRecording:
      bars(x: menuBarX, width: 0.11, heights: [0.31, 0.69, 0.94, 0.56], opacities: [1, 1, 1, 1]) + menuCursor
    }
  }

  private static let menuBarX = [0.02, 0.21, 0.40, 0.59]
  private static let menuCursor = cursor(stemX: 0.82, stemWidth: 0.11, stemHeight: 0.88, serifX: 0.75, serifWidth: 0.25,
                                         serifHeight: 0.09, serifY: [0.03, 0.88])

  /// Barras centradas en y = 0,5.
  private static func bars(x: [Double], width: Double, heights: [Double], opacities: [Double]) -> [Piece] {
    zip(x, zip(heights, opacities)).map { x, shape in
      Piece(x: x, y: 0.5 - shape.0 / 2, width: width, height: shape.0, opacity: shape.1, isCursor: false)
    }
  }

  /// Palo centrado en y = 0,5 y, si se piden, remates horizontales arriba y abajo.
  private static func cursor(stemX: Double, stemWidth: Double, stemHeight: Double, serifX: Double = 0, serifWidth: Double = 0,
                             serifHeight: Double = 0, serifY: [Double] = []) -> [Piece] {
    [Piece(x: stemX, y: 0.5 - stemHeight / 2, width: stemWidth, height: stemHeight, opacity: 1, isCursor: true)]
      + serifY.map { Piece(x: serifX, y: $0, width: serifWidth, height: serifHeight, opacity: 1, isCursor: true) }
  }
}
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 173 tests in 36 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/BrandMark.swift Sources/SinteclaCoreTests/BrandMarkTests.swift
git commit -m 'feat: geometría del dibujo «onda que escribe»

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: Icono de la app

**Files:**
- Create: `Sources/Sintecla/BrandMarkRenderer.swift`
- Modify: `Sources/Sintecla/DebugCommands.swift`
- Create: `scripts/make-icon.sh`, `Resources/AppIcon.icns` (generado)
- Modify: `Resources/Info.plist`, `scripts/build-app.sh`

**Interfaces:**
- Consumes: `BrandMark.pieces(_:)` y `BrandMark.Variant` (Tarea 1).
- Produces: `enum BrandMarkRenderer { static let ink: CGColor; static func draw(_:in:color:context:); static func menuImage(recording: Bool) -> NSImage; static let iconFiles: [(pixels: Int, name: String)]; static func iconPNG(pixels: Int) -> Data? }`; `Sintecla --make-icon carpeta.iconset`; `Resources/AppIcon.icns`.

El dibujo en píxeles no se puede comprobar con tests del núcleo, porque la app no tiene target de tests. Aquí se compila, se genera el `.icns` y se mira a ojo (paso 7). `menuImage` queda lista para la Tarea 3.

- [ ] **Step 1: Pintar el dibujo, el icono y la imagen de la barra**

Crear `Sources/Sintecla/BrandMarkRenderer.swift`:

```swift
import AppKit
import SinteclaCore
import SwiftUI

/// Pinta `BrandMark`: el icono de la app (cristal claro) y la imagen plantilla de la barra de menú.
enum BrandMarkRenderer {
  /// Casi negro del dibujo en el icono.
  static let ink = CGColor(srgbRed: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255, alpha: 1)

  /// Dibuja las piezas en `rect`. Quartz tiene el origen abajo y la geometría arriba: se da la vuelta a la y.
  static func draw(_ variant: BrandMark.Variant, in rect: CGRect, color: CGColor, context: CGContext) {
    for piece in BrandMark.pieces(variant) {
      let frame = CGRect(x: rect.minX + piece.x * rect.width, y: rect.maxY - piece.maxY * rect.height,
                         width: piece.width * rect.width, height: piece.height * rect.height)
      let radius = min(frame.width, frame.height) / 2
      context.addPath(CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil))
      context.setFillColor(color.copy(alpha: piece.opacity) ?? color)
      context.fillPath()
    }
  }

  /// Imagen plantilla de 16 × 16 pt: macOS la pinta en negro o blanco según la barra. El reposo va en el canal alfa.
  static func menuImage(recording: Bool) -> NSImage {
    let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
      guard let context = NSGraphicsContext.current?.cgContext else { return false }
      draw(recording ? .menuRecording : .menuIdle, in: rect.insetBy(dx: 1, dy: 1), color: .black, context: context)
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Sintecla"
    return image
  }

  // MARK: - Icono de la app

  /// Lados en píxeles del `.iconset` y su nombre de archivo.
  static let iconFiles: [(pixels: Int, name: String)] = [16, 32, 128, 256, 512].flatMap { points in
    [(points, "icon_\(points)x\(points).png"), (points * 2, "icon_\(points)x\(points)@2x.png")]
  }

  /// PNG del icono de `pixels` × `pixels`: squircle estándar de macOS (824 de 1024) de cristal claro con el dibujo.
  static func iconPNG(pixels: Int) -> Data? {
    guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let scale = CGFloat(pixels) / 1024
    let tile = CGRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let shape = RoundedRectangle(cornerRadius: 185.4 * scale, style: .continuous).path(in: tile).cgPath

    // Relleno: de blanco arriba a gris perla abajo.
    context.saveGState()
    context.addPath(shape)
    context.clip()
    let fill = CGGradient(colorsSpace: nil, colors: [CGColor(gray: 1, alpha: 1),
                                                     CGColor(srgbRed: 0xE4 / 255, green: 0xE4 / 255, blue: 0xE8 / 255, alpha: 1)] as CFArray,
                          locations: [0, 1])!
    context.drawLinearGradient(fill, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    // Brillo: media elipse blanca en la mitad de arriba, del 35 % a transparente.
    let sheen = CGGradient(colorsSpace: nil, colors: [CGColor(gray: 1, alpha: 0.35), CGColor(gray: 1, alpha: 0)] as CFArray,
                           locations: [0, 1])!
    context.saveGState()
    context.translateBy(x: tile.midX, y: tile.maxY)
    context.scaleBy(x: 1, y: 0.5)
    context.drawRadialGradient(sheen, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: tile.width * 0.75, options: [])
    context.restoreGState()
    // Borde fino por dentro: blanco arriba y gris abajo (el trazo se recorta a la mitad de dentro).
    context.addPath(shape)
    context.setLineWidth(max(8 * scale, 1))
    context.replacePathWithStrokedPath()
    context.clip()
    let rim = CGGradient(colorsSpace: nil, colors: [CGColor(gray: 1, alpha: 1),
                                                    CGColor(srgbRed: 0xC8 / 255, green: 0xC8 / 255, blue: 0xCE / 255, alpha: 1)] as CFArray,
                         locations: [0, 1])!
    context.drawLinearGradient(rim, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    context.restoreGState()

    draw(pixels <= 32 ? .small : .large, in: tile, color: ink, context: context)
    guard let image = context.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
  }
}
```

- [ ] **Step 2: Orden `--make-icon`**

En `Sources/Sintecla/DebugCommands.swift`, cambiar:

```swift
///   Sintecla --meeting-record segundos carpeta           (reunión real con el grabador; lanzar con `open`)
```

por:

```swift
///   Sintecla --meeting-record segundos carpeta           (reunión real con el grabador; lanzar con `open`)
///   Sintecla --make-icon carpeta.iconset                 (PNG del icono; lo usa scripts/make-icon.sh)
```

Y cambiar:

```swift
                  | --meeting-record segundos carpeta
    """
```

por:

```swift
                  | --meeting-record segundos carpeta | --make-icon carpeta.iconset
    """
```

Y cambiar:

```swift
    case "--meeting-record" where rest.count >= 2: return { await meetingRecord(seconds: Double(first) ?? 30, folder: rest[1]) }
```

por:

```swift
    case "--meeting-record" where rest.count >= 2: return { await meetingRecord(seconds: Double(first) ?? 30, folder: rest[1]) }
    case "--make-icon" where !rest.isEmpty: return { makeIcon(folder: first) }
```

Y cambiar:

```swift
  @MainActor
  private static func run(
```

por:

```swift
  /// `Sintecla --make-icon carpeta.iconset`: los PNG del icono que junta `iconutil` (scripts/make-icon.sh).
  static func makeIcon(folder: String) -> String {
    let url = URL(fileURLWithPath: folder)
    do {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
      for file in BrandMarkRenderer.iconFiles {
        guard let png = BrandMarkRenderer.iconPNG(pixels: file.pixels) else { return "ERROR: no se pudo dibujar \(file.name)" }
        try png.write(to: url.appendingPathComponent(file.name))
      }
    } catch {
      return "ERROR: \(error.localizedDescription)"
    }
    return "\(BrandMarkRenderer.iconFiles.count) PNG en \(folder)"
  }

  @MainActor
  private static func run(
```

- [ ] **Step 3: Script que genera el `.icns`**

Crear `scripts/make-icon.sh`:

```bash
#!/bin/bash
# Genera Resources/AppIcon.icns con el dibujo de BrandMark (Sintecla --make-icon) e iconutil.
# Solo hace falta si cambia el diseño del icono: el .icns va en git.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product Sintecla 2>&1 | tail -1
BIN="$(swift build -c release --product Sintecla --show-bin-path)/Sintecla"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
"$BIN" --make-icon "$TMP/AppIcon.iconset"
iconutil -c icns "$TMP/AppIcon.iconset" -o Resources/AppIcon.icns
echo "✅ Resources/AppIcon.icns"
```

- [ ] **Step 4: Hacerlo ejecutable**

Run:

```bash
chmod +x scripts/make-icon.sh
```

- [ ] **Step 5: Generar `Resources/AppIcon.icns`**

Run:

```bash
scripts/make-icon.sh
```

Esperado: `10 PNG en`.

- [ ] **Step 6: Comprobar que el `.icns` trae los 10 tamaños**

Run:

```bash
D=$(mktemp -d) && iconutil -c iconset Resources/AppIcon.icns -o $D/check.iconset && ls $D/check.iconset | wc -l && rm -rf $D
```

Esperado: `10`.

- [ ] **Step 7: Mirar el icono**

```bash
D=$(mktemp -d)
"$(swift build -c release --product Sintecla --show-bin-path)/Sintecla" --make-icon $D/icono.iconset
open $D/icono.iconset/icon_512x512@2x.png $D/icono.iconset/icon_16x16.png
```

Esperado: squircle blanco perla con la onda (5 barras que oscurecen hacia el cursor) y el cursor en «I». A 16 px, 3 barras y el palo. Después: `rm -rf $D`.

- [ ] **Step 8: El `Info.plist` declara el icono**

En `Resources/Info.plist`, cambiar:

```xml
  <key>CFBundlePackageType</key><string>APPL</string>
```

por:

```xml
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
```

- [ ] **Step 9: `build-app.sh` copia el icono y renueva la caché**

En `scripts/build-app.sh`, cambiar:

```bash
cp Resources/Info.plist "$APP/Contents/Info.plist"
```

por:

```bash
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
```

Y cambiar:

```bash
cp -R "$APP" "$DEST/"
```

por:

```bash
cp -R "$APP" "$DEST/"
# Finder y el Dock guardan el icono en caché: con la fecha cambiada vuelven a leerlo.
touch "$DEST/$APP_NAME.app"
```

- [ ] **Step 10: Compilar**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | tail -1
```

Esperado: `Build of product 'Sintecla' complete!`.

- [ ] **Step 11: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 173 tests in 36 suites passed`.

- [ ] **Step 12: Commit**

```bash
git add Sources/Sintecla/BrandMarkRenderer.swift Sources/Sintecla/DebugCommands.swift scripts/make-icon.sh Resources/AppIcon.icns Resources/Info.plist scripts/build-app.sh
git commit -m 'feat: icono de la app «onda que escribe»

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: La onda en la barra de menú y versión 0.5.1

**Files:**
- Modify: `Sources/Sintecla/MenuBar.swift` (`setRecording`)
- Modify: `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`
- Test: `Sources/SinteclaCoreTests/SmokeTests.swift`

**Interfaces:**
- Consumes: `BrandMarkRenderer.menuImage(recording:)` (Tarea 2).
- Produces: La barra de menú con la onda en reposo y grabando; versión 0.5.1 (build 6).

- [ ] **Step 1: Test de la versión nueva**

En `Sources/SinteclaCoreTests/SmokeTests.swift`, cambiar:

```swift
#expect(AppInfo.version == "0.5.0")
```

por:

```swift
#expect(AppInfo.version == "0.5.1")
```

- [ ] **Step 2: Ver que falla**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA el test con `Expectation failed: (AppInfo.version → "0.5.0") == "0.5.1"`.

- [ ] **Step 3: Versión 0.5.1**

En `Sources/SinteclaCore/AppInfo.swift`, cambiar:

```swift
public static let version = "0.5.0"
```

por:

```swift
public static let version = "0.5.1"
```

- [ ] **Step 4: Versión 0.5.1 (build 6) en el Info.plist**

En `Resources/Info.plist`, cambiar:

```xml
<key>CFBundleShortVersionString</key><string>0.5.0</string>
```

por:

```xml
<key>CFBundleShortVersionString</key><string>0.5.1</string>
```

Y cambiar:

```xml
<key>CFBundleVersion</key><string>5</string>
```

por:

```xml
<key>CFBundleVersion</key><string>6</string>
```

- [ ] **Step 5: Ver que pasa**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 173 tests in 36 suites passed`.

- [ ] **Step 6: La barra de menú usa la onda**

En `Sources/Sintecla/MenuBar.swift`, cambiar:

```swift
    statusItem.button?.image = NSImage(systemSymbolName: recording ? "mic.fill" : "mic",
                                       accessibilityDescription: "Sintecla")
```

por:

```swift
    statusItem.button?.image = BrandMarkRenderer.menuImage(recording: recording)
```

- [ ] **Step 7: Compilar**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | tail -1
```

Esperado: `Build of product 'Sintecla' complete!`.

- [ ] **Step 8: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 173 tests in 36 suites passed`.

- [ ] **Step 9: Commit**

```bash
git add Sources/Sintecla/MenuBar.swift Sources/SinteclaCore/AppInfo.swift Resources/Info.plist Sources/SinteclaCoreTests/SmokeTests.swift
git commit -m 'feat: la onda que escribe en la barra de menú

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

- [ ] **Step 10: Instalar la versión nueva**

Run:

```bash
scripts/build-app.sh
```

Esperado: `✅ Instalada en /Applications/Sintecla.app`. Los permisos se conservan.

---
### Task 4: Aceptación del icono

**Files:**
- Modify: `docs/superpowers/specs/2026-09-23-sintecla-design.md` (estado)

**Interfaces:**
- Consumes: La app instalada (Tarea 3).
- Produces: Etiqueta `v0.5.1` y la rama `icono` integrada en `main`.

Lo hace el usuario: es lo que no se pudo ver sin captura de pantalla (spec del icono §6).

- [ ] **Step 1: Checklist manual del icono. Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | Finder → Aplicaciones | Sintecla con la onda que escribe, sin marco gris |
| 2 | Spotlight (⌘ Espacio) «Sintecla» | El mismo icono |
| 3 | Abrir Sintecla… (sale en el Dock) | El icono en el Dock |
| 4 | Ajustes del Sistema → Privacidad y seguridad → Accesibilidad | El icono junto a Sintecla |
| 5 | Barra de menú, en reposo y dictando | Onda apagada en reposo; encendida y más alta al dictar |
| 6 | Cambiar entre modo claro y oscuro | La onda de la barra se ve en los dos |
| 7 | Dictado, traducción, Ask, notas y reuniones | Igual que en la 0.5.0 |

Si Finder o el Dock siguen con el icono genérico, es la caché: `killall Dock` (solo si el usuario quiere) o cerrar sesión.

- [ ] **Step 2: Marcar el icono como entregado en la spec**

En `docs/superpowers/specs/2026-09-23-sintecla-design.md`, cambiar:

```text
F4b entregada (`v0.5.0`).
```

por:

```text
F4b entregada (`v0.5.0`). Icono entregado (`v0.5.1`).
```

- [ ] **Step 3: Cerrar**

```bash
git add docs/superpowers/specs/2026-09-23-sintecla-design.md
git commit -m 'docs: icono entregado

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
swift run sintecla-tests
git tag -a v0.5.1 -m 'Icono «onda que escribe»'
```

Después, integrar `icono` en `main` con superpowers:finishing-a-development-branch.

---
## Autorrevisión frente a la especificación (icono)

| Requisito (spec del icono) | Dónde |
|---|---|
| §2 Geometría de las variantes grande, pequeña, reposo y grabando | Tarea 1 |
| §3 Squircle 824/1024 continuo, cristal claro (relleno, brillo, borde), dibujo en `#1C1C1E`, pequeña a ≤ 32 px, 10 PNG, `--make-icon`, `make-icon.sh`, `.icns` en git, `CFBundleIconFile`, copia en `build-app.sh` | Tarea 2 |
| §4 Imagen plantilla de 16 pt, reposo al 45 %, accesibilidad «Sintecla» | Tareas 2 (`menuImage`) y 3 |
| §5 Versión 0.5.1 | Tarea 3 |
| §6 Tests, revisión visual y aceptación a mano | Tareas 1, 2 (paso 7) y 4 |
| §7 Marco gris (comprobado antes del plan) y caché (`touch`) | Hechos verificados y Tarea 2 |

**Consistencia de tipos revisada:**
- `BrandMark.Variant` y `BrandMark.pieces(_:)` (Tarea 1) los usa `BrandMarkRenderer.draw` (Tarea 2).
- `BrandMarkRenderer.iconFiles` e `iconPNG(pixels:)` (Tarea 2) los usa `DebugCommands.makeIcon(folder:)` (Tarea 2).
- `BrandMarkRenderer.menuImage(recording:)` (Tarea 2) lo usa `MenuBar.setRecording(_:)` (Tarea 3).
