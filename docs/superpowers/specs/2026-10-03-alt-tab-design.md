# Alt-Tab: ⌘Tab por ventanas — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-10-03. Entregado en `v0.12.0` (aceptado por el usuario).
- **Relación:** un módulo más de `2026-09-25-bateria-modulos-design.md` (§2), como Finder y Capturas. Es la pieza «Alt-Tab» de la hoja de ruta de `2026-09-25-herramientas-finder-design.md`.
- **Versión:** 0.12.0 (build 13), rama `alt-tab`, un solo plan.
- **Después:** un «dock útil configurable», con su propio diseño, que empieza por las vistas del Dock (0.13.0). DockDoor se desinstala cuando estén (§9).

## 1. Objetivo

Cambiar de **ventana**, no de app, con ⌘Tab, viendo una miniatura de cada una, como en Windows o con AltTab. Sustituye al selector de macOS mientras el módulo esté encendido.

**No-objetivos:**
- cerrar, minimizar o salir de apps desde el selector;
- ventanas de otros escritorios;
- buscar escribiendo;
- vistas del Dock (van con el dock configurable);
- elegir otro atajo.

## 2. El módulo

- **Módulo «Alt-Tab»:** UserDefaults `moduleAltTab`, **apagado de fábrica**. Es el quinto en Módulos.
- **Permisos:**
  - **Accesibilidad:** el que ya usa Sintecla. Sirve para listar las ventanas minimizadas y para poner una ventana delante.
  - **Grabación de pantalla:** el de Capturas, para las miniaturas. Sin él, el selector funciona igual, con el icono de la app en lugar de la miniatura, y la página lo avisa.
- **Página «Alt-Tab»:**
  - el atajo y cómo se usa;
  - el estado de los dos permisos;
  - el aviso de que, mientras está encendido, ⌘Tab abre el selector de Sintecla y no el de macOS.
- **Tarjeta de Inicio:** «⌘Tab por ventanas»; sin el permiso de Grabación de pantalla, «Sin miniaturas: falta el permiso de Grabación de pantalla».
- **Menú de la barra:** sin bloque. El selector solo se abre con el teclado.

## 3. Uso

- **Abrir:** **⌘Tab** abre el selector con la **segunda** ventana ya marcada (la anterior que usaste). **⇧⌘Tab** lo abre con la **última** marcada.
- **Con ⌘ pulsado:**
  - **Tab** avanza y **⇧Tab** retrocede, dando la vuelta al llegar al final;
  - **← →** también mueven;
  - **Esc** cierra el selector sin cambiar nada;
  - **ratón:** pasar por encima de una tarjeta la marca y un **clic** salta a ella al momento.
- **Soltar ⌘:** salta a la ventana marcada.
- **Cambio rápido:** si se suelta ⌘ antes de **150 ms**, salta a la ventana marcada sin llegar a enseñar el panel.
- **Sin ventanas** que enseñar: el selector no se abre y ⌘Tab no hace nada.
- **Una sola ventana:** se abre con ella marcada; al soltar ⌘ queda delante.

## 4. Qué ventanas salen y en qué orden

1. Las del **escritorio actual**, de la usada más recientemente a la más antigua. Es el orden de delante a atrás que da macOS.
2. Al final, las **minimizadas**, en el orden en que las devuelvan las apps.

**No salen:**
- las de Sintecla;
- las que no son de nivel normal: barras de menú, Dock, paneles flotantes y avisos;
- las de menos de 50 × 50 puntos;
- las de apps sin interfaz (las que macOS marca como agentes o de fondo).

Una ventana sin título enseña el nombre de su app.

## 5. El panel

- **Dónde:** un panel de cristal (Liquid Glass) en el centro de la pantalla del ratón. No activa Sintecla y está por encima de todo.
- **Tarjetas:**
  - una por ventana, de unos 200 × 150 puntos;
  - con la miniatura (o el icono grande de la app si está minimizada o falta el permiso);
  - debajo, el icono pequeño de la app y el título, cortado con «…».
- **Filas:** hasta **6 tarjetas por fila**; si hay más, pasa a varias filas. Si no caben en el 80 % de la pantalla, se encogen.
- **La marcada:** con un borde y un fondo resaltados.
- **Las minimizadas:** atenuadas.
- **Miniaturas:** el panel sale al momento con los iconos y cada miniatura sustituye a su icono en cuanto se captura.

## 6. Saltar a una ventana

1. Si está **minimizada**, se restaura (Accesibilidad: `kAXMinimizedAttribute` a falso).
2. Se pone **delante** de su app (Accesibilidad: `kAXRaiseAction` y `kAXMainAttribute`).
3. Se **activa la app** de la ventana.

La activación cooperativa de macOS 14 o posterior puede no dejar activar otra app desde Sintecla. Se comprueba en el prototipo (§8, riesgos).

## 7. Piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `Module.altTab`, `ModulePage.altTab`, `ModuleSwitches.altTab` | Core | El módulo, su página y su interruptor |
| `AltTabShortcut` | Core | Qué pulsaciones abren el selector (⌘Tab, ⇧⌘Tab) y cuáles lo mueven o cierran mientras ⌘ está pulsado |
| `SwitcherWindow` | Core | Datos de una ventana: app, título, minimizada, tamaño, capa y número |
| `WindowSwitcherOrder` | Core | Filtrar y ordenar (§4) |
| `SwitcherState` | Core | La marcada: empieza en la segunda (o la última con ⇧), avanza y retrocede dando la vuelta, y la marca el ratón |
| `AppSettings.moduleAltTab` | App | El interruptor |
| `WindowCatalog` | App | Lista de macOS (`CGWindowListCopyWindowInfo`) más las minimizadas por Accesibilidad |
| `WindowThumbnails` | App | Miniaturas con ScreenCaptureKit (`SCScreenshotManager`), en segundo plano |
| `WindowSwitcherPanel` | App | El panel de cristal con las tarjetas y el ratón |
| `AltTabController` | App | Teclas → panel → salto. Va el último en la cadena del `EventTap` |
| `AltTabPage`, tarjeta de Inicio | App | §2 |
| `AppInfo`, `Info.plist`, `SmokeTests`, README, spec principal | — | 0.12.0 (build 13) |

## 8. Pruebas y riesgos

### 8.1 Tests automáticos

- **`AltTabShortcut`:**
  - ⌘Tab abre y ⇧⌘Tab abre hacia atrás;
  - con ⌥, ⌃ u otras teclas, no abre;
  - con el selector abierto: Tab, ⇧Tab, ←, → y Esc.
- **`WindowSwitcherOrder`:**
  - mantiene el orden de macOS;
  - las minimizadas van al final;
  - quita las de Sintecla, las que no son de nivel normal y las pequeñas;
  - sin título, el nombre de la app.
- **`SwitcherState`:**
  - empieza en la segunda, o en la última con ⇧;
  - con una sola ventana, en ella;
  - avanza y retrocede dando la vuelta;
  - el ratón marca;
  - sin ventanas, no hay marcada.
- **Módulos:** `altTab` apagado de fábrica, su página y su lugar en `enabled`.

### 8.2 Aceptación a mano

Con DockDoor aún instalado (su selector ya está apagado):

1. Módulos → encender Alt-Tab. ⌘Tab abre el selector de Sintecla y no el de macOS.
2. Con varias ventanas de una misma app (por ejemplo, dos de Safari): salen las dos y se puede saltar entre ellas.
3. Un toque rápido de ⌘Tab alterna entre las dos últimas ventanas, sin parpadeo.
4. Tab, ⇧Tab, flechas, Esc y el ratón, como en §3.
5. Una ventana minimizada sale al final, atenuada; al elegirla, se restaura.
6. Miniaturas en todas las ventanas visibles.
7. Saltar a una ventana de otra app la deja delante y con el teclado.
8. Apagar el módulo: vuelve el ⌘Tab de macOS.
9. Dictado, Finder, Capturas y el resto, como antes.

### 8.3 Riesgos

| Riesgo | Mitigación |
|---|---|
| macOS atiende ⌘Tab antes que el `EventTap` de Sintecla | AltTab lo consigue con un `CGEventTap`. Se comprueba primero en el prototipo; si no se pudiera, se para y se habla con el usuario antes de seguir |
| La activación cooperativa no deja activar la app de la ventana | Se prueba en el prototipo. La alternativa es poner la ventana delante con Accesibilidad (`kAXRaiseAction`) y `NSRunningApplication.activate` |
| Las miniaturas tardan con muchas ventanas | El panel sale con iconos y las miniaturas llegan después, en segundo plano |
| Una app no responde a Accesibilidad y bloquea la lista | Las llamadas a Accesibilidad llevan un tiempo máximo (`AXUIElementSetMessagingTimeout`, 0,1 s) |

## 9. Entrega

Un plan en la rama `alt-tab`, versión **0.12.0**, con la aceptación al final.

El usuario pidió el 2026-10-03 **desinstalar DockDoor** (`/Applications/DockDoor.app` a la Papelera) cuando este módulo funcionara. Al aceptarlo, ese mismo día, se decidió esperar a las vistas del Dock de Sintecla (0.13.0), porque son lo que DockDoor sigue haciendo.
