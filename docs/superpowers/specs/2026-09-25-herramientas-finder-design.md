# Herramientas: cortar y pegar en Finder — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-09-25.
- **Relación con la spec principal:** `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§3 Arquitectura: `EventTap`; §7 Interfaz: ventana Sintecla).
- **Versión:** 0.9.0.

## 1. Objetivo

El usuario quiere que Sintecla sea más general: juntar en una sola app de la barra de menú utilidades que hoy da Windows o que en Mac son apps de pago. Así ahorra sitio y no instala más apps.

Esta pieza hace dos cosas:

1. **La sección «Herramientas»,** donde irán todas las utilidades: cada una con su interruptor y **todas apagadas por defecto**. Sintecla sigue siendo, sobre todo, la app de dictado, también para quien la descargue de GitHub.
2. **La primera herramienta: cortar y pegar archivos en Finder** con ⌘X y ⌘V, como en Windows (lo que hacen apps de pago como Command X).

**Hoja de ruta** (cada una con su propio diseño, plan y versión; el orden se confirma al terminar la anterior):

1. **Alt-Tab:** panel con las ventanas de todas las apps, con ⌥ izquierdo + Tab, porque el ⌥ derecho es la tecla de dictado del usuario.
2. **Copiar texto de la pantalla:** como TextSniper, con el OCR de Apple (Vision). Necesita el permiso de Grabación de pantalla.
3. **Batería:** como AlDente (límite de carga y modos Pro). Necesita un ayudante con permisos de administrador. Cualquier prueba que toque la carga, solo con permiso explícito del usuario.

No se hacen porque macOS 26 ya las trae: colocar ventanas en mitades o cuartos, y el historial del portapapeles (en Spotlight).

No-objetivos de esta pieza: cortar y pegar fuera de Finder; poner «Cortar» en el menú Edición de Finder; atenuar en Finder los archivos cortados; deshacer.

## 2. Cortar y pegar en Finder

Solo actúa si se cumplen las tres condiciones:
- el interruptor está encendido;
- **Finder** es la app activa (`com.apple.finder`);
- **no se está escribiendo**: el elemento enfocado no es un campo de texto (rol `AXTextField`, `AXTextArea`, `AXSearchField` o `AXComboBox`), como cuando se renombra un archivo o se busca.

Si alguna falla, ⌘X y ⌘V hacen lo de siempre.

- **⌘X** (con ⌘ y ninguna otra tecla modificadora):
  1. Sintecla se queda la pulsación y envía **⌘C**.
  2. Unos 200 ms después mira el portapapeles. Si ha cambiado y tiene archivos, apunta el corte y la pastilla avisa: **«Cortado: 3 elementos · ⌘V para mover»** (en singular, «1 elemento»).
  3. Si no ha cambiado o no tiene archivos (no había nada seleccionado), no hace nada más.
- **⌘V:**
  - Si hay un corte apuntado y el portapapeles sigue igual que tras el corte (mismo `changeCount`), Sintecla se queda la pulsación y envía **⌥⌘V**: Finder **mueve** los archivos a la carpeta abierta, también a otro disco. El corte se olvida.
  - Si no hay corte, o se ha copiado otra cosa después, ⌘V pega como siempre y el corte se olvida.
- **Al pegar no hay aviso:** Finder ya enseña los archivos movidos.
- **Pulsaciones generadas:** las de Sintecla (⌘C y ⌥⌘V) llevan la marca `EventTap.syntheticMarker`, así que el propio `EventTap` no las vuelve a procesar.
- **Prioridad:** el dictado va primero. Si una pulsación ya la usan los atajos de dictado (por ejemplo, para cancelar), Finder no la ve.

## 3. La sección Herramientas

- **En la ventana de Sintecla,** una entrada nueva en la barra lateral, **«Herramientas»** (icono `wrench.and.screwdriver`), entre IA y el final de los ajustes.
- **Contenido:**
  - Una sección **«Finder»** con el interruptor «Cortar y pegar archivos (⌘X, ⌘V)».
  - Debajo, el texto: «⌘X corta los archivos seleccionados y ⌘V los mueve a la carpeta abierta, como en Windows. Al renombrar, ⌘X corta texto como siempre.»
- **Cuándo se aplica:** al momento, sin reiniciar.
- **Permisos:** usa el de Accesibilidad, que Sintecla ya tiene. No pide ninguno nuevo.

## 4. Piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `FinderCut` | Core | Decide qué hacer con cada ⌘X y ⌘V (§2) según el interruptor, la app, si se escribe y el `changeCount` del portapapeles. Recuerda el corte y da el texto del aviso. Puro y con tests. |
| `EventTap` | App | Además de los atajos, pasa cada pulsación con su código y sus modificadores a quien la quiera (`onKeyDown`). Se la traga si esa función devuelve `true`. |
| `Paster.postCommand` | App | Admite modificadores extra (⌥ para ⌥⌘V) |
| `FinderCutter` | App | Une `FinderCut` con Finder: app activa, elemento enfocado, portapapeles (archivos y `changeCount`), envío de ⌘C y ⌥⌘V, y el aviso |
| `DictationController` | App | Crea el `FinderCutter`, lo engancha a `EventTap.onKeyDown` (después de los atajos de dictado) y le pasa el aviso de la pastilla |
| `AppSettings.finderCut` | App | Interruptor; UserDefaults `finderCut`, `false` por defecto |
| `MainSection.tools`, `ToolsTab` | App | La sección Herramientas (§3) |
| `AppInfo`, `Info.plist`, `SmokeTests` | Core / app / tests | Versión 0.9.0 (build 10) |
| README | Docs | Fila «Herramientas» en «Qué hace» |

## 5. Pruebas

- **Tests automáticos** (`FinderCut`):
  - Con el interruptor apagado, fuera de Finder o escribiendo: ⌘X y ⌘V pasan como siempre.
  - ⌘X en Finder pide copiar como corte. Si después cambia el portapapeles y hay archivos, se apunta el corte y se da el número de elementos. Sin cambio o sin archivos, no se apunta nada.
  - ⌘V con el corte apuntado y el mismo `changeCount`: se mueve, y el corte se olvida (el siguiente ⌘V pasa).
  - ⌘V con otro `changeCount` (se copió otra cosa): pasa y el corte se olvida.
  - Texto del aviso en singular y en plural.
- **Aceptación a mano:**
  1. Encender la herramienta. En Finder, cortar 2 archivos con ⌘X: aparece el aviso. Pegarlos con ⌘V en otra carpeta: se mueven.
  2. Lo mismo hacia otro disco o un USB: se mueven, no se copian.
  3. Renombrar un archivo, seleccionar parte del nombre y pulsar ⌘X: corta el texto, sin aviso. Lo mismo en el buscador de Finder y en «Ir a la carpeta» (⇧⌘G).
  4. Cortar con ⌘X, copiar otra cosa con ⌘C y pulsar ⌘V: pega lo copiado; los archivos cortados no se mueven.
  5. En Notas, ⌘X y ⌘V cortan y pegan texto como siempre.
  6. Con el interruptor apagado, ⌘X en Finder no hace nada, como en macOS.
  7. El dictado, sus atajos y el pegado funcionan como en la 0.8.0.

## 6. Riesgos

| Riesgo | Mitigación |
|---|---|
| Finder tarda en copiar y a los 200 ms el portapapeles aún no ha cambiado | Se mira hasta 3 veces en 600 ms; si no cambia, no se apunta el corte (el usuario puede repetir ⌘X) |
| Un campo de texto de Finder que no se detecta como tal | Ahí ⌘X copiaría el texto en vez de cortarlo. Los campos de Finder (renombrar, buscar, «Ir a la carpeta») se comprueban en la aceptación. El ⌘V no se ve afectado: solo cambia si hay un corte de archivos apuntado |
| Otras apps que también cambian ⌘X o ⌘V en Finder | Pueden chocar. Por eso la herramienta viene apagada y el README lo avisa |
