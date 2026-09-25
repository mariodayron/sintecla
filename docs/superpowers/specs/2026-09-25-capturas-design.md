# Capturas y texto de la pantalla — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-09-25.
- **Relación:**
  - Es un módulo más de `2026-09-25-bateria-modulos-design.md` (§2): tarjeta en Inicio, página, bloque del menú e interruptor en Módulos.
  - La batería de esa spec quedó aparcada (§12). Este módulo ocupa su sitio en la 0.10.0.
- **Versión:** 0.10.0 (rama `modulos`), junto con los módulos. Dos planes seguidos (§8).

## 1. Objetivo

Juntar en Sintecla lo que hoy hacen las apps de capturas de pantalla (al estilo de Shottr o TextSniper):

- **Capturar** la pantalla o una zona, con la imagen siempre en el portapapeles y un editor para anotarla.
- **Copiar el texto** de cualquier zona de la pantalla (OCR), o el contenido de un QR o un código de barras.
- **Traducir o preguntar** a la IA sobre ese texto.

**No-objetivos de esta versión:**
- en el editor: difuminar o pixelar, recortar, borrar zonas, fijar la captura en pantalla, guardar en archivo, márgenes o fondo, y la regla que detecta bordes sola;
- capturas con desplazamiento, con retraso o grabación de vídeo;
- selección propia con la pantalla congelada: se usa la de macOS (§2.3).

## 2. El módulo

### 2.1 Encendido y permiso

- **Módulo «Capturas»:** UserDefaults `moduleCaptures`, **apagado de fábrica** (como Finder).
- **Permiso de Grabación de pantalla,** que da el usuario:
  - se comprueba con `CGPreflightScreenCaptureAccess()`;
  - la página Capturas enseña si está dado, con dos botones: «Dar permiso…» (`CGRequestScreenCaptureAccess()`) y «Abrir Ajustes».
  - **Sin permiso,** un atajo no captura: la pastilla avisa «Falta el permiso de Grabación de pantalla» y se abre la página Capturas. Sin él, macOS entregaría capturas vacías.
- **Atajos de macOS:**
  - ⇧⌘3 y ⇧⌘4 también son atajos de captura de macOS (`com.apple.symbolichotkeys`, 28 a 31).
  - Si alguno está activo, la página avisa: «macOS también usa ⇧⌘3 o ⇧⌘4: desactívalos en Ajustes → Teclado → Atajos de teclado → Capturas de pantalla», con un botón para abrir esos ajustes.
  - Sintecla no los cambia.

### 2.2 Atajos

Con ⇧⌘ y ninguna otra tecla modificadora (códigos de tecla 18 a 21). Solo con el módulo encendido; si no, pasan como siempre.

| Atajo | Acción |
|---|---|
| **⇧⌘3** | Captura la **pantalla donde está el ratón**. La copia al portapapeles y abre el editor (§3) |
| **⇧⌘4** | **Zona o ventana** con la cruz de macOS. Copia y abre el editor |
| **⇧⌘2** | **Texto** de una zona (§2.4), copiado al portapapeles |
| **⇧⌘1** | **Texto** de una zona, copiado y en la **tarjeta** (§2.5) |

- **Prioridad:** en la cadena de teclas del `EventTap` van los atajos de dictado, luego Finder y luego Capturas.
- **Menú:** un bloque «Capturas» con las cuatro acciones y sus atajos a la vista.
- **Inicio:** la tarjeta de Capturas enseña «⇧⌘4 zona · ⇧⌘2 texto» y, si falta el permiso, «Falta el permiso de Grabación de pantalla».

### 2.3 Cómo se captura

Con `/usr/sbin/screencapture` de macOS, a un archivo temporal (`<temporal>/Sintecla-capturas/<uuid>.png`), sin el sonido de macOS (`-x`):

| Qué | Orden |
|---|---|
| Pantalla | `screencapture -x -D <n> <archivo>`, con `n` la pantalla bajo el ratón |
| Zona o ventana | `screencapture -i -x <archivo>`: arrastrar para una zona, Espacio para una ventana, Esc cancela (entonces no hay archivo y no pasa nada) |

- La imagen se lee y **el archivo se borra enseguida.** Las capturas nunca se guardan en disco.
- **Al portapapeles** va en PNG y en TIFF, para que la acepten todas las apps. La pastilla avisa: «Captura copiada».

### 2.4 Texto (OCR) y códigos

- **OCR:** Vision de Apple, con `VNRecognizeTextRequest` preciso, idiomas español e inglés y corrección de idioma.
  - **Orden:** de arriba abajo. Los trozos a la misma altura (se solapan más de la mitad en vertical) forman una fila, se ordenan de izquierda a derecha y se unen con un espacio.
  - Las filas se unen con saltos de línea: las líneas quedan como en la pantalla.
- **Códigos:** `VNDetectBarcodesRequest`. Si en la zona hay QR o códigos de barras, se copia su contenido (uno por línea) **en lugar del texto.**
- **Avisos en la pastilla:**
  - «Texto copiado · 23 palabras» (en singular, «1 palabra»);
  - «QR copiado: https://…», o «Código copiado: …» si es de barras. El contenido se corta a 40 caracteres, con «…».
  - «No hay texto en esa zona» (el portapapeles no cambia).

### 2.5 La tarjeta de ⇧⌘1

Un panel flotante, como la tarjeta de Ask Anything, con:
- **El texto reconocido,** que se puede editar.
- **Copiar:** copia el texto tal como esté, editado incluido.
- **Traducir:**
  - si el texto está en español, al idioma de «Traducir a»; si no, al español;
  - usa la traducción de Sintecla (Apple y, de respaldo, Gemini);
  - la traducción sale debajo, con su propio «Copiar».
- **Preguntar:**
  - abre un campo para escribir la pregunta («¿Qué significa?», «Resúmelo»…);
  - Intro la envía a Gemini o, sin clave o sin conexión, a Apple, con el texto como contexto;
  - la respuesta sale debajo, con su propio «Copiar».
- **Esc** cierra la tarjeta.

## 3. El editor

### 3.1 Ventana y barra

- **Cuándo se abre:** tras ⇧⌘3 o ⇧⌘4, **una ventana por captura**, titulada «Captura · 1007 × 771».
- **Barra:**

| Zona | Contenido |
|---|---|
| Izquierda | **Copiar** (⌘C) |
| Herramientas | **Seleccionar** (V) · **Flecha** (A) · **Texto** (T) · **Rectángulo** (R) · **Lápiz** (P) · **Subrayador** (H) · **Pasos** (N) · **Regla** (M) |
| Estilo | 6 colores (rojo de fábrica; también amarillo, verde, azul, negro y blanco) y 3 grosores: fino, medio y grueso |
| Derecha | Color de la captura bajo el cursor (`#151515`; **Tab** copia ese texto) · tamaño en píxeles · zoom |

### 3.2 Herramientas

- **Flecha, Rectángulo y Lápiz:** se arrastra.
- **Subrayador:** trazo ancho y semitransparente, amarillo de fábrica.
- **Texto:** clic y escribir; Intro o clic fuera lo termina. Doble clic sobre un texto lo edita. El tamaño de letra va con el grosor.
- **Pasos:** cada clic pone un círculo numerado (1, 2, 3…). Si se borra uno, los demás se renumeran por orden de creación.
- **Seleccionar:**
  - clic en una anotación la elige;
  - arrastrar la mueve;
  - ⌫ la borra;
  - con una elegida, cambiar color o grosor se lo cambia a ella.
- **Regla:**
  - se arrastra y enseña la distancia en píxeles de la imagen: total, horizontal y vertical;
  - es una guía: **no sale en la imagen copiada**;
  - se borra al empezar otra medida o al cambiar de herramienta.
- **Deshacer y rehacer:** ⌘Z y ⇧⌘Z.
- **Zoom:** ⌘0 ajusta a la ventana, ⌘1 pone el 100 %, y también ⌘+, ⌘− y pellizcar.
- **Esc:** si se está escribiendo un texto, lo termina; si hay una anotación elegida, la suelta; si no, cierra la ventana.

### 3.3 Portapapeles siempre al día

- La imagen se copia **al capturar**.
- **Con cada cambio** (añadir, mover, borrar, cambiar color o grosor, deshacer, rehacer, terminar un texto) se vuelve a copiar sola, con las anotaciones:
  - medio segundo después del último cambio;
  - a tamaño real (los píxeles de la captura, Retina incluido);
  - sin aviso en la pastilla.
- **⌘C y el botón Copiar** copian al momento y avisan: «Captura copiada».
- **Al cerrar** no pasa nada más: ya estaba copiada.
- **Si se copia otra cosa** con el editor abierto y luego se vuelve a tocar la captura, la captura vuelve a pisar el portapapeles. Es lo esperado mientras se edita.
- **Tab** (color bajo el cursor) copia el texto del color: es una acción explícita, y el siguiente cambio en la captura la vuelve a copiar.

## 4. Piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `Module.captures`, `ModulePage.captures`, `ModuleSwitches.captures` | Core | El módulo, su página y su interruptor |
| `CaptureShortcut` | Core | De código de tecla y modificadoras a `.screen`, `.area`, `.text` o `.textCard`. Solo ⇧⌘1 a ⇧⌘4 |
| `TextRecognizer` | Core | OCR y códigos con Vision sobre un `CGImage`: filas en orden y códigos por delante del texto |
| `CaptureNotice` | Core | Los textos de la pastilla (§2.1, §2.3, §2.4) |
| `AnnotationDocument` | Core | Anotaciones en coordenadas de píxeles de la imagen: añadir, elegir, mover, borrar, cambiar estilo, deshacer y rehacer, numerar pasos, tocar (hit test), medir con la regla y el texto del color (`#RRGGBB`) |
| `AppSettings.moduleCaptures` | App | El interruptor (UserDefaults `moduleCaptures`, `false`) |
| `ScreenCapture` | App | Lanza `screencapture` y lee y borra el archivo; la pantalla bajo el ratón; el permiso; los atajos de macOS activos |
| `CaptureController` | App | Atajo → permiso → captura → portapapeles → editor, tarjeta o pastilla. Va en la cadena del `EventTap` detrás de Finder |
| `CaptureEditorWindow` | App | Ventana, barra, lienzo (dibuja la captura y las anotaciones), exportación a tamaño real y copia automática |
| `CaptureTextCard` | App | La tarjeta de ⇧⌘1 (§2.5) |
| `CapturesPage`, tarjeta de Inicio, bloque del menú | App | §2.1 y §2.2 |
| `AppInfo`, `Info.plist`, `SmokeTests` | Core / app / tests | 0.10.0 (build 11), con los módulos |
| README, spec principal | Docs | Fila «Capturas» y la ventana por módulos (§7 de la spec principal) |

## 5. Pruebas

### 5.1 Tests automáticos

- **`CaptureShortcut`:** ⇧⌘1 a ⇧⌘4 dan su acción; con otras modificadoras o con otras teclas, nada.
- **`TextRecognizer`:**
  - filas a partir de cajas inventadas: dos columnas en la misma fila, filas desordenadas y solapes;
  - los códigos van antes que el texto.
  - **Con Vision de verdad:**
    - se dibuja «Configuración: añadir 3 términos» en una imagen y el OCR lo devuelve, con las tildes;
    - se genera un QR con `https://example.com` (CoreImage) y se lee su contenido.
- **`CaptureNotice`:** singular y plural, el corte a 40 caracteres y el aviso sin texto.
- **`AnnotationDocument`:**
  - añadir, mover y borrar;
  - deshacer y rehacer, también varios seguidos;
  - renumerar los pasos al borrar uno;
  - el hit test de una flecha (cerca de la línea sí, lejos no);
  - la regla (distancia total, horizontal y vertical);
  - cambiar el estilo de la elegida;
  - el texto del color.
- **Módulos:** `captures` apagado de fábrica, su página y su lugar en `enabled`.

### 5.2 Aceptación a mano

Con cualquier otra app de capturas cerrada y el permiso dado:

1. ⇧⌘3: la pantalla del ratón va al portapapeles (se puede pegar en Notas) y se abre el editor.
2. ⇧⌘4: zona; y otra vez con Espacio, una ventana; Esc cancela sin hacer nada.
3. ⇧⌘2 sobre un párrafo: se pega el texto con sus líneas y la pastilla dice cuántas palabras. Sobre un QR: se pega el enlace.
4. ⇧⌘1: la tarjeta con el texto. Traducir y Preguntar responden; Copiar copia; Esc cierra.
5. Editor:
   - cada herramienta;
   - mover, borrar, deshacer y rehacer;
   - los pasos se renumeran;
   - la regla mide y no sale al pegar;
   - Tab copia el color;
   - tras cada cambio, pegar en Notas da la versión anotada sin pulsar ⌘C.
6. Sin el permiso: aviso y se abre la página.
7. Con el módulo apagado, ⇧⌘1 a ⇧⌘4 no hacen nada.
8. Con dos pantallas (si hay): ⇧⌘3 captura la del ratón.
9. Dictado, Finder y el resto, como antes.

## 6. Riesgos

| Riesgo | Mitigación |
|---|---|
| La numeración de `screencapture -D` no coincide con la de las pantallas de AppKit | Se comprueba en el prototipo. Si no coincide, ⇧⌘3 usa ScreenCaptureKit (`SCScreenshotManager`) para esa pantalla |
| El permiso de Grabación de pantalla no pasa al `screencapture` que lanza Sintecla | Se comprueba en el prototipo. Si no pasa, la captura se hace con ScreenCaptureKit dentro de Sintecla y la cruz de macOS solo da el rectángulo |
| Otras apps que usan ⇧⌘1 o ⇧⌘2 | Mientras el módulo está encendido no les llegan. Por eso viene apagado y la página lo dice |
| Otra app de capturas con los mismos atajos | Se cierra al usar las de Sintecla |
| Texto pequeño o de poco contraste | Las capturas Retina dan el doble de píxeles. Si no hay texto, el aviso lo dice y el portapapeles no cambia |

## 7. Pendientes que no cambian este diseño

- **La batería,** aparcada: `2026-09-25-bateria-modulos-design.md` §12.

## 8. Entrega

En la rama `modulos`, dos planes seguidos, cada uno con su aceptación:

1. **Capturas sin editor:**
   - el módulo y el permiso;
   - los cuatro atajos;
   - ⇧⌘3 y ⇧⌘4 copian al portapapeles, pero aún sin editor;
   - OCR y códigos, y la tarjeta de ⇧⌘1;
   - la página, el bloque del menú y la tarjeta de Inicio.
2. **El editor** (§3). Después, la versión 0.10.0 con los módulos, el README y la spec principal.
