# Sintecla — F4b: Tono por web — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que en Safari el tono salga del dominio de la pestaña (Gmail formal, WhatsApp Web informal, GitHub técnico…), con una lista de webs editable en Ajustes → Tonos.

**Architecture:** El núcleo `SinteclaCore` gana `SiteRules` (normalizar dominios y buscar la regla más larga), que es puro y tiene tests. `ToneRules` gana `bySite` y `tone(for:host:)`, y los `tones.json` antiguos reciben la lista inicial. La app añade `SafariSite`, que lee por Accesibilidad el `AXURL` de la página de Safari en segundo plano al pulsar la tecla. `DictationController` pasa el dominio a `ModeRunner` dentro de `Recording.site`, y la pestaña Tonos gana la sección «Tono por web (Safari)».

**Tech Stack:** Lo de la F1–F4a (Swift 6.3 de las Command Line Tools en modo de lenguaje 5, SwiftPM, AppKit, SwiftUI, Swift Testing). Además, `ApplicationServices` (`AXUIElement`: `kAXFocusedUIElementAttribute`, `kAXParentAttribute`, `kAXChildrenAttribute`, `kAXURLAttribute`), leído en un `Task.detached`.

**Especificación:** `docs/superpowers/specs/2026-09-24-tono-por-web-design.md` (y la fila F4b de §12 de la spec principal).

**Punto de partida:** la rama `fase-4b`, que sale de `main` (`v0.4.0`) con la especificación de la F4b:

```bash
git checkout fase-4b
```

## Global Constraints

- Todo lo de la F1–F4a sigue vigente:
  - macOS 26.0 o superior, Apple Silicon.
  - Sin Xcode ni dependencias externas; todos los targets en `.swiftLanguageMode(.v5)`.
  - Tests con `swift run sintecla-tests` (**nunca `swift test`**).
  - Bundle id `local.sintecla.app`; textos visibles en español; solo blanco, negro, grises y transparente.
- **Solo Safari** (`com.apple.Safari`); ningún permiso nuevo: solo Accesibilidad, que ya tiene la app.
- **Privacidad:** de la dirección solo se queda el dominio, y solo de páginas `http`/`https`. Vive en memoria y no va al historial.
- **Lectura:**
  - Se sube desde el foco hasta el `AXWebArea` **más externo**, como mucho **40** niveles.
  - Si el foco no está en la página, se busca en la ventana (`AXFocusedWindow` o `AXMainWindow`) en anchura, como mucho **10** niveles y **500** elementos.
  - **0,5 s** de tope por llamada, y la lectura se abandona a los **0,5 s**.
  - Nunca en el hilo principal.
- **Reglas:**
  - Una regla vale para su dominio y sus subdominios, y gana la más larga.
  - Si ninguna web coincide, se usa el tono de la app.
  - Los `tones.json` sin `bySite` reciben la lista inicial; una lista vacía se conserva.
- **Lista inicial:**
  - Formal: `mail.google.com`, `outlook.live.com`, `outlook.office.com`, `outlook.office365.com`, `docs.google.com`.
  - Informal: `web.whatsapp.com`, `web.telegram.org`, `slack.com`, `discord.com`, `messenger.com`.
  - Técnico: `github.com`, `chatgpt.com`, `claude.ai`, `gemini.google.com`.
- Versión **0.5.0** (build 5).
- Commits: en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código de este plan se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `fase-4b`: compiló y pasó los tests en cada tarea, y el árbol final quedó idéntico al del prototipo.

- **164 tests** (35 suites) en verde: los 155 de la F4a y 9 nuevos.
- La release compila sin avisos.

**Lo que no se pudo probar aquí** (queda para la aceptación, Tarea 4):
- **La lectura real del dominio en Safari.** La shell de estas pruebas no tiene permiso de Accesibilidad y no se toca. Si Safari no diera `AXURL`, el plan B de la spec (§8, AppleScript) pide un permiso nuevo: solo con el visto bueno del usuario.
- **El aspecto de la sección nueva de Tonos.**

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| Los `tones.json` guardados antes no tienen `bySite` | `init(from:)` con `decodeIfPresent` y la lista inicial (Tarea 1) |
| `xmail.google.com` acaba en `mail.google.com` pero no es subdominio suyo | Se compara con `"." + dominio` (Tarea 1) |
| Con Safari colgado, cada llamada de Accesibilidad espera su tope y se encadenarían | `Reader` con fecha límite: pasada, no se hace ninguna llamada más (Tarea 2) |
| Un `iframe` incrustado tiene su propio `AXWebArea` con otro dominio | Se sigue subiendo y cuenta el más externo, el de la barra de direcciones (Tarea 2) |
| Los `Recording` de `DebugCommands.swift` no saben de webs | `site` es opcional y vale `nil` por defecto: no hay que tocarlos (Tarea 2) |
| Tras mover la carpeta del proyecto, `swift build` falla con `missing required module 'SwiftShims'` | Caché de módulos con rutas viejas: `rm -rf .build` |

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/SiteRules.swift` | Normalizar dominios y buscar la regla | 1 |
| `Sources/SinteclaCore/Tone.swift` | `ToneRules.bySite`, `tone(for:host:)`, lista inicial, `tones.json` antiguos | 1 |
| `Sources/SinteclaCoreTests/ToneBySiteTests.swift` | Tests de la F4b | 1 |
| `Sources/Sintecla/SafariSite.swift` | Dominio de la pestaña de Safari por Accesibilidad | 2 |
| `Sources/Sintecla/ModeRunner.swift` | `Recording.site` y tono con el dominio | 2 |
| `Sources/Sintecla/DictationController.swift` | Lanzar la lectura al pulsar (o al soltar en notas) y esperarla | 2 |
| `Sources/Sintecla/Windows.swift` | Sección «Tono por web (Safari)» | 3 |
| `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`, `Sources/SinteclaCoreTests/SmokeTests.swift` | Versión 0.5.0 | 3 |

---

### Task 1: Reglas de tono por web

**Files:**
- Create: `Sources/SinteclaCore/SiteRules.swift`
- Modify: `Sources/SinteclaCore/Tone.swift`
- Test: `Sources/SinteclaCoreTests/ToneBySiteTests.swift`

**Interfaces:**
- Consumes: `Tone`, `ToneRules(byBundleID:)` y `ToneRules.defaults` (F1).
- Produces: `enum SiteRules { static let browsers: Set<String>; static func normalize(_ text: String) -> String?; static func match(_ host: String, in sites: some Collection<String>) -> String? }`; `ToneRules.bySite: [String: Tone]`, `ToneRules(byBundleID:bySite: = [:])` y `func tone(for bundleID: String?, host: String? = nil) -> Tone` (sustituye a `tone(for:)`; las llamadas antiguas siguen valiendo).

Todo puro: el dominio llega ya leído. La regla de una web solo cuenta si la app es Safari (spec §3).

- [ ] **Step 1: Escribir los tests**

Crear `Sources/SinteclaCoreTests/ToneBySiteTests.swift`:

```swift
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct SiteRulesTests {
  @Test(arguments: [
    ("https://www.LinkedIn.com/feed/", "linkedin.com"),
    ("mail.google.com", "mail.google.com"),
    ("  web.whatsapp.com \n", "web.whatsapp.com"),
    ("http://intranet.brisenta.es:8080/x?y#z", "intranet.brisenta.es"),
    ("WWW.GitHub.com", "github.com"),
    ("docs.google.com/document/d/123", "docs.google.com"),
  ])
  func normalizes(input: String, expected: String) {
    #expect(SiteRules.normalize(input) == expected)
  }

  @Test(arguments: ["hola", "", "   ", ".com", "google.", "google..com", "mañana.es", "a b.com", "https://"])
  func rejects(_ input: String) {
    #expect(SiteRules.normalize(input) == nil)
  }

  @Test func matchesTheDomainAndItsSubdomains() {
    let sites = ["slack.com", "mail.google.com", "google.com", "gemini.google.com"]
    #expect(SiteRules.match("slack.com", in: sites) == "slack.com")
    #expect(SiteRules.match("miempresa.slack.com", in: sites) == "slack.com")
    #expect(SiteRules.match("notslack.com", in: sites) == nil)
    #expect(SiteRules.match("slack.com", in: [String]()) == nil)
  }

  @Test func theLongestRuleWins() {
    let sites = ["google.com", "mail.google.com", "gemini.google.com"]
    #expect(SiteRules.match("gemini.google.com", in: sites) == "gemini.google.com")
    #expect(SiteRules.match("mail.google.com", in: sites) == "mail.google.com")
    // Un sufijo que no es subdominio no cuenta: cae en la regla del padre.
    #expect(SiteRules.match("xmail.google.com", in: sites) == "google.com")
  }
}

@Suite struct ToneBySiteTests {
  let safari = "com.apple.Safari"

  @Test func safariUsesTheToneOfTheSite() {
    let rules = ToneRules.defaults
    #expect(rules.tone(for: safari, host: "mail.google.com") == .formal)
    #expect(rules.tone(for: safari, host: "web.whatsapp.com") == .informal)
    #expect(rules.tone(for: safari, host: "miempresa.slack.com") == .informal)
    #expect(rules.tone(for: safari, host: "github.com") == .technical)
  }

  @Test func aSiteNotInTheListUsesTheToneOfSafari() {
    var rules = ToneRules.defaults
    #expect(rules.tone(for: safari, host: "es.wikipedia.org") == .neutral)
    rules.byBundleID[safari] = .formal
    #expect(rules.tone(for: safari, host: "es.wikipedia.org") == .formal)
    #expect(rules.tone(for: safari, host: nil) == .formal)
  }

  @Test func theSiteOnlyCountsInSafari() {
    let rules = ToneRules.defaults
    #expect(rules.tone(for: "com.apple.mail", host: "web.whatsapp.com") == .formal)
    #expect(rules.tone(for: nil, host: "web.whatsapp.com") == .neutral)
  }

  @Test func anOldTonesFileGetsTheInitialSites() throws {
    let old = #"{"byBundleID":{"com.apple.Safari":"formal","net.whatsapp.WhatsApp":"informal"}}"#
    let rules = try JSONDecoder().decode(ToneRules.self, from: Data(old.utf8))
    #expect(rules.byBundleID == ["com.apple.Safari": .formal, "net.whatsapp.WhatsApp": .informal])
    #expect(rules.bySite == ToneRules.defaults.bySite)
  }

  @Test func anEmptySiteListIsKept() throws {
    var rules = ToneRules.defaults
    rules.bySite = [:]
    let decoded = try JSONDecoder().decode(ToneRules.self, from: JSONEncoder().encode(rules))
    #expect(decoded == rules)
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: cannot find 'SiteRules' in scope`.

- [ ] **Step 3: Normalizar dominios y buscar la regla**

Crear `Sources/SinteclaCore/SiteRules.swift`:

```swift
import Foundation

/// Tono por web: dominios de la lista y regla que corresponde a la pestaña de Safari.
public enum SiteRules {
  /// Apps donde cuenta el tono por web.
  public static let browsers: Set<String> = ["com.apple.Safari"]

  /// Dominio de una dirección o de lo que escribe el usuario: sin esquema, ruta, puerto ni `www.` inicial.
  /// nil si no parece un dominio (sin punto, con espacios o caracteres raros).
  public static func normalize(_ text: String) -> String? {
    var s = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if let scheme = s.range(of: "://") { s = String(s[scheme.upperBound...]) }
    s = String(s.prefix { !"/?#".contains($0) })
    s = String(s.prefix { $0 != ":" })
    if s.hasPrefix("www.") { s.removeFirst(4) }
    let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789.-")
    guard s.contains("."), !s.hasPrefix("."), !s.hasSuffix("."), !s.contains(".."),
          s.allSatisfy(allowed.contains) else { return nil }
    return s
  }

  /// La regla que vale para `host`: su dominio o uno de sus padres (`slack.com` cubre `miempresa.slack.com`).
  /// Si hay varias, la más larga.
  public static func match(_ host: String, in sites: some Collection<String>) -> String? {
    sites.filter { host == $0 || host.hasSuffix("." + $0) }.max { $0.count < $1.count }
  }
}
```

- [ ] **Step 4: Tonos por web en `ToneRules`**

En `Sources/SinteclaCore/Tone.swift`, cambiar:

```swift
/// Qué tono usa cada app (por bundle id). Editable en Ajustes → Tonos.
public struct ToneRules: Codable, Equatable, Sendable {
  public var byBundleID: [String: Tone]

  public init(byBundleID: [String: Tone]) {
    self.byBundleID = byBundleID
  }

  public func tone(for bundleID: String?) -> Tone {
    guard let bundleID else { return .neutral }
    return byBundleID[bundleID] ?? .neutral
  }
```

por:

```swift
/// Qué tono usa cada app (por bundle id) y, en Safari, cada web (por dominio). Editable en Ajustes → Tonos.
public struct ToneRules: Codable, Equatable, Sendable {
  public var byBundleID: [String: Tone]
  /// Dominio sin `www.` → tono. Solo cuenta en Safari (`SiteRules.browsers`).
  public var bySite: [String: Tone]

  public init(byBundleID: [String: Tone], bySite: [String: Tone] = [:]) {
    self.byBundleID = byBundleID
    self.bySite = bySite
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    byBundleID = try container.decode([String: Tone].self, forKey: .byBundleID)
    // Los tones.json de antes de la 0.5.0 no tienen webs: reciben la lista inicial.
    bySite = try container.decodeIfPresent([String: Tone].self, forKey: .bySite) ?? Self.defaults.bySite
  }

  /// En Safari, el tono de la web si está en la lista; si no, el de la app.
  public func tone(for bundleID: String?, host: String? = nil) -> Tone {
    guard let bundleID else { return .neutral }
    if SiteRules.browsers.contains(bundleID), let host, let site = SiteRules.match(host, in: bySite.keys),
       let tone = bySite[site] {
      return tone
    }
    return byBundleID[bundleID] ?? .neutral
  }
```

Y cambiar:

```swift
    "com.openai.codex": .technical,
  ])
}
```

por:

```swift
    "com.openai.codex": .technical,
  ], bySite: [
    // Formal
    "mail.google.com": .formal,
    "outlook.live.com": .formal,
    "outlook.office.com": .formal,
    "outlook.office365.com": .formal,
    "docs.google.com": .formal,
    // Informal
    "web.whatsapp.com": .informal,
    "web.telegram.org": .informal,
    "slack.com": .informal,
    "discord.com": .informal,
    "messenger.com": .informal,
    // Técnico
    "github.com": .technical,
    "chatgpt.com": .technical,
    "claude.ai": .technical,
    "gemini.google.com": .technical,
  ])
}
```

- [ ] **Step 5: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 164 tests in 35 suites passed`.

- [ ] **Step 6: Commit**

```bash
git add Sources/SinteclaCore/SiteRules.swift Sources/SinteclaCore/Tone.swift Sources/SinteclaCoreTests/ToneBySiteTests.swift
git commit -m 'feat: reglas de tono por web con la lista inicial

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: Leer la web de Safari al dictar

**Files:**
- Create: `Sources/Sintecla/SafariSite.swift`
- Modify: `Sources/Sintecla/ModeRunner.swift`
- Modify: `Sources/Sintecla/DictationController.swift`

**Interfaces:**
- Consumes: `SiteRules.browsers`, `SiteRules.normalize(_:)` y `ToneRules.tone(for:host:)` (Tarea 1).
- Produces: `enum SafariSite { static func read(_ app: NSRunningApplication?) -> Task<String?, Never>?; @MainActor static func frontTab() async -> String?; static func host(pid: pid_t) -> String? }`; `Recording.site: String? = nil`.

La lectura por Accesibilidad no se puede probar sin el permiso: aquí solo se compila y se comprueba que los tests siguen en verde. Se prueba a mano en la Tarea 4.

- [ ] **Step 1: Lector del dominio de Safari**

Crear `Sources/Sintecla/SafariSite.swift`:

```swift
import AppKit
import ApplicationServices
import SinteclaCore

/// Dominio de la pestaña de Safari (tono por web), por Accesibilidad: sin permisos nuevos. Solo se queda el dominio,
/// nunca la dirección completa, y no se guarda en ningún sitio.
enum SafariSite {
  /// La lectura se abandona pasado este tiempo (cada llamada de Accesibilidad tiene además su tope de 0,5 s).
  static let maxDuration: TimeInterval = 0.5
  /// Niveles que se sube desde el foco buscando la página.
  static let maxClimb = 40
  /// Búsqueda en la ventana cuando el foco no está en la página.
  static let maxDepth = 10
  static let maxElements = 500

  /// Empieza a leer el dominio en segundo plano si `app` es Safari; nil si no lo es.
  static func read(_ app: NSRunningApplication?) -> Task<String?, Never>? {
    guard let app, let id = app.bundleIdentifier, SiteRules.browsers.contains(id) else { return nil }
    let pid = app.processIdentifier
    return Task.detached { host(pid: pid) }
  }

  /// Dominio de la pestaña de delante de Safari aunque no sea la app activa (Ajustes → Tonos).
  @MainActor
  static func frontTab() async -> String? {
    let safari = NSWorkspace.shared.runningApplications.first { SiteRules.browsers.contains($0.bundleIdentifier ?? "") }
    return await read(safari)?.value
  }

  /// Sube desde el elemento con el foco hasta la página (`AXWebArea`) más externa; si el foco no está en la página
  /// (p. ej., en la barra de direcciones), la busca en la ventana de delante.
  static func host(pid: pid_t) -> String? {
    let reader = Reader(deadline: Date().addingTimeInterval(maxDuration))
    // Con el objeto de todo el sistema, el tope de 0,5 s por llamada vale para todos los elementos.
    AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.5)
    let app = AXUIElementCreateApplication(pid)
    if let focused = reader.element(app, kAXFocusedUIElementAttribute),
       let page = reader.outermostWebArea(from: focused), let host = reader.host(of: page) {
      return host
    }
    guard let window = reader.element(app, kAXFocusedWindowAttribute) ?? reader.element(app, kAXMainWindowAttribute),
          let page = reader.firstWebArea(in: window) else { return nil }
    return reader.host(of: page)
  }

  /// Llamadas de Accesibilidad con fecha límite: pasada, todas devuelven nil.
  private struct Reader {
    let deadline: Date

    func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
      guard Date() < deadline else { return nil }
      var value: CFTypeRef?
      guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
      return value
    }

    func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
      guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
      return (value as! AXUIElement)
    }

    func role(_ element: AXUIElement) -> String? {
      attribute(element, kAXRoleAttribute) as? String
    }

    func outermostWebArea(from start: AXUIElement) -> AXUIElement? {
      var current: AXUIElement? = start
      var outermost: AXUIElement?
      for _ in 0..<SafariSite.maxClimb {
        guard let element = current, let kind = role(element),
              kind != kAXWindowRole, kind != kAXApplicationRole else { break }
        if kind == "AXWebArea" { outermost = element }
        current = self.element(element, kAXParentAttribute)
      }
      return outermost
    }

    /// Recorrido en anchura: la primera página es la de la pestaña visible.
    func firstWebArea(in window: AXUIElement) -> AXUIElement? {
      var level = [window]
      var visited = 0
      for _ in 0..<SafariSite.maxDepth where !level.isEmpty {
        var next: [AXUIElement] = []
        for element in level {
          if role(element) == "AXWebArea" { return element }
          visited += 1
          guard visited < SafariSite.maxElements, Date() < deadline else { return nil }
          next += (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
        }
        level = next
      }
      return nil
    }

    /// Solo páginas `http`/`https`, y solo el dominio.
    func host(of page: AXUIElement) -> String? {
      guard let value = attribute(page, kAXURLAttribute) else { return nil }
      let url = CFGetTypeID(value) == CFURLGetTypeID() ? (value as! URL) : (value as? String).flatMap(URL.init(string:))
      guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""), let host = url.host() else { return nil }
      return SiteRules.normalize(host)
    }
  }
}
```

- [ ] **Step 2: El dominio va en la grabación y decide el tono**

En `Sources/Sintecla/ModeRunner.swift`, cambiar:

```swift
  var target: (bundleID: String?, name: String?)
```

por:

```swift
  var target: (bundleID: String?, name: String?)
  /// Dominio de la pestaña si se dictó en Safari (tono por web).
  var site: String? = nil
```

Y cambiar:

```swift
    let tone = settings.tones.tone(for: recording.target.bundleID)
```

por:

```swift
    let tone = settings.tones.tone(for: recording.target.bundleID, host: recording.site)
```

- [ ] **Step 3: Lanzar la lectura al pulsar (en notas, al soltar) y esperarla al procesar**

En `Sources/Sintecla/DictationController.swift`, cambiar:

```swift
  private var target: (bundleID: String?, name: String?) = (nil, nil)
```

por:

```swift
  private var target: (bundleID: String?, name: String?) = (nil, nil)
  /// Dominio de la pestaña de Safari donde se dicta (tono por web), leído en segundo plano.
  private var siteTask: Task<String?, Never>?
```

Y cambiar:

```swift
    target = (app?.bundleIdentifier, app?.localizedName)
```

por:

```swift
    target = (app?.bundleIdentifier, app?.localizedName)
    siteTask = SafariSite.read(app)
```

Y cambiar:

```swift
    appleModel?.prewarm(instructions: PromptLibrary.dictationInstructions(tone: settings.tones.tone(for: target.bundleID)))
```

por:

```swift
    // El modelo local se prepara con el tono ya resuelto (en Safari, el de la web).
    let tones = settings.tones, bundleID = target.bundleID, siteTask = self.siteTask
    Task { [weak self] in
      let site = await siteTask?.value
      self?.appleModel?.prewarm(instructions: PromptLibrary.dictationInstructions(tone: tones.tone(for: bundleID, host: site)))
    }
```

Y cambiar:

```swift
    let target = mode == .notes ? (app?.bundleIdentifier, app?.localizedName) : self.target
```

por:

```swift
    let target = mode == .notes ? (app?.bundleIdentifier, app?.localizedName) : self.target
    let siteTask = mode == .notes ? SafariSite.read(app) : self.siteTask
```

Y cambiar:

```swift
      let selection = await selectionTask?.value
      let recording = Recording(mode: mode, raw: raw, audioSeconds: session.audioSeconds, target: target,
                                language: language, selection: selection, releasedAt: releasedAt)
```

por:

```swift
      let selection = await selectionTask?.value
      let site = await siteTask?.value
      let recording = Recording(mode: mode, raw: raw, audioSeconds: session.audioSeconds, target: target, site: site,
                                language: language, selection: selection, releasedAt: releasedAt)
```

- [ ] **Step 4: Compilar**

Run:

```bash
swift build -c release --product Sintecla 2>&1 | tail -1
```

Esperado: `Build of product 'Sintecla' complete!`.

- [ ] **Step 5: Los tests siguen en verde**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 164 tests in 35 suites passed`.

- [ ] **Step 6: Commit**

```bash
git add Sources/Sintecla/SafariSite.swift Sources/Sintecla/ModeRunner.swift Sources/Sintecla/DictationController.swift
git commit -m 'feat: en Safari el tono sale de la web de la pestaña

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: Sección «Tono por web (Safari)» y versión 0.5.0

**Files:**
- Modify: `Sources/Sintecla/Windows.swift` (`TonesTab`)
- Modify: `Sources/SinteclaCore/AppInfo.swift`, `Resources/Info.plist`
- Test: `Sources/SinteclaCoreTests/SmokeTests.swift`

**Interfaces:**
- Consumes: `SiteRules.normalize(_:)`, `ToneRules.bySite` (Tarea 1); `SafariSite.frontTab()` (Tarea 2).
- Produces: La pestaña Tonos con la lista de webs, «Añadir la web abierta en Safari (…)» y el campo «Otra web»; versión 0.5.0 (build 5).

- [ ] **Step 1: Test de la versión nueva**

En `Sources/SinteclaCoreTests/SmokeTests.swift`, cambiar:

```swift
#expect(AppInfo.version == "0.4.0")
```

por:

```swift
#expect(AppInfo.version == "0.5.0")
```

- [ ] **Step 2: Ver que falla**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA el test con `Expectation failed: (AppInfo.version → "0.4.0") == "0.5.0"`.

- [ ] **Step 3: Versión 0.5.0**

En `Sources/SinteclaCore/AppInfo.swift`, cambiar:

```swift
public static let version = "0.4.0"
```

por:

```swift
public static let version = "0.5.0"
```

- [ ] **Step 4: Versión 0.5.0 (build 5) en el Info.plist**

En `Resources/Info.plist`, cambiar:

```xml
<key>CFBundleShortVersionString</key><string>0.4.0</string>
```

por:

```xml
<key>CFBundleShortVersionString</key><string>0.5.0</string>
```

Y cambiar:

```xml
<key>CFBundleVersion</key><string>4</string>
```

por:

```xml
<key>CFBundleVersion</key><string>5</string>
```

- [ ] **Step 5: Ver que pasa**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 164 tests in 35 suites passed`.

- [ ] **Step 6: Pestaña Tonos: lista de webs y cómo añadirlas**

En `Sources/Sintecla/Windows.swift`, cambiar:

```swift
struct TonesTab: View {
  @Bindable var settings: AppSettings

  var body: some View {
```

por:

```swift
struct TonesTab: View {
  @Bindable var settings: AppSettings
  /// Dominio de la pestaña de delante de Safari (se relee al volver a la ventana).
  @State private var openSite: String?
  @State private var newSite = ""

  var body: some View {
```

Y cambiar:

```swift
            Button(appName(id)) { settings.tones.byBundleID[id] = .neutral }
          }
        }
      }
    }
    .formStyle(.grouped)
  }
```

por:

```swift
            Button(appName(id)) { settings.tones.byBundleID[id] = .neutral }
          }
        }
      }
      Section("Tono por web (Safari)") {
        ForEach(settings.tones.bySite.keys.sorted(), id: \.self) { site in
          HStack {
            Picker(site, selection: siteBinding(for: site)) {
              ForEach(Tone.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Button(role: .destructive) {
              settings.tones.bySite[site] = nil
            } label: { Image(systemName: "trash") }
              .buttonStyle(.borderless)
          }
        }
      }
      Section {
        Button(openSite.map { "Añadir la web abierta en Safari (\($0))" } ?? "Añadir la web abierta en Safari") {
          if let openSite { settings.tones.bySite[openSite] = .neutral }
        }
        .disabled(openSite.map { settings.tones.bySite[$0] != nil } ?? true)
        HStack {
          TextField("Otra web", text: $newSite, prompt: Text("p. ej. linkedin.com"))
            .onSubmit(addNewSite)
          Button("Añadir", action: addNewSite)
            .disabled(SiteRules.normalize(newSite).map { settings.tones.bySite[$0] != nil } ?? true)
        }
      }
    }
    .formStyle(.grouped)
    .task { openSite = await SafariSite.frontTab() }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
      Task { openSite = await SafariSite.frontTab() }
    }
  }

  private func addNewSite() {
    guard let site = SiteRules.normalize(newSite), settings.tones.bySite[site] == nil else { return }
    settings.tones.bySite[site] = .neutral
    newSite = ""
  }

  private func siteBinding(for site: String) -> Binding<Tone> {
    Binding(get: { settings.tones.bySite[site] ?? .neutral },
            set: { settings.tones.bySite[site] = $0 })
  }
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

Esperado: `Test run with 164 tests in 35 suites passed`.

- [ ] **Step 9: Commit**

```bash
git add Sources/Sintecla/Windows.swift Sources/SinteclaCore/AppInfo.swift Resources/Info.plist Sources/SinteclaCoreTests/SmokeTests.swift
git commit -m 'feat: sección «Tono por web (Safari)» en Ajustes → Tonos

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

- [ ] **Step 10: Instalar la versión nueva**

Run:

```bash
scripts/build-app.sh
```

Esperado: `✅ Instalada en /Applications/Sintecla.app`. Los permisos se conservan.

---
### Task 4: Aceptación de la F4b

**Files:**
- Modify: `docs/superpowers/specs/2026-09-23-sintecla-design.md` (estado)

**Interfaces:**
- Consumes: La app instalada (Tarea 3), con permiso de Accesibilidad.
- Produces: Etiqueta `v0.5.0` y la rama `fase-4b` integrada en `main`.

Lo hace el usuario en Safari: es la parte que no se pudo probar sin permisos (spec F4b §7).

- [ ] **Step 1: Checklist manual F4b. Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | Abre Gmail en Safari y luego Ajustes → Tonos | Botón «Añadir la web abierta en Safari (mail.google.com)», desactivado porque ya está en la lista |
| 2 | En un correo nuevo de Gmail, dicta "hola Juan te escribo para confirmar la reunión del jueves un saludo" | Tono formal: saludo y despedida en su propia línea |
| 3 | En WhatsApp Web, dicta un mensaje de una frase | Sin punto final |
| 4 | En una web que no está en la lista (p. ej. el buscador de Wikipedia) | Tono de Safari (Neutro) |
| 5 | Escribe `https://www.linkedin.com/feed` en «Otra web» y pulsa «Añadir» | Sale `linkedin.com` como Neutro; cambiarle el tono y quitarla funciona |
| 6 | Con LinkedIn abierto en Safari, vuelve a la ventana de Sintecla | El botón pasa a «Añadir la web abierta en Safari (linkedin.com)» |
| 7 | Dicta en Mail y en WhatsApp (apps) | Su tono de siempre |
| 8 | Dictado, traducción, Ask, notas y reuniones | Igual que en la 0.4.0 |

- [ ] **Step 2: Marcar la F4b como entregada en la spec**

En `docs/superpowers/specs/2026-09-23-sintecla-design.md`, cambiar:

```text
F4a entregada (`v0.4.0`).
```

por:

```text
F4a entregada (`v0.4.0`). F4b entregada (`v0.5.0`).
```

- [ ] **Step 3: Cerrar la fase**

```bash
git add docs/superpowers/specs/2026-09-23-sintecla-design.md
git commit -m 'docs: F4b entregada

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
swift run sintecla-tests
git tag -a v0.5.0 -m 'F4b: tono por web'
```

Después, integrar `fase-4b` en `main` con superpowers:finishing-a-development-branch.

---
## Autorrevisión frente a la especificación (F4b)

| Requisito (spec F4b) | Dónde |
|---|---|
| §2 Solo Safari; subir desde el foco al `AXWebArea` más externo (≤ 40 niveles); si no, buscar en la ventana (≤ 10 niveles, ≤ 500 elementos); solo el dominio de páginas `http`/`https`; 0,5 s; fuera del hilo principal | Tarea 2 |
| §2 La misma lectura para «Añadir la web abierta en Safari», con Safari detrás | Tareas 2 (`frontTab`) y 3 |
| §3 Normalizar dominios, subdominios, la más larga gana, solo en Safari, si no el tono de la app | Tarea 1 |
| §3 Lista inicial; `tones.json` antiguos con la lista inicial; lista vacía conservada | Tarea 1 |
| §4 Leer al pulsar (notas: al soltar), esperar al procesar, `prewarm` con el tono resuelto, dominio en `Recording` | Tarea 2 |
| §5 Sección «Tono por web (Safari)», quitar, «Añadir la web abierta…» (relee al volver a la ventana), «Otra web» normalizada | Tarea 3 |
| §6 Versión 0.5.0 | Tarea 3 |
| §7 Tests automáticos y aceptación a mano | Tareas 1 y 4 |

**Consistencia de tipos revisada:**
- `SiteRules.normalize` (Tarea 1) la usan `SafariSite.host(of:)` (Tarea 2) y el campo «Otra web» (Tarea 3).
- `SiteRules.browsers` (Tarea 1) decide tanto la regla (`tone(for:host:)`) como si se lee (`SafariSite.read`, Tarea 2).
- `Recording.site` (Tarea 2) llega a `tone(for:host:)` en `ModeRunner.run`.
