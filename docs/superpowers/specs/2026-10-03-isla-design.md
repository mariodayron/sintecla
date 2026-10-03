# La isla: la muesca de Sintecla — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-10-03. Ajustado ese mismo día al probar el prototipo: lo de Sintecla sale en la isla aunque se trabaje en la pantalla externa, y con la tapa cerrada hay una isla virtual (§3.6).
- **Relación:**
  - un módulo más de `2026-09-25-bateria-modulos-design.md` (§2);
  - se lleva a la muesca la pastilla de la spec principal (`2026-09-23-sintecla-design.md`): dictado, reunión y avisos.
- **Versión:** 0.14.0 (build 15), rama `isla`, un solo plan.
- **Después:** más cosas en la isla (calendario, temporizador, bandeja de archivos, batería…), cada una con su diseño.

## 1. Objetivo

Que la muesca del MacBook sea una **isla viva**, como la Dynamic Island del iPhone, que Apple no tiene en el Mac. Será una sola forma negra que crece y cambia con animaciones de muelle, y dentro llevará:
- **la música** que suena en cualquier app;
- **todo lo de Sintecla** que hoy sale en la pastilla de abajo.

**No-objetivos:**
- la música en pantallas sin muesca (con la tapa cerrada, la isla virtual solo lleva lo de Sintecla);
- notificaciones de otras apps (macOS no deja leerlas);
- una onda que siga el sonido real (habría que grabar el audio del Mac todo el rato);
- volumen, salida de audio (AirPlay) o listas de reproducción;
- calendario, archivos y el resto de ideas para la isla (van después).

## 2. El módulo

- **Módulo «Isla»:** UserDefaults `moduleIsland`, **apagado de fábrica**. Es el séptimo en Módulos. Su símbolo es `capsule.tophalf.filled`.
- **Encendido y con la pantalla del MacBook a la vista:** la pastilla de Sintecla sale en la isla, no abajo, aunque se esté trabajando en otra pantalla.
- **Encendido y con la tapa cerrada:** isla virtual (§3.6).
- **Apagado:** todo como ahora.
- **Permisos:** ninguno nuevo.
- **Página «Isla»:**
  - qué enseña y cómo se usa;
  - si hay música disponible: «Música: lista» o «Música: no disponible en este macOS».
- **Tarjeta de Inicio:** «Música y Sintecla en la muesca»; sin pantalla con muesca, «Sin muesca: solo Sintecla, arriba en el centro».

## 3. Cómo se comporta

### 3.1 Formas

| Forma | Cuándo | Qué lleva |
|---|---|---|
| **Muesca** | Nada que enseñar | Nada: igual que la muesca real |
| **Compacta** | Suena música (o está en pausa hace menos de 5 minutos) | Crece unos 40 puntos por lado. Carátula a la izquierda y la onda a la derecha |
| **Desplegada** | Ratón encima de la isla durante 0,15 s, con música | Carátula grande, título y artista, barra de progreso, tiempos y ⏮ ⏯ ⏭ |
| **Actividad** | Sintecla está dictando, procesando, en reunión o avisando | Lo de §3.3. Manda sobre la música |
| **Actividad con burbuja** | Actividad y hay música | La actividad en la isla y, al lado derecho, una burbuja redonda con la carátula |

- **Animación:** siempre es la misma forma negra que cambia de tamaño con un muelle (respuesta 0,35 s, amortiguación 0,8). El contenido entra y sale con fundido y una escala corta.
- **Esquinas:** la forma imita la muesca, con las esquinas de arriba curvadas hacia fuera, pegadas al borde de la pantalla, y las de abajo redondeadas. Cuanto más crece, más se redondea abajo.
- **Recoger:** al sacar el ratón de la isla desplegada, se recoge a los 0,3 s.

### 3.2 Música

- **Fuente:** cualquier app que macOS reconozca como «lo que suena» (Spotify, Música, Safari, Chrome, Podcasts…).
- **Datos:** título, artista, álbum, duración, punto actual, si suena, carátula y la app.
- **Compacta:**
  - la carátula, de 17 puntos;
  - la onda: 4 barras **animadas**, del color principal de la carátula (blanco si no hay), quietas en pausa.
- **Desplegada:**
  - **un clic en la carátula** abre la app que suena;
  - **la barra de progreso** se puede arrastrar para ir a otro punto;
  - ⏮ anterior, ⏯ pausa o sigue, ⏭ siguiente.
- **Sin carátula:** el icono de la app que suena.
- **Pausada más de 5 minutos, o sin nada que suene:** vuelve a la forma de muesca.

### 3.3 Sintecla en la isla

En blanco y negro, como la pastilla de ahora; los textos son los mismos que en la pastilla.

| Estado | Isla |
|---|---|
| Escuchando (dictado, traducir, preguntar, notas) | Crece 86 puntos por lado y baja 30 por debajo de la muesca: el icono del modo a la izquierda, la onda de la voz a la derecha (en notas, también el cronómetro) y el texto debajo («Escuchando… (Esc cancela)») |
| Procesando | Compacta, con «Procesando…» (o «Traduciendo…», «Pensando…»…) y un brillo que recorre el borde |
| Hecho | Un ✓ breve y se recoge |
| Reunión | Alta: ⏺, «Reunión · 12:48» y debajo la última frase oída |
| Aviso (capturas, Finder, mensajes) | Baja 2 s con un rebote, con su símbolo y su texto, y se recoge |

### 3.4 La música al dictar

- **Al empezar a escuchar** en dictado, traducir, preguntar o notas: si sonaba música, Sintecla la **pausa**.
- **Al terminar de escuchar** (soltar la tecla o cancelar): la **reanuda solo si la pausó Sintecla**. Si ya estaba parada, o el usuario la paró o la puso él mientras tanto, no la toca.
- **Reunión:** no pausa nada.
- Con el módulo apagado o sin música disponible, no se pausa nada.

### 3.5 Ratón y teclado

- La isla solo recibe el ratón **dentro de su forma**. La barra de menús de alrededor sigue funcionando como siempre.
- **No activa Sintecla:** la app de delante sigue con el teclado.
- **Pantalla completa:** en reposo (muesca, compacta) se esconde; las actividades de Sintecla sí salen.

### 3.6 Sin muesca (tapa cerrada)

- **Isla virtual:** arriba en el centro de la pantalla principal, colgando de la barra de menús, con una muesca imaginaria de 180 puntos de ancho y el alto de la barra.
- **Solo lo de Sintecla:** baja al dictar, en reuniones y con los avisos, sin burbuja. Sin nada que enseñar, no se ve.
- **En una fila centrada:** sin cámara en medio, el icono, el texto y la onda (o el cronómetro) van juntos en el centro, y la isla baja solo 14 puntos por debajo de la barra de menús.
- **Sin música** (lo eligió el usuario). La pausa al dictar sigue funcionando.

## 4. La música por dentro

- Desde macOS 15.4, `MediaRemote` no responde a apps que no son de Apple. **A través de `/usr/bin/perl`**, que es de Apple, sí responde. Comprobado en macOS 27.0.1 con Spotify: título, artista, álbum, duración y punto.
- **El ayudante:**
  - un archivo C pequeño de Sintecla (`Resources/Island/NowPlaying.c`), que `build-app.sh` compila como biblioteca;
  - un script de `perl` que la carga.

  Sintecla arranca `perl` con el script como proceso hijo.
- **Del ayudante a Sintecla:** una línea JSON en cada cambio (canción, pausa, punto), con la carátula en base64 solo cuando cambia.
- **De Sintecla al ayudante:** órdenes por la entrada estándar (`play`, `pause`, `toggle`, `next`, `previous`, `seek <segundos>`), con `MRMediaRemoteSendCommand` y `MRMediaRemoteSetElapsedTime`.
- **Si el ayudante se cae:** se relanza con espera creciente (1, 2, 4… hasta 60 s). Si nunca responde, la página dice «Música: no disponible en este macOS» y la isla sigue sin música.
- **Si las órdenes no funcionaran por esta vía** (se comprueba primero en el prototipo): ⏯ ⏮ ⏭ con las teclas multimedia simuladas, y sin arrastrar el progreso.

## 5. Piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `Module.island`, `ModulePage.island`, `ModuleSwitches.island` | Core | El módulo, su página y su interruptor |
| `IslandLayout` | Core | Qué forma y qué contenido toca (§3.1), con sus medidas |
| `NowPlaying` | Core | Leer las líneas del ayudante y calcular el punto actual |
| `MusicPauser` | Core | Pausar al escuchar y reanudar solo si pausó Sintecla (§3.4) |
| `ArtworkColor` | Core | El color principal de la carátula, para la onda |
| `Resources/Island/NowPlaying.c`, `now-playing.pl` | Recursos | El ayudante (§4) |
| `scripts/build-app.sh` | — | Compila el ayudante y lo mete en la app |
| `AppSettings.moduleIsland` | App | El interruptor |
| `NowPlayingClient` | App | Arranca, lee y relanza el ayudante; manda las órdenes |
| `NotchScreen` | App | La pantalla con muesca y el sitio de la muesca (`safeAreaInsets` y `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`) |
| `IslandShape`, `IslandView`, `IslandPanel` | App | La forma, el contenido y el panel |
| `IslandController` | App | Une Sintecla, la música, el ratón y la pantalla completa |
| `DictationController` | App | Manda sus estados a la isla o a la pastilla, y avisa a `MusicPauser` |
| `IslandPage`, tarjeta de Inicio | App | §2 |
| `AppInfo`, `Info.plist`, `SmokeTests`, README, spec principal | — | 0.14.0 (build 15) |

## 6. Pruebas y riesgos

### 6.1 Tests automáticos

- **`IslandLayout`:**
  - sin nada, muesca; con música, compacta; con ratón y música, desplegada;
  - una actividad manda sobre la música, y con música lleva burbuja;
  - en pantalla completa, sin actividad, oculta;
  - la música en pausa más de 5 minutos vuelve a muesca;
  - las medidas de cada forma.
- **`NowPlaying`:**
  - lee una línea completa y una sin carátula;
  - una línea rota no cambia nada;
  - el punto actual avanza con el tiempo si suena y no si está en pausa;
  - nunca pasa de la duración.
- **`MusicPauser`:**
  - pausa si sonaba y reanuda al terminar;
  - no reanuda si no la pausó él;
  - no reanuda si el usuario la tocó entre medias;
  - en reunión no hace nada.
- **`ArtworkColor`:** una imagen roja da rojo; una gris da blanco (sin color, la onda va en blanco).
- **Módulos:** `island` apagado de fábrica, su página y su lugar en `enabled`.

### 6.2 Aceptación a mano

1. Módulos → encender Isla. Sin música: la muesca, como siempre.
2. Spotify sonando: compacta con carátula y onda de su color. En pausa, la onda se para.
3. Ratón encima: se despliega con muelle; ⏮ ⏯ ⏭ funcionan; arrastrar el progreso; clic en la carátula abre Spotify. Al salir, se recoge.
4. Un vídeo de YouTube en Safari: sale igual.
5. Dictar con música: se pausa, la burbuja sale a un lado, la isla escucha; al soltar, vuelve a sonar y se juntan.
6. Dictar con la música ya en pausa: al terminar sigue en pausa.
7. Procesando, hecho, reunión con su cronómetro, y un aviso de Capturas en la isla.
8. La barra de menús junto a la isla responde; la app de delante no pierde el teclado.
9. Pantalla completa (un vídeo): la isla en reposo no molesta; un dictado sí sale.
10. Con el ratón en la pantalla externa y la tapa abierta, dictar: sale en la isla del MacBook.
11. Con la tapa cerrada: sin música en la isla; al dictar, la isla baja arriba en el centro.
12. Alt-Tab, Dock, Capturas y el resto, como antes.

### 6.3 Riesgos

| Riesgo | Mitigación |
|---|---|
| Apple cierra el rodeo de `perl` | La isla y lo de Sintecla siguen; solo desaparece la música, y la página lo dice |
| Las órdenes no funcionan por el rodeo | Se prueba primero; si no, las teclas multimedia (§4) |
| La isla compacta tapa menús o iconos junto a la muesca | Crece unos 40 puntos por lado; se ajusta en el prototipo |
| El panel roba clics a la barra de menús | Solo recibe el ratón dentro de su forma |
| Gasto de batería | Animaciones solo con la isla a la vista; la onda quieta en pausa; el ayudante solo escribe cuando algo cambia |
| La app que suena no da carátula | El icono de la app |

## 7. Entrega

Un plan en la rama `isla`, versión **0.14.0**, con la aceptación al final.
