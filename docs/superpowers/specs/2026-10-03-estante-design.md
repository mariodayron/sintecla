# Estante y avisos en la isla — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-10-03.
- **Relación:** amplía la isla de `2026-10-03-isla-design.md` (módulo «Isla», `moduleIsland`). Todo lo de aquí solo funciona con ese módulo encendido.
- **Versión:** 0.15.0 (build 16), rama `estante`, un solo plan.

## 1. Objetivo

Dos cosas más en la isla de la muesca:
- **un estante de archivos**: arrastras archivos a la muesca, se quedan ahí y luego los sacas a otra carpeta o app (como Yoink o NotchNook);
- **avisos de carga y AirPods**: al enchufar o desenchufar el Mac, al conectar los AirPods y cuando queda poca batería.

**No-objetivos:**
- limitar la carga (la batería tipo AlDente sigue aparcada; aquí solo se leen datos);
- avisos de otros dispositivos Bluetooth (teclado, ratón…);
- el estante con la tapa cerrada (§3.5);
- calendario, temporizador y otras ideas para la isla.

## 2. Ajustes

Dos interruptores nuevos en la página «Isla», los dos **encendidos de fábrica**:

| Ajuste | UserDefaults | Qué apaga |
|---|---|---|
| Estante | `islandShelf` | Soltar archivos en la muesca y la fila del estante. Los archivos guardados no se borran: vuelven al encenderlo |
| Avisos de batería y AirPods | `islandDeviceNotices` | Todos los avisos de §4 |

- **Permisos:** ninguno nuevo.
- La página «Isla» explica cómo usar el estante: arrastrar a la muesca para guardar, arrastrar fuera para sacar, ⌥ para que se quede.

## 3. El estante

### 3.1 Meter archivos

- **Ventana invisible sobre la muesca.** Tiene el tamaño exacto de la muesca real. Ahí no hay nada de la barra de menús, así que no tapa ningún clic. Solo acepta arrastres de archivos (URLs de archivo).
- **Al llegar a la muesca con archivos arrastrados**, la isla se abre como **bandeja**: «Suelta aquí para guardarlo en el estante», con un borde discontinuo. Mientras la bandeja está abierta, el panel de la isla recibe el arrastre en toda su forma.
- **Al soltar:** los archivos y carpetas se añaden al final del estante. Si uno ya estaba, no se repite.
- **Si sales de la bandeja sin soltar:** se recoge a los 0,3 s, como la desplegada.
- **A pantalla completa:** la isla está oculta, pero la ventana sobre la muesca sigue aceptando archivos.

### 3.2 Qué se ve

| Situación | Isla |
|---|---|
| Sin música y con archivos | **Compacta del estante:** 🗂 a la izquierda y el número de archivos a la derecha |
| Con música, con o sin archivos | La compacta de la música, como ahora |
| Ratón encima, con música o con archivos | **Desplegada:** arriba la música (si la hay) y debajo la fila del estante (si hay archivos) |

- **La fila:**
  - cada archivo con su icono de Finder (o la miniatura si es una imagen) y el nombre cortado por el centro;
  - si no caben, la fila se desplaza de lado;
  - al pasar por un archivo sale una ✕ para quitarlo;
  - con doble clic se abre con su app;
  - «Vaciar» a la derecha quita todos.
- **Medidas:** la desplegada solo con estante es más baja que con música; con las dos, más alta (se fijan en el prototipo).

### 3.3 Sacar archivos

- **Arrastrar un archivo de la fila** a una carpeta, al escritorio o a una app.
  - Si se suelta en un sitio que lo acepta, **se quita del estante**.
  - Si se mantiene **⌥** al soltar, **se queda**.
  - Si no se suelta en ningún sitio, se queda.
- **Es el original:** el estante guarda un enlace, no una copia. Al soltarlo en Finder se copia, y con ⌘ se mueve, como al arrastrar desde Finder.
- **Varios a la vez:** no en esta versión. Se arrastra de uno en uno.

### 3.4 Guardado

- La lista se guarda en `~/Library/Application Support/Sintecla/estante.json`.
- Cada archivo se guarda con un **marcador** (`URL.bookmarkData`), así que se sigue encontrando aunque se mueva o se renombre.
- **Al arrancar y al abrir la desplegada,** los archivos que ya no se encuentran (borrados o en la Papelera) se quitan solos.
- Sin límite de archivos.

### 3.5 Tapa cerrada

Sin muesca no hay estante: no se pueden soltar archivos y no se ve la fila. Los archivos siguen guardados para cuando vuelva la muesca.

## 4. Avisos de carga y AirPods

### 4.1 Cuándo salen

| Aviso | Cuándo | Qué dice |
|---|---|---|
| **Enchufado** | Al conectar el cargador | ⚡ en verde, «Cargando · 80 %». Si macOS no carga (Optimizar carga, o al 100 %), «Enchufado · 80 %» |
| **Desenchufado** | Al quitar el cargador | 🔋 «80 % · 6 h 20 min». Si macOS aún calcula el tiempo, solo el porcentaje |
| **AirPods** | Al conectarlos | Su icono y tres anillos: izquierdo, derecho y estuche, con su %. El que no da dato (estuche cerrado) no sale |
| **Batería baja del Mac** | Sin cargador, al bajar del **20 %** y del **10 %** | 🪫 en rojo, «Batería baja · 10 %». Una vez por umbral; se rearma al enchufar |
| **Batería baja de los AirPods** | Un auricular al **10 %** o menos | En rojo, el icono y el auricular con su %. Una vez por conexión |

- Mientras los AirPods estén conectados, la batería se vuelve a mirar **cada minuto** (solo para el aviso de batería baja).
- Al arrancar Sintecla no sale ningún aviso: se toma el estado actual como punto de partida.

### 4.2 Cómo conviven con lo demás

- **Duración:** 3 s cada uno, con la misma animación que los avisos de Sintecla (bajan, rebotan y se recogen).
- **Música:** si suena, se aparta a la burbuja mientras dura el aviso, como con un dictado.
- **Sintecla manda:** si está dictando, procesando o en reunión, el aviso espera a que termine. Si al terminar ya han pasado más de **10 s**, se descarta, salvo los de batería baja.
- **Varios a la vez:** salen en fila, uno detrás de otro, en el orden en que llegaron.
- **Tapa cerrada:** salen en la isla virtual, en una sola fila (como los de Sintecla, §3.6 de la isla).
- **Pantalla completa:** salen igual que los avisos de Sintecla.

### 4.3 De dónde salen los datos

- **Carga:** API de energía de macOS (`IOPSNotificationCreateRunLoopSource` y `IOPSCopyPowerSourcesInfo`): porcentaje, si está enchufado, si carga y tiempo restante. Avisa sola de cada cambio. No toca el SMC.
- **AirPods:**
  - **Conexión:** `IOBluetoothDevice.register(forConnectNotifications:selector:)`. Solo cuentan los auriculares de Apple (los que dan batería de cada auricular).
  - **Batería:** se lee del dispositivo Bluetooth (izquierdo, derecho, estuche). Si no está disponible, de `system_profiler SPBluetoothDataType` (comprobado en el Mac del usuario: da izquierdo, derecho y estuche).
- **Se comprueba primero en el prototipo** qué vía da la batería en macOS 27 y cuánto tarda.

## 5. Piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `Shelf` | Core | La lista: añadir sin repetir, quitar, vaciar, «sacado» (quita salvo ⌥), limpiar los que faltan; codificable para guardarla |
| `PowerNotices` | Core | Del estado de carga anterior y el nuevo, qué aviso toca, con los umbrales y su rearme |
| `AirPodsNotices` | Core | Al conectar, el aviso con las baterías; batería baja una vez por conexión |
| `NoticeQueue` | Core | La cola: 3 s cada uno, espera a Sintecla, descarta a los 10 s salvo batería baja |
| `IslandLayout` | Core | Formas nuevas: compacta del estante, bandeja, desplegada con estante, aviso del sistema; sus medidas |
| `AppSettings.islandShelf`, `islandDeviceNotices` | App | Los interruptores |
| `ShelfStore` | App | Guarda y carga `estante.json` con los marcadores; resuelve cada archivo |
| `ShelfDropWindow` | App | La ventana invisible sobre la muesca que recibe los arrastres |
| `ShelfRow` | App | La fila; el arrastre hacia fuera con `NSDraggingSource`, para saber si se soltó y si había ⌥ |
| `PowerMonitor` | App | Escucha la API de energía |
| `AirPodsMonitor` | App | Escucha las conexiones Bluetooth y lee la batería |
| `IslandController`, `IslandView`, `IslandPanel` | App | Unen todo: formas, bandeja, fila, avisos y su cola |
| `IslandPage` | App | Los dos interruptores y la ayuda del estante |
| `AppInfo`, `Info.plist`, `SmokeTests`, README, spec principal | — | 0.15.0 (build 16) |

## 6. Pruebas y riesgos

### 6.1 Antes del plan, en el prototipo

1. Una ventana sobre la muesca recibe un arrastre de archivos desde Finder (y no tapa clics de la barra de menús).
2. La batería de los AirPods: por Bluetooth y, si no, por `system_profiler`; cuánto tarda.
3. El aviso de la API de energía llega al enchufar y al desenchufar.

### 6.2 Tests automáticos

- **`Shelf`:**
  - añade al final y no repite;
  - quitar uno y vaciar;
  - «sacado» quita; con ⌥ se queda;
  - limpiar quita los que faltan y deja el resto en su orden;
  - guardar y cargar da la misma lista.
- **`PowerNotices`:**
  - enchufar da «Cargando», o «Enchufado» si no carga;
  - desenchufar da el porcentaje y el tiempo, o solo el porcentaje sin tiempo;
  - bajar del 20 % sin cargador avisa una vez; del 10 % otra; seguir bajando no repite;
  - enchufar rearma los umbrales;
  - el primer estado no avisa.
- **`AirPodsNotices`:**
  - conectar da el aviso con las tres baterías, sin las que faltan;
  - un auricular al 10 % avisa una vez; reconectar lo rearma.
- **`NoticeQueue`:**
  - uno detrás de otro, 3 s cada uno;
  - con Sintecla ocupada espera;
  - pasados 10 s se descarta, salvo batería baja.
- **`IslandLayout`:**
  - sin música y con archivos, compacta del estante;
  - con música, la compacta de la música aunque haya archivos;
  - ratón encima con archivos, desplegada; su alto con y sin música;
  - arrastrando, bandeja, también a pantalla completa;
  - un aviso del sistema se comporta como una actividad (con burbuja si hay música);
  - sin muesca, ni estante ni bandeja, pero sí avisos.

### 6.3 Aceptación a mano

1. Página Isla: los dos interruptores encendidos.
2. Arrastrar un archivo desde Finder a la muesca: se abre la bandeja; al soltar, la compacta muestra 🗂 1.
3. Meter tres más (uno repetido): 🗂 3… sin repetir.
4. Ratón encima: la fila con iconos; con música, la música arriba y la fila debajo.
5. Sacar uno al escritorio: se copia y se quita del estante. Con ⌥: se copia y se queda.
6. ✕ en uno, doble clic en otro (se abre), «Vaciar».
7. Reiniciar Sintecla: los archivos siguen. Mover uno de carpeta: sigue. Borrar otro: desaparece.
8. Desenchufar y enchufar el cargador: los dos avisos.
9. Conectar los AirPods: el aviso con las tres baterías.
10. Dictar con música y enchufar el cargador a la vez: el aviso sale al terminar.
11. Tapa cerrada: no hay estante; conectar los AirPods da el aviso en la isla virtual.
12. Apagar los interruptores: nada del estante ni avisos; al volver a encender, los archivos siguen.
13. La música, Sintecla, Alt-Tab, el Dock y Capturas, como antes.

La batería baja no se fuerza a mano (habría que descargar el Mac): la cubren los tests.

### 6.4 Riesgos

| Riesgo | Mitigación |
|---|---|
| La ventana sobre la muesca no recibe arrastres (o tapa algo) | Se prueba primero; si falla, detectar el arrastre por la posición del ratón y abrir la bandeja |
| No hay vía para leer la batería de los AirPods | `system_profiler` funciona en el Mac del usuario; si también falla, el aviso sale sin baterías |
| `system_profiler` tarda | Se lanza en segundo plano; el aviso sale cuando llega el dato |
| Un archivo guardado se borra | Se quita solo del estante (§3.4) |
| Los avisos molestan | Su interruptor en la página Isla |

## 7. Entrega

Un plan en la rama `estante`, versión **0.15.0**, con la aceptación al final. Sin subir a GitHub hasta que lo pida el usuario.
