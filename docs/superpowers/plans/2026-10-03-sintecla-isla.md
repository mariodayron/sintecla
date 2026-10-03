# Sintecla — La isla (0.14.0) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** la muesca del MacBook como una Dynamic Island: la música que suena y todo lo que hoy enseña la pastilla de Sintecla, con una sola forma que cambia con muelle; al dictar, la música se pausa.

**Architecture:**
- **En el núcleo, con tests:**
  - `IslandLayout` (qué forma y cuánto mide) e `IslandHover` (cuándo se despliega);
  - `NowPlaying` y `NowPlayingUpdate` (lo que suena y las líneas del ayudante);
  - `MusicPresence` (cuándo se enseña), `MusicPauser` (pausar al dictar) y `ArtworkTint` (color de la onda).
- **El ayudante de música:** una biblioteca C que carga `/usr/bin/perl`, compilada por `build-app.sh`; habla con Sintecla por la entrada y la salida estándar.
- **En la app:**
  - `NowPlayingClient` arranca y escucha el ayudante;
  - `NotchScreen` encuentra la muesca;
  - `IslandShape`, `IslandView` e `IslandPanel` la pintan;
  - `IslandController` lo une todo y `DictationController` decide si su estado va a la isla o a la pastilla.

**Tech Stack:** Lo de siempre:
- Swift 6.4 de las Command Line Tools 27, en modo de lenguaje 5;
- SwiftPM, Swift Testing, SwiftUI y AppKit;
- además, C con CoreFoundation y `MediaRemote` (privado, cargado con `dlopen`) para el ayudante.

**Especificación:** `docs/superpowers/specs/2026-10-03-isla-design.md`.

**Punto de partida:** la rama `isla` (sale de `main` en la 0.13.0, con la especificación):

```bash
git checkout isla
```

## Global Constraints

- **Todo lo de antes sigue vigente:**
  - macOS 26.0 o superior, Apple Silicon.
  - Sin Xcode ni dependencias externas; modo de lenguaje 5.
  - Tests con `swift run sintecla-tests` (**nunca `swift test`**).
  - Textos visibles en español.
  - La release compila sin avisos.
- **Compilar la app con las Command Line Tools 27:** con el SDK de macOS 26, mediante `source scripts/sdk-env.sh` (lo hace `build-app.sh`). Los avisos `ld: warning: search path …` los pone SwiftPM y no cuentan.
- **Módulo «Isla»:** UserDefaults `moduleIsland`, **apagado de fábrica**. Es el séptimo en Módulos, con el símbolo `capsule.tophalf.filled`.
- **En la pantalla con muesca** (la del MacBook), aunque se trabaje en otra. **Con la tapa cerrada,** isla virtual arriba en el centro de la pantalla principal, colgando de la barra de menús: solo lo de Sintecla, y sin nada no se ve.
- **Medidas** (sobre una muesca de 208 × 37,5 puntos):
  - compacta, 40 puntos más por lado;
  - actividades altas, 86 más por lado y 30 por debajo;
  - desplegada, 420 de ancho y 148 por debajo;
  - burbuja, del alto de la muesca, a 8 puntos;
  - sin muesca, una muesca imaginaria de 180 puntos por el alto de la barra de menús, y las actividades en una fila centrada que baja 14 por debajo.
- **Tiempos:**
  - desplegar a los 0,15 s con el ratón encima y recoger a los 0,3 s;
  - muelle de 0,35 s con amortiguación 0,8 (los avisos, 0,62, con rebote);
  - la música en pausa se va a los 5 minutos.
- **Colores:** blanco sobre negro; solo la onda de la música lleva el color de la carátula.
- **Pausa al dictar:** al escuchar (no en reunión) si sonaba; reanuda solo si pausó Sintecla.
- **Versión:** 0.14.0 (build 15).
- **Commits:** en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `isla`: compiló, pasó los tests en cada tarea y el árbol final quedó idéntico al del prototipo.

- **341 tests** (57 suites) en verde: los 315 de antes y 26 nuevos. La release compila sin avisos (aparte de los `ld: warning: search path` de SwiftPM).
- **`MediaRemote` en macOS 27.0.1,** en el Mac del usuario con Spotify:
  - llamado directamente, no devuelve nada;
  - **a través de `/usr/bin/perl`, sí:** título, artista, álbum, duración, punto, carátula (un JPEG de 133 KB) y la app;
  - las órdenes funcionan por la misma vía: pausa y play (comprobado con «¿suena?» antes y después) e ir a otro punto (5 s más, reflejado a los 1,5 s).
- **La muesca:** pantalla del MacBook de 1710 × 1112 puntos; `auxiliaryTopLeftArea` y `auxiliaryTopRightArea` de 751 de ancho y `safeAreaInsets.top` de 37,5, así que la muesca mide 208 × 37,5.
- **La app firmada** con la biblioteca dentro pasa `codesign --verify --strict`, y el ayudante funciona desde dentro de la app.
- **La isla de verdad,** con el módulo encendido y el ratón movido por el programa:
  - en reposo, compacta con la carátula y la onda del color de la carátula, moviéndose;
  - a los 0,1 s con el ratón encima, aún sin desplegar; después, desplegada con la canción, el progreso, los tiempos y los controles;
  - al sacar el ratón, recogida.
- **Los estados de Sintecla y la burbuja,** pintados con `ImageRenderer`: escuchando, notas, reunión, procesando, traduciendo, aviso, mensaje y hecho; la burbuja con la carátula al lado del dictado.
- **El usuario lo probó en el prototipo:** dictar con música (se pausa y sale la burbuja). Pidió tres cambios, ya hechos:
  - la carátula se perdía al pausar Spotify;
  - en la pantalla externa salía la pastilla de antes: ahora sale siempre la isla;
  - con la tapa cerrada, «una alternativa pro»: la isla virtual, solo con Sintecla (lo eligió él), con el icono, el texto y la onda en una fila centrada (con los lados de la muesca quedaba descentrado).
- **Sin probar** (lo comprueba la Tarea 7): los controles con el ratón, pantalla completa y la tapa cerrada.

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| `MediaRemote` no responde a Sintecla desde macOS 15.4 | El ayudante corre dentro de `/usr/bin/perl` |
| El punto de la canción solo se actualiza a saltos | El ayudante manda el punto y su hora (`timestamp`); `NowPlaying.position(at:)` calcula el actual |
| La carátula pesa (133 KB en base64) | El ayudante la manda solo cuando cambia (`artworkID`) |
| `snprintf` con un búfer de 64 cortaba el `pid` | Búfer de 256 |
| La salida del ayudante cerrada llamaría sin parar al lector | `readabilityHandler` a nil con datos vacíos |
| El panel encima de la barra de menús le robaría los clics | `ignoresMouseEvents` salvo con el ratón dentro de la isla compacta o desplegada |
| Spotify quita la carátula en pausa y, al volver, el ayudante no la reenviaba (la isla se quedaba con el icono de Spotify) | El ayudante olvida la última carátula cuando una línea llega sin ella, y el cliente la mantiene si es la misma canción |
| `ProgressView` no se pinta igual en todos lados y no va con el brillo | Un arco que gira, dibujado con SwiftUI |
| `#expect` no acepta llamadas que cambian el valor | Se guardan antes en una variable |
| La desplegada con 128 puntos cortaba los controles | 148 |

**Cambios sobre la spec, pedidos por el usuario al probar el prototipo (ya en la spec):**
- Lo de Sintecla va a la isla aunque se trabaje en la pantalla externa.
- Con la tapa cerrada, isla virtual solo con Sintecla, en lugar de la pastilla de abajo.

**Decisiones de este plan que la spec no fijaba:**
- **Las actividades altas** llevan el icono y la onda (o el cronómetro) a los lados de la muesca y el texto debajo, en 30 puntos (la spec decía «46 de alto»).
- **Notas** llevan el cronómetro y la onda a la derecha.
- **El ayudante** también mira cada 3 s, por si algún cambio no avisa.

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/Island.swift`, `Sources/SinteclaCore/NowPlaying.swift` y sus tests | Formas, ratón y música en el núcleo | 1 |
| `Resources/Island/NowPlaying.c`, `Resources/Island/now-playing.pl`, `scripts/build-app.sh`, `Sources/Sintecla/NowPlayingClient.swift` | El ayudante de música y su cliente | 2 |
| `Sources/SinteclaCore/Modules.swift`, `Sources/SinteclaCoreTests/ModulesTests.swift`, `Sources/Sintecla/AppSettings.swift`, `Sources/Sintecla/NotchScreen.swift`, `Sources/Sintecla/IslandPage.swift`, `Sources/Sintecla/HomeView.swift`, `Sources/Sintecla/MainWindow.swift` | El módulo | 3 |
| `Sources/Sintecla/Overlay.swift`, `Sources/Sintecla/IslandShape.swift`, `Sources/Sintecla/IslandView.swift`, `Sources/Sintecla/IslandPanel.swift` | La vista | 4 |
| `Sources/Sintecla/IslandController.swift`, `Sources/Sintecla/DictationController.swift` | El controlador | 5 |
| `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`, `Sources/SinteclaCoreTests/SmokeTests.swift`, `README.md`, `docs/superpowers/specs/2026-09-23-sintecla-design.md` | 0.14.0 | 6 |

---

### Task 1: La isla en el núcleo: formas, ratón y música

**Files:**
- Create: `Sources/SinteclaCore/Island.swift` y `Sources/SinteclaCore/NowPlaying.swift`
- Test: `Sources/SinteclaCoreTests/IslandTests.swift` y `Sources/SinteclaCoreTests/NowPlayingTests.swift`

**Interfaces:**
- Consumes: `HotkeyMode` (`Sources/SinteclaCore/HotkeyTypes.swift`).
- Produces: `IslandActivity` (`.listening`, `.meeting`, `.processing`, `.done`, `.notice`; `isTall`); `IslandForm` (`.hidden`, `.notch`, `.compact`, `.expanded`, `.activity(_:bubble:)`); `IslandLayout.form(activity:music:hovering:fullScreen:hasNotch:)` (`hasNotch` a `true` por defecto), `.size(of:notch:hasNotch:)`, `.bubbleDiameter(notch:)` y sus medidas (`wing`, `tallWing`, `tallDrop`, `virtualDrop`, `expandedWidth`, `expandedDrop`, `bubbleGap`); `IslandHover` (`update(inside:at:) -> Bool`, `isExpanded`, `reset()`); `NowPlaying` (`position(at:)`, `progress(at:)`, `clock(_:)`); `NowPlayingUpdate.parse(_:)` (`.nothing`, `.track(_:artwork:)`); `MusicPresence` (`update(_:at:)`, `isShown(_:at:)`); `MusicPauser` (`listeningStarted(mode:musicPlaying:)`, `musicChanged(isPlaying:)`, `listeningEnded()`, que devuelven `.pause`, `.play` o nil); `ArtworkTint(of:)` y `.white`.

Todo lo que se puede probar sin pantalla: qué forma toca y cuánto mide, cuándo se despliega con el ratón, leer las líneas del ayudante, el punto de la canción, cuándo se enseña la música, la pausa al dictar y el color de la carátula.

- [ ] **Step 1: Tests: formas, medidas y ratón de la isla**

Crear `Sources/SinteclaCoreTests/IslandTests.swift`:

```swift
import CoreGraphics
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct IslandTests {
  // MARK: Formas

  @Test func withNothingItIsTheNotch() {
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: false) == .notch)
    #expect(IslandLayout.form(activity: nil, music: false, hovering: true, fullScreen: false) == .notch)
  }

  @Test func musicIsCompactAndExpandsWithTheMouse() {
    #expect(IslandLayout.form(activity: nil, music: true, hovering: false, fullScreen: false) == .compact)
    #expect(IslandLayout.form(activity: nil, music: true, hovering: true, fullScreen: false) == .expanded)
  }

  @Test func sinteclaWinsAndMusicGoesToTheBubble() {
    #expect(IslandLayout.form(activity: .listening, music: false, hovering: true, fullScreen: false)
              == .activity(.listening, bubble: false))
    #expect(IslandLayout.form(activity: .meeting, music: true, hovering: true, fullScreen: false)
              == .activity(.meeting, bubble: true))
  }

  @Test func fullScreenHidesTheRestButNotSintecla() {
    #expect(IslandLayout.form(activity: nil, music: true, hovering: false, fullScreen: true) == .hidden)
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: true) == .hidden)
    #expect(IslandLayout.form(activity: .notice, music: false, hovering: false, fullScreen: true)
              == .activity(.notice, bubble: false))
  }

  @Test func withoutNotchOnlySinteclaShows() {
    #expect(IslandLayout.form(activity: nil, music: true, hovering: true, fullScreen: false, hasNotch: false) == .hidden)
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: false, hasNotch: false) == .hidden)
    #expect(IslandLayout.form(activity: .listening, music: true, hovering: false, fullScreen: false, hasNotch: false)
              == .activity(.listening, bubble: false))
  }

  // MARK: Medidas

  private let notch = CGSize(width: 208, height: 37.5)

  @Test func sizesGrowFromTheNotch() {
    #expect(IslandLayout.size(of: .hidden, notch: notch) == .zero)
    #expect(IslandLayout.size(of: .notch, notch: notch) == notch)
    #expect(IslandLayout.size(of: .compact, notch: notch) == CGSize(width: 288, height: 37.5))
    #expect(IslandLayout.size(of: .expanded, notch: notch) == CGSize(width: 420, height: 185.5))
    #expect(IslandLayout.size(of: .activity(.listening, bubble: true), notch: notch) == CGSize(width: 380, height: 67.5))
    // «Hecho» cabe en los lados, como la compacta.
    #expect(IslandLayout.size(of: .activity(.done, bubble: false), notch: notch) == CGSize(width: 288, height: 37.5))
    #expect(IslandLayout.bubbleDiameter(notch: notch) == 37.5)
  }

  @Test func withoutNotchActivitiesAreOneRow() {
    let virtual = CGSize(width: 180, height: 24)
    #expect(IslandLayout.size(of: .activity(.listening, bubble: false), notch: virtual, hasNotch: false)
              == CGSize(width: 352, height: 38))
    #expect(IslandLayout.size(of: .activity(.done, bubble: false), notch: virtual, hasNotch: false)
              == CGSize(width: 260, height: 24))
  }

  @Test func onlyDoneStaysShort() {
    #expect(IslandActivity.listening.isTall && IslandActivity.meeting.isTall && IslandActivity.processing.isTall)
    #expect(IslandActivity.notice.isTall)
    #expect(!IslandActivity.done.isTall)
  }

  // MARK: Ratón

  private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

  @Test func expandsAfterAShortHover() {
    var hover = IslandHover()
    var changed = hover.update(inside: true, at: t0)
    #expect(!changed)
    changed = hover.update(inside: true, at: t0 + 0.1)
    #expect(!changed)
    changed = hover.update(inside: true, at: t0 + 0.15)
    #expect(changed)
    #expect(hover.isExpanded)
  }

  @Test func passingByDoesNotExpand() {
    var hover = IslandHover()
    hover.update(inside: true, at: t0)
    hover.update(inside: false, at: t0 + 0.1)
    let changed = hover.update(inside: true, at: t0 + 0.2)
    #expect(!changed)
    #expect(!hover.isExpanded)
  }

  @Test func collapsesAfterLeavingAndComingBackKeepsIt() {
    var hover = IslandHover()
    hover.update(inside: true, at: t0)
    hover.update(inside: true, at: t0 + 0.2)
    var changed = hover.update(inside: false, at: t0 + 1)
    #expect(!changed)
    changed = hover.update(inside: true, at: t0 + 1.2)
    #expect(!changed)
    changed = hover.update(inside: false, at: t0 + 1.3)
    #expect(!changed)
    changed = hover.update(inside: false, at: t0 + 1.5)
    #expect(!changed)
    changed = hover.update(inside: false, at: t0 + 1.6)
    #expect(changed)
    #expect(!hover.isExpanded)
  }

  @Test func resetCollapses() {
    var hover = IslandHover()
    hover.update(inside: true, at: t0)
    hover.update(inside: true, at: t0 + 0.2)
    hover.reset()
    #expect(!hover.isExpanded)
  }
}
```

- [ ] **Step 2: Tests: líneas del ayudante, punto de la canción, presencia, pausa al dictar y color**

Crear `Sources/SinteclaCoreTests/NowPlayingTests.swift`:

```swift
import CoreGraphics
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct NowPlayingTests {
  private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

  // MARK: Las líneas del ayudante

  @Test func readsAFullLine() throws {
    let line = #"{"playing":true,"title":"Canción de prueba","artist":"Artista","album":"Álbum","duration":195,"#
      + #""elapsed":17.5,"timestamp":1790000000,"pid":1463,"artworkID":"a1","artwork":"aGVsbG8="}"#
    let update = try #require(NowPlayingUpdate.parse(line))
    guard case .track(let track, let artwork) = update else {
      Issue.record("no es una canción")
      return
    }
    #expect(track == NowPlaying(title: "Canción de prueba", artist: "Artista", album: "Álbum", duration: 195,
                                elapsed: 17.5, timestamp: t0, isPlaying: true, pid: 1463, artworkID: "a1"))
    #expect(artwork == Data("hello".utf8))
  }

  @Test func aLineWithoutArtworkKeepsTheID() throws {
    let line = #"{"playing":false,"title":"Vídeo","duration":0,"elapsed":3,"timestamp":1790000000,"artworkID":"a1"}"#
    let update = try #require(NowPlayingUpdate.parse(line))
    guard case .track(let track, let artwork) = update else {
      Issue.record("no es una canción")
      return
    }
    #expect(track.artworkID == "a1" && artwork == nil && !track.isPlaying && track.artist.isEmpty)
  }

  @Test func nothingPlaying() {
    #expect(NowPlayingUpdate.parse(#"{"empty":true}"#) == .nothing)
  }

  @Test func brokenLinesChangeNothing() {
    #expect(NowPlayingUpdate.parse("") == nil)
    #expect(NowPlayingUpdate.parse(#"{"playing":true,"title":"#) == nil)
    #expect(NowPlayingUpdate.parse(#"{"playing":true,"timestamp":1790000000}"#) == nil)  // sin título
  }

  // MARK: El punto de la canción

  private func track(playing: Bool, elapsed: TimeInterval = 10, duration: TimeInterval = 100) -> NowPlaying {
    NowPlaying(title: "x", duration: duration, elapsed: elapsed, timestamp: t0, isPlaying: playing)
  }

  @Test func positionAdvancesOnlyWhilePlaying() {
    #expect(track(playing: true).position(at: t0 + 5) == 15)
    #expect(track(playing: false).position(at: t0 + 5) == 10)
    #expect(track(playing: true).progress(at: t0 + 40) == 0.5)
  }

  @Test func positionNeverPassesTheDuration() {
    #expect(track(playing: true).position(at: t0 + 500) == 100)
    // Sin duración, sigue contando y el progreso es 0.
    #expect(track(playing: true, duration: 0).position(at: t0 + 500) == 510)
    #expect(track(playing: true, duration: 0).progress(at: t0 + 5) == 0)
  }

  @Test func clock() {
    #expect(NowPlaying.clock(68.9) == "1:08")
    #expect(NowPlaying.clock(5) == "0:05")
    #expect(NowPlaying.clock(3725) == "1:02:05")
    #expect(NowPlaying.clock(-3) == "0:00")
  }

  // MARK: Cuándo se enseña

  @Test func pausedMusicStaysFiveMinutes() {
    var presence = MusicPresence()
    let paused = track(playing: false)
    presence.update(paused, at: t0)
    #expect(presence.isShown(paused, at: t0 + 299))
    #expect(!presence.isShown(paused, at: t0 + 300))
    // Vuelve a sonar: se enseña, y la pausa siguiente cuenta de nuevo.
    presence.update(track(playing: true), at: t0 + 400)
    #expect(presence.isShown(track(playing: true), at: t0 + 400))
    presence.update(paused, at: t0 + 500)
    #expect(presence.isShown(paused, at: t0 + 700))
    #expect(!presence.isShown(nil, at: t0))
  }

  // MARK: Pausar al dictar

  @Test func pausesWhilePlayingAndResumesAfter() {
    var pauser = MusicPauser()
    var command = pauser.listeningStarted(mode: .dictation, musicPlaying: true)
    #expect(command == .pause)
    pauser.musicChanged(isPlaying: false)  // la propia pausa
    command = pauser.listeningEnded()
    #expect(command == .play)
    command = pauser.listeningEnded()
    #expect(command == nil)
  }

  @Test func doesNotResumeWhatItDidNotPause() {
    var pauser = MusicPauser()
    var command = pauser.listeningStarted(mode: .translation, musicPlaying: false)
    #expect(command == nil)
    command = pauser.listeningEnded()
    #expect(command == nil)
  }

  @Test func doesNotResumeIfTheUserPlayedItMeanwhile() {
    var pauser = MusicPauser()
    _ = pauser.listeningStarted(mode: .ask, musicPlaying: true)
    pauser.musicChanged(isPlaying: true)
    let command = pauser.listeningEnded()
    #expect(command == nil)
  }

  @Test func meetingsLeaveTheMusicAlone() {
    var pauser = MusicPauser()
    var command = pauser.listeningStarted(mode: .meeting, musicPlaying: true)
    #expect(command == nil)
    command = pauser.listeningEnded()
    #expect(command == nil)
  }

  // MARK: Color de la carátula

  private func image(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGImage {
    let context = CGContext(data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
    return context.makeImage()!
  }

  @Test func aDarkRedCoverGivesABrightRed() {
    let tint = ArtworkTint(of: image(red: 0.5, green: 0, blue: 0))
    #expect(abs(tint.red - 1) < 0.01 && tint.green < 0.01 && tint.blue < 0.01)
  }

  @Test func aGreyOrBlackCoverGivesWhite() {
    #expect(ArtworkTint(of: image(red: 0.5, green: 0.5, blue: 0.5)) == .white)
    #expect(ArtworkTint(of: image(red: 0.02, green: 0, blue: 0)) == .white)
  }
}
```

- [ ] **Step 3: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find type 'NowPlaying' in scope`.

- [ ] **Step 4: `IslandActivity`, `IslandForm`, `IslandLayout` e `IslandHover`**

Crear `Sources/SinteclaCore/Island.swift`:

```swift
import CoreGraphics
import Foundation

/// Lo que hace Sintecla, visto desde la isla (spec «La isla» §3.3).
public enum IslandActivity: Equatable, Sendable {
  /// Dictado, traducir, preguntar o notas.
  case listening
  case meeting
  case processing
  case done
  /// Avisos y mensajes de la pastilla.
  case notice

  /// Las que bajan por debajo de la muesca, con el texto debajo. «Hecho» cabe en los lados.
  public var isTall: Bool { self != .done }
}

/// La forma de la isla (spec «La isla» §3.1).
public enum IslandForm: Equatable, Sendable {
  /// A pantalla completa, sin nada de Sintecla: no se ve.
  case hidden
  /// Igual que la muesca real.
  case notch
  /// Con música: carátula a un lado y onda al otro.
  case compact
  /// Con música y el ratón encima.
  case expanded
  /// Sintecla; con `bubble`, la música va al lado en una burbuja.
  case activity(IslandActivity, bubble: Bool)
}

/// Qué forma toca y cuánto mide (spec «La isla» §3.1).
public enum IslandLayout {
  /// Lo que crece la forma compacta por cada lado de la muesca.
  public static let wing: CGFloat = 40
  /// Lo que crecen por cada lado las actividades altas, y lo que bajan por debajo de la muesca.
  public static let tallWing: CGFloat = 86
  public static let tallDrop: CGFloat = 30
  /// Sin muesca, todo va en una fila: lo que baja por debajo de la barra de menús.
  public static let virtualDrop: CGFloat = 14
  /// La desplegada: ancho mínimo y lo que baja por debajo de la muesca.
  public static let expandedWidth: CGFloat = 420
  public static let expandedDrop: CGFloat = 148
  /// Hueco entre la isla y la burbuja de la música.
  public static let bubbleGap: CGFloat = 8

  /// `hasNotch` a false: tapa cerrada, isla virtual arriba en el centro, solo con lo de Sintecla; sin nada, no se ve.
  public static func form(activity: IslandActivity?, music: Bool, hovering: Bool, fullScreen: Bool,
                          hasNotch: Bool = true) -> IslandForm {
    guard hasNotch else { return activity.map { .activity($0, bubble: false) } ?? .hidden }
    if let activity { return .activity(activity, bubble: music) }
    if fullScreen { return .hidden }
    guard music else { return .notch }
    return hovering ? .expanded : .compact
  }

  /// `hasNotch` a false: isla virtual; las actividades altas llevan todo en una fila y bajan menos.
  public static func size(of form: IslandForm, notch: CGSize, hasNotch: Bool = true) -> CGSize {
    switch form {
    case .hidden: .zero
    case .notch: notch
    case .compact, .activity(.done, _): CGSize(width: notch.width + 2 * wing, height: notch.height)
    case .expanded: CGSize(width: max(notch.width + 2 * wing, expandedWidth), height: notch.height + expandedDrop)
    case .activity: CGSize(width: notch.width + 2 * tallWing, height: notch.height + (hasNotch ? tallDrop : virtualDrop))
    }
  }

  /// La burbuja de la música: un círculo del alto de la muesca.
  public static func bubbleDiameter(notch: CGSize) -> CGFloat { notch.height }
}

/// Desplegar al tener el ratón encima 0,15 s y recoger a los 0,3 s de sacarlo (spec «La isla» §3.1).
public struct IslandHover: Equatable, Sendable {
  public static var expandDelay: TimeInterval { 0.15 }
  public static var collapseDelay: TimeInterval { 0.3 }
  /// Las fechas son grandes: sin este margen, 0,15 s podrían medir 0,1499999.
  static var epsilon: TimeInterval { 0.001 }

  public private(set) var isExpanded = false
  private var insideSince: Date?
  private var outsideSince: Date?

  public init() {}

  /// Cada vez que se mueve el ratón (y al cumplirse cada espera). Devuelve si cambió `isExpanded`.
  @discardableResult
  public mutating func update(inside: Bool, at now: Date) -> Bool {
    if inside {
      outsideSince = nil
      guard !isExpanded else { return false }
      let since = insideSince ?? now
      insideSince = since
      guard now.timeIntervalSince(since) >= Self.expandDelay - Self.epsilon else { return false }
      isExpanded = true
      return true
    }
    insideSince = nil
    guard isExpanded else { return false }
    let since = outsideSince ?? now
    outsideSince = since
    guard now.timeIntervalSince(since) >= Self.collapseDelay - Self.epsilon else { return false }
    isExpanded = false
    outsideSince = nil
    return true
  }

  /// Sin música que desplegar, o al cambiar de pantalla.
  public mutating func reset() {
    self = IslandHover()
  }
}
```

- [ ] **Step 5: `NowPlaying`, `NowPlayingUpdate`, `MusicPresence`, `MusicPauser` y `ArtworkTint`**

Crear `Sources/SinteclaCore/NowPlaying.swift`:

```swift
import CoreGraphics
import Foundation

/// Lo que suena (spec «La isla» §3.2 y §4). `elapsed` es el punto en `timestamp`: el actual se calcula con
/// `position(at:)`, sin preguntar cada segundo.
public struct NowPlaying: Equatable, Sendable {
  public var title: String
  public var artist: String
  public var album: String
  /// 0 si no se sabe.
  public var duration: TimeInterval
  public var elapsed: TimeInterval
  public var timestamp: Date
  public var isPlaying: Bool
  /// La app que suena.
  public var pid: Int32?
  /// Cambia cuando cambia la carátula.
  public var artworkID: String?

  public init(title: String, artist: String = "", album: String = "", duration: TimeInterval = 0,
              elapsed: TimeInterval = 0, timestamp: Date, isPlaying: Bool, pid: Int32? = nil, artworkID: String? = nil) {
    self.title = title
    self.artist = artist
    self.album = album
    self.duration = duration
    self.elapsed = elapsed
    self.timestamp = timestamp
    self.isPlaying = isPlaying
    self.pid = pid
    self.artworkID = artworkID
  }

  /// El punto de la canción ahora: avanza si suena y nunca pasa de la duración.
  public func position(at now: Date) -> TimeInterval {
    let position = elapsed + (isPlaying ? max(0, now.timeIntervalSince(timestamp)) : 0)
    return min(max(0, position), duration > 0 ? duration : .infinity)
  }

  /// De 0 a 1; 0 si no se sabe la duración.
  public func progress(at now: Date) -> Double {
    duration > 0 ? position(at: now) / duration : 0
  }

  /// «1:08», o «1:02:05» con horas.
  public static func clock(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds.rounded(.down)))
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
      : String(format: "%d:%02d", s / 60, s % 60)
  }
}

/// Una línea del ayudante de música.
public enum NowPlayingUpdate: Equatable, Sendable {
  /// No suena nada.
  case nothing
  /// `artwork`: la carátula, solo cuando cambia.
  case track(NowPlaying, artwork: Data?)

  private struct Line: Decodable {
    var empty: Bool?
    var playing: Bool?
    var title: String?
    var artist: String?
    var album: String?
    var duration: Double?
    var elapsed: Double?
    var timestamp: Double?
    var pid: Int32?
    var artworkID: String?
    var artwork: String?
  }

  /// Ejemplo: `{"playing":true,"title":"…","artist":"…","duration":195,"elapsed":17.7,"timestamp":1791054000.5,
  /// "pid":1463,"artworkID":"…","artwork":"<base64>"}` o `{"empty":true}`. Una línea rota da nil.
  public static func parse(_ text: String) -> NowPlayingUpdate? {
    guard let data = text.data(using: .utf8), let line = try? JSONDecoder().decode(Line.self, from: data) else {
      return nil
    }
    if line.empty == true { return .nothing }
    guard let title = line.title, let timestamp = line.timestamp else { return nil }
    let track = NowPlaying(title: title, artist: line.artist ?? "", album: line.album ?? "",
                           duration: line.duration ?? 0, elapsed: line.elapsed ?? 0,
                           timestamp: Date(timeIntervalSince1970: timestamp), isPlaying: line.playing ?? false,
                           pid: line.pid, artworkID: line.artworkID)
    return .track(track, artwork: line.artwork.flatMap { Data(base64Encoded: $0) })
  }
}

/// Cuándo se enseña la música (spec «La isla» §3.2): sonando, o en pausa hace menos de 5 minutos.
public struct MusicPresence: Equatable, Sendable {
  public static var pausedLinger: TimeInterval { 300 }
  private var pausedSince: Date?

  public init() {}

  /// Con cada cambio de lo que suena. La pausa cuenta desde que se ve por primera vez.
  public mutating func update(_ track: NowPlaying?, at now: Date) {
    guard let track, !track.isPlaying else {
      pausedSince = nil
      return
    }
    if pausedSince == nil { pausedSince = now }
  }

  public func isShown(_ track: NowPlaying?, at now: Date) -> Bool {
    guard let track else { return false }
    if track.isPlaying { return true }
    guard let pausedSince else { return true }
    return now.timeIntervalSince(pausedSince) < Self.pausedLinger
  }
}

/// Pausar la música al escuchar y reanudarla al terminar, solo si la pausó Sintecla (spec «La isla» §3.4).
public struct MusicPauser: Equatable, Sendable {
  public enum Command: Equatable, Sendable {
    case pause, play
  }

  private var pausedByUs = false

  public init() {}

  /// Empieza a escuchar. En reunión no se toca la música.
  public mutating func listeningStarted(mode: HotkeyMode, musicPlaying: Bool) -> Command? {
    guard mode != .meeting, musicPlaying else { return nil }
    pausedByUs = true
    return .pause
  }

  /// Si la música vuelve a sonar mientras tanto, la puso el usuario: al terminar no se toca.
  public mutating func musicChanged(isPlaying: Bool) {
    if isPlaying { pausedByUs = false }
  }

  /// Termina de escuchar (o se cancela).
  public mutating func listeningEnded() -> Command? {
    defer { pausedByUs = false }
    return pausedByUs ? .play : nil
  }
}

/// El color de la onda: el principal de la carátula, subido de brillo para que se vea sobre negro. Una carátula sin
/// color (gris, blanco o negro) da blanco.
public struct ArtworkTint: Equatable, Sendable {
  public let red: Double
  public let green: Double
  public let blue: Double

  public static let white = ArtworkTint(red: 1, green: 1, blue: 1)

  public init(red: Double, green: Double, blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
  }

  /// Se reduce a 16 × 16 y se hace la media de los píxeles con color.
  public init(of image: CGImage) {
    let side = 16
    var bytes = [UInt8](repeating: 0, count: side * side * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
      guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                    bytesPerRow: side * 4, space: space,
                                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
      context.interpolationQuality = .medium
      context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
      return true
    }
    guard drawn else {
      self = .white
      return
    }
    var sum = (r: 0.0, g: 0.0, b: 0.0), count = 0.0
    for index in stride(from: 0, to: bytes.count, by: 4) {
      let r = Double(bytes[index]) / 255, g = Double(bytes[index + 1]) / 255, b = Double(bytes[index + 2]) / 255
      let high = max(r, g, b), low = min(r, g, b)
      // Solo los píxeles con color y no casi negros.
      guard high > 0.15, (high - low) / high > 0.25 else { continue }
      sum = (sum.r + r, sum.g + g, sum.b + b)
      count += 1
    }
    // Menos de un 10 % de píxeles con color: blanco.
    guard count >= Double(side * side) * 0.1 else {
      self = .white
      return
    }
    let mean = (r: sum.r / count, g: sum.g / count, b: sum.b / count)
    let scale = 1 / max(mean.r, mean.g, mean.b)
    self.init(red: mean.r * scale, green: mean.g * scale, blue: mean.b * scale)
  }
}
```

- [ ] **Step 6: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 341 tests in 57 suites passed`.

- [ ] **Step 7: Commit**

```bash
git add Sources/SinteclaCore/Island.swift Sources/SinteclaCoreTests/IslandTests.swift Sources/SinteclaCore/NowPlaying.swift Sources/SinteclaCoreTests/NowPlayingTests.swift
git commit -m 'feat: formas, ratón y música de la isla en el núcleo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: El ayudante de música y su cliente

**Files:**
- Create: `Resources/Island/NowPlaying.c` y `Resources/Island/now-playing.pl`
- Modify: `scripts/build-app.sh`
- Create: `Sources/Sintecla/NowPlayingClient.swift`

**Interfaces:**
- Consumes: `NowPlaying`, `NowPlayingUpdate.parse(_:)` y `ArtworkTint(of:)` (Tarea 1).
- Produces: `Contents/Resources/NowPlaying.dylib` y `now-playing.pl` en la app; `NowPlayingClient.shared` (`@Observable`) con `status` (`.stopped`, `.starting`, `.ready`, `.unavailable`), `track`, `artwork`, `tint`, `onChange`, `start()`, `stop()`, `send(_:)` (`.play`, `.pause`, `.toggle`, `.next`, `.previous`) y `seek(to:)`.

Desde macOS 15.4, `MediaRemote` no responde a apps que no son de Apple, pero sí a `/usr/bin/perl`. El ayudante es una biblioteca C que carga un script de perl; Sintecla lo arranca como proceso hijo y habla con él por la entrada y la salida estándar (una línea JSON por cambio; una orden por línea). Aún no lo arranca nadie: lo hará la isla en la Tarea 5.

- [ ] **Step 1: El ayudante en C**

Crear `Resources/Island/NowPlaying.c`:

```text
// Ayudante de música de Sintecla (spec «La isla» §4).
//
// Desde macOS 15.4, MediaRemote no responde a apps que no son de Apple, pero sí a /usr/bin/perl. Por eso esta
// biblioteca la carga `now-playing.pl` dentro de perl, y Sintecla habla con ella por la entrada y la salida estándar:
//   - salida: una línea JSON con cada cambio de lo que suena ({"empty":true} si no suena nada);
//   - entrada: una orden por línea: play, pause, toggle, next, previous o «seek <segundos>».
// Al cerrarse la entrada (Sintecla ha salido), termina.

#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef void (*GetInfoFn)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*GetPlayingFn)(dispatch_queue_t, void (^)(Boolean));
typedef void (*GetPIDFn)(dispatch_queue_t, void (^)(int));
typedef void (*RegisterFn)(dispatch_queue_t);
typedef Boolean (*SendCommandFn)(int, CFDictionaryRef);
typedef void (*SetElapsedFn)(double);

static GetInfoFn get_info;
static GetPlayingFn get_playing;
static GetPIDFn get_pid;
static SendCommandFn send_command;
static SetElapsedFn set_elapsed;

static char *last_line;
static char last_artwork_id[64];
static int report_pending;

// MARK: - JSON

typedef struct {
  char *text;
  size_t length, capacity;
} Buffer;

static void append(Buffer *buffer, const char *text, size_t length) {
  if (buffer->length + length + 1 > buffer->capacity) {
    buffer->capacity = (buffer->length + length + 1) * 2;
    buffer->text = realloc(buffer->text, buffer->capacity);
  }
  memcpy(buffer->text + buffer->length, text, length);
  buffer->length += length;
  buffer->text[buffer->length] = 0;
}

static void append_text(Buffer *buffer, const char *text) { append(buffer, text, strlen(text)); }

static void append_string(Buffer *buffer, CFStringRef string) {
  append_text(buffer, "\"");
  if (string) {
    CFIndex size = CFStringGetMaximumSizeForEncoding(CFStringGetLength(string), kCFStringEncodingUTF8) + 1;
    char *utf8 = malloc(size);
    if (CFStringGetCString(string, utf8, size, kCFStringEncodingUTF8)) {
      for (const unsigned char *c = (const unsigned char *)utf8; *c; c++) {
        char escaped[8];
        if (*c == '"' || *c == '\\') {
          snprintf(escaped, sizeof escaped, "\\%c", *c);
          append_text(buffer, escaped);
        } else if (*c < 0x20) {
          snprintf(escaped, sizeof escaped, "\\u%04x", *c);
          append_text(buffer, escaped);
        } else {
          append(buffer, (const char *)c, 1);
        }
      }
    }
    free(utf8);
  }
  append_text(buffer, "\"");
}

static void append_base64(Buffer *buffer, const UInt8 *bytes, CFIndex length) {
  static const char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  char quad[4];
  for (CFIndex i = 0; i < length; i += 3) {
    UInt32 n = (UInt32)bytes[i] << 16;
    if (i + 1 < length) n |= (UInt32)bytes[i + 1] << 8;
    if (i + 2 < length) n |= bytes[i + 2];
    quad[0] = table[(n >> 18) & 63];
    quad[1] = table[(n >> 12) & 63];
    quad[2] = i + 1 < length ? table[(n >> 6) & 63] : '=';
    quad[3] = i + 2 < length ? table[n & 63] : '=';
    append(buffer, quad, 4);
  }
}

static CFTypeRef value(CFDictionaryRef info, const char *key) {
  CFStringRef name = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
  CFTypeRef found = CFDictionaryGetValue(info, name);
  CFRelease(name);
  return found;
}

static double number(CFDictionaryRef info, const char *key, double fallback) {
  CFTypeRef found = value(info, key);
  double result = fallback;
  if (found && CFGetTypeID(found) == CFNumberGetTypeID()) CFNumberGetValue(found, kCFNumberDoubleType, &result);
  return result;
}

static CFStringRef string(CFDictionaryRef info, const char *key) {
  CFTypeRef found = value(info, key);
  return found && CFGetTypeID(found) == CFStringGetTypeID() ? found : NULL;
}

// MARK: - Avisos

static void emit(CFDictionaryRef info, Boolean playing, int pid) {
  Buffer line = {0};
  CFStringRef title = info ? string(info, "kMRMediaRemoteNowPlayingInfoTitle") : NULL;
  if (!title || CFStringGetLength(title) == 0) {
    append_text(&line, "{\"empty\":true}");
  } else {
    char number_text[256];
    append_text(&line, playing ? "{\"playing\":true,\"title\":" : "{\"playing\":false,\"title\":");
    append_string(&line, title);
    append_text(&line, ",\"artist\":");
    append_string(&line, string(info, "kMRMediaRemoteNowPlayingInfoArtist"));
    append_text(&line, ",\"album\":");
    append_string(&line, string(info, "kMRMediaRemoteNowPlayingInfoAlbum"));
    double timestamp = CFAbsoluteTimeGetCurrent();
    CFTypeRef date = value(info, "kMRMediaRemoteNowPlayingInfoTimestamp");
    if (date && CFGetTypeID(date) == CFDateGetTypeID()) timestamp = CFDateGetAbsoluteTime(date);
    snprintf(number_text, sizeof number_text, ",\"duration\":%.3f,\"elapsed\":%.3f,\"timestamp\":%.3f,\"pid\":%d",
             number(info, "kMRMediaRemoteNowPlayingInfoDuration", 0),
             number(info, "kMRMediaRemoteNowPlayingInfoElapsedTime", 0),
             timestamp + kCFAbsoluteTimeIntervalSince1970, pid);
    append_text(&line, number_text);
    CFTypeRef artwork = value(info, "kMRMediaRemoteNowPlayingInfoArtworkData");
    if (artwork && CFGetTypeID(artwork) == CFDataGetTypeID() && CFDataGetLength(artwork) > 0) {
      // La carátula se reconoce por su tamaño y un resumen de sus primeros bytes, y solo viaja cuando cambia.
      const UInt8 *bytes = CFDataGetBytePtr(artwork);
      CFIndex length = CFDataGetLength(artwork);
      UInt32 hash = 2166136261u;
      for (CFIndex i = 0; i < length && i < 8192; i++) hash = (hash ^ bytes[i]) * 16777619u;
      char artwork_id[64];
      snprintf(artwork_id, sizeof artwork_id, "%ld-%08x", (long)length, hash);
      append_text(&line, ",\"artworkID\":\"");
      append_text(&line, artwork_id);
      append_text(&line, "\"");
      if (strcmp(artwork_id, last_artwork_id) != 0) {
        append_text(&line, ",\"artwork\":\"");
        append_base64(&line, bytes, length);
        append_text(&line, "\"");
        strlcpy(last_artwork_id, artwork_id, sizeof last_artwork_id);
      }
    } else {
      // Algunas apps (Spotify) la quitan en pausa: al volver, aunque sea la misma, se manda otra vez.
      last_artwork_id[0] = 0;
    }
    append_text(&line, "}");
  }
  if (!last_line || strcmp(line.text, last_line) != 0) {
    printf("%s\n", line.text);
    fflush(stdout);
    free(last_line);
    last_line = line.text;
  } else {
    free(line.text);
  }
}

static void report(void) {
  get_info(dispatch_get_main_queue(), ^(CFDictionaryRef info) {
    if (info) CFRetain(info);
    get_playing(dispatch_get_main_queue(), ^(Boolean playing) {
      get_pid(dispatch_get_main_queue(), ^(int pid) {
        emit(info, playing, pid);
        if (info) CFRelease(info);
      });
    });
  });
}

/// Los avisos de MediaRemote llegan a ráfagas: se juntan en uno cada 100 ms.
static void schedule_report(double delay) {
  if (report_pending) return;
  report_pending = 1;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    report_pending = 0;
    report();
  });
}

static void changed(CFNotificationCenterRef center, void *observer, CFNotificationName name, const void *object,
                    CFDictionaryRef info) {
  schedule_report(0.1);
}

// MARK: - Órdenes

static void run_command(char *command) {
  if (strcmp(command, "play") == 0) send_command(0, NULL);
  else if (strcmp(command, "pause") == 0) send_command(1, NULL);
  else if (strcmp(command, "toggle") == 0) send_command(2, NULL);
  else if (strcmp(command, "next") == 0) send_command(4, NULL);
  else if (strcmp(command, "previous") == 0) send_command(5, NULL);
  else if (strncmp(command, "seek ", 5) == 0) set_elapsed(atof(command + 5));
  else return;
  // La app tarda un poco en aplicar la orden.
  schedule_report(0.3);
}

static void listen_to_commands(void) {
  static char pending[1024];
  static size_t used;
  dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0,
                                                    dispatch_get_main_queue());
  dispatch_source_set_event_handler(source, ^{
    char chunk[512];
    ssize_t count = read(STDIN_FILENO, chunk, sizeof chunk);
    if (count <= 0) exit(0);  // Sintecla ha salido
    for (ssize_t i = 0; i < count; i++) {
      if (chunk[i] == '\n') {
        pending[used] = 0;
        run_command(pending);
        used = 0;
      } else if (used < sizeof pending - 1) {
        pending[used++] = chunk[i];
      }
    }
  });
  dispatch_resume(source);
}

// MARK: - Arranque

/// La llama `now-playing.pl`. No vuelve nunca: termina cuando se cierra la entrada.
void sintecla_now_playing_run(void *perl, void *cv) {
  void *media = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
  get_info = (GetInfoFn)dlsym(media, "MRMediaRemoteGetNowPlayingInfo");
  get_playing = (GetPlayingFn)dlsym(media, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
  get_pid = (GetPIDFn)dlsym(media, "MRMediaRemoteGetNowPlayingApplicationPID");
  send_command = (SendCommandFn)dlsym(media, "MRMediaRemoteSendCommand");
  set_elapsed = (SetElapsedFn)dlsym(media, "MRMediaRemoteSetElapsedTime");
  RegisterFn register_notifications = (RegisterFn)dlsym(media, "MRMediaRemoteRegisterForNowPlayingNotifications");
  if (!get_info || !get_playing || !get_pid || !send_command || !set_elapsed || !register_notifications) {
    fprintf(stderr, "MediaRemote no disponible\n");
    exit(1);
  }
  register_notifications(dispatch_get_main_queue());
  const char *names[] = {"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                         "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
                         "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"};
  for (int i = 0; i < 3; i++) {
    CFStringRef name = CFStringCreateWithCString(NULL, names[i], kCFStringEncodingUTF8);
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, changed, name, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFRelease(name);
  }
  // Por si algún cambio no avisa (un salto en la canción, por ejemplo): se mira también cada 3 s.
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
  dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), 3 * NSEC_PER_SEC,
                            NSEC_PER_SEC / 2);
  dispatch_source_set_event_handler(timer, ^{ report(); });
  dispatch_resume(timer);
  listen_to_commands();
  report();
  CFRunLoopRun();
}
```

- [ ] **Step 2: El script de perl que lo carga**

Crear `Resources/Island/now-playing.pl`:

```text
#!/usr/bin/perl
# Ayudante de música de Sintecla (spec «La isla» §4): carga NowPlaying.dylib dentro de /usr/bin/perl, que sí puede
# preguntar a MediaRemote, y le pasa el control. Uso: /usr/bin/perl now-playing.pl /ruta/NowPlaying.dylib
use strict;
use warnings;
use DynaLoader;

my $library = shift @ARGV or die "falta la ruta de NowPlaying.dylib\n";
my $handle = DynaLoader::dl_load_file($library, 0) or die DynaLoader::dl_error() . "\n";
my $symbol = DynaLoader::dl_find_symbol($handle, "sintecla_now_playing_run") or die "NowPlaying.dylib sin su función\n";
DynaLoader::dl_install_xsub("main::run", $symbol);
run();
```

- [ ] **Step 3: Compila sin avisos**

Run:

```bash
clang -dynamiclib -O2 -Wall -Wextra -Werror -Wno-unused-parameter -mmacosx-version-min=26.0 -framework CoreFoundation Resources/Island/NowPlaying.c -o /tmp/sintecla-NowPlaying.dylib 2>&1 && echo compilado
```

Esperado: `compilado`.

- [ ] **Step 4: `build-app.sh` lo compila y lo mete en la app**

En `scripts/build-app.sh`, cambiar:

```bash
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
```

por:

```bash
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# El ayudante de música de la isla (spec «La isla» §4): una biblioteca que carga /usr/bin/perl con su script.
clang -dynamiclib -O2 -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=26.0 -framework CoreFoundation \
  Resources/Island/NowPlaying.c -o "$APP/Contents/Resources/NowPlaying.dylib"
cp Resources/Island/now-playing.pl "$APP/Contents/Resources/now-playing.pl"
```

- [ ] **Step 5: `NowPlayingClient`**

Crear `Sources/Sintecla/NowPlayingClient.swift`:

```swift
import AppKit
import Observation
import SinteclaCore

/// Habla con el ayudante de música (spec «La isla» §4): lo arranca dentro de `/usr/bin/perl`, lee lo que suena y le
/// manda las órdenes. Si se cae, lo relanza con espera creciente. Hay uno solo para toda la app.
@MainActor @Observable
final class NowPlayingClient {
  static let shared = NowPlayingClient()

  enum Status: Equatable {
    case stopped
    case starting
    /// Ya ha dicho algo: la música funciona en este macOS.
    case ready
    /// No arranca o no responde.
    case unavailable
  }

  private(set) var status = Status.stopped
  private(set) var track: NowPlaying?
  private(set) var artwork: NSImage?
  /// El color de la onda, sacado de la carátula.
  private(set) var tint = ArtworkTint.white
  /// Con cada cambio de lo que suena (para `MusicPauser`).
  var onChange: ((NowPlaying?) -> Void)?

  private var process: Process?
  private var input: FileHandle?
  private var buffer = Data()
  private var retryDelay: TimeInterval = 1
  private var retryTask: Task<Void, Never>?
  private var wanted = false

  /// La biblioteca y el script, dentro de la app (`build-app.sh` los mete). Con `swift run` no están.
  private static var files: (library: URL, script: URL)? {
    guard let library = Bundle.main.url(forResource: "NowPlaying", withExtension: "dylib"),
          let script = Bundle.main.url(forResource: "now-playing", withExtension: "pl") else { return nil }
    return (library, script)
  }

  func start() {
    wanted = true
    guard process == nil else { return }
    launch()
  }

  func stop() {
    wanted = false
    retryTask?.cancel()
    process?.terminate()
    process = nil
    input = nil
    status = .stopped
    publish(nil, artwork: nil)
  }

  enum Command: String {
    case play, pause, toggle, next, previous
  }

  func send(_ command: Command) {
    write(command.rawValue)
  }

  func seek(to seconds: TimeInterval) {
    write(String(format: "seek %.2f", seconds))
  }

  private func write(_ line: String) {
    try? input?.write(contentsOf: Data((line + "\n").utf8))
  }

  private func launch() {
    guard let files = Self.files else {
      status = .unavailable
      return
    }
    if status != .ready { status = .starting }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
    process.arguments = [files.script.path, files.library.path]
    let output = Pipe(), input = Pipe()
    process.standardOutput = output
    process.standardInput = input
    process.standardError = FileHandle.nullDevice
    output.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      // Vacío: el ayudante ha cerrado su salida; sin esto, se volvería a llamar sin parar.
      guard !data.isEmpty else {
        handle.readabilityHandler = nil
        return
      }
      Task { @MainActor in self?.received(data) }
    }
    process.terminationHandler = { [weak self] _ in
      Task { @MainActor in self?.ended() }
    }
    do {
      try process.run()
    } catch {
      status = .unavailable
      return
    }
    self.process = process
    self.input = input.fileHandleForWriting
  }

  private func received(_ data: Data) {
    buffer.append(data)
    while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
      let line = String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self)
      buffer.removeSubrange(buffer.startIndex...newline)
      guard let update = NowPlayingUpdate.parse(line) else { continue }
      status = .ready
      retryDelay = 1
      switch update {
      case .nothing: publish(nil, artwork: nil)
      case .track(let track, let data): publish(track, artwork: data)
      }
    }
  }

  private func publish(_ track: NowPlaying?, artwork data: Data?) {
    // El ayudante manda la carátula solo cuando cambia: sin datos y con el mismo `artworkID`, sigue la que había.
    // Sin carátula y con la misma canción (Spotify la quita en pausa), también sigue.
    if let data, let image = NSImage(data: data) {
      artwork = image
      tint = image.cgImage(forProposedRect: nil, context: nil, hints: nil).map(ArtworkTint.init(of:)) ?? .white
    } else if track?.artworkID == nil, !Self.sameSong(track, self.track) {
      artwork = nil
      tint = .white
    }
    guard track != self.track else { return }
    self.track = track
    onChange?(track)
  }

  private static func sameSong(_ a: NowPlaying?, _ b: NowPlaying?) -> Bool {
    guard let a, let b else { return false }
    return a.title == b.title && a.artist == b.artist && a.album == b.album
  }

  /// El ayudante ha terminado: si no era a propósito, se relanza con espera creciente (1, 2, 4… hasta 60 s).
  private func ended() {
    process = nil
    input = nil
    buffer.removeAll()
    guard wanted else { return }
    if status != .ready { status = .unavailable }
    publish(nil, artwork: nil)
    let delay = retryDelay
    retryDelay = min(60, retryDelay * 2)
    retryTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay))
      guard let self, !Task.isCancelled, self.wanted, self.process == nil else { return }
      self.launch()
    }
  }
}
```

- [ ] **Step 6: Compilar la release (sin avisos)**

Run:

```bash
source scripts/sdk-env.sh && swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build complete' | grep -v 'ld: warning: search path' | tail -3
```

Esperado: `Build complete!`.

- [ ] **Step 7: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 341 tests in 57 suites passed`.

- [ ] **Step 8: Commit**

```bash
git add Resources/Island/NowPlaying.c Resources/Island/now-playing.pl scripts/build-app.sh Sources/Sintecla/NowPlayingClient.swift
git commit -m 'feat: ayudante de música para la isla

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: El módulo Isla, su página y su tarjeta

**Files:**
- Modify: `Sources/SinteclaCore/Modules.swift` y Test: `Sources/SinteclaCoreTests/ModulesTests.swift`
- Modify: `Sources/Sintecla/AppSettings.swift` (`moduleIsland`)
- Create: `Sources/Sintecla/NotchScreen.swift` y `Sources/Sintecla/IslandPage.swift`
- Modify: `Sources/Sintecla/HomeView.swift` (tarjeta) y `Sources/Sintecla/MainWindow.swift` (página)

**Interfaces:**
- Consumes: `NowPlayingClient.shared.status` (Tarea 2).
- Produces: `Module.island`, `ModulePage.island`, `ModuleSwitches.island` (con `island: Bool = false` en el `init`); `AppSettings.moduleIsland` (UserDefaults `moduleIsland`, `false`); `NotchScreen.current` y `NotchScreen.notchRect(on:)`; `IslandPage()`.

- [ ] **Step 1: Tests: el módulo Isla, apagado salvo que se diga**

En `Sources/SinteclaCoreTests/ModulesTests.swift`, cambiar:

```swift
  let allOn = ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true, altTab: true, dock: true)
```

por:

```swift
  let allOn = ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true, altTab: true, dock: true,
                             island: true)
```

Y cambiar:

```swift
    #expect(Module.dock.pages == [.dock])
```

por:

```swift
    #expect(Module.dock.pages == [.dock])
    #expect(Module.island.pages == [.island])
```

Y cambiar:

```swift
    #expect(Module.allCases.map(\.name) == ["Dictado", "Reuniones", "Finder", "Capturas", "Alt-Tab", "Dock"])
```

por:

```swift
    #expect(Module.allCases.map(\.name) == ["Dictado", "Reuniones", "Finder", "Capturas", "Alt-Tab", "Dock", "Isla"])
    #expect(ModulePage.island.title == "Isla")
```

Y cambiar:

```swift
    #expect(allOn.enabled == [.dictation, .meetings, .finder, .captures, .altTab, .dock])
```

por:

```swift
    #expect(allOn.enabled == [.dictation, .meetings, .finder, .captures, .altTab, .dock, .island])
```

Y cambiar:

```swift
    switches[.dock] = false
    #expect(!switches.dock)
  }
```

por:

```swift
    switches[.dock] = false
    #expect(!switches.dock)
    switches[.island] = false
    #expect(!switches.island)
  }
```

Y cambiar:

```swift
    #expect(!ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true, altTab: true).dock)
```

por:

```swift
    #expect(!ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true, altTab: true).dock)
    #expect(!ModuleSwitches(dictation: true, meetings: true, finder: true, captures: true, altTab: true, dock: true).island)
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: extra argument 'island' in call`.

- [ ] **Step 3: `Module.island`, su página y su interruptor**

En `Sources/SinteclaCore/Modules.swift`, cambiar:

```swift
  case dictation, meetings, finder, captures, altTab, dock
```

por:

```swift
  case dictation, meetings, finder, captures, altTab, dock, island
```

Y cambiar:

```swift
    case .dock: "Dock"
    }
  }

  public var symbol: String {
    switch self {
    case .dictation: "waveform"
```

por:

```swift
    case .dock: "Dock"
    case .island: "Isla"
    }
  }

  public var symbol: String {
    switch self {
    case .dictation: "waveform"
```

Y cambiar:

```swift
    case .dock: "dock.rectangle"
    }
  }

  /// Lo que hace, para la página Módulos.
```

por:

```swift
    case .dock: "dock.rectangle"
    case .island: "capsule.tophalf.filled"
    }
  }

  /// Lo que hace, para la página Módulos.
```

Y cambiar:

```swift
      + "Las miniaturas necesitan el permiso de Grabación de pantalla."
    }
```

por:

```swift
      + "Las miniaturas necesitan el permiso de Grabación de pantalla."
    case .island: "La muesca del MacBook cobra vida, como la Dynamic Island: la música que suena y el dictado, las "
      + "reuniones y los avisos de Sintecla. Al dictar, la música se pausa."
    }
```

Y cambiar:

```swift
  case dock

  public var module: Module {
```

por:

```swift
  case dock
  case island

  public var module: Module {
```

Y cambiar:

```swift
    case .dock: .dock
    }
```

por:

```swift
    case .dock: .dock
    case .island: .island
    }
```

Y cambiar:

```swift
    case .dock: "Dock"
    }
  }

  public var symbol: String {
    switch self {
    case .history:
```

por:

```swift
    case .dock: "Dock"
    case .island: "Isla"
    }
  }

  public var symbol: String {
    switch self {
    case .history:
```

Y cambiar:

```swift
    case .dock: "dock.rectangle"
    }
  }
}

/// Qué módulos están encendidos.
```

por:

```swift
    case .dock: "dock.rectangle"
    case .island: "capsule.tophalf.filled"
    }
  }
}

/// Qué módulos están encendidos.
```

Y cambiar:

```swift
  public var dock: Bool

  public init(dictation: Bool, meetings: Bool, finder: Bool, captures: Bool = false, altTab: Bool = false,
              dock: Bool = false) {
```

por:

```swift
  public var dock: Bool
  public var island: Bool

  public init(dictation: Bool, meetings: Bool, finder: Bool, captures: Bool = false, altTab: Bool = false,
              dock: Bool = false, island: Bool = false) {
```

Y cambiar:

```swift
    self.dock = dock
```

por:

```swift
    self.dock = dock
    self.island = island
```

Y cambiar:

```swift
      case .dock: dock
```

por:

```swift
      case .dock: dock
      case .island: island
```

Y cambiar:

```swift
      case .dock: dock = newValue
```

por:

```swift
      case .dock: dock = newValue
      case .island: island = newValue
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 341 tests in 57 suites passed`.

- [ ] **Step 5: `AppSettings.moduleIsland`**

En `Sources/Sintecla/AppSettings.swift`, cambiar:

```swift
  var moduleDock: Bool { didSet { defaults.set(moduleDock, forKey: "moduleDock") } }
```

por:

```swift
  var moduleDock: Bool { didSet { defaults.set(moduleDock, forKey: "moduleDock") } }
  /// Módulo Isla (spec «La isla»), apagado por defecto.
  var moduleIsland: Bool { didSet { defaults.set(moduleIsland, forKey: "moduleIsland") } }
```

Y cambiar:

```swift
      "moduleAltTab": false, "moduleDock": false,
```

por:

```swift
      "moduleAltTab": false, "moduleDock": false, "moduleIsland": false,
```

Y cambiar:

```swift
    moduleDock = defaults.bool(forKey: "moduleDock")
```

por:

```swift
    moduleDock = defaults.bool(forKey: "moduleDock")
    moduleIsland = defaults.bool(forKey: "moduleIsland")
```

Y cambiar:

```swift
                     altTab: moduleAltTab, dock: moduleDock)
```

por:

```swift
                     altTab: moduleAltTab, dock: moduleDock, island: moduleIsland)
```

Y cambiar:

```swift
      if moduleDock != newValue.dock { moduleDock = newValue.dock }
```

por:

```swift
      if moduleDock != newValue.dock { moduleDock = newValue.dock }
      if moduleIsland != newValue.island { moduleIsland = newValue.island }
```

- [ ] **Step 6: `NotchScreen`: la pantalla con muesca y la muesca**

Crear `Sources/Sintecla/NotchScreen.swift`:

```swift
import AppKit

/// La pantalla con muesca y el sitio de la muesca (spec «La isla» §5). Solo la del MacBook la tiene: con la tapa
/// cerrada no hay ninguna, y la isla es virtual (`virtualNotch(on:)`).
@MainActor
enum NotchScreen {
  static var current: NSScreen? {
    NSScreen.screens.first { $0.safeAreaInsets.top > 0 && $0.auxiliaryTopLeftArea != nil }
  }

  /// El rectángulo de la muesca, en coordenadas de AppKit: entre las dos zonas libres de arriba
  /// (`auxiliaryTopLeftArea` y `auxiliaryTopRightArea`), con el alto de `safeAreaInsets.top`.
  static func notchRect(on screen: NSScreen) -> CGRect? {
    guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return nil }
    let frame = screen.frame
    let height = screen.safeAreaInsets.top
    let width = frame.width - left.width - right.width
    guard width > 0, height > 0 else { return nil }
    return CGRect(x: frame.minX + left.width, y: frame.maxY - height, width: width, height: height)
  }

  /// Sin muesca: una muesca imaginaria arriba en el centro, del alto de la barra de menús, de donde cuelga la isla.
  static func virtualNotch(on screen: NSScreen) -> CGRect {
    let size = CGSize(width: 180, height: NSStatusBar.system.thickness)
    return CGRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height, width: size.width,
                  height: size.height)
  }
}
```

- [ ] **Step 7: La página Isla**

Crear `Sources/Sintecla/IslandPage.swift`:

```swift
import Combine
import SinteclaCore
import SwiftUI

/// Isla → Isla (spec «La isla» §2): qué enseña, si hay muesca y si la música funciona en este macOS.
struct IslandPage: View {
  private let music = NowPlayingClient.shared
  @State private var hasNotch = NotchScreen.current != nil
  private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

  var body: some View {
    Form {
      Section("Qué enseña") {
        LabeledContent("Música", value: "Carátula y onda; al pasar el ratón, la canción y sus controles")
        LabeledContent("Sintecla", value: "Dictado, reuniones y avisos, en lugar de la pastilla de abajo")
        LabeledContent("Al dictar", value: "La música se pausa y vuelve al terminar")
        Text("Al pasar el ratón por la isla con música se despliega: un clic en la carátula abre la app que suena y la "
             + "barra de progreso se puede arrastrar.")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("Estado") {
        LabeledContent("Muesca") {
          Label(hasNotch ? "Pantalla del MacBook" : "Sin muesca: isla arriba en el centro, solo con Sintecla",
                systemImage: hasNotch ? "checkmark.circle.fill" : "macbook")
        }
        LabeledContent("Música") {
          switch music.status {
          case .ready: Label("Lista", systemImage: "checkmark.circle.fill")
          case .unavailable: Label("No disponible en este macOS", systemImage: "xmark.circle")
          case .starting, .stopped: Label("Comprobando…", systemImage: "hourglass")
          }
        }
      }
    }
    .formStyle(.grouped)
    .onReceive(timer) { _ in hasNotch = NotchScreen.current != nil }
  }
}
```

- [ ] **Step 8: La tarjeta de la isla en Inicio**

En `Sources/Sintecla/HomeView.swift`, cambiar:

```swift
        Label("Sin miniaturas: falta el permiso de Grabación de pantalla", systemImage: "exclamationmark.triangle")
          .font(.callout)
      }
    }
```

por:

```swift
        Label("Sin miniaturas: falta el permiso de Grabación de pantalla", systemImage: "exclamationmark.triangle")
          .font(.callout)
      }
    case .island:
      Text("Música y Sintecla en la muesca").foregroundStyle(.secondary)
      if NotchScreen.current == nil {
        Label("Sin muesca: solo Sintecla, arriba en el centro", systemImage: "macbook").font(.callout)
      }
    }
```

- [ ] **Step 9: La página en la ventana**

En `Sources/Sintecla/MainWindow.swift`, cambiar:

```swift
    case .dock: DockPage()
```

por:

```swift
    case .dock: DockPage()
    case .island: IslandPage()
```

- [ ] **Step 10: Compilar la release (sin avisos)**

Run:

```bash
source scripts/sdk-env.sh && swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build complete' | grep -v 'ld: warning: search path' | tail -3
```

Esperado: `Build complete!`.

Si sale alguna línea `warning:` (aparte de las de `ld: warning: search path`, que se filtran), corrígela antes de seguir.

- [ ] **Step 11: Commit**

```bash
git add Sources/SinteclaCore/Modules.swift Sources/SinteclaCoreTests/ModulesTests.swift Sources/Sintecla/AppSettings.swift Sources/Sintecla/NotchScreen.swift Sources/Sintecla/IslandPage.swift Sources/Sintecla/HomeView.swift Sources/Sintecla/MainWindow.swift
git commit -m 'feat: módulo Isla con su página y su tarjeta

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 4: La vista de la isla

**Files:**
- Create: `Sources/Sintecla/IslandShape.swift`, `Sources/Sintecla/IslandView.swift` y `Sources/Sintecla/IslandPanel.swift`
- Modify: `Sources/Sintecla/Overlay.swift` (los textos e iconos, compartidos)

**Interfaces:**
- Consumes: Tarea 1 (`IslandForm`, `IslandLayout`, `IslandActivity`, `NowPlaying`, `ArtworkTint`); `NowPlayingClient` (Tarea 2); `OverlayModel`, `LevelBars` y `OverlayView.clock(_:)` (`Overlay.swift`); `FirstMouseHostingView` (Ask Anything).
- Produces: `IslandShape(flare:bottomRadius:)`; `IslandModel` (`form`, `notch`, `hasNotch`, `scrub`); `IslandView(model:overlay:music:onOpenApp:onCommand:onSeek:)` con `IslandView.flare`; `MusicBars(playing:tint:)`; `IslandPanel(view:)` con `show(on:notch:)`, `hide()` y `acceptsMouse`; `OverlayView.symbol(for:)` y `OverlayView.label(for:liveText:)`.

La isla lee el mismo `OverlayModel` que la pastilla: por eso los textos y los iconos de cada estado pasan a funciones de `OverlayView` que usan las dos. La forma es una sola y cambia con el muelle; dentro, el contenido entra y sale con fundido.

- [ ] **Step 1: `OverlayView`: el icono y el texto de cada estado, para la isla también**

En `Sources/Sintecla/Overlay.swift`, cambiar:

```swift
  private var symbol: String {
    switch model.phase {
```

por:

```swift
  private var symbol: String { Self.symbol(for: model.phase) }

  /// El icono de cada estado (también lo usa la isla).
  static func symbol(for phase: OverlayModel.Phase) -> String {
    switch phase {
```

Y cambiar:

```swift
  /// Texto de la cápsula; nil = solo la gota (al terminar, la cápsula se funde en ella).
  private var label: String? {
    switch model.phase {
    case .listening(.notes): model.liveText.isEmpty ? "Tomando notas… (Esc cancela)" : model.liveText
    case .listening(.meeting): model.liveText.isEmpty ? "Reunión" : model.liveText
```

por:

```swift
  private var label: String? { Self.label(for: model.phase, liveText: model.liveText) }

  /// Texto de la cápsula (también lo usa la isla); nil = solo la gota (al terminar, la cápsula se funde en ella).
  static func label(for phase: OverlayModel.Phase, liveText: String) -> String? {
    switch phase {
    case .listening(.notes): liveText.isEmpty ? "Tomando notas… (Esc cancela)" : liveText
    case .listening(.meeting): liveText.isEmpty ? "Reunión" : liveText
```

- [ ] **Step 2: `IslandShape`: la forma de la muesca**

Crear `Sources/Sintecla/IslandShape.swift`:

```swift
import SwiftUI

/// La forma de la isla (spec «La isla» §3.1): como la muesca, pegada al borde de arriba, con las esquinas de arriba
/// abiertas hacia fuera (`flare`) y las de abajo redondeadas (`bottomRadius`). El cuerpo ocupa todo el ancho menos las
/// dos curvas de arriba. Los dos radios se animan con el muelle, igual que el tamaño.
struct IslandShape: Shape {
  var flare: CGFloat
  var bottomRadius: CGFloat

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(flare, bottomRadius) }
    set {
      flare = newValue.first
      bottomRadius = newValue.second
    }
  }

  func path(in rect: CGRect) -> Path {
    let flare = min(flare, rect.width / 4, rect.height / 2)
    let radius = min(bottomRadius, (rect.width - 2 * flare) / 2, rect.height - flare)
    let left = rect.minX + flare, right = rect.maxX - flare
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addQuadCurve(to: CGPoint(x: left, y: rect.minY + flare), control: CGPoint(x: left, y: rect.minY))
    path.addArc(tangent1End: CGPoint(x: left, y: rect.maxY), tangent2End: CGPoint(x: right, y: rect.maxY), radius: radius)
    path.addArc(tangent1End: CGPoint(x: right, y: rect.maxY), tangent2End: CGPoint(x: right, y: rect.minY), radius: radius)
    path.addLine(to: CGPoint(x: right, y: rect.minY + flare))
    path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: right, y: rect.minY))
    path.closeSubpath()
    return path
  }
}
```

- [ ] **Step 3: `IslandView`: formas, música, Sintecla y burbuja**

Crear `Sources/Sintecla/IslandView.swift`:

```swift
import AppKit
import Observation
import SinteclaCore
import SwiftUI

/// Lo que decide el controlador y pinta la isla.
@MainActor @Observable
final class IslandModel {
  var form = IslandForm.notch
  /// El tamaño de la muesca de esta pantalla.
  var notch = CGSize(width: 200, height: 32)
  /// Sin muesca (tapa cerrada): isla virtual, con lo de Sintecla en una fila centrada.
  var hasNotch = true
  /// Mientras se arrastra la barra de progreso: la fracción que se enseña (de 0 a 1).
  var scrub: Double?
}

/// La isla (spec «La isla» §3): una sola forma negra que cambia de tamaño con un muelle; dentro, la música o lo de
/// Sintecla, que entran y salen con fundido. Siempre en blanco sobre negro.
struct IslandView: View {
  let model: IslandModel
  let overlay: OverlayModel
  let music: NowPlayingClient
  var onOpenApp: () -> Void
  var onCommand: (NowPlayingClient.Command) -> Void
  var onSeek: (Double) -> Void

  /// Lo que se abren las esquinas de arriba hacia los lados.
  static let flare: CGFloat = 6
  static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
  /// Los avisos bajan con un rebote.
  static let bounce = Animation.spring(response: 0.4, dampingFraction: 0.62)

  var body: some View {
    let size = IslandLayout.size(of: model.form, notch: model.notch, hasNotch: model.hasNotch)
    island(size)
      .overlay(alignment: .topTrailing) {
        if case .activity(_, true) = model.form {
          bubble
            .offset(x: IslandLayout.bubbleDiameter(notch: model.notch) + IslandLayout.bubbleGap)
            .transition(.scale(scale: 0.3, anchor: .leading).combined(with: .opacity))
        }
      }
      .animation(isNotice ? Self.bounce : Self.spring, value: model.form)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .foregroundStyle(.white)
      .environment(\.colorScheme, .dark)
  }

  private var isNotice: Bool {
    if case .activity(.notice, _) = model.form { return true }
    return false
  }

  // MARK: La forma

  private func island(_ size: CGSize) -> some View {
    ZStack(alignment: .top) {
      IslandShape(flare: Self.flare, bottomRadius: bottomRadius).fill(.black)
      if case .activity(.processing, _) = model.form {
        Shimmer(flare: Self.flare, bottomRadius: bottomRadius)
      }
      content
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipped()
    }
    .frame(width: size.width + 2 * Self.flare, height: size.height)
    .shadow(color: .black.opacity(model.form == .expanded ? 0.35 : 0), radius: 18, y: 8)
    .opacity(model.form == .hidden ? 0 : 1)
  }

  private var bottomRadius: CGFloat {
    switch model.form {
    case .hidden, .notch: 10
    case .compact, .activity(.done, _): 13
    case .activity: 22
    case .expanded: 32
    }
  }

  // MARK: Lo de dentro

  @ViewBuilder private var content: some View {
    switch model.form {
    case .hidden, .notch:
      Color.clear
    case .compact:
      compact.transition(.opacity)
    case .expanded:
      expanded.transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
    case .activity(let activity, _):
      activityView(activity)
        .id(activity)
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
    }
  }

  private var compact: some View {
    HStack(spacing: 0) {
      Artwork(music: music, side: 22).padding(.leading, 9)
      Spacer()
      MusicBars(playing: music.track?.isPlaying ?? false, tint: music.tint).padding(.trailing, 12)
    }
    .frame(height: model.notch.height)
  }

  @ViewBuilder private var expanded: some View {
    if let track = music.track {
      VStack(spacing: 0) {
        Color.clear.frame(height: model.notch.height)
        HStack(spacing: 12) {
          Button(action: onOpenApp) { Artwork(music: music, side: 56) }
            .buttonStyle(.plain)
            .help("Abrir la app que suena")
          VStack(alignment: .leading, spacing: 2) {
            Text(track.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            Text(track.artist.isEmpty ? track.album : track.artist)
              .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
          }
          Spacer(minLength: 8)
          MusicBars(playing: track.isPlaying, tint: music.tint)
        }
        .padding(.top, 6)
        if track.duration > 0 {
          ProgressRow(track: track, model: model, onSeek: onSeek).padding(.top, 10)
        }
        HStack(spacing: 34) {
          ControlButton(symbol: "backward.fill", size: 15) { onCommand(.previous) }
          ControlButton(symbol: track.isPlaying ? "pause.fill" : "play.fill", size: 21) { onCommand(.toggle) }
          ControlButton(symbol: "forward.fill", size: 15) { onCommand(.next) }
        }
        .padding(.top, 4)
      }
      .padding(.horizontal, 22)
    }
  }

  @ViewBuilder private func activityView(_ activity: IslandActivity) -> some View {
    let phase = overlay.phase
    if !model.hasNotch {
      // Sin cámara en medio: el icono, el texto y la onda, en una fila centrada.
      HStack(spacing: 10) {
        leftWing(phase)
        if activity.isTall {
          Text(OverlayView.label(for: phase, liveText: overlay.liveText) ?? "")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .lineLimit(1)
            .truncationMode(.head)
            .contentTransition(.opacity)
        }
        rightWing(phase)
      }
      .padding(.horizontal, 18)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if activity.isTall {
      VStack(spacing: 0) {
        HStack(spacing: 0) {
          leftWing(phase).frame(width: IslandLayout.tallWing)
          Spacer()
          rightWing(phase).frame(width: IslandLayout.tallWing)
        }
        .frame(height: model.notch.height)
        Text(OverlayView.label(for: phase, liveText: overlay.liveText) ?? "")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .lineLimit(1)
          .truncationMode(.head)
          .contentTransition(.opacity)
          .padding(.horizontal, 18)
          .frame(height: IslandLayout.tallDrop - 6)
      }
    } else {
      HStack {
        leftWing(phase).frame(width: IslandLayout.wing)
        Spacer()
      }
      .frame(height: model.notch.height)
    }
  }

  @ViewBuilder private func leftWing(_ phase: OverlayModel.Phase) -> some View {
    if case .processing = phase {
      Spinner()
    } else {
      Image(systemName: OverlayView.symbol(for: phase))
        .font(.system(size: 15, weight: .semibold))
        .contentTransition(.symbolEffect(.replace))
    }
  }

  @ViewBuilder private func rightWing(_ phase: OverlayModel.Phase) -> some View {
    switch phase {
    case .listening(.meeting):
      if let startedAt = overlay.startedAt {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
          Text(OverlayView.clock(context.date.timeIntervalSince(startedAt)))
            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
        }
      }
    case .listening(.notes):
      HStack(spacing: 6) {
        if let startedAt = overlay.startedAt {
          TimelineView(.periodic(from: startedAt, by: 1)) { context in
            Text(OverlayView.clock(context.date.timeIntervalSince(startedAt)))
              .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
          }
        }
        LevelBars(level: overlay.level).scaleEffect(0.8)
      }
    case .listening:
      LevelBars(level: overlay.level).scaleEffect(0.8)
    default:
      EmptyView()
    }
  }

  // MARK: La burbuja

  private var bubble: some View {
    let side = IslandLayout.bubbleDiameter(notch: model.notch)
    return Circle().fill(.black)
      .frame(width: side, height: side)
      .overlay {
        Artwork(music: music, side: side - 10).clipShape(.circle)
      }
      .overlay(alignment: .bottomTrailing) {
        if music.track?.isPlaying == false {
          Image(systemName: "pause.fill").font(.system(size: 7, weight: .bold))
            .padding(3).background(.black, in: .circle)
        }
      }
  }
}

/// La carátula, o el icono de la app que suena si no hay.
private struct Artwork: View {
  let music: NowPlayingClient
  let side: CGFloat

  var body: some View {
    Group {
      if let artwork = music.artwork {
        Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
      } else if let pid = music.track?.pid, let icon = NSRunningApplication(processIdentifier: pid)?.icon {
        Image(nsImage: icon).resizable()
      } else {
        Image(systemName: "music.note").resizable().scaledToFit().padding(side * 0.2)
      }
    }
    .frame(width: side, height: side)
    .clipShape(.rect(cornerRadius: side * 0.24))
  }
}

/// La onda de la música: 4 barras animadas del color de la carátula, quietas en pausa (spec «La isla» §3.2). No sigue
/// el sonido real.
struct MusicBars: View {
  let playing: Bool
  let tint: ArtworkTint
  private static let speeds: [Double] = [5.1, 7.3, 6.2, 8.9]
  private static let phases: [Double] = [0, 1.3, 2.1, 0.7]

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playing)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      HStack(spacing: 2) {
        ForEach(0..<4, id: \.self) { index in
          Capsule()
            .fill(Color(red: tint.red, green: tint.green, blue: tint.blue))
            .frame(width: 3, height: playing ? Self.height(index, time) : 3)
        }
      }
    }
    .frame(height: 14)
    .animation(.easeInOut(duration: 0.25), value: playing)
  }

  private static func height(_ index: Int, _ time: Double) -> CGFloat {
    let wave = (sin(time * speeds[index] + phases[index]) + 1) / 2
    let swell = 0.6 + 0.4 * (sin(time * 1.7 + Double(index)) + 1) / 2
    return 4 + 10 * CGFloat(wave * swell)
  }
}

/// La barra de progreso, que se puede arrastrar, y los tiempos.
private struct ProgressRow: View {
  let track: NowPlaying
  let model: IslandModel
  var onSeek: (Double) -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.5)) { context in
      let fraction = model.scrub ?? track.progress(at: context.date)
      let position = fraction * track.duration
      VStack(spacing: 4) {
        GeometryReader { geometry in
          Capsule().fill(.white.opacity(0.2))
            .overlay(alignment: .leading) {
              Capsule().fill(.white).frame(width: geometry.size.width * fraction)
            }
            .frame(height: model.scrub == nil ? 4 : 6)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0)
              .onChanged { model.scrub = min(1, max(0, $0.location.x / geometry.size.width)) }
              .onEnded { _ in if let scrub = model.scrub { onSeek(scrub) } })
        }
        .frame(height: 10)
        .animation(.easeOut(duration: 0.15), value: model.scrub == nil)
        HStack {
          Text(NowPlaying.clock(position))
          Spacer()
          Text("-" + NowPlaying.clock(track.duration - position))
        }
        .font(.system(size: 10, weight: .medium).monospacedDigit())
        .foregroundStyle(.white.opacity(0.55))
      }
    }
  }
}

/// Un control de la música: se ilumina con el ratón encima.
private struct ControlButton: View {
  let symbol: String
  let size: CGFloat
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: size, weight: .semibold))
        .contentTransition(.symbolEffect(.replace))
        .frame(width: 30, height: 26)
        .opacity(hovering ? 1 : 0.85)
        .scaleEffect(hovering ? 1.1 : 1)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

/// Procesando: un arco que gira, dibujado a mano para que vaya a juego con el brillo del borde.
private struct Spinner: View {
  var body: some View {
    TimelineView(.animation) { context in
      Circle()
        .trim(from: 0.15, to: 1)
        .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate * 360))
    }
    .frame(width: 14, height: 14)
  }
}

/// Procesando: un brillo que recorre el borde de la isla.
private struct Shimmer: View {
  let flare: CGFloat
  let bottomRadius: CGFloat

  var body: some View {
    TimelineView(.animation) { context in
      let angle = context.date.timeIntervalSinceReferenceDate * 220
      IslandShape(flare: flare, bottomRadius: bottomRadius)
        .stroke(AngularGradient(colors: [.clear, .white.opacity(0.85), .clear, .clear], center: .center,
                                angle: .degrees(angle)), lineWidth: 1.5)
    }
  }
}
```

- [ ] **Step 4: `IslandPanel`: el panel encima de la barra de menús**

Crear `Sources/Sintecla/IslandPanel.swift`:

```swift
import AppKit
import SwiftUI

/// El panel de la isla: transparente, encima de la barra de menús y pegado arriba, centrado en la muesca. No activa
/// Sintecla, y solo recibe el ratón cuando el controlador se lo pide (con el ratón dentro de la isla): así la barra de
/// menús de alrededor sigue funcionando.
@MainActor
final class IslandPanel {
  /// Cabe la isla más grande (desplegada) con su sombra, y la burbuja al lado.
  static let size = CGSize(width: 760, height: 240)

  private let panel: NSPanel

  init(view: IslandView) {
    panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.nonactivatingPanel, .borderless],
                    backing: .buffered, defer: false)
    // Por encima de la barra de menús.
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    panel.contentView = FirstMouseHostingView(rootView: view)
  }

  var acceptsMouse: Bool {
    get { !panel.ignoresMouseEvents }
    set { if panel.ignoresMouseEvents == newValue { panel.ignoresMouseEvents = !newValue } }
  }

  /// Pegado arriba de la pantalla y centrado en la muesca.
  func show(on screen: NSScreen, notch: CGRect) {
    let frame = NSRect(x: notch.midX - Self.size.width / 2, y: screen.frame.maxY - Self.size.height,
                       width: Self.size.width, height: Self.size.height)
    if panel.frame != frame { panel.setFrame(frame, display: true) }
    panel.orderFrontRegardless()
  }

  func hide() {
    acceptsMouse = false
    panel.orderOut(nil)
  }
}
```

- [ ] **Step 5: Compilar la release (sin avisos)**

Run:

```bash
source scripts/sdk-env.sh && swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build complete' | grep -v 'ld: warning: search path' | tail -3
```

Esperado: `Build complete!`.

- [ ] **Step 6: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 341 tests in 57 suites passed`.

- [ ] **Step 7: Commit**

```bash
git add Sources/Sintecla/Overlay.swift Sources/Sintecla/IslandShape.swift Sources/Sintecla/IslandView.swift Sources/Sintecla/IslandPanel.swift
git commit -m 'feat: vista de la isla con música, Sintecla y burbuja

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 5: El controlador de la isla

**Files:**
- Create: `Sources/Sintecla/IslandController.swift`
- Modify: `Sources/Sintecla/DictationController.swift` (la pastilla o la isla, y arrancarla)

**Interfaces:**
- Consumes: Tareas 1 a 4; `AppSettings.moduleIsland`; `NotchScreen`.
- Produces: `IslandController(settings:overlay:)` con `start()`, `claimActivity() -> Bool` e `isActive`; `DictationController.presentOverlay()`.

El controlador mira el ratón con monitores globales y locales (sin temporizadores fijos), y el panel solo recibe clics con el ratón dentro de la isla compacta o desplegada: así la barra de menús de alrededor sigue funcionando. Con la isla encendida y la pantalla del MacBook a la vista, lo de Sintecla va siempre a la isla, aunque se trabaje en otra pantalla; sin ella (tapa cerrada), a la pastilla de abajo.

- [ ] **Step 1: `IslandController`: forma, ratón, pantalla completa y pausa al dictar**

Crear `Sources/Sintecla/IslandController.swift`:

```swift
import AppKit
import Observation
import SinteclaCore

/// Módulo Isla (spec «La isla»): une lo que suena, lo que hace Sintecla (el mismo `OverlayModel` de la pastilla), el
/// ratón y la pantalla completa, y decide la forma de la isla. También pausa la música al dictar (§3.4).
@MainActor
final class IslandController {
  private let settings: AppSettings
  private let overlay: OverlayModel
  private let music = NowPlayingClient.shared
  private let model = IslandModel()
  private lazy var panel = IslandPanel(view: IslandView(
    model: model, overlay: overlay, music: music,
    onOpenApp: { [weak self] in self?.openPlayingApp() },
    onCommand: { [weak self] in self?.music.send($0) },
    onSeek: { [weak self] in self?.seek(to: $0) }))
  private var hover = IslandHover()
  private var presence = MusicPresence()
  private var pauser = MusicPauser()
  private var screen: NSScreen?
  private var notch: CGRect?
  private var fullScreen = false
  /// Sin muesca (tapa cerrada): isla virtual en la pantalla principal, solo con lo de Sintecla.
  private var hasNotch = true
  /// Lo de Sintecla sale en la isla, y no en la pastilla (lo pide `DictationController` con `claimActivity()`).
  private var takesActivity = false
  /// El modo que se estaba escuchando, para saber cuándo empieza y cuándo termina.
  private var listening: HotkeyMode?
  private var monitors: [Any] = []
  private var observers: [NSObjectProtocol] = []
  private var observingPhase = false
  private var lingerTask: Task<Void, Never>?
  private var recheckTask: Task<Void, Never>?

  init(settings: AppSettings, overlay: OverlayModel) {
    self.settings = settings
    self.overlay = overlay
  }

  /// Encendido y con una pantalla: la del MacBook o, con la tapa cerrada, la principal (isla virtual).
  var isActive: Bool { settings.moduleIsland && screen != nil }

  /// Lo llama Sintecla al arrancar: desde ahí, la isla sigue al interruptor del módulo.
  func start() {
    apply()
    withObservationTracking { _ = settings.moduleIsland } onChange: { [weak self] in
      Task { @MainActor in self?.start() }
    }
  }

  /// Antes de enseñar un estado de Sintecla: true si lo enseña la isla (encendida, aunque se esté trabajando en otra
  /// pantalla); si no, va a la pastilla de abajo.
  func claimActivity() -> Bool {
    takesActivity = isActive
    refresh()
    return takesActivity
  }

  private func apply() {
    if settings.moduleIsland {
      music.onChange = { [weak self] in self?.musicChanged($0) }
      music.start()
      install()
      watchPhase()
      screensChanged()
    } else {
      music.onChange = nil
      music.stop()
      uninstall()
      takesActivity = false
      screen = nil
      notch = nil
      panel.hide()
    }
  }

  // MARK: Avisos

  private func install() {
    guard monitors.isEmpty else { return }
    let moved: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
    if let global = NSEvent.addGlobalMonitorForEvents(matching: moved, handler: { [weak self] _ in
      MainActor.assumeIsolated { self?.mouseMoved() }
    }) {
      monitors.append(global)
    }
    if let local = NSEvent.addLocalMonitorForEvents(matching: moved, handler: { [weak self] event in
      MainActor.assumeIsolated { self?.mouseMoved() }
      return event
    }) {
      monitors.append(local)
    }
    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                        queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.screensChanged() }
    })
    let workspace = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
      observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.spaceChanged() }
      })
    }
  }

  private func uninstall() {
    monitors.forEach(NSEvent.removeMonitor)
    monitors.removeAll()
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    observers.removeAll()
  }

  /// Cada cambio de estado de Sintecla: la forma y, al empezar y terminar de escuchar, la pausa de la música.
  private func watchPhase() {
    guard !observingPhase else { return }
    observingPhase = true
    withObservationTracking { _ = overlay.phase } onChange: { [weak self] in
      Task { @MainActor in
        self?.observingPhase = false
        self?.phaseChanged()
        self?.watchPhase()
      }
    }
  }

  private func phaseChanged() {
    guard settings.moduleIsland else { return }
    var mode: HotkeyMode?
    if case .listening(let current) = overlay.phase { mode = current }
    if let mode, listening == nil,
       let command = pauser.listeningStarted(mode: mode, musicPlaying: music.track?.isPlaying ?? false) {
      send(command)
    }
    if mode == nil, listening != nil, let command = pauser.listeningEnded() {
      send(command)
    }
    listening = mode
    refresh()
  }

  private func send(_ command: MusicPauser.Command) {
    music.send(command == .pause ? .pause : .play)
  }

  private func musicChanged(_ track: NowPlaying?) {
    pauser.musicChanged(isPlaying: track?.isPlaying ?? false)
    presence.update(track, at: Date())
    // En pausa, la música se va de la isla a los 5 minutos.
    lingerTask?.cancel()
    if let track, !track.isPlaying {
      lingerTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(MusicPresence.pausedLinger + 0.5))
        guard !Task.isCancelled else { return }
        self?.refresh()
      }
    }
    refresh()
  }

  private func screensChanged() {
    if let real = NotchScreen.current, let rect = NotchScreen.notchRect(on: real) {
      screen = real
      notch = rect
      hasNotch = true
    } else {
      // La pantalla principal es la de la barra de menús.
      screen = NSScreen.screens.first
      notch = screen.map(NotchScreen.virtualNotch(on:))
      hasNotch = false
    }
    hover.reset()
    checkFullScreen()
    refresh()
  }

  /// Al cambiar de escritorio o de app; la animación de macOS tarda un poco en dejar la ventana en su sitio.
  private func spaceChanged() {
    checkFullScreen()
    refresh()
    Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(700))
      self?.checkFullScreen()
      self?.refresh()
    }
  }

  /// A pantalla completa: la app de delante tiene una ventana normal del tamaño de la pantalla de la muesca.
  private func checkFullScreen() {
    guard let screen, let app = NSWorkspace.shared.frontmostApplication,
          let primary = NSScreen.screens.first?.frame else {
      fullScreen = false
      return
    }
    // La lista de ventanas mide desde arriba a la izquierda de la pantalla principal.
    let target = CGRect(x: screen.frame.minX, y: primary.maxY - screen.frame.maxY, width: screen.frame.width,
                        height: screen.frame.height)
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
      as? [[String: Any]] ?? []
    fullScreen = windows.contains { window in
      guard (window[kCGWindowOwnerPID as String] as? Int32) == app.processIdentifier,
            (window[kCGWindowLayer as String] as? Int) == 0,
            let bounds = window[kCGWindowBounds as String] as? NSDictionary,
            let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
      return rect == target
    }
  }

  // MARK: Forma y ratón

  private func refresh() {
    guard isActive, let screen, let notch else {
      panel.hide()
      return
    }
    let activity = takesActivity ? Self.activity(for: overlay.phase) : nil
    let showsMusic = presence.isShown(music.track, at: Date())
    if !showsMusic { hover.reset() }
    let form = IslandLayout.form(activity: activity, music: showsMusic, hovering: hover.isExpanded,
                                 fullScreen: fullScreen, hasNotch: hasNotch)
    model.notch = notch.size
    model.hasNotch = hasNotch
    if model.form != form { model.form = form }
    panel.show(on: screen, notch: notch)
    updateMouse()
  }

  private static func activity(for phase: OverlayModel.Phase) -> IslandActivity? {
    switch phase {
    case .hidden: nil
    case .listening(.meeting): .meeting
    case .listening: .listening
    case .processing: .processing
    case .done: .done
    case .message, .notice: .notice
    }
  }

  /// El sitio de la isla en la pantalla, con las curvas de arriba.
  private var islandRect: CGRect? {
    guard let screen, let notch else { return nil }
    let size = IslandLayout.size(of: model.form, notch: notch.size, hasNotch: hasNotch)
    guard size != .zero else { return nil }
    let width = size.width + 2 * IslandView.flare
    return CGRect(x: notch.midX - width / 2, y: screen.frame.maxY - size.height, width: width, height: size.height)
  }

  private func mouseMoved() {
    guard isActive else { return }
    updateMouse()
  }

  /// Con música, el ratón dentro de la isla la despliega (y fuera la recoge); solo entonces el panel recibe clics.
  private func updateMouse() {
    let inside = islandRect?.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) ?? false
    panel.acceptsMouse = inside && (model.form == .compact || model.form == .expanded)
    let musicForm = model.form == .compact || model.form == .expanded
    if hover.update(inside: inside && musicForm, at: Date()) { refresh() }
    // El ratón puede quedarse quieto: se vuelve a mirar cuando se cumple la espera.
    recheckTask?.cancel()
    let waiting = musicForm && inside != hover.isExpanded
    guard waiting else { return }
    let delay = inside ? IslandHover.expandDelay : IslandHover.collapseDelay
    recheckTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay + 0.02))
      guard !Task.isCancelled else { return }
      self?.updateMouse()
    }
  }

  // MARK: Acciones

  private func openPlayingApp() {
    guard let pid = music.track?.pid, let url = NSRunningApplication(processIdentifier: pid)?.bundleURL else { return }
    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
  }

  /// La barra se queda donde se soltó hasta que la app confirma el salto.
  private func seek(to fraction: Double) {
    guard let track = music.track, track.duration > 0 else { return }
    music.seek(to: fraction * track.duration)
    Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(900))
      self?.model.scrub = nil
    }
  }
}
```

- [ ] **Step 2: `DictationController`: la isla o la pastilla, y arrancar la isla**

En `Sources/Sintecla/DictationController.swift`, cambiar:

```swift
  private lazy var dock = DockPreviewController(settings: settings)
```

por:

```swift
  private lazy var dock = DockPreviewController(settings: settings)
  /// Módulo Isla: la pastilla en la muesca y la música.
  private lazy var island = IslandController(settings: settings, overlay: overlayModel)
```

Y cambiar:

```swift
    dock.start()
```

por:

```swift
    dock.start()
    island.start()
```

Y cambiar:

```swift
    overlayModel.phase = phase
    overlay.show()
```

por:

```swift
    overlayModel.phase = phase
    presentOverlay()
```

Y cambiar:

```swift
      overlayModel.phase = .listening(.meeting)
      overlay.show()
      return
```

por:

```swift
      overlayModel.phase = .listening(.meeting)
      presentOverlay()
      return
```

Y cambiar:

```swift
    overlayModel.liveText = ""
    overlay.hide()
  }
```

por:

```swift
    overlayModel.liveText = ""
    overlay.hide()
  }

  /// La isla si está encendida y la pantalla del MacBook está a la vista; si no, la pastilla de abajo (spec «La isla» §2).
  private func presentOverlay() {
    if island.claimActivity() {
      overlay.hide()
    } else {
      overlay.show()
    }
  }
```

- [ ] **Step 3: Compilar la release (sin avisos)**

Run:

```bash
source scripts/sdk-env.sh && swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build complete' | grep -v 'ld: warning: search path' | tail -3
```

Esperado: `Build complete!`.

- [ ] **Step 4: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 341 tests in 57 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Sintecla/IslandController.swift Sources/Sintecla/DictationController.swift
git commit -m 'feat: la isla en la muesca, con la música en pausa al dictar

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 6: Versión 0.14.0, README y spec principal

**Files:**
- Modify: `Sources/SinteclaCoreTests/SmokeTests.swift`, `Sources/SinteclaCore/AppInfo.swift` y `Resources/Info.plist`
- Modify: `README.md` y `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§7)

**Interfaces:**
- Consumes: Todo lo anterior.
- Produces: La versión 0.14.0 (build 15), instalada.

La línea «Estado» de la spec principal y la etiqueta `v0.14.0` se ponen al cerrar la versión, cuando el usuario lo pida.

- [ ] **Step 1: El test de la versión**

En `Sources/SinteclaCoreTests/SmokeTests.swift`, cambiar:

```swift
#expect(AppInfo.version == "0.13.0")
```

por:

```swift
#expect(AppInfo.version == "0.14.0")
```

- [ ] **Step 2: Ver que falla**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA el test con `Expectation failed: AppInfo.version == "0.14.0"`.

- [ ] **Step 3: `AppInfo.version`**

En `Sources/SinteclaCore/AppInfo.swift`, cambiar:

```swift
public static let version = "0.13.0"
```

por:

```swift
public static let version = "0.14.0"
```

- [ ] **Step 4: `Info.plist`**

En `Resources/Info.plist`, cambiar:

```xml
  <key>CFBundleShortVersionString</key><string>0.13.0</string>
  <key>CFBundleVersion</key><string>14</string>
```

por:

```xml
  <key>CFBundleShortVersionString</key><string>0.14.0</string>
  <key>CFBundleVersion</key><string>15</string>
```

- [ ] **Step 5: Ver que pasa**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 341 tests in 57 suites passed`.

- [ ] **Step 6: README: el módulo Isla**

En `README.md`, cambiar:

```text
un clic salta a una, y la tarjeta marcada tiene botones para cerrarla o minimizarla. |
| **Y además** |
```

por:

```text
un clic salta a una, y la tarjeta marcada tiene botones para cerrarla, minimizarla o salir de la app. |
| **Isla** | La muesca del MacBook cobra vida, como la Dynamic Island: la música que suena (carátula, onda, y al pasar el ratón la canción con sus controles) y el dictado, las reuniones y los avisos de Sintecla. Al dictar, la música se pausa y vuelve al terminar. |
| **Y además** |
```

Y cambiar:

```text
Dictado, Reuniones, Finder, Capturas, Alt-Tab y Dock son **módulos**
```

por:

```text
Dictado, Reuniones, Finder, Capturas, Alt-Tab, Dock e Isla son **módulos**
```

Y cambiar:

```text
Finder, Capturas, Alt-Tab y Dock vienen apagados.
```

por:

```text
Finder, Capturas, Alt-Tab, Dock e Isla vienen apagados.
```

Y cambiar:

```text
Con el módulo Dock encendido: al pasar el ratón por una app del Dock salen sus ventanas, y `Esc` cierra la vista.
```

por:

```text
Con el módulo Dock encendido: al pasar el ratón por una app del Dock salen sus ventanas, y `Esc` cierra la vista.

Con el módulo Isla encendido: al pasar el ratón por la isla con música se despliega; un clic en la carátula abre la app que suena y la barra de progreso se puede arrastrar.
```

- [ ] **Step 7: Spec principal (§7): la isla**

En `docs/superpowers/specs/2026-09-23-sintecla-design.md`, cambiar:

```text
Alt-Tab y Dock; los cuatro últimos, apagados de fábrica)
```

por:

```text
Alt-Tab, Dock e Isla; los cinco últimos, apagados de fábrica)
```

Y cambiar:

```text
y **Dock** (cómo se usa y permisos, ver `2026-10-03-dock-vistas-design.md`).
```

por:

```text
**Dock** (cómo se usa y permisos, ver `2026-10-03-dock-vistas-design.md`) e **Isla** (qué enseña, la muesca y la música, ver `2026-10-03-isla-design.md`).
```

Y cambiar:

```text
Un clic salta a una, y la tarjeta marcada tiene botones para cerrarla o minimizarla.
```

por:

```text
Un clic salta a una, y la tarjeta marcada tiene botones para cerrarla, minimizarla o salir de la app.
- **Isla** (desde la 0.14.0, módulo Isla): la muesca del MacBook como una Dynamic Island. Con música, crece con la carátula y una onda de su color, y al pasar el ratón se despliega con la canción, el progreso y los controles (la música llega por un ayudante dentro de `/usr/bin/perl`). La pastilla de Sintecla sale en ella cuando el ratón está en la pantalla del MacBook; si suena música, se aparta a una burbuja y se pausa mientras se dicta.
```

- [ ] **Step 8: Compilar la release (sin avisos)**

Run:

```bash
source scripts/sdk-env.sh && swift build -c release --product Sintecla 2>&1 | grep -E 'warning:|error:|Build complete' | grep -v 'ld: warning: search path' | tail -3
```

Esperado: `Build complete!`.

- [ ] **Step 9: Commit**

```bash
git add Sources/SinteclaCoreTests/SmokeTests.swift Sources/SinteclaCore/AppInfo.swift Resources/Info.plist README.md docs/superpowers/specs/2026-09-23-sintecla-design.md
git commit -m 'feat: versión 0.14.0 con la isla

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

- [ ] **Step 10: Instalar la versión nueva**

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
- Produces: Nada nuevo. La 0.14.0 se cierra cuando el usuario lo pida.

La hace el usuario (spec §6.2).

- [ ] **Step 1: Checklist. Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | Módulos → encender Isla, sin música | La muesca, como siempre |
| 2 | Spotify sonando; luego en pausa | Compacta con carátula y onda de su color; en pausa, la onda se para |
| 3 | Ratón encima de la isla | Se despliega con muelle; ⏮ ⏯ ⏭ funcionan; se arrastra el progreso; clic en la carátula abre Spotify; al salir, se recoge |
| 4 | Un vídeo de YouTube en Safari | Sale igual |
| 5 | Dictar con música | Se pausa, la burbuja sale al lado, la isla escucha; al soltar, vuelve a sonar y se juntan |
| 6 | Dictar con la música ya en pausa | Al terminar sigue en pausa |
| 7 | Procesando, hecho, reunión y un aviso de Capturas | Salen en la isla |
| 8 | La barra de menús junto a la isla, y escribir en la app de delante | Responde, y no pierde el teclado |
| 9 | Un vídeo a pantalla completa; dictar encima | La isla en reposo no molesta; el dictado sí sale |
| 10 | Con el ratón en la pantalla externa, dictar | Sale en la isla del MacBook, no en la pastilla de abajo |
| 11 | Tapa cerrada (solo la pantalla externa): música sonando y luego dictar | Sin música en la isla; al dictar, la isla baja arriba en el centro de la pantalla, sin burbuja |
| 12 | Alt-Tab, Dock, Capturas y el resto | Como antes |

---
## Autorrevisión frente a la especificación

| Requisito (spec «La isla») | Dónde |
|---|---|
| §2 Módulo apagado de fábrica; con muesca o virtual; página con qué enseña, la muesca y la música; tarjeta de Inicio | Tarea 3 |
| §3.1 Formas, muelle, esquinas y recoger | Tareas 1 y 4 |
| §3.2 Música: fuente, datos, compacta, desplegada, sin carátula y pausa de 5 minutos | Tareas 1, 2 y 4 |
| §3.3 Sintecla en la isla | Tareas 4 y 5 |
| §3.4 La música al dictar | Tareas 1 y 5 |
| §3.5 Ratón, teclado y pantalla completa | Tareas 4 y 5 |
| §4 El ayudante, sus líneas, sus órdenes y relanzarlo | Tarea 2 |
| §5 Piezas y 0.14.0 (build 15) | Tareas 1 a 6 |
| §6.1 Tests | Tareas 1 y 3 |
| §6.2 Aceptación | Tarea 7 |
| §6.3 Riesgos | Tareas 2, 4 y 5 |

**Consistencia de tipos revisada:**
- `IslandLayout`, `IslandForm` e `IslandActivity` (Tarea 1) los usan `IslandView` (Tarea 4) e `IslandController` (Tarea 5).
- `IslandHover` y `MusicPresence` (Tarea 1) los usa `IslandController` (Tarea 5).
- `NowPlayingUpdate.parse(_:)` y `ArtworkTint(of:)` (Tarea 1) los usa `NowPlayingClient` (Tarea 2).
- `MusicPauser` (Tarea 1) lo usa `IslandController`, que manda `.pause` y `.play` con `NowPlayingClient.send(_:)` (Tareas 2 y 5).
- `NowPlayingClient.shared.status` (Tarea 2) lo lee `IslandPage` (Tarea 3).
- `NotchScreen` (Tarea 3) lo usan la tarjeta de Inicio (Tarea 3) e `IslandController` (Tarea 5).
- `OverlayView.symbol(for:)` y `label(for:liveText:)` (Tarea 4) los usa `IslandView` (Tarea 4).
