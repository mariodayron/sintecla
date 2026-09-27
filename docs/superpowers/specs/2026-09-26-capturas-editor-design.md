# Editor de capturas completo (pixelar, recortar, guardar y fijar) — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-09-26. Entregado en `v0.11.0` (aceptado por el usuario).
- **Relación:** amplía el editor de `2026-09-25-capturas-design.md` (§3). Quita de sus no-objetivos (§1) difuminar o pixelar, recortar, fijar la captura en pantalla y guardar en archivo.
- **Versión:** 0.11.0 (build 12), rama `capturas-editor`, un solo plan.

## 1. Objetivo

Que el editor de Sintecla sustituya a Shottr del todo. Hoy le faltan cuatro cosas que el usuario usa:

1. **Pixelar** zonas para tapar datos.
2. **Recortar** la captura.
3. **Guardar** en archivo.
4. **Fijar** la captura flotando encima de todo.

**No-objetivos:**
- desenfocar (el pixelado tapa mejor: el texto no se puede recuperar);
- recortar al soltar sin confirmar;
- dejar pasar los clics a través de una captura fijada, o su transparencia;
- otros formatos que no sean PNG;
- márgenes o fondo, capturas con desplazamiento o con retraso.

## 2. Pixelar

- **Herramienta Pixelar**, tecla **B**, entre Pasos y Regla en la barra.
- **Uso:** se arrastra un rectángulo y la zona se tapa con cuadros.
- **Tamaño del cuadro:** va con el grosor: fino 8, medio 12 y grueso 18 puntos (× la escala de la captura).
- **Qué se pixela:** solo la captura, nunca las anotaciones. Una flecha o un texto encima de la zona se siguen viendo, estén por encima o por debajo en el orden de dibujo.
- **Cómo se calcula:** cada cuadro es el color medio de esa parte de la captura. La zona se reduce y se vuelve a ampliar sin suavizar.
- **Es una anotación más:** se elige, se mueve, se borra con ⌫ y se deshace con ⌘Z. El color no le afecta; el grosor, sí.
- **Un clic sin arrastrar** (menos de 4 puntos) no deja nada, como el rectángulo.

## 3. Recortar

- **Herramienta Recortar**, tecla **C**, la última de la barra.
- **Marco:**
  - se arrastra un marco sobre la captura;
  - tiene asas en las esquinas y en el centro de los lados para ajustarlo, y arrastrar dentro lo mueve;
  - fuera del marco, la captura se oscurece;
  - el marco enseña su tamaño en píxeles («800 × 600»).
- **Intro** aplica el recorte. **Esc** quita el marco sin recortar. Cambiar de herramienta también lo quita.
- **Al aplicarlo:**
  - el lienzo pasa a medir la zona recortada;
  - el título pasa a «Captura · 800 × 600»;
  - lo copiado, guardado o fijado sale recortado;
  - como es un cambio, la captura se vuelve a copiar sola (§3.3 de la spec de Capturas).
- **Sin perder nada:**
  - la captura entera se conserva por dentro y el recorte es un rectángulo sobre ella;
  - **⌘Z** deshace el recorte y ⇧⌘Z lo rehace;
  - volver a recortar parte de la zona actual (el marco empieza en ella) y solo puede quedarse dentro de la captura entera;
  - las anotaciones que quedan fuera no se borran: no se ven, y vuelven al deshacer el recorte.
- **Color bajo el cursor, regla y hit test:** siguen en píxeles de la captura entera, así que el recorte no los cambia.

## 4. Guardar

- **⌘S** guarda al momento un PNG (con las anotaciones y recortado) en la **carpeta de capturas**:
  - de fábrica, el Escritorio;
  - se cambia en la página Capturas → «Carpeta de las capturas», con «Elegir carpeta…» (UserDefaults `captureFolder`, una ruta).
- **Nombre:** «Captura 2026-09-26 a las 10.42.13.png», con la fecha y la hora de la captura, no la de guardar. Si ya existe, «Captura … 2.png», «… 3.png»…
- **⇧⌘S «Guardar como…»:** la ventana de guardar de macOS, con ese nombre y la carpeta de capturas de partida. No cambia la carpeta de capturas.
- **Avisos en la pastilla:** «Guardada en Escritorio» (el nombre de la carpeta) o «No se pudo guardar».
- **Tras guardar:** el editor sigue abierto y el portapapeles no cambia.

## 5. Fijar en pantalla

- **⌘P** o el botón **Fijar**: la captura, tal como está (anotada y recortada), pasa a una **ventanita fijada** y el editor se oculta.
- **La ventanita:**
  - sin barra y con sombra;
  - encima de las ventanas normales y en todos los escritorios;
  - no activa Sintecla, así que no quita el teclado a la app que se usa;
  - aparece donde estaba el lienzo y al mismo tamaño en pantalla.
- **Qué se hace con ella:**
  - **arrastrar** la mueve;
  - la **rueda** o **pellizcar** la escalan, del 20 % al 400 % de su tamaño real, sin moverse de sitio la esquina de arriba a la izquierda;
  - **doble clic** la cierra y vuelve a abrir su editor como estaba (anotaciones, recorte y deshacer);
  - **Esc** o **⌘W**, con ella elegida, la cierran, y con ella su editor oculto.
- **Varias a la vez:** cada captura se fija por su cuenta.
- **Dock:** mientras solo haya capturas fijadas, Sintecla no sale en el Dock. El editor oculto no cuenta; vuelve a contar al reabrirse.

## 6. Barra

| Zona | Contenido |
|---|---|
| Izquierda | Tres botones de icono: **Copiar** (⌘C), **Guardar** (⌘S) y **Fijar** (⌘P) |
| Herramientas | Seleccionar (V) · Flecha (A) · Texto (T) · Rectángulo (R) · Lápiz (P) · Subrayador (H) · Pasos (N) · **Pixelar (B)** · Regla (M) · **Recortar (C)** |
| Estilo | Como ahora |
| Derecha | Como ahora |

- La ventana pasa a un ancho mínimo de unos 960 puntos. El valor exacto sale del prototipo.
- **⌘P** no choca con el Lápiz (P, sin ⌘).

## 7. Piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `AnnotationTool.pixelate`, `.crop`; `AnnotationShape.pixelate(CGRect)`; `AnnotationWidth.pixelBlock` | Core | Las herramientas y la anotación nuevas |
| `AnnotationDocument.crop`, `setCrop(_:)`, `visibleSize` | Core | El recorte, dentro de deshacer y rehacer |
| `AnnotationRenderer` | Core | Pixela a partir de la captura; `render` sale recortado |
| `CaptureFiles` | Core | El nombre del archivo y uno libre si ya existe |
| `CaptureNotice.saved(_:)`, `saveFailed` | Core | Los avisos de guardar |
| `CaptureCanvasView` | App | Pixelar; el marco de recorte con asas, Intro y Esc; el lienzo al tamaño del recorte |
| `CaptureEditor` | App | Los botones; ⌘S, ⇧⌘S y ⌘P; ocultarse y volver |
| `PinnedCapture` | App | La ventanita fijada |
| `AppSettings.captureFolder`, `CapturesPage` | App | La carpeta de capturas |
| `AppInfo`, `Info.plist`, `SmokeTests`, README, spec principal | — | 0.11.0 (build 12) |

## 8. Pruebas

### 8.1 Tests automáticos

- **Pixelar:**
  - dentro de un cuadro, todos los píxeles son iguales;
  - la zona cambia respecto a la captura (un patrón fino se vuelve liso);
  - una flecha dibujada antes que el pixelado se sigue viendo encima de él;
  - fuera de la zona, la captura no cambia.
- **Recortar:**
  - lo exportado mide lo que el recorte, con el contenido de esa zona;
  - ⌘Z devuelve el tamaño entero y ⇧⌘Z el recortado;
  - las anotaciones de fuera siguen en el documento;
  - el hit test y el color bajo el cursor siguen en píxeles de la captura entera;
  - el recorte se ajusta a la captura entera.
- **Nombre del archivo:** «Captura 2026-09-26 a las 10.42.13.png»; con uno igual ya existente, « 2»; con « 2» también, « 3».
- **Avisos:** «Guardada en Escritorio» y «No se pudo guardar».
- **Herramientas:** B y C, y el orden de la barra.

### 8.2 Aceptación a mano

1. Pixelar un correo o un número: no se lee; con una flecha encima, la flecha se ve.
2. Recortar con el marco y sus asas, Intro; ⌘Z vuelve a la captura entera; volver a recortar; Esc quita el marco.
3. Pegar en Notas tras recortar, sin ⌘C: sale recortada.
4. ⌘S: el archivo aparece en el Escritorio con su nombre, y otra vez con « 2»; la pastilla lo dice.
5. Cambiar la carpeta en la página Capturas y ⌘S: va a la nueva.
6. ⇧⌘S: la ventana de guardar con el nombre puesto.
7. ⌘P: la ventanita encima de otra app que se sigue usando con el teclado; moverla y escalarla; doble clic vuelve al editor como estaba; Esc la cierra.
8. Dos capturas fijadas a la vez.
9. Lo de la 0.10.0 como antes.

## 9. Riesgos

| Riesgo | Mitigación |
|---|---|
| El pixelado con cuadros grandes aún deja adivinar texto muy grande | El grosor grueso da cuadros de 18 pt. Se comprueba en la aceptación |
| La ventanita fijada roba el teclado a la app de delante | Es un panel que no activa la app. Solo toma el teclado (para Esc y ⌘W) al hacer clic en ella |
| Guardar en una carpeta sin permiso (por ejemplo, una que ya no existe) | «No se pudo guardar», y la carpeta se cambia en la página |

## 10. Entrega

Un plan en la rama `capturas-editor`:
- pixelar;
- recortar;
- guardar;
- fijar;
- 0.11.0 con el README y la spec principal;
- aceptación.

Al cerrar, `main` y la etiqueta `v0.11.0` se suben a GitHub si el usuario lo pide.
