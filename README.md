# Sintecla

Dictado por voz para macOS. Mantén pulsada la tecla 🌐, habla y suelta: el texto aparece limpio y ordenado donde tengas el cursor, en cualquier app. La voz se transcribe en tu Mac, sin límite de palabras; el texto lo ordena Gemini si pones una clave, o Apple Intelligence en tu Mac si no.

Inspirada en [Typeless](https://typeless.com); no tiene relación con ella. La app está en español (y dicta también en inglés).

## Qué hace

| | |
|---|---|
| **Dictado** | Quita muletillas y repeticiones, ordena las ideas aunque las digas dos veces, entiende las autocorrecciones («a las cinco, no perdón, a las seis»), pone puntuación y listas. El tono se adapta a la app (formal en Mail, informal en WhatsApp, prompt ordenado en Claude o ChatGPT…) y, en Safari, a la web (Gmail, WhatsApp Web, claude.ai…). |
| **Traducción** | Hablas en español y pega en inglés (u otro idioma). |
| **Ask Anything** | Con texto seleccionado: «hazlo más formal», «resúmelo»… Sin selección: preguntas rápidas o «busca X en YouTube». |
| **Notas** | Una nota de voz larga, organizada en resumen, ideas y tareas. |
| **Reuniones** | Graba tu micro y el audio del Mac, transcribe las dos pistas y te deja el acta en PDF. |
| **Aprende de ti** | El diccionario aprende las palabras que corriges después de pegar; «Mi estilo» se saca de tu historial. |
| **Finder** | Cortar y pegar archivos con ⌘X y ⌘V, como en Windows. Si ya usas otra app que cambia ⌘X en Finder, déjalo apagado. |
| **Capturas** | ⇧⌘3 captura la pantalla y ⇧⌘4 una zona o una ventana: van al portapapeles y se abren en un editor para anotarlas (flecha, texto, rectángulo, lápiz, subrayador, pasos numerados, pixelar, regla, recortar y color bajo el cursor). Cada cambio se vuelve a copiar solo; ⌘S la guarda en archivo y ⌘P la deja flotando encima de todo. ⇧⌘2 copia el texto de cualquier zona de la pantalla o el contenido de un QR; ⇧⌘1, además, lo traduce o responde preguntas sobre él. |
| **Alt-Tab** | ⌘Tab cambia de ventana, no de app, como en Windows: un panel con una miniatura de cada ventana del escritorio, por uso reciente (las minimizadas al final). Con ⌘ pulsado, Tab y las flechas eligen; al soltar, salta. Sustituye al ⌘Tab de macOS mientras está encendido. |
| **Dock** | Al pasar el ratón por una app abierta del Dock salen sus ventanas, con una miniatura de cada una: un clic salta a una, y la tarjeta marcada tiene botones para cerrarla, minimizarla o salir de la app. |
| **Isla** | La muesca del MacBook cobra vida, como la Dynamic Island: la música que suena (carátula, onda, y al pasar el ratón la canción con sus controles) y el dictado, las reuniones y los avisos de Sintecla. Al dictar, la música se pausa y vuelve al terminar. Desde la 0.16.0, un **estante de archivos** (arrástralos a la muesca y sácalos después; guarda el original) y **avisos de carga y AirPods** (al enchufar o desenchufar, al conectar los AirPods con la batería de cada auricular, y con batería baja). |
| **Mando** | El móvil como trackpad y mando del Mac, sin instalar nada: se enciende desde la barra de menús y se escanea un QR (misma Wi-Fi). Trackpad con gestos, música, volumen, escribir en el Mac, brillo, Spotlight, pestañas y reposo programado. El enlace lleva una llave: sin ella, el Mac no obedece. Viene de [MacRemote](https://github.com/mariodayron/MacRemote), ahora en Swift dentro de Sintecla. |
| **Y además** | Historial, estadísticas, atajos configurables, modo susurro y tecla ⌥ derecha para teclados sin 🌐. |

Dictado, Reuniones, Finder, Capturas, Alt-Tab, Dock e Isla son **módulos**: se encienden y se apagan en la página **Módulos** de la ventana de Sintecla, y uno apagado desaparece del menú y deja de funcionar. Finder, Capturas, Alt-Tab, Dock e Isla vienen apagados.

## Requisitos

- Mac con **Apple Silicon** y **macOS 26** (Tahoe) o posterior.
- **Apple Intelligence** activado: la limpieza del dictado usa el modelo de Apple en el Mac. Sin él, Sintecla limpia solo con reglas.
- **Command Line Tools** de Xcode (no hace falta Xcode entero).
- Opcional: una **clave de API de Gemini** ([Google AI Studio](https://aistudio.google.com/apikey)) para ordenar mejor el dictado, Ask Anything, las notas, las reuniones y el respaldo de la traducción. El dictado funciona sin ella.

## Instalar

```bash
xcode-select --install          # solo si aún no tienes las Command Line Tools
git clone https://github.com/mariodayron/sintecla.git
cd sintecla
scripts/build-app.sh
```

`build-app.sh` compila la app, la firma para tu Mac, la copia en `/Applications` y la abre. Su icono (una onda que acaba en un cursor) aparece en la barra de menú.

Para actualizar: `git pull` y otra vez `scripts/build-app.sh`. Los permisos se conservan.

## Primer arranque

El asistente de permisos te guía:

1. **Accesibilidad**: para detectar los atajos y pegar el texto.
2. **Micrófono** y **Reconocimiento de voz**.
3. **Ajustes del Sistema → Teclado → «Pulsar tecla 🌐 para» → «No hacer nada»**, para que 🌐 no abra los emojis ni el dictado de Apple.
4. **Audio del sistema**: solo para las reuniones; se pide la primera vez que grabas una.
5. **Grabación de pantalla**: solo para Capturas; se da en su página. Después hay que salir de Sintecla y volver a abrirla.

Después, desde el icono de la barra de menú → **Abrir Sintecla…** (abre en Inicio, con una tarjeta por módulo; pulsa la de Dictado):

- **Dictado → IA**: pega tu clave de Gemini (se guarda en el Llavero del Mac, no en ningún archivo).
- **Dictado → Atajos e idioma → Tecla base**: si tu teclado externo no manda la tecla 🌐 al Mac (pasa con algunos Logitech), elige «⌥ derecha» o «Las dos».

La primera vez, macOS descarga el modelo de reconocimiento de voz del idioma; tarda unos segundos.

## Atajos

Mantén la tecla para grabar mientras hablas, o púlsala una vez para manos libres (otra pulsación termina).

| Atajo | Modo |
|---|---|
| `🌐` | Dictado |
| `🌐` + `⇧` | Traducción |
| `🌐` + `Espacio` | Ask Anything |
| `🌐` + `⌃` | Notas |
| `🌐` + `⌥` | Empezar o terminar una reunión |
| `Esc` | Cancelar |

Las teclas que acompañan a 🌐 se cambian en **Dictado → Atajos e idioma**.

Con el módulo Capturas encendido: `⇧⌘3` pantalla, `⇧⌘4` zona o ventana, `⇧⌘2` texto y `⇧⌘1` texto con traducir y preguntar. En el editor, cada herramienta tiene su tecla (V, A, T, R, P, H, N, B, M y C), `Tab` copia el color bajo el cursor, `⌘Z` deshace, `⌘S` guarda (`⇧⌘S`, Guardar como…) y `⌘P` fija la captura en pantalla.

Con el módulo Alt-Tab encendido: `⌘Tab` abre el selector de ventanas (`⇧⌘Tab`, hacia atrás); con `⌘` pulsado, `Tab`, `⇧Tab` y las flechas mueven la marca, `Esc` cierra y al soltar `⌘` salta a la ventana marcada.

Con el módulo Dock encendido: al pasar el ratón por una app del Dock salen sus ventanas, y `Esc` cierra la vista.

Con el módulo Isla encendido: al pasar el ratón por la isla con música se despliega; un clic en la carátula abre la app que suena y la barra de progreso se puede arrastrar.

## Privacidad

- **La voz no sale de tu Mac**: la transcripción (el `SpeechTranscriber` de Apple) es local.
- **El texto del dictado va a Gemini** si pones una clave, para ordenarlo, junto con el nombre de la app (y la web, en Safari), «Mi estilo» y los términos del diccionario. Se apaga en **Dictado → IA → «Ordenar el dictado con Gemini»**; apagado o sin clave, lo ordena el modelo de Apple Intelligence en tu Mac y no sale nada.
- **Solo va a Gemini**, y solo si pones una clave: el dictado (salvo que lo apagues), Ask Anything, las notas, las actas de reuniones, la traducción cuando falla la de Apple, «Aprender de mi historial» (únicamente al pulsar ese botón) y, en Capturas, el texto de la tarjeta de ⇧⌘1 al pulsar Preguntar o Traducir.
- **Las capturas solo se guardan en disco si pulsas ⌘S** (en la carpeta que elijas en la página Capturas). Si no, van al portapapeles, y el archivo temporal de macOS se borra al leerlo.
- **Tus datos** se quedan en tu Mac:
  - `~/Library/Application Support/Sintecla/` guarda el historial (las últimas 500 entradas), el diccionario, los tonos y las estadísticas (solo números).
  - `~/Documents/Sintecla/Reuniones/` guarda las actas.

## Desinstalar

```bash
pkill -x Sintecla; rm -rf /Applications/Sintecla.app
rm -rf ~/Library/Application\ Support/Sintecla
security delete-generic-password -s local.sintecla.app -a gemini   # la clave de Gemini, si la guardaste
```

Y quita Sintecla de Ajustes del Sistema → Privacidad y seguridad (Accesibilidad, Micrófono, Grabación de pantalla…).

## Desarrollo

- `swift run sintecla-tests`: los tests (Swift Testing). Sin Xcode, `swift test` no funciona; por eso van en un ejecutable aparte.
- Con las Command Line Tools 27, `build-app.sh` compila la app con el SDK de macOS 26 (`scripts/sdk-env.sh`): en el de macOS 27, `@State` de SwiftUI es una macro cuyo plugin solo trae Xcode. Para compilarla a mano: `source scripts/sdk-env.sh && swift build -c release --product Sintecla`.
- `swift run -c release sintecla-eval [--traduccion | --ordenar]`: bancos de calidad con el modelo local (`Resources/eval/`). El de ordenar con Gemini: `Sintecla --rewrite-bench`.
- `scripts/make-icon.sh`: regenera `Resources/AppIcon.icns` a partir del dibujo en código.
- Órdenes de prueba sin abrir la app: `Sintecla --gemini-check`, `--rewrite "texto"`, `--translate "texto"`, `--ask "orden"`, `--transcribe audio.aiff`… (lista completa en `Sources/Sintecla/DebugCommands.swift`).

Estructura:

- `Sources/SinteclaCore/`: la lógica sin interfaz (limpieza, atajos, diccionario, tonos, estadísticas…), con tests.
- `Sources/Sintecla/`: la app (AppKit y SwiftUI, audio, Accesibilidad, ventanas).
- `docs/superpowers/`: los diseños y planes de cada fase, en español.

## Licencia

[MIT](LICENSE).
