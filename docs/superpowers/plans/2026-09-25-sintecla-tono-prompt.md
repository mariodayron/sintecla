# Sintecla — Tono «Prompt para IA» — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un quinto tono, «Prompt para IA», que en Claude, ChatGPT, Codex y sus webs convierte lo dictado en un prompt ordenado (primero lo que se pide, luego el contexto y los requisitos en lista), sin añadir nada.

**Architecture:** Todo en el núcleo `SinteclaCore`, con tests:
- `Tone.prompt` y sus líneas en `ToneFormatter` (Apple y Gemini), con etiquetas permitidas.
- `ToneRules` cambia sus valores por defecto y pasa las apps y webs de IA de Técnico a Prompt una sola vez (`version` 2).
- `DictationRewriter`, con el tono Prompt, cuenta las etiquetas como dichas y admite hasta un 50 % de palabras nuevas.

La app no cambia: los selectores de Ajustes → Tonos salen de `Tone.allCases`.

**Tech Stack:** Lo de siempre: Swift 6.3 de las Command Line Tools en modo de lenguaje 5, SwiftPM, FoundationModels, Swift Testing y Gemini (`CloudTextModel`).

**Especificación:** `docs/superpowers/specs/2026-09-25-tono-prompt-design.md`. Amplía `2026-09-24-ordenar-dictado-design.md` dentro de la 0.8.0.

**Punto de partida:** la rama `ordenar`, con «Ordenar el dictado» hecho (plan `2026-09-24-sintecla-ordenar.md`, Tareas 1–5 y el arreglo de los saludos) y la especificación del tono:

```bash
git checkout ordenar
```

## Global Constraints

- **Todo lo de antes sigue vigente:**
  - macOS 26.0 o superior, Apple Silicon.
  - Sin Xcode ni dependencias externas; todos los targets en `.swiftLanguageMode(.v5)`.
  - Tests con `swift run sintecla-tests` (**nunca `swift test`**).
  - Textos visibles en español.
  - La clave de Gemini solo la lee la app; nunca se imprime.
- **El tono:** `Tone.prompt`, nombre **«Prompt para IA»**, detrás de Técnico en `Tone.allCases`.
- **Por defecto:**
  - Prompt: las apps `com.anthropic.claudefordesktop`, `com.openai.chat` y `com.openai.codex`, y las webs `claude.ai`, `chatgpt.com` y `gemini.google.com`.
  - Terminal, iTerm, Warp, VS Code, Cursor y github.com siguen en **Técnico**.
- **Paso a la 0.8.0:** un `tones.json` sin `version` (o con `version` < 2) pasa esas apps y webs de Técnico a Prompt, respeta cualquier otro tono y queda con `version` = 2. Ocurre **una sola vez**.
- **Filtro con el tono Prompt** (solo en el camino de Gemini):
  - «Requisitos», «Contexto», «Pasos» y «Objetivo» cuentan como dichas;
  - admite hasta un **50 %** de palabras nuevas;
  - el resto, igual: longitud ≤ 1,3×, la pregunta sigue siendo pregunta y no se aceptan saludos inventados.
- **Bancos:**
  - `sintecla-eval`: **42/42**;
  - `--traduccion`: **20/20**;
  - `--ordenar` (ahora con 15 casos) con Apple: **al menos 10/15**;
  - `Sintecla --rewrite-bench` con Gemini: **al menos 13/15**.
- Commits: en español, con prefijo convencional y la línea final `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Todas las rutas son relativas a la raíz del repositorio.

## Hechos verificados antes de escribir este plan

Todo el código de este plan se compiló y se ejecutó en un prototipo. Después, un script aplicó el plan paso a paso sobre un clon limpio de `ordenar`: compiló, pasó los tests y los bancos en cada tarea, y el árbol final quedó idéntico al del prototipo.

- **226 tests** (42 suites) en verde: los 219 de antes y 7 nuevos. La release compila sin avisos.
- **Gemini** (`--rewrite-bench`, con la clave y «Mi estilo» reales): **15, 13 y 14 de 15** en tres pasadas. Los 3 casos de prompt salen bien. Lo que varía entre pasadas: un «oye» o un «o sea» que se queda.
- **Apple:** ordenar 11/15, dictado 42/42 y traducción 20/20.
- **Salida real de Gemini** con el tono Prompt: «Crea una función en Swift. / Contexto: / - Lee un JSON de la carpeta de documentos. / - Si el JSON está roto, no debe petar y hay que moverlo a otro sitio. / - Debe incluir tests.»

**Trampas ya resueltas (no las "arregles"):**

| Trampa | Solución en el plan |
|---|---|
| Con un 25 % de palabras nuevas como máximo, el filtro rechazaba el prompt de Gemini: al pasar a imperativo cambian muchas palabras (42 % en la prueba) | `DictationRewriter.promptNovelRatio = 0.5` solo con el tono Prompt (Tarea 2) |
| «Requisitos:» y «Contexto:» contaban como palabras nuevas | `ToneFormatter.allowedLabels(for:)` (Tareas 1 y 2) |
| Los `tones.json` de antes guardan Claude y ChatGPT en Técnico, así que los valores por defecto nuevos no les llegarían | `ToneRules.version` y el paso una sola vez (Tarea 1) |
| Apple no limpia órdenes a una IA («hazme…», «resúmeme…», «cómo se hace…»): las obedece o las contesta, con el tono Prompt y con el Técnico | Se queda así (spec §7): sin Gemini, esos dictados salen solo con las reglas. El banco con Apple lo tiene en cuenta (≥ 10/15) |
| Gemini escribe «3200 €» en vez de «tres mil doscientos euros» | El banco admite «euros\|€» (Tarea 3) |

## Mapa de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `Sources/SinteclaCore/Tone.swift` | `Tone.prompt`, valores por defecto, `version` y el paso a la 0.8.0, líneas de tono y etiquetas | 1 |
| `Sources/SinteclaCore/Notes.swift` | Notas en Markdown con el tono Prompt | 1 |
| `Sources/SinteclaCoreTests/PromptToneTests.swift` | Tests del tono | 1 |
| `Sources/SinteclaCore/DictationRewriter.swift`, `Sources/SinteclaCoreTests/DictationRewriterTests.swift` | Filtro con el tono Prompt | 2 |
| `Resources/eval/ordenar_es.json`, `README.md`, `docs/superpowers/specs/2026-09-23-sintecla-design.md` | Banco con 3 casos de prompt, README y spec principal | 3 |

---

### Task 1: El tono «Prompt para IA»

**Files:**
- Modify: `Sources/SinteclaCore/Tone.swift`
- Modify: `Sources/SinteclaCore/Notes.swift` (`NotesFormat.forApp`)
- Test: `Sources/SinteclaCoreTests/PromptToneTests.swift`

**Interfaces:**
- Consumes: `Tone`, `ToneRules` (con `init(from:)` propio desde la F4b), `ToneFormatter.instruction`, `cloudInstruction` y `postProcess` (0.8.0, Tarea 2 de ordenar) y `NotesFormat.forApp(bundleID:tone:)`.
- Produces: `Tone.prompt` (`label` «Prompt para IA»); `ToneRules.version: Int`, `ToneRules.currentVersion = 2`, `init(byBundleID:bySite:version:)`; `ToneFormatter.allowedLabels(for: Tone) -> [String]`.

Todo el tono en un solo sitio. Los `switch` sobre `Tone` están todos en `Tone.swift`; la app no tiene ninguno, y sus selectores salen de `Tone.allCases`.

- [ ] **Step 1: Tests del tono**

Crear `Sources/SinteclaCoreTests/PromptToneTests.swift`:

```swift
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct PromptToneTests {
  let safari = "com.apple.Safari"

  @Test func aiAppsAndSitesUseThePromptTone() {
    let rules = ToneRules.defaults
    #expect(rules.tone(for: "com.anthropic.claudefordesktop") == .prompt)
    #expect(rules.tone(for: "com.openai.chat") == .prompt)
    #expect(rules.tone(for: "com.openai.codex") == .prompt)
    #expect(rules.tone(for: safari, host: "claude.ai") == .prompt)
    #expect(rules.tone(for: safari, host: "chatgpt.com") == .prompt)
    #expect(rules.tone(for: safari, host: "gemini.google.com") == .prompt)
    // Donde también se dictan comandos y código, sigue el técnico.
    #expect(rules.tone(for: "com.apple.Terminal") == .technical)
    #expect(rules.tone(for: safari, host: "github.com") == .technical)
    #expect(Tone.prompt.label == "Prompt para IA")
    #expect(Tone.allCases == [.formal, .informal, .technical, .prompt, .neutral])
  }

  @Test func anOldTonesFileMovesAIFromTechnicalToPrompt() throws {
    let old = #"{"byBundleID":{"com.anthropic.claudefordesktop":"technical","com.openai.chat":"informal","#
      + #""com.apple.Terminal":"technical"},"bySite":{"chatgpt.com":"technical","github.com":"technical"}}"#
    let rules = try JSONDecoder().decode(ToneRules.self, from: Data(old.utf8))
    #expect(rules.byBundleID == ["com.anthropic.claudefordesktop": .prompt, "com.openai.chat": .informal,
                                 "com.apple.Terminal": .technical])
    #expect(rules.bySite == ["chatgpt.com": .prompt, "github.com": .technical])
    #expect(rules.version == ToneRules.currentVersion)
  }

  @Test func theChangeHappensOnlyOnce() throws {
    var rules = ToneRules.defaults
    rules.byBundleID["com.anthropic.claudefordesktop"] = .technical
    let decoded = try JSONDecoder().decode(ToneRules.self, from: JSONEncoder().encode(rules))
    #expect(decoded == rules)
    #expect(decoded.tone(for: "com.anthropic.claudefordesktop") == .technical)
  }

  @Test func promptLinesForAppleAndGemini() {
    #expect(ToneFormatter.instruction(for: .prompt).hasPrefix("Es un mensaje para una IA: pon primero lo que se pide"))
    #expect(ToneFormatter.cloudInstruction(for: .prompt).hasPrefix("prompt para una IA: empieza por lo que se pide"))
    #expect(ToneFormatter.cloudInstruction(for: .prompt).hasSuffix("no añadas requisitos, roles, formatos ni peticiones que no haya dicho"))
    #expect(ToneFormatter.postProcess("Haz una función.", tone: .prompt) == "Haz una función.")
    #expect(ToneFormatter.allowedLabels(for: .prompt) == ["Requisitos", "Contexto", "Pasos", "Objetivo"])
    #expect(ToneFormatter.allowedLabels(for: .technical).isEmpty)
  }

  @Test func notesInAIAppsAreMarkdown() {
    #expect(NotesFormat.forApp(bundleID: "com.anthropic.claudefordesktop", tone: .prompt) == .markdown)
  }
}
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA al compilar con `error: type 'Tone' has no member 'prompt'`.

- [ ] **Step 3: El tono, sus valores por defecto, el paso a la 0.8.0 y sus líneas**

En `Sources/SinteclaCore/Tone.swift`, cambiar:

```swift
  case formal, informal, technical, neutral
```

por:

```swift
  case formal, informal, technical, prompt, neutral
```

Y cambiar:

```swift
    case .technical: "Técnico"
    case .neutral: "Neutro"
```

por:

```swift
    case .technical: "Técnico"
    case .prompt: "Prompt para IA"
    case .neutral: "Neutro"
```

Y cambiar:

```swift
  public var bySite: [String: Tone]

  public init(byBundleID: [String: Tone], bySite: [String: Tone] = [:]) {
    self.byBundleID = byBundleID
    self.bySite = bySite
  }
```

por:

```swift
  public var bySite: [String: Tone]
  /// 2 desde la 0.8.0 (tono Prompt para IA). Los tones.json de antes no la tienen.
  public var version: Int

  public static let currentVersion = 2
  /// Apps y webs de IA que en la 0.8.0 pasan de Técnico (su valor por defecto hasta entonces) a Prompt.
  static let aiApps: Set<String> = ["com.anthropic.claudefordesktop", "com.openai.chat", "com.openai.codex"]
  static let aiSites: Set<String> = ["claude.ai", "chatgpt.com", "gemini.google.com"]

  public init(byBundleID: [String: Tone], bySite: [String: Tone] = [:], version: Int = Self.currentVersion) {
    self.byBundleID = byBundleID
    self.bySite = bySite
    self.version = version
  }
```

Y cambiar:

```swift
    bySite = try container.decodeIfPresent([String: Tone].self, forKey: .bySite) ?? Self.defaults.bySite
  }
```

por:

```swift
    bySite = try container.decodeIfPresent([String: Tone].self, forKey: .bySite) ?? Self.defaults.bySite
    version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
    // Una sola vez: las apps y webs de IA que siguen en Técnico pasan a Prompt; otro tono elegido se respeta.
    if version < 2 {
      for id in Self.aiApps where byBundleID[id] == .technical { byBundleID[id] = .prompt }
      for site in Self.aiSites where bySite[site] == .technical { bySite[site] = .prompt }
      version = Self.currentVersion
    }
  }
```

Y cambiar:

```swift
    "dev.warp.Warp-Stable": .technical,
    "com.anthropic.claudefordesktop": .technical,
    "com.openai.chat": .technical,
    "com.openai.codex": .technical,
```

por:

```swift
    "dev.warp.Warp-Stable": .technical,
    // Prompt para IA
    "com.anthropic.claudefordesktop": .prompt,
    "com.openai.chat": .prompt,
    "com.openai.codex": .prompt,
```

Y cambiar:

```swift
    "github.com": .technical,
    "chatgpt.com": .technical,
    "claude.ai": .technical,
    "gemini.google.com": .technical,
```

por:

```swift
    "github.com": .technical,
    // Prompt para IA
    "chatgpt.com": .prompt,
    "claude.ai": .prompt,
    "gemini.google.com": .prompt,
```

Y cambiar:

```swift
    case .technical: "Contexto técnico: conserva literalmente términos técnicos, nombres de código, rutas y palabras en inglés."
    case .neutral: ""
```

por:

```swift
    case .technical: "Contexto técnico: conserva literalmente términos técnicos, nombres de código, rutas y palabras en inglés."
    case .prompt: "Es un mensaje para una IA: pon primero lo que se pide y conserva literalmente términos técnicos, código, rutas y palabras en inglés."
    case .neutral: ""
```

Y cambiar:

```swift
    case .technical: "técnico: conserva literalmente términos técnicos, nombres de código, comandos, rutas y palabras en inglés; si describe pasos, ponlos en lista numerada"
    case .neutral: "neutro: claro y correcto"
    }
  }
```

por:

```swift
    case .technical: "técnico: conserva literalmente términos técnicos, nombres de código, comandos, rutas y palabras en inglés; si describe pasos, ponlos en lista numerada"
    case .prompt: "prompt para una IA: empieza por lo que se pide y después el contexto; si hay 2 o más requisitos, condiciones o pasos, ponlos en lista con «- » bajo una etiqueta corta («Requisitos:», «Pasos:» o «Contexto:»); conserva literalmente términos técnicos, código, rutas y palabras en inglés; no añadas requisitos, roles, formatos ni peticiones que no haya dicho"
    case .neutral: "neutro: claro y correcto"
    }
  }

  /// Etiquetas que el tono Prompt pone a sus listas: el filtro no las cuenta como palabras nuevas.
  public static func allowedLabels(for tone: Tone) -> [String] {
    tone == .prompt ? ["Requisitos", "Contexto", "Pasos", "Objetivo"] : []
  }
```

Y cambiar:

```swift
    case .technical, .neutral: text
```

por:

```swift
    case .technical, .prompt, .neutral: text
```

- [ ] **Step 4: Notas en Markdown también con el tono Prompt**

En `Sources/SinteclaCore/Notes.swift`, cambiar:

```swift
    if tone == .technical { return .markdown }
```

por:

```swift
    if tone == .technical || tone == .prompt { return .markdown }
```

- [ ] **Step 5: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 224 tests in 42 suites passed`.

- [ ] **Step 6: Commit**

```bash
git add Sources/SinteclaCore/Tone.swift Sources/SinteclaCore/Notes.swift Sources/SinteclaCoreTests/PromptToneTests.swift
git commit -m 'feat: tono «Prompt para IA» para Claude, ChatGPT, Codex y sus webs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 2: El filtro deja estructurar el prompt

**Files:**
- Modify: `Sources/SinteclaCore/DictationRewriter.swift`
- Test: `Sources/SinteclaCoreTests/DictationRewriterTests.swift`

**Interfaces:**
- Consumes: `ToneFormatter.allowedLabels(for:)` y `Tone.prompt` (Tarea 1); `OutputGuard.maxNovelRatio` y `FakeModel` (0.8.0).
- Produces: `DictationRewriter.promptNovelRatio = 0.5`; con el tono Prompt, `rewrite` acepta las etiquetas y hasta un 50 % de palabras nuevas.

Solo en el camino de Gemini. El de Apple (`DictationCleaner`) no cambia: con órdenes a una IA no sirve (spec §7).

- [ ] **Step 1: Tests: etiquetas e imperativo con el tono Prompt, y rechazo con el Técnico**

En `Sources/SinteclaCoreTests/DictationRewriterTests.swift`, cambiar:

```swift
  @Test func answerRejectedByTheGuardFallsBackWithoutError() async {
```

por:

```swift
  @Test func promptLabelsCountAsSaid() async {
    let dictated = "revisa el login porque falla en safari y en chrome, falla en los dos, y añade tests"
    let structured = "Contexto:\nEl login falla en Safari y en Chrome.\n\nRequisitos:\n- Revísalo.\n- Añade tests."
    let cloud = FakeModel { _ in structured }
    #expect(await rewriter(cloud).rewrite(dictated, tone: .prompt) == DictationRewriter.Result(text: structured, engine: .gemini))
    // Con otro tono, «Contexto» y «Requisitos» son palabras nuevas y el filtro lo rechaza.
    #expect(await rewriter(cloud).rewrite(dictated, tone: .technical).engine == .rules)
  }

  @Test func promptAllowsRewritingIntoTheImperative() async {
    // Salida real de Gemini: al pasar a imperativo cambian muchas palabras («lea» → «Lee», «mueva» → «moverlo»).
    let dictated = "oye quiero que me hagas una función en swift que, o sea, que lea un json de la carpeta de documentos, "
      + "y que si el json está roto pues que no pete, que lo mueva a otro sitio, y bueno que tenga tests"
    let prompt = "Crea una función en Swift.\nContexto:\n- Lee un JSON de la carpeta de documentos.\n"
      + "- Si el JSON está roto, no debe petar y hay que moverlo a otro sitio.\n- Debe incluir tests."
    let cloud = FakeModel { _ in prompt }
    #expect(await rewriter(cloud).rewrite(dictated, tone: .prompt).engine == .gemini)
    #expect(await rewriter(cloud).rewrite(dictated, tone: .technical).engine == .rules)
  }

  @Test func answerRejectedByTheGuardFallsBackWithoutError() async {
```

- [ ] **Step 2: Ver que fallan**

Run:

```bash
swift run sintecla-tests
```

Esperado: FALLA el test con `Test promptAllowsRewritingIntoTheImperative() recorded an issue at DictationRewriterTests.swift:87:5: Expectation failed`.

- [ ] **Step 3: Etiquetas permitidas y 50 % de palabras nuevas con el tono Prompt**

En `Sources/SinteclaCore/DictationRewriter.swift`, cambiar:

```swift
  public static let timeout: TimeInterval = 6
```

por:

```swift
  public static let timeout: TimeInterval = 6
  /// El tono Prompt reescribe más (imperativo, etiquetas y listas): admite hasta la mitad de palabras nuevas.
  public static let promptNovelRatio = 0.5
```

Y cambiar:

```swift
      guard outputGuard.accepts(input: pre, output: output, allowedNewWords: Set(terms)) else {
```

por:

```swift
      var check = outputGuard
      if tone == .prompt { check.maxNovelRatio = max(check.maxNovelRatio, Self.promptNovelRatio) }
      guard check.accepts(input: pre, output: output, allowedNewWords: Set(terms + ToneFormatter.allowedLabels(for: tone))) else {
```

- [ ] **Step 4: Ver que pasan**

Run:

```bash
swift run sintecla-tests
```

Esperado: `Test run with 226 tests in 42 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/SinteclaCore/DictationRewriter.swift Sources/SinteclaCoreTests/DictationRewriterTests.swift
git commit -m 'feat: el filtro deja a Gemini estructurar el prompt

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

---
### Task 3: Banco con casos de prompt, README y spec principal

**Files:**
- Modify: `Resources/eval/ordenar_es.json`
- Modify: `README.md`, `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§6)

**Interfaces:**
- Consumes: `EvalSample.tono` y las alternativas «a|b» de `EvalBench` (0.8.0).
- Produces: `ordenar_es.json` con 15 casos (3 con `"tono": "prompt"`).

Los 3 casos nuevos: una función con requisitos, una orden a la IA sobre un texto (no se ejecuta) y una pregunta técnica (sigue siendo pregunta).

- [ ] **Step 1: Los 3 casos de prompt y «euros|€»**

Sustituir todo el contenido de `Resources/eval/ordenar_es.json`:

```json
[
  {"entrada": "vale pues mañana tenemos la reunión con el cliente, o sea la reunión es a las diez, y hay que llevar el presupuesto, el presupuesto actualizado, y bueno también las fotos de la obra, y que no se nos olvide el presupuesto eh", "requeridas": ["diez|10", "presupuesto actualizado", "fotos de la obra"], "prohibidas": ["o sea", "eh", "vale pues", "bueno"]},
  {"entrada": "lo que te quería decir es que el pedido no ha llegado, o sea que no ha llegado todavía el pedido, y que si puedes llamar al proveedor para ver qué pasa con el pedido", "requeridas": ["pedido", "proveedor"], "prohibidas": ["o sea"]},
  {"entrada": "necesito que me mandes el informe, el informe de ventas digo, antes del viernes, porque el viernes tengo la reunión y lo necesito para la reunión", "requeridas": ["informe de ventas", "viernes"], "prohibidas": ["digo"]},
  {"entrada": "bueno la idea es que la app sea más rápida, que vaya más rápido, sobre todo al abrir, que al abrir tarda mucho", "requeridas": ["rápid", "abrir"], "prohibidas": ["bueno"]},
  {"entrada": "oye sabes si el martes hay reunión o la han movido al miércoles", "requeridas": ["martes", "miércoles"], "prohibidas": ["oye"], "pregunta": true},
  {"entrada": "escríbele a Ana que llego tarde a la comida", "requeridas": ["Escríbele a Ana", "llego tarde"], "prohibidas": ["Hola"]},
  {"entrada": "recuérdame llamar al fontanero mañana, al fontanero, por lo de la caldera", "requeridas": ["Recuérdame", "fontanero", "caldera"], "prohibidas": []},
  {"entrada": "en el archivo package punto swift añade el target sintecla eval, o sea añade un executable target que se llame sintecla eval", "requeridas": ["target"], "prohibidas": ["o sea"], "tono": "technical"},
  {"entrada": "hola marta te escribo porque el presupuesto que te mandé, el presupuesto de la reforma, tiene un error en el total, el total correcto son tres mil doscientos euros, un saludo", "requeridas": ["Marta", "reforma", "euros|€", "saludo"], "prohibidas": [], "tono": "formal"},
  {"entrada": "y entonces le dije que no, que no podíamos, que no podíamos hacerlo esta semana porque esta semana estamos con lo de Valencia, lo de la obra de Valencia, y que la semana que viene sí", "requeridas": ["Valencia", "semana que viene"], "prohibidas": ["que no, que no"]},
  {"entrada": "apunta que hay que comprar tornillos, tornillos del ocho, cinta americana y y guantes, guantes de trabajo", "requeridas": ["tornillos", "cinta americana", "guantes"], "prohibidas": ["y y"]},
  {"entrada": "quedamos el jueves a las cinco, no perdón, el viernes a las cinco en la oficina, en la oficina de Madrid", "requeridas": ["viernes", "cinco", "oficina de Madrid"], "prohibidas": ["jueves", "perdón"]},
  {"entrada": "oye quiero que me hagas una función en swift que, o sea, que lea un json de la carpeta de documentos, y que si el json está roto pues que no pete, que lo mueva a otro sitio, y bueno que tenga tests", "requeridas": ["Swift", "JSON", "tests"], "prohibidas": ["o sea", "oye", "bueno"], "tono": "prompt"},
  {"entrada": "resúmeme este texto en tres puntos, en tres puntos como mucho, y que sea en inglés porque es para un cliente de fuera, para un cliente de Londres", "requeridas": ["resúm|resum", "tres puntos", "inglés", "Londres"], "prohibidas": [], "tono": "prompt"},
  {"entrada": "oye cómo se hace, cómo se hace un merge de una rama en git sin perder, sin perder los cambios que tengo sin guardar", "requeridas": ["merge", "git", "cambios"], "prohibidas": ["oye"], "pregunta": true, "tono": "prompt"}
]
```

- [ ] **Step 2: Banco de ordenar con Apple: al menos 10 de 15**

Run:

```bash
swift run -c release sintecla-eval --ordenar 2>&1 | tail -1
```

Esperado: `Aciertos: 11/15 (73%)`.

Con Apple, los 3 casos de prompt salen solo con las reglas (spec §7): es lo esperado.

- [ ] **Step 3: El banco del dictado sigue entero**

Run:

```bash
swift run -c release sintecla-eval 2>&1 | tail -1
```

Esperado: `Aciertos: 42/42 (100%)`.

- [ ] **Step 4: El de la traducción también**

Run:

```bash
swift run -c release sintecla-eval --traduccion 2>&1 | tail -1
```

Esperado: `Aciertos: 20/20 (100%)`.

- [ ] **Step 5: README: el tono de las apps de IA**

En `README.md`, cambiar:

```text
El tono se adapta a la app (formal en Mail, informal en WhatsApp…) y, en Safari, a la web (Gmail, WhatsApp Web…).
```

por:

```text
El tono se adapta a la app (formal en Mail, informal en WhatsApp, prompt ordenado en Claude o ChatGPT…) y, en Safari, a la web (Gmail, WhatsApp Web, claude.ai…).
```

- [ ] **Step 6: Spec principal §6: la fila del tono nuevo**

En `docs/superpowers/specs/2026-09-23-sintecla-design.md`, cambiar:

```text
| Técnico | VS Code, Cursor, Terminal, iTerm2, Warp, Claude, ChatGPT | Términos técnicos e identificadores literales, listas Markdown |
```

por:

```text
| Técnico | VS Code, Cursor, Terminal, iTerm2, Warp | Términos técnicos e identificadores literales, listas Markdown |
| Prompt para IA (desde la 0.8.0) | Claude, ChatGPT, Codex; en Safari claude.ai, chatgpt.com, gemini.google.com | Lo que se pide primero, luego el contexto y los requisitos en lista con etiqueta corta, sin añadir nada (ver `2026-09-25-tono-prompt-design.md`) |
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

Esperado: `Test run with 226 tests in 42 suites passed`.

- [ ] **Step 9: Commit**

```bash
git add Resources/eval/ordenar_es.json README.md docs/superpowers/specs/2026-09-23-sintecla-design.md
git commit -m 'test: casos de prompt en el banco; README y spec del tono nuevo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
```

- [ ] **Step 10: Instalar la versión nueva**

Run:

```bash
scripts/build-app.sh
```

Esperado: `✅ Instalada en /Applications/Sintecla.app`. Al abrirse, tu `tones.json` pasa Claude, ChatGPT y Codex a Prompt.

- [ ] **Step 11: Banco de ordenar con Gemini (solo manda los 15 casos inventados)**

Run:

```bash
/Applications/Sintecla.app/Contents/MacOS/Sintecla --rewrite-bench
```

Esperado: `Aciertos: 13/15` o más, con `[gemini]` en cada caso.

---
### Task 4: Aceptación del tono (con la de la 0.8.0)

**Files:**
- —

**Interfaces:**
- Consumes: La app instalada (Tarea 3).
- Produces: Nada nuevo: la 0.8.0 se cierra con la Tarea 6 del plan `2026-09-24-sintecla-ordenar.md`, con estas pruebas añadidas.

Lo hace el usuario, junto con la checklist de «Ordenar el dictado».

- [ ] **Step 1: Checklist manual del tono. Anota ✓/✗ y cualquier fallo**

| # | Prueba | Esperado |
|---|---|---|
| 1 | Ajustes → Tonos | Claude, ChatGPT y Codex en «Prompt para IA»; Terminal, VS Code y Cursor en Técnico |
| 2 | En Claude (la app), dictar «oye quiero que me hagas una función en swift que lea un json de la carpeta de documentos, y que si está roto no pete, que lo mueva a otro sitio, y que tenga tests» | La petición primero y los requisitos en lista; nada inventado |
| 3 | En chatgpt.com (Safari), dictar una pregunta («cómo se hace un merge sin perder los cambios») | Se pega la pregunta, ordenada; no la respuesta |
| 4 | Poner Claude en Técnico, salir y volver a abrir Sintecla | Claude sigue en Técnico (el paso a Prompt solo ocurre una vez) |

---
## Autorrevisión frente a la especificación (tono Prompt)

| Requisito (spec del tono) | Dónde |
|---|---|
| §1 Ordenar y estructurar como prompt sin añadir nada; Terminal, editores y github.com siguen en Técnico | Tareas 1 y 2 |
| §2 `Tone.prompt` «Prompt para IA», valores por defecto, paso a la 0.8.0 una sola vez, notas en Markdown | Tarea 1 |
| §3 Líneas de Gemini y de Apple, sin ajuste final | Tarea 1 |
| §4 Etiquetas permitidas y 50 % de palabras nuevas en el camino de Gemini | Tareas 1 y 2 |
| §5 Piezas: `Tone`, `ToneRules`, `ToneFormatter`, `NotesFormat`, `DictationRewriter`, banco, README y spec principal | Tareas 1–3 |
| §6 Tests, bancos (≥ 10/15 con Apple, ≥ 13/15 con Gemini, 42/42, 20/20) y aceptación | Tareas 1–4 |
| §7 Lo visto en el prototipo (Apple con órdenes a una IA) | Trampas y Tarea 3 |

**Consistencia de tipos revisada:**
- `ToneFormatter.allowedLabels(for:)` (Tarea 1) la usa `DictationRewriter.rewrite` (Tarea 2).
- `ToneRules.version` y `currentVersion` (Tarea 1) los usan los tests de la Tarea 1.
- `DictationRewriter.promptNovelRatio` (Tarea 2) solo se aplica con `Tone.prompt`.
