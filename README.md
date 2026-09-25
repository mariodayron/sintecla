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
| **Herramientas** | Utilidades de Windows o de apps de pago, cada una con su interruptor y apagadas de fábrica. Por ahora, cortar y pegar archivos en Finder con ⌘X y ⌘V. Si ya usas otra app que cambia ⌘X en Finder, deja esta apagada. |
| **Y además** | Historial, estadísticas, atajos configurables, modo susurro y tecla ⌥ derecha para teclados sin 🌐. |

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

Después, desde el icono de la barra de menú → **Abrir Sintecla…**:

- **Ajustes → IA**: pega tu clave de Gemini (se guarda en el Llavero del Mac, no en ningún archivo).
- **Ajustes → General → Tecla base**: si tu teclado externo no manda la tecla 🌐 al Mac (pasa con algunos Logitech), elige «⌥ derecha» o «Las dos».

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

Las teclas que acompañan a 🌐 se cambian en **Ajustes → General → Atajos**.

## Privacidad

- **La voz no sale de tu Mac**: la transcripción (el `SpeechTranscriber` de Apple) es local.
- **El texto del dictado va a Gemini** si pones una clave, para ordenarlo, junto con el nombre de la app (y la web, en Safari), «Mi estilo» y los términos del diccionario. Se apaga en **Ajustes → IA → «Ordenar el dictado con Gemini»**; apagado o sin clave, lo ordena el modelo de Apple Intelligence en tu Mac y no sale nada.
- **Solo va a Gemini**, y solo si pones una clave: el dictado (salvo que lo apagues), Ask Anything, las notas, las actas de reuniones, la traducción cuando falla la de Apple y «Aprender de mi historial» (únicamente al pulsar ese botón).
- **Tus datos** se quedan en tu Mac:
  - `~/Library/Application Support/Sintecla/` guarda el historial (las últimas 500 entradas), el diccionario, los tonos y las estadísticas (solo números).
  - `~/Documents/Sintecla/Reuniones/` guarda las actas.

## Desinstalar

```bash
pkill -x Sintecla; rm -rf /Applications/Sintecla.app
rm -rf ~/Library/Application\ Support/Sintecla
security delete-generic-password -s local.sintecla.app -a gemini   # la clave de Gemini, si la guardaste
```

Y quita Sintecla de Ajustes del Sistema → Privacidad y seguridad (Accesibilidad, Micrófono…).

## Desarrollo

- `swift run sintecla-tests`: los tests (Swift Testing). Sin Xcode, `swift test` no funciona; por eso van en un ejecutable aparte.
- `swift run -c release sintecla-eval [--traduccion | --ordenar]`: bancos de calidad con el modelo local (`Resources/eval/`). El de ordenar con Gemini: `Sintecla --rewrite-bench`.
- `scripts/make-icon.sh`: regenera `Resources/AppIcon.icns` a partir del dibujo en código.
- Órdenes de prueba sin abrir la app: `Sintecla --gemini-check`, `--rewrite "texto"`, `--translate "texto"`, `--ask "orden"`, `--transcribe audio.aiff`… (lista completa en `Sources/Sintecla/DebugCommands.swift`).

Estructura:

- `Sources/SinteclaCore/`: la lógica sin interfaz (limpieza, atajos, diccionario, tonos, estadísticas…), con tests.
- `Sources/Sintecla/`: la app (AppKit y SwiftUI, audio, Accesibilidad, ventanas).
- `docs/superpowers/`: los diseños y planes de cada fase, en español.

## Licencia

[MIT](LICENSE).
