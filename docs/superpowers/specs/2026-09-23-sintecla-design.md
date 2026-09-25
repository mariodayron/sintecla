# Sintecla — Especificación de diseño

- **Fecha:** 2026-09-23
- **Estado:** aprobado. F1 entregada (`v0.1.0`). F2 entregada (`v0.2.0`). F3 entregada (`v0.3.0`); queda por comprobar una reunión real de ≥ 20 min. F4a entregada (`v0.4.0`). F4b entregada (`v0.5.0`). Icono entregado (`v0.5.1`). F4c entregada (`v0.6.0`). Estadísticas entregadas (`v0.7.0`).
- **Qué es:** app de dictado por voz para macOS que replica las funciones de Typeless (typeless.com) sin límite de palabras, con transcripción y limpieza locales y gratuitas, más dos extras: notas organizadas y actas de reuniones en PDF.

---

## 1. Objetivos y no-objetivos

### Objetivos
1. Dictar en **cualquier app** con `Fn` y que el texto limpio **se pegue solo** en el cuadro de texto activo.
2. Igualar las funciones de Typeless en Mac: limpieza IA (muletillas, repeticiones, autocorrecciones, listas), traducción al hablar, Ask Anything (editar/preguntar sobre selección, respuestas rápidas, acciones web), diccionario personal, tono por app, modo susurro, historial.
3. **Coste cero** en el uso diario: voz→texto y limpieza 100 % locales (Apple). Solo Ask Anything, notas, el respaldo de la traducción y las reuniones usan una API barata (Gemini `gemini-3.5-flash-lite`, menos de 1 $/mes estimado).
4. Extras: **modo Notas** (grabación larga → ideas organizadas pegadas en el cursor) y **modo Reunión** (graba micro + audio del sistema → resumen estructurado en PDF).
5. Arranque automático al iniciar sesión.

### No-objetivos
- Windows, iOS, Android, sincronización en la nube, gestión de equipos.
- Más de 2 idiomas de dictado: solo **español (es_ES)** e **inglés (en_US)**. Otros idiomas (motor Whisper) quedan fuera.
- Distribución en App Store o notarización: es una app personal compilada en local.
- Identificar por voz a cada participante remoto de una reunión (solo "Tú" / "Otros").

---

## 2. Entorno y decisiones tomadas (con evidencia)

**Máquina de desarrollo:** Mac con Apple Silicon y macOS 26, sin Xcode (solo Command Line Tools, Swift 6.3). Si Typeless está abierto, también usa `Fn` (Sintecla avisa).

| Decisión | Motivo / prueba realizada |
|---|---|
| App nativa Swift propia, compilada con SwiftPM (sin Xcode) | Elegida frente a modificar VoiceInk (requiere Xcode, ~15 GB) o usar Handy/OpenTypeless (faltan funciones). `swift` de las CLT compila código con Speech, FoundationModels, CoreAudio y WebKit (probado). |
| Voz→texto: `SpeechAnalyzer` + `SpeechTranscriber` de Apple (es_ES / en_US) | Local, gratis, ilimitado. es_ES y en_* ya instalados en el Mac. Transcribe en ~0,06 s tras soltar (probado). La API de vocabulario `AnalysisContext.contextualStrings` existe, pero apenas influye ("Brisenta" → "brisa"/"brosanta", probado): el diccionario se aplica después (§6). `DictationTranscriber` sí usa el vocabulario, pero perdió palabras en la prueba. |
| Limpieza de dictado: **reglas deterministas + modelo local de Apple (FoundationModels) + filtro anti-invención** | Probado con 6 frases reales: 6/6 correctas, 0,3–0,5 s (1,3 s la primera, sin precalentar). El modelo de Apple **solo** falló autocorrecciones y respondió una pregunta dictada inventando la respuesta; la capa de reglas + filtro lo corrige. |
| Sin macros `@Generable` | El plugin `FoundationModelsMacros` no viene en las CLT (error de compilación comprobado). Para salidas estructuradas con Apple se usa `DynamicGenerationSchema` (probado). |
| Contexto del modelo Apple: 4.096 tokens | `SystemLanguageModel.default.contextSize` = 4096 (probado). Textos largos se trocean. |
| IA en la nube: **Gemini `gemini-3.5-flash-lite` de pago** para Ask Anything (preguntas, ediciones que el modelo local no resuelve, acciones web), notas, respaldo de la traducción y reuniones | 0,30 $/M tokens de entrada y 2,50 $/M de salida (unos 0,60 $/mes con uso diario); el plan de pago no usa los datos para entrenar. Elegido por el usuario frente a `gemini-3.1-flash-lite` (0,25/1,50 $): con la clave real y el VPN, 10 preguntas dieron mediana 1,07 s frente a 2,55 s; notas de 10 min en 4,5–4,9 s; los dos esquemas JSON funcionan por la API compatible con OpenAI (probado). `gemini-2.5-flash-lite` (0,10/0,40 $) ya solo lo pueden usar quienes lo usaban antes (documentación de modelos, septiembre de 2026). Funciona también a través de VPN (probado: una clave inválida da error en 0,27 s). Groq descartado: bloquea algunas IP de VPN ("Access denied", probado). |
| Traducción: **traductor de Apple** (`TranslationSession(installedSource:target:preferredStrategy: .highFidelity)`) sobre el texto ya limpio | Probado con 16 frases dictadas. El modelo de lenguaje de Apple con instrucciones de traducir acertó 10: respondió preguntas ("It is 10:00 AM in Tokyo", "Paris"), escribió un poema, contestó "Hello" y tradujo al francés. El traductor acertó 16/16 y nunca obedece al texto. `highFidelity` respeta "Supabase" (`lowLatency` escribió "Subase"). Español → en/fr/de/it/pt/ja/zh/ko ya instalados en el Mac. Banco de 20 frases: 20/20, mediana 0,71 s. |
| Modelo de Apple: **tope de tokens** por tarea; muestreo *greedy* para limpiar y editar, temperatura 0,4 para responder | Sin tope, dictar "escribe un poema…" hacía que la IA escribiera el poema entero antes de que el filtro lo rechazara (máximo 3,5 s en el banco); con tope, máximo 1,2 s y 42/42 igual. Con respuestas largas el greedy entra en bucle (405 palabras, 40 distintas, 6 s); con temperatura 0,4 no. Editar con temperatura llegó a pasar un texto al portugués: por eso las ediciones siguen en greedy. |
| Clave de Gemini en el Llavero **a través de `/usr/bin/security`** | La app va firmada ad hoc y el Llavero ata cada entrada al hash de la compilación: tras recompilar, la API del Llavero la deniega (-25293) o pide la contraseña del Mac, incluso con acceso para "cualquier app" (probado). Las entradas que crea y lee `security` no preguntan nunca (probado con 3 recompilaciones; ~85 ms por lectura). La clave va por stdin en hexadecimal, nunca en los argumentos. |
| Cliente IA con formato **OpenAI-compatible** | Un único cliente sirve para Gemini (`https://generativelanguage.googleapis.com/v1beta/openai/`) y, cambiando URL/modelo, para Groq u Ollama sin código nuevo. |
| Captura de audio del sistema: **Core Audio process tap** (`AudioHardwareCreateProcessTap` + `CATapDescription`) en un dispositivo agregado privado cuyo reloj es la **salida interna del Mac** | Nativo desde macOS 14.2, sin drivers virtuales; compila con las CLT; funciona con AirPods y con altavoces (probado). El IOProc entrega el audio a la **frecuencia nominal del agregado**, no a la que anuncia el formato del tap (48 kHz): con AirPods en llamada llegaba a 24 kHz y la transcripción salía acelerada. Se lee la frecuencia nominal, se vigila si cambia y se convierte al formato del transcriptor (probado: palabra por palabra). Graba **todo** lo que suena en el Mac, música incluida. |
| Tiempos de las frases de reunión: `result.range` de `SpeechTranscriber` sobre un **reloj común** a las dos pistas | Cada búfer se sella con su hora de llegada; si llega con un hueco de más de 0,3 s se marca su inicio real (`AnalyzerInput(buffer:bufferStartTime:)`). Así "Tú" y "Otros" quedan alineadas (probado). |
| Captura del micro: **`AudioQueue` de solo entrada** con la entrada por defecto, abierta en segundo plano | Con AirPods, `AVAudioEngine` une su entrada (perfil de llamada, 24 kHz) y su salida (música, 48 kHz), que son dos dispositivos distintos, en un dispositivo agregado que no arranca: 0 muestras ("StartAndWaitForState returned error 3"), y `engine.start()` bloqueaba el hilo del teclado. Con `AudioQueue`, primer audio a los 0,25–0,54 s; `AVCaptureSession` también funciona (0,41 s) (probado). |
| Eco en reuniones: **se quita al final comparando las dos pistas** (`MeetingTranscript.removingEcho`), sin `setVoiceProcessingEnabled` | La cancelación de eco de Apple exige `AVAudioEngine`, que falla con AirPods (fila anterior); los AirPods en modo llamada ya la hacen. Con altavoces, el micro recoge la reunión entera y "Tú" la repetía (probado): se quita cada frase de "Tú" de 3 o más palabras que coincide en ±1,5 s con frases de "Otros" que contienen al menos el 60 % de sus palabras. |
| PDF: HTML propio → **impresión de WebKit a A4** (`WKWebView.printOperation` + `runModal` sobre una ventana fuera de pantalla) | `createPDF` da una sola página larga; la impresión pagina bien A4 con márgenes de 15 mm (probado: 6 páginas en 0,8 s). |
| Acta con Gemini: esquema JSON del §5.5 | Reunión sintética de 20 min: acta en ~5 s, 16–19 tareas, todas con su responsable y fecha, sin inventar (probado). Coste de la entrada: unos céntimos por hora de reunión. |
| Interfaz con **Liquid Glass** de macOS 26 (SwiftUI `glassEffect`, `GlassEffectContainer`), solo en **blanco, negro y transparente** | Estilo elegido por el usuario ("D"): piezas de cristal que se funden y se separan con animación al cambiar de estado. Los botones del sistema se ven apagados en un panel que no toma el foco: la tarjeta usa botones propios. |
| Tests: **Swift Testing** (`import Testing`) lanzados con `swift run sintecla-tests` | `Testing.framework` está en las CLT; XCTest no. `swift test` no ejecuta nada sin Xcode (probado); un ejecutable propio llama a `Testing.__swiftPMEntryPoint()`. |

---

## 3. Arquitectura

### 3.1 Flujo común a todos los modos

```
Atajo (HotkeyMonitor)
  → Captura de audio (AudioCapture [+ SystemAudioTap en reuniones])
  → Voz→texto en streaming (Transcriber, Apple, local)
  → Contexto (ContextReader: app activa, selección, diccionario, tono)
  → IA según modo (LLMRouter → AppleLLM | CloudLLM, con respaldos)
  → Salida (Output: pegar · reemplazar selección · tarjeta · abrir URL · PDF)
  → Historial (Store)
```

### 3.2 Módulos

| Módulo | Target | Responsabilidad | Tecnología |
|---|---|---|---|
| `HotkeyStateMachine` | Core | Lógica pura: eventos de teclado → acciones (empezar/terminar/cancelar, modo, pulsar vs mantener) | Swift puro |
| `EventTap` | App | Recibe `flagsChanged`/`keyDown` globales, alimenta la máquina de estados, se traga `Space`/`Esc` cuando corresponde | `CGEventTap` activo |
| `AudioCapture` | App | Micro → búferes PCM en el formato del transcriptor; ganancia +10 dB con limitador en modo susurro; pre-roll desde que se pulsa la tecla. En cada grabación, la entrada que macOS tenga en ese momento (Mac, AirPods…); se abre y se cierra en segundo plano | `AudioQueue` de solo entrada |
| `SystemAudioTap` | App | Audio de todas las apps excepto Sintecla (reuniones), convertido al formato del transcriptor aunque cambie la frecuencia | Core Audio process tap + aggregate device |
| `MeetingTrack` | App | Transcribe una pista de reunión y entrega cada frase con su inicio y su fin en el reloj de la reunión | `Speech` |
| `MeetingRecorder` | App | Graba una reunión (micro + sistema, dos `MeetingTrack`, audio m4a opcional) y, al parar, hace el acta, el Markdown y el PDF | Swift concurrency |
| `Transcriber` | App | Streaming a `SpeechAnalyzer`; resultados finales y volátiles; sesgo con diccionario | `Speech` |
| `RulesCleaner` | Core | Muletillas, arranques de relleno, repeticiones, autocorrecciones con marcador | Swift puro (regex + algoritmo de ancla) |
| `OutputGuard` | Core | Rechaza salidas de IA que inventan o cambian el sentido | Swift puro |
| `AppleLLM` | Core | Limpieza, edición, respuestas y notas sin conexión | `FoundationModels` |
| `AppleTranslator` | Core | Traducción local | `Translation` |
| `CloudLLM` | Core | Cliente OpenAI-compatible (chat completions, JSON schema, reintentos) | `URLSession` |
| `TranslationPipeline`, `AskPipeline`, `NotesOrganizer` | Core | Cada modo con su cadena de motores y respaldos | Swift puro |
| `PromptLibrary` | Core | Instrucciones por tarea + tono + diccionario | Swift puro |
| `IntentClassifier` | Core | Ask Anything: ¿editar, responder o abrir? (`TranslationCommand` reconoce "tradúcelo al…") | Reglas |
| `URLTemplates` | Core | Plantillas fijas de búsqueda web | Swift puro |
| `Chunker` | Core | Trocea por frases para no exceder 4.096 tokens | Swift puro |
| `Dictionary` | Core | Términos (sesgo STT + prompt) y reglas de reemplazo | Swift puro |
| `ToneProfile` | Core | bundle id → tono (formal/informal/técnico/neutro) y formato (Markdown o texto plano) | Swift puro |
| `HistoryStore` | Core | Historial JSONL, estadísticas | Swift puro |
| `MeetingTranscript`, `MeetingSummary`, `MeetingRenderer`, `MeetingSummarizer` | Core | Frases con tiempo (JSONL), quitar el eco, acta (Codable), Markdown y HTML, petición a Gemini | Swift puro |
| `MeetingStore` | Core | Una carpeta por reunión: ficha, transcripción que crece frase a frase, pendientes tras un cierre inesperado | Swift puro |
| `ContextReader` | App | App activa; texto seleccionado vía Accesibilidad con respaldo ⌘C; ¿es editable? | `NSWorkspace`, `AXUIElement` |
| `Paster` | App | Pegar con ⌘V preservando/restaurando el portapapeles | `NSPasteboard`, `CGEvent` |
| `Overlay` | App | Pastilla flotante de cristal (modo, onda, estado, cronómetro) | `NSPanel` no activante + SwiftUI (`GlassEffectContainer`) |
| `AskCard` | App | Tarjeta de respuesta de cristal con Copiar / Insertar / ✕ | `NSPanel` + SwiftUI |
| `PDFRenderer` | App | HTML del acta → PDF A4 paginado | `WKWebView.printOperation` |
| `MenuBar`, `MainWindow` (Reuniones, Historial y Ajustes), `Onboarding` | App | Interfaz | AppKit + SwiftUI |
| `LoginItem` | App | Arranque al iniciar sesión | `SMAppService.mainApp` |
| `Keychain` | App | Clave API de Gemini | `/usr/bin/security` |
| `DictationController` + `ModeRunner` | App | Orquestan cada modo (Dictado, Traducción, Ask, Notas, Reunión) | Swift concurrency |

### 3.3 Estructura del proyecto

```
Package.swift                    # swift-tools-version 6.2, platforms: .macOS("26.0"), sin dependencias externas
Sources/
  SinteclaCore/                  # lógica sin AppKit (incluye AppleLLM y CloudLLM)
  Sintecla/                      # ejecutable de la app (AppKit, audio, UI)
  sintecla-eval/                 # CLI del banco de calidad
  SinteclaCoreTests/             # tests (Swift Testing) en una librería normal
  sintecla-tests/                # ejecutable que lanza los tests
Resources/
  Info.plist
  AppIcon.icns
  eval/dictado_es.json           # banco de frases
  eval/reunion_20min.jsonl       # reunión sintética para probar el acta
scripts/
  build-app.sh                   # compila, empaqueta, firma, instala en /Applications
docs/superpowers/specs/          # esta especificación
```

---

## 4. Atajos y máquina de estados

### 4.1 Mapa de atajos (tecla base = `Fn`/🌐 por defecto)

Valores por defecto. Desde la F4c, la tecla que acompaña a la base en Traducción, Ask, Notas y Reunión se elige en Ajustes → General (ver `2026-09-24-editor-de-atajos-design.md`).

| Atajo | Modo | Semántica |
|---|---|---|
| `Fn` mantener | Dictado | Graba mientras se mantiene; al soltar termina y pega |
| `Fn` pulsar | Dictado manos libres | Pulsación inicia; otra pulsación de `Fn` termina y pega |
| `Fn + ⇧` | Traducción | Igual que dictado (mantener o pulsar) |
| `Fn + Space` | Ask Anything | Igual que dictado; `Space` no llega a la app |
| `Fn + ⌃` | Notas | Igual que dictado (pensado para manos libres) |
| `Fn + ⌥` | Reunión | Conmutador: pulsar inicia, pulsar de nuevo detiene. También desde el menú |
| `Esc` | Cancelar | Durante una grabación (no reunión): descarta. `Esc` no llega a la app |

**Tecla base alternativa** (Ajustes → General) para teclados externos que no mandan su Fn al Mac (p. ej. algunos Logitech: su descriptor HID no la declara): **⌥ derecha**, o **las dos** (🌐 o ⌥ derecha: manda la primera que se pulse y, mientras sigue abajo, la otra es un modificador normal). Con ⌥ derecha: Traducción `⌥der + ⇧`, Ask `⌥der + Space`, Notas `⌥der + ⌃`, Reunión `⌥der + ⌘`. Con las dos, la Reunión es `🌐 + ⌥` o `⌥der + ⌘`.

### 4.2 Reglas de detección
- **Pulsar**: la tecla base se suelta antes de **0,30 s** sin otra tecla entre medias.
- **Mantener**: la tecla base sigue pulsada a los **0,30 s**.
- El **modo** se decide por los modificadores (`⇧`, `⌃`, `⌥`/`⌘`) activos o por `Space` pulsado mientras la base está abajo, en el instante de pasar a grabación.
- **Pre-roll**: el micro arranca al pulsar la base (estado *armado*) para no perder la primera sílaba; si se cancela, el audio se descarta.
- **No estorbar**: si con la base pulsada (armado o grabando en modo mantener) se pulsa **cualquier otra tecla** que no sea `Space`/`⇧`/`⌃`/`⌥`/`⌘`, se cancela en silencio y la tecla pasa a la app (así funcionan `Fn+←`, `Fn+Supr`, `⌥der+2` = `@`).
- En manos libres, las teclas normales pasan sin cancelar; una pulsación de la tecla base (con o sin modificadores) termina y `Esc` cancela.
- El atajo de Reunión es un conmutador que actúa al soltar la tecla base, tanto si fue pulsación como si se mantuvo.
- Mientras se procesa un resultado, los atajos se ignoran con un aviso sonoro breve.
- Durante una reunión, los demás modos están desactivados (el micro está en uso); el overlay lo indica.

### 4.3 Estados
`reposo` → (base abajo) → `armado` → (soltar < 0,30 s) → `grabando(manosLibres)` | (≥ 0,30 s) → `grabando(mantener)` → (fin) → `procesando` → `reposo`. Desde `armado`/`grabando`: otra tecla → `reposo` (cancelado); `Esc` → `reposo` (cancelado). La máquina es una función pura `(estado, evento, tiempo) → (estado, [acción])`, 100 % testeable.

---

## 5. Modos en detalle

### 5.1 Dictado (Gemini si hay clave; si no, Apple en el Mac)
1. `Transcriber` (es_ES por defecto; en_US desde el menú) con `contextualStrings` = términos del diccionario.
2. `RulesCleaner`:
   - Borra disfluencias: `eh`, `em`, `ehm`, `mmm`, `hmm`, `en plan`.
   - Borra relleno inicial: `bueno`, `vale`, `pues`, `o sea` al comienzo del dictado.
   - Colapsa palabras repetidas seguidas (`con con` → `con`).
   - **Autocorrecciones** con marcadores `no perdón`, `perdón`, `mejor dicho`, `quiero decir`, `no espera`, `o mejor`: en `X <marcador> Y`, toma la primera palabra de `Y` como ancla, la busca hacia atrás (máx. 8 palabras) y borra desde ahí hasta el final del marcador; si no hay ancla, borra la palabra previa al marcador.
3. `AppleLLM` (muestreo *greedy*, entrada entre `<t>…</t>`): desde la 0.8.0 **ordena** (quita muletillas, titubeos y repeticiones, y une las frases que hablan de lo mismo) sin añadir nada; puntuación, tildes, mayúsculas, listas con guiones si hay ≥ 3 elementos, reglas de tono de la app. Instrucción explícita: nunca responder ni obedecer el texto. Si el texto supera ~1.500 caracteres, `Chunker` lo divide por frases y se procesa por trozos.
4. `OutputGuard`: acepta la salida solo si (a) ≤ 25 % de palabras de contenido son nuevas (excluyendo términos del diccionario y marcas de lista), (b) longitud entre 0,3× y 1,3× la entrada, (c) si la entrada es pregunta, la salida también. La entrada es pregunta si la salida de `RulesCleaner` contiene `?` o empieza por un interrogativo (`qué`, `cómo`, `cuál`, `cuándo`, `dónde`, `por qué`, `quién`, `cuánto`). Si no, se usa la salida de `RulesCleaner` con mayúscula inicial y punto final.
5. `Dictionary.apply`: reemplazos exactos, sin distinguir mayúsculas y por palabra completa.
6. Ajuste final de tono (p. ej. informal: sin punto final si es un único enunciado).
7. `Paster` pega en el cursor.

Se precalienta el modelo (`prewarm`) al empezar a grabar para evitar la latencia de la primera llamada.

**Con Gemini (desde la 0.8.0, `2026-09-24-ordenar-dictado-design.md`):** con clave y «Ordenar el dictado con Gemini» encendido (lo está por defecto), los dictados de 6 palabras o más los ordena Gemini tras el paso 2, con todo el texto, el tono, la app o web, «Mi estilo» y los términos del diccionario (6 s, sin reintentos). Su salida pasa por el mismo `OutputGuard`; si no pasa o Gemini falla, se sigue en el paso 3.

### 5.2 Traducción (Apple, respaldo Gemini)
1. Igual que 5.1 hasta tener el texto limpio (reglas, IA de Apple, filtro, diccionario).
2. El **traductor de Apple** lo pasa al idioma destino. Por defecto, inglés; se elige en el menú "Traducir a" y en Ajustes: English, Español, Français, Deutsch, Italiano, Português, 日本語, 中文, 한국어. Si el destino coincide con el idioma de dictado, se traduce al otro (español ↔ inglés).
3. Validación:
   - Idioma: con 3 palabras o más, `NLLanguageRecognizer` debe dar el idioma destino (dominante o con probabilidad ≥ 0,3). Con menos palabras no se comprueba: no es fiable ("Hello Ana" sale turco).
   - Longitud entre 0,5× y 2,0× la del texto limpio (±8 caracteres).
   - Si el original era pregunta, la traducción también.
4. Si la validación falla → Gemini, con la instrucción de traducir sin responder. Si Gemini tampoco sirve → se pega el texto limpio sin traducir y la pastilla avisa.
5. Al final se restaura la grafía de los términos del diccionario y se aplica el ajuste de tono.

### 5.3 Ask Anything (`Fn + Space`)
1. Al empezar a grabar, `ContextReader` lee la selección: `kAXSelectedTextAttribute` del elemento enfocado; si está vacío o no disponible, respaldo con `⌘C` (se guarda el portapapeles, se comprueba `changeCount`, se restaura). También determina si la selección es **editable** (rol `AXTextField`/`AXTextArea`/`AXComboBox`/`AXSearchField` o `AXValue` modificable). Si no se puede saber, se asume editable.
2. `IntentClassifier` (reglas) sobre lo dictado:
   - **Pregunta**: termina en `?`, empieza por interrogativo (`qué`, `cómo`, `cuál`, `cuándo`, `dónde`, `por qué`, `quién`, `cuánto`) o contiene `explica`, `qué significa`, `de qué va`.
   - **Acción web**: sin selección y empieza por `busca`, `búscame`, `abre`, `pon`, `enséñame` o `muéstrame`. Gemini extrae `{sitio, consulta}`; si el sitio no está en las plantillas, se usa Google.
   - **Orden de edición**: el resto.
3. Enrutado:

| Selección | Intención | Motor | Salida |
|---|---|---|---|
| cualquiera | "tradúcelo al {idioma}" | Traductor de Apple (si falla, como el resto de órdenes) | Reemplaza la selección si es editable; si no, tarjeta |
| editable | orden de edición | Apple (respaldo Gemini si > 2.500 caracteres o falla) | **Reemplaza la selección** (pegar) |
| editable | pregunta | Gemini (sin clave o sin red: Apple, "respuesta local") | Tarjeta |
| no editable | cualquiera | Gemini (sin clave o sin red: Apple, "respuesta local") | Tarjeta |
| ninguna | pregunta u otra orden ("escribe un correo a…") | Gemini (sin clave o sin red: Apple, "respuesta local") | Tarjeta (con "Insertar") |
| ninguna | acción web | Gemini (JSON `{sitio, consulta}`); sin Gemini, reglas | Abre URL |

4. **Plantillas de URL** (únicas permitidas; la consulta va codificada con percent-encoding): Google `https://www.google.com/search?q=`, YouTube `https://www.youtube.com/results?search_query=`, Amazon `https://www.amazon.es/s?k=`, Maps `https://www.google.com/maps/search/`, Wikipedia `https://es.wikipedia.org/w/index.php?search=`. Si el sitio no es uno de estos → Google.
5. **Tarjeta**: panel flotante no activante, abajo al centro; texto en Markdown; botones Copiar, Insertar (pega en el cursor) y ✕; `Esc` la cierra. Sin conexión: responde Apple con la etiqueta "respuesta local".

Las ediciones son del **texto seleccionado**: el texto nuevo sustituye a la selección al pegar. Como una edición puede introducir palabras nuevas legítimamente, su filtro es distinto al del dictado.

- **Limpieza de la salida:** quita bloques ```, comillas envolventes, etiquetas `<texto>` y frases de entrada tipo "Aquí tienes…:".
- **Rechazo** si la salida:
  - está vacía o es idéntica a la selección (el modelo no hizo nada, como en "tutéale");
  - trae huecos tipo "[Tu nombre]" que no estaban;
  - mide menos que el menor de 0,2× y 20 caracteres, o más de 3,0× + 200 caracteres (un resumen de un texto largo puede quedar muy por debajo de 0,2×);
  - cambia de idioma con detección segura (≥ 0,8 en los dos textos), salvo que la orden nombre un idioma.
- Si se rechaza, se reintenta con Gemini; si tampoco vale, se muestra el error en la tarjeta sin tocar la selección.

El modelo de Apple edita con muestreo greedy y un tope de tokens igual a la longitud de la selección + 200. En las pruebas hizo bien 9 de 12 órdenes y las otras 3 las rechazó el filtro. Sin Gemini responde en local con temperatura 0,4 y como mucho 500 tokens, y la tarjeta lo indica con la etiqueta "respuesta local".

Selección por Accesibilidad con un tiempo máximo de 0,5 s por consulta. Si el elemento enfocado es un cuadro de texto y la selección está vacía, no se usa ⌘C, que sin selección suena a error.

### 5.4 Notas (`Fn + ⌃`, Gemini)
- Grabación larga; el overlay muestra cronómetro y las últimas palabras reconocidas.
- Cada resultado final de la transcripción se añade a un **borrador en disco** (`drafts/<uuid>.txt`) para no perder nada.
- Al terminar: `RulesCleaner` → Gemini con instrucción de organizar **sin inventar**, con secciones (solo las que tengan contenido): **Resumen** (2–3 frases), **Ideas clave** (agrupadas por tema), **Tareas**, **Pendiente de decidir**.
- Formato según la app de destino: **Markdown** en apps Markdown (tono técnico + Obsidian, Notion, Bear); **texto plano** con títulos terminados en `:` y viñetas `•` en el resto.
- Se pega en el cursor y **el resultado se queda en el portapapeles** (no se restaura el anterior) y en el historial. El borrador se borra tras el éxito.
- Gemini devuelve JSON (`resumen`, `ideas[{tema, puntos}]`, `tareas`, `pendiente`), que Sintecla convierte al formato de la app. Así el formato no depende del modelo.
- Sin conexión o error: `AppleLLM` saca viñetas de cada trozo de ~2.000 caracteres, quita las repetidas y las pega bajo "Ideas clave". El aviso de la pastilla es "Resumen local · {motivo}". En las pruebas tardó 4,1 s con 2 minutos de voz y 8,5 s con 6. No se hace organización final: con esquema, el modelo local entró en bucle hasta llenar el contexto (51 s); sin esquema, los "resúmenes" copiaban la primera viñeta. Sin ninguna IA, se pega la transcripción limpia.
- El formato se decide con la app activa **al terminar** (puedes cambiar de app mientras hablas).
- Si se cancela con `Esc`, un borrador con texto se conserva: aparece en el menú "Notas sin procesar (N)…", que abre la carpeta.

### 5.5 Reunión (`Fn + ⌥`, menú o ventana, Gemini) — Fase 3
- **Fuentes**: micro = pista **"Tú"**; audio del sistema (todas las apps salvo Sintecla, también la música) = pista **"Otros"**. Cada pista tiene su `MeetingTrack` con el idioma de dictado, y las dos van al mismo reloj.
- **Indicador**: la pastilla se queda abajo durante toda la reunión, con el icono de grabar en su gota de cristal y, en la cápsula, la onda, el cronómetro y la última frase oída. El menú cambia a "■ Detener reunión (N min)". Sin rojo: todo en blanco, negro y transparente.
- **Persistencia continua**: `~/Library/Application Support/Sintecla/meetings/<id>/` con `meeting.json` (estado, duración, título, tareas, rutas) y `transcript.jsonl` con `{t, fin, pista, texto}` por frase, escrita al momento. Audio opcional (Ajustes → General → Reuniones, activado por defecto): `mic.m4a` y `sistema.m4a` (AAC mono, 16 kHz, 32 kbps: ~15 MB/h por pista).
- **Al detener**: la pastilla pasa a "Preparando el acta…"; se ordenan las frases por tiempo y se quita el eco (§2) → Gemini con salida JSON según este esquema:
  ```json
  {"titulo": "", "participantes": [""], "resumen": "",
   "temas": [{"titulo": "", "puntos": [""]}],
   "decisiones": [""],
   "tareas": [{"responsable": "", "tarea": "", "fecha": ""}],
   "dudas": [""], "proximos_pasos": [""]}
  ```
  → `MeetingSummary` → HTML con plantilla propia en blanco y negro (cabecera con fecha y duración, secciones con contenido, tabla de tareas y, en otra página, el **anexo con la transcripción** con marcas de tiempo y "Tú"/"Otros") → PDF A4.
- **Salida**: `~/Documents/Sintecla/Reuniones/AAAA-MM-DD HHmm – <título>.pdf` y `.md`; se abre el PDF, se copia el acta en Markdown al portapapeles y aparece una notificación "Acta lista".
- **Lista de reuniones** (ventana Sintecla → Reuniones): cada una con su estado (grabando, preparando, lista, pendiente), duración y número de tareas; doble clic abre el PDF; menú contextual para abrir el PDF o el Markdown, mostrar en el Finder o borrar.
- **Sin conexión, sin clave o error de Gemini**: la reunión queda *pendiente* con el motivo; "Reintentar" en la lista o en el menú "Reuniones pendientes (N)…". Si Sintecla se cierra a mitad, al abrirse la reunión queda pendiente con lo transcrito hasta entonces. Si no se oyó nada, no hay acta y se borra la carpeta.
- **Durante la reunión** los demás modos están desactivados: el atajo avisa "Reunión en curso".
- **Aviso legal** en el primer uso: informar a los participantes de la grabación (RGPD en contexto de empresa). Hay que aceptarlo para grabar.

---

## 6. Tono por app y diccionario

**Tonos (lista editable; valores iniciales por bundle id, verificados al implementar):**

| Tono | Apps iniciales | Reglas |
|---|---|---|
| Formal | Mail, Outlook, Word, Pages, Spark | Puntuación completa, párrafos, saludo/despedida en línea propia, sin emojis |
| Informal | WhatsApp, Telegram, Mensajes, Slack, Discord | Puntuación ligera, sin punto final si es un único enunciado |
| Técnico | VS Code, Cursor, Terminal, iTerm2, Warp | Términos técnicos e identificadores literales, listas Markdown |
| Prompt para IA (desde la 0.8.0) | Claude, ChatGPT, Codex; en Safari claude.ai, chatgpt.com, gemini.google.com | Lo que se pide primero, luego el contexto y los requisitos en lista con etiqueta corta, sin añadir nada (ver `2026-09-25-tono-prompt-design.md`) |
| Neutro | resto | Estándar |

Desde la F4b, en Safari el tono sale del dominio de la pestaña (Gmail formal, WhatsApp Web informal…), con su propia lista editable (ver `2026-09-24-tono-por-web-design.md`).

Campo libre **"Mi estilo"** (p. ej. "tuteo, sin emojis") que se añade a las instrucciones de edición y notas.

**Diccionario:** lista de términos (`Brisenta`, `Supabase`…) y reglas `origen → destino` (`bri senta → Brisenta`). Se usa en tres sitios: sesgo del reconocimiento de voz (`contextualStrings`; en la práctica `SpeechTranscriber` apenas lo tiene en cuenta), corrección aproximada de palabras que no existen (`fuzzyFix` con el corrector ortográfico del sistema: "brosanta" → "Brisenta", pero "brisa" se queda) y reemplazos exactos antes y después de la IA. No va en las instrucciones de la IA: el modelo local lo ignora (probado). Desde la F4a el diccionario también aprende de las correcciones que haces después de pegar (ver `2026-09-24-aprende-de-ti-design.md`).

---

## 7. Interfaz

- **Estilo**: Liquid Glass de macOS 26, variante "D": cada pieza (icono, cápsula, botones) es una gota de cristal que se funde con las demás o se separa con animación de muelle al cambiar de estado. Solo blanco, negro y transparente; tipografía redondeada.
- **Barra de menú** (icono: la «onda que escribe» del icono de la app, en reposo / grabando, sin color; ver `2026-09-24-icono-design.md`): Estado · Micrófono en uso (el que elige macOS; solo informativo) · Idioma de dictado (es/en) · Modo susurro ✓ · Traducir a ▸ · ● Grabar reunión / ■ Detener reunión (N min) · Reuniones pendientes (N)… (solo si hay) · Pegar último resultado · Notas sin procesar (N)… (solo si hay) · Abrir Sintecla… (⌘O) · Historial… · Ajustes… (⌘,) · Permisos… · Salir. Historial y Ajustes abren su sección de la ventana Sintecla.
- **Overlay**: abajo al centro; el icono del modo en su gota de cristal y, al lado, una cápsula con las barras de nivel, el cronómetro (notas y reuniones) y el estado. Al procesar, la gota muestra un indicador de progreso; al terminar la cápsula se funde en la gota con ✓. Mensaje de error 2 s. Sonidos de inicio/fin desactivables.
- **Tarjeta de Ask Anything**: una sola lámina de cristal con el icono, el título, la pregunta entendida («…») en pequeño, el texto con desplazamiento y los botones propios Copiar / Insertar / ✕.
- **Ventana Sintecla** (menú "Abrir Sintecla…"): barra lateral de cristal con **Reuniones** (lista y botón «Grabar reunión»), **Historial**, **Estadísticas** y **Ajustes**: General (inicio de sesión, sonidos, susurro, idioma de dictado, "Traducir a", tecla base, editor de atajos y, en Reuniones, "Guardar el audio") · Diccionario · Tonos · IA (clave de Gemini con Guardar/Borrar —se guarda en el Llavero—, modelo configurable —por defecto `gemini-3.5-flash-lite`—, "Probar conexión", "Mi estilo"). Con la ventana abierta, Sintecla sale en el Dock y tiene menú Edición (⌘C/⌘V en los campos). Los permisos siguen en el asistente ("Permisos…" en el menú).
- **Historial**: buscador, lista con fecha/modo/app/texto, botón Copiar.
- **Estadísticas** (desde la 0.7.0): cifras, gráfica y reparto por app y por modo, con un resumen por día que no se recorta (ver `2026-09-24-estadisticas-design.md`).
- **Asistente de primer arranque**: comprueba permisos con ✓/✗ y botones a cada panel de Ajustes del Sistema; comprueba la tecla 🌐 ("No hacer nada") y avisa si Typeless está abierto.

---

## 8. Datos y almacenamiento

| Dato | Dónde |
|---|---|
| Ajustes simples | `UserDefaults` (dominio `local.sintecla.app`) |
| Diccionario, tonos | `~/Library/Application Support/Sintecla/dictionary.json`, `tones.json` |
| Historial | `…/Sintecla/history.jsonl` (máx. 500 entradas, se compacta al arrancar) |
| Estadísticas | `…/Sintecla/stats.json` (resumen por día, solo números; no se recorta) |
| Entrada de historial | `{id, fecha, modo, appBundleId, appNombre, idioma, segundosAudio, textoCrudo, textoFinal, palabras, motor (apple/reglas/gemini), latenciaMs}` |
| Borradores de notas | `…/Sintecla/drafts/<uuid>.txt` |
| Reuniones (trabajo) | `…/Sintecla/meetings/<id>/`: `meeting.json`, `transcript.jsonl` y, si se guarda el audio, `mic.m4a` y `sistema.m4a` |
| Actas | `~/Documents/Sintecla/Reuniones/` (PDF y Markdown) |
| Clave API Gemini | Llavero (servicio `local.sintecla.app`, cuenta `gemini`), leída y escrita con `/usr/bin/security` |

El audio de dictado y notas **nunca se guarda**; el de las reuniones solo si está activado "Guardar el audio". Al pegar, el contenido temporal del portapapeles se marca con `org.nspasteboard.TransientType` y `org.nspasteboard.ConcealedType` para que los gestores de portapapeles lo ignoren.

---

## 9. Errores y respaldos

**Principio: nunca se pierde lo dictado.**

| Situación | Comportamiento |
|---|---|
| Silencio / transcripción vacía | Overlay "No te he oído"; no pega |
| Apple Intelligence desactivado o modelo no disponible | Dictado con solo `RulesCleaner` + diccionario; aviso único en el overlay |
| Error, rechazo (*guardrail*) o salida rechazada por `OutputGuard` | Salida de `RulesCleaner` |
| Gemini falla al ordenar el dictado | Lo ordena Apple; la pastilla avisa «Limpieza local · <motivo>» |
| Texto > contexto de Apple | `Chunker` por frases |
| Gemini: sin red, 401, 429, 5xx, tiempo agotado (30 s; 120 s en notas/reuniones) | 2 reintentos con espera exponencial en 429/5xx; luego respaldo según modo (§5) |
| Sin clave de Gemini | Ask Anything y notas usan Apple con aviso; reuniones quedan pendientes |
| No hay cuadro de texto | Se pega igualmente; historial + "Pegar último resultado" (notas y reuniones también en portapapeles) |
| Permiso retirado | Overlay con botón al asistente de permisos |
| Typeless abierto | Aviso con botón "Cerrar Typeless" |
| Fallo al leer la selección | Ask Anything sin selección |
| Reunión sin nada transcrito | "No se oyó nada: no hay acta"; se borra la carpeta |
| Sintecla se cierra durante una reunión | Al abrirse, la reunión queda pendiente con lo ya transcrito; "Reintentar" hace el acta |

---

## 10. Permisos, firma e instalación

- **Info.plist**: `CFBundleIdentifier = local.sintecla.app`, `LSUIElement = true` (sin icono en el Dock), `LSMinimumSystemVersion = 26.0`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSAudioCaptureUsageDescription`.
- **Permisos TCC**: Micrófono, Accesibilidad (tap de teclado activo, ⌘V/⌘C sintéticos, lectura de selección), Monitorización de entrada si macOS la exige para el tap, Grabación de audio del sistema (solo reuniones).
- **Firma estable**: firma ad-hoc con requisito fijo (`designated => identifier "local.sintecla.app"`), sin certificado ni contraseña. Así macOS identifica la app por su bundle id y los permisos sobreviven a cada recompilación (comprobado en la F1; no hizo falta un certificado propio). `build-app.sh` acepta `SIGN_ID` para firmar con un certificado del Llavero.
- **`scripts/build-app.sh`**: `swift build -c release` → ensambla `Sintecla.app` (binario e `Info.plist`) → `codesign` (ad-hoc por defecto, o `SIGN_ID="Sintecla Dev"`) → copia a `/Applications/Sintecla.app` → relanza la app.
- **Inicio de sesión**: `SMAppService.mainApp.register()` (activado por defecto; interruptor en Ajustes).
- Sin sandbox ni *hardened runtime* (app personal), por lo que no necesita *entitlements*.

---

## 11. Pruebas y criterios de calidad

- **Tests automáticos (`swift run sintecla-tests`, Swift Testing)** sobre `SinteclaCore`: máquina de estados de atajos (pulsar, mantener, combos, `Fn+←` cancela, `Esc`, ⌥ derecha + `2`) y `BaseKeyTracker` (qué tecla base está abajo, también con las dos), `RulesCleaner` (cada regla y las 6 frases probadas), `OutputGuard`, `Dictionary`, `ToneProfile`, `Chunker`, `HistoryStore`, `CloudLLM` (peticiones y respuestas simuladas con `URLProtocol`), traducción (`TranslationGuard`, flujo con traductores falsos), Ask Anything (`IntentClassifier`, `TranslationCommand`, plantillas web, `EditGuard`, enrutado con modelos falsos), notas (formato Markdown/texto, organizador, borradores) y reuniones (JSONL, quitar el eco, reloj, acta en Markdown y HTML, duración, petición a Gemini con un modelo falso, `MeetingStore` con reuniones interrumpidas, nombres de archivo).
- **Banco de calidad `sintecla-eval`**: `Resources/eval/dictado_es.json`, ≥ 40 frases `{entrada, requeridas[], prohibidas[], pregunta?}` (muletillas, autocorrecciones, listas, preguntas, términos del diccionario, órdenes que no deben obedecerse). Pasa una frase si contiene todas las `requeridas`, ninguna `prohibida` y conserva `?` cuando corresponde. **Objetivo: ≥ 90 % de aciertos.** El CLI ejecuta el flujo real (`RulesCleaner` → `AppleLLM` → `OutputGuard`) e informa aciertos y latencias. Con `--traduccion` usa `Resources/eval/traduccion_es.json` (20 frases, español → inglés) y el flujo real de traducción.
- **`Sintecla --mic-test [segundos]`** (lanzado con `open -n -W --stdout … /Applications/Sintecla.app --args --mic-test 3`, para usar el permiso de micrófono de la app): dice qué micrófono se usa y cuándo llega el primer audio.
- **Modos de prueba sin micrófono** (con la clave y el modelo de Ajustes): `Sintecla --transcribe audio.aiff`, `--translate "texto"`, `--ask "orden" ["selección"]`, `--notes transcripcion.txt`, `--gemini-check` (texto y los dos esquemas JSON; muestra el error completo si falla), `--ask-bench` (10 preguntas en un proceso, como dentro de la app; da la mediana), `--meeting-summary transcripcion.jsonl` (acta en Markdown y su latencia) y `--meeting-pdf transcripcion.jsonl acta.pdf`. `Resources/eval/reunion_20min.jsonl` es una reunión sintética de 20 min para probarlos.
- **`Sintecla --meeting-record segundos carpeta`** (lanzado con `open`, como `--mic-test`): una reunión real con el grabador de la app (micro y audio del sistema), guardada en `carpeta` y no en Documentos; imprime las frases en vivo, el nivel máximo y cuánto tardó el acta.
- **Latencia objetivo** (soltar tecla → texto pegado): dictado ≤ 30 s de voz, mediana ≤ 1,0 s; Ask con Gemini mediana ≤ 2,5 s; notas de 10 min ≤ 8 s.
- **Checklist manual por fase**: dictar en Notas, Mail, Slack, WhatsApp, Chrome, VS Code; `Fn+←` sigue funcionando; traducir; Ask con selección editable, de una web y sin selección; acción "busca X en YouTube"; notas de 5 min; reunión de prueba en Zoom/Discord con PDF; reiniciar el Mac y comprobar que arranca sola.

---

## 12. Fases de entrega

Cada fase tiene su propio plan de implementación y se entrega funcionando antes de empezar la siguiente.

| Fase | Contenido | Hecho cuando |
|---|---|---|
| **F1 — Núcleo de dictado** | Proyecto SwiftPM, scripts de firma/compilación/instalación, barra de menú, asistente de permisos, `EventTap` + máquina de estados (incl. tecla base ⌥ derecha), `AudioCapture` (pre-roll, susurro), `Transcriber` es/en, `RulesCleaner` + `AppleLLM` + `OutputGuard`, diccionario, tonos por app, `Paster`, overlay y sonidos, historial + estadísticas + "Pegar último resultado", inicio de sesión, tests, `sintecla-eval` | Tests en verde, eval ≥ 90 %, checklist F1 superado, arranca solo tras reiniciar |
| **F2 — Traducción, Ask Anything y Notas** | `CloudLLM` (Gemini) + Llavero + pestaña IA, traducción (traductor de Apple), `ContextReader` (selección + editable), `IntentClassifier`, edición, tarjeta, acciones web, notas con borrador y respaldo local | Tests en verde, bancos de dictado y traducción ≥ 90 %, `--gemini-check` en verde, Ask con Gemini mediana ≤ 2,5 s, notas de 10 min ≤ 8 s, checklist F2 superado |
| **F3 — Reuniones** | `SystemAudioTap`, doble transcriptor con reloj común, eco quitado al final, persistencia continua, esquema JSON, acta en Markdown y PDF A4, audio opcional, pendientes/reintento, aviso legal; ventana Sintecla (Reuniones, Historial, Ajustes) y estilo Liquid Glass en blanco y negro | Tests en verde, `--meeting-record` en verde, reunión de prueba de ≥ 20 min → PDF correcto |
| **F3b — Grabadora portátil** | Aparato M5Stack CoreS3 que graba reuniones y charlas fuera del Mac; Sintecla las importa por USB-C (v2: Wi-Fi) y hace el acta con voces (Gemini). Ver `docs/superpowers/specs/2026-09-23-grabadora-design.md` | Se especifica aparte (arquitectura aprobada) |
| **F4a — Aprende de ti** | Diccionario que aprende de tus correcciones (automático tras pegar y a mano) y "Mi estilo" sacado del historial con Gemini. Ver `docs/superpowers/specs/2026-09-24-aprende-de-ti-design.md` | Tests en verde y aceptación a mano de ese diseño (§5) |
| **F4b — Tono por web** | En Safari, tono según el dominio de la pestaña (Gmail, WhatsApp Web…), lista editable en Tonos. Ver `docs/superpowers/specs/2026-09-24-tono-por-web-design.md` | Tests en verde y aceptación a mano de ese diseño (§7) |
| **Icono (0.5.1)** | Icono de la app «onda que escribe» en claro y el mismo dibujo en la barra de menú. Ver `docs/superpowers/specs/2026-09-24-icono-design.md` | Tests en verde y aceptación a mano de ese diseño (§6) |
| **Estadísticas (0.7.0)** | Resumen por día que no se recorta, cifras (hoy, racha, tiempo ahorrado, mejor día), gráfica y reparto por app y por modo. Ver `docs/superpowers/specs/2026-09-24-estadisticas-design.md` | Tests en verde y aceptación a mano de ese diseño (§9) |
| **F4c — Editor de atajos** | Elegir la tecla que acompaña a la base en cada modo (⇧, ⌃, ⌥, ⌘ o Espacio), sin repetir. Ver `docs/superpowers/specs/2026-09-24-editor-de-atajos-design.md` | Tests en verde y aceptación a mano de ese diseño (§8) |
| **F4 — Extras** | Identificación de hablantes (junto con la F3b) | Se especifica aparte |

---

## 13. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Teclado externo sin 🌐 visible para macOS | Tecla base ⌥ derecha, o «las dos» (🌐 en el Mac y ⌥ derecha en el externo) |
| macOS usa la tecla 🌐 (emojis/dictado/fuente de entrada) | El asistente pide "No hacer nada" y detecta el valor actual |
| Selección ilegible por Accesibilidad (apps Electron) | Respaldo ⌘C |
| Calidad de limpieza en frases no vistas | Banco `sintecla-eval` ampliable con tus frases; reglas y prompt ajustables; el guard evita invenciones |
| Gemini retira o limita un modelo | Ya pasó con `gemini-2.5-flash-lite` (acceso limitado a usuarios antiguos): ID configurable en Ajustes → IA; por defecto `gemini-3.5-flash-lite` (alternativa más barata y el doble de lenta: `gemini-3.1-flash-lite`) |
| El Llavero pide la contraseña tras cada recompilación | Clave leída y escrita con `/usr/bin/security` (entradas sin diálogo) |
| Gemini devuelve a veces caracteres con doble codificación ("dÃ­a"; 1 de cada ~40 notas) | `CloudTextModel` repara esas secuencias en el texto y dentro del JSON |
| Gemini rechaza el esquema JSON (compatibilidad OpenAI en beta) | `--gemini-check` lo detecta; notas y acciones web siguen funcionando con sus respaldos locales |
| Permisos perdidos al recompilar | Firma ad-hoc con requisito fijo; respaldo con certificado "Sintecla Dev" |
| Eco en reuniones con altavoces | Se quita al final comparando las dos pistas; mejor con auriculares |
| El audio del sistema incluye todo lo que suena (música, avisos) | Pausar la música durante la reunión; lo que no se dice en la reunión apenas afecta al acta |
| La frecuencia del agregado cambia a mitad (AirPods que pasan a modo llamada) | Se vigila la frecuencia nominal y se rehace el conversor |
| Con Bluetooth el micro tarda en abrirse (cambio a perfil de llamada) | El audio llega 0,25–0,5 s después de pulsar: conviene empezar a hablar tras medio segundo. Captura en segundo plano para no retrasar el teclado |
| Entrada segura (campos de contraseña) desactiva el tap | Comportamiento esperado de macOS; no se dicta en contraseñas |
