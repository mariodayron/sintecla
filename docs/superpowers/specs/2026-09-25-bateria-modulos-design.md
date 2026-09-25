# Módulos y batería — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-09-25.
- **Relación:**
  - Sigue a `2026-09-25-herramientas-finder-design.md` (0.9.0). Su hoja de ruta ponía la batería al final; el usuario la adelanta.
  - La sección «Herramientas» de la 0.9.0 pasa a ser el módulo Finder.
  - Cambia la ventana y la barra de menú de la spec principal (§7).
- **Versión:** 0.10.0 (rama `bateria`), en tres planes seguidos (§10).

## 1. Objetivo

El usuario quiere que Sintecla junte en una sola app de la barra de menú lo que hoy hacen varias. La siguiente es la gestión de la batería, al estilo de **AlDente Pro**.

Esta versión hace tres cosas:

1. **Organiza Sintecla por módulos:** Dictado, Reuniones, Batería y Finder.
   - Hay una página de inicio con tarjetas y una página para encender o apagar cada módulo.
   - El menú de la barra pasa a ser un panel con un bloque por módulo.
2. **La batería con todo lo de AlDente Pro:**
   - límite de carga, descarga, Top Up, Sailing y porcentaje real;
   - protección por calor y comportamiento en reposo;
   - calibración, programación, LED del MagSafe, flujo de energía y Atajos.
3. **Un ayudante del sistema** (`sintecla-battery`), que el usuario instala una vez con su contraseña. Lleva el control de la carga aunque Sintecla esté cerrada.

**No-objetivos:**
- el modo de bajo consumo (necesitaría otro permiso de administrador);
- iconos de la batería aparte en la barra de menú;
- acciones nativas de Atajos (App Intents necesita Xcode, y el proyecto solo usa las Command Line Tools);
- Macs con Intel.

## 2. Módulos

| Módulo | Qué incluye | Páginas en la ventana |
|---|---|---|
| **Dictado** | Dictado, traducción, Ask Anything y notas | Historial · Estadísticas · Diccionario · Tonos · IA · Atajos e idioma |
| **Reuniones** | Grabar reuniones y actas | Reuniones (con el ajuste «Guardar también el audio») |
| **Batería** | §4 a §7 | Estado · Carga · Calibración y programación · Ajustes |
| **Finder** | Cortar y pegar archivos (0.9.0) | Cortar y pegar |

- **La página «Módulos»** tiene un interruptor por módulo. Un módulo apagado no se ve ni funciona:
  - desaparecen su tarjeta, sus páginas y su bloque del panel;
  - con Dictado apagado, los atajos de dictado no hacen nada;
  - con Reuniones apagado, no se puede grabar;
  - con Batería apagada, el ayudante devuelve la carga a macOS;
  - con Finder apagado, ⌘X y ⌘V van como siempre.
- **Al actualizar desde la 0.9.0:**
  - Dictado y Reuniones, encendidos;
  - Finder, como estuviera el interruptor `finderCut`, que pasa a ser el del módulo;
  - Batería, apagada hasta que se instale el ayudante.
- **La página «General»** se queda con lo común: abrir al iniciar sesión, sonidos y permisos.
- **Pasan a Dictado → Atajos e idioma:** el modo susurro, el idioma, «Traducir a», la tecla base y el editor de atajos.

## 3. Ventana y panel del menú

### 3.1 Inicio

- La ventana de Sintecla abre en **Inicio**: una tarjeta por módulo encendido, con un resumen en vivo.

  | Tarjeta | Qué enseña |
  |---|---|
  | Dictado | Dictados y palabras de hoy |
  | Reuniones | Actas de la semana, pendientes (si hay) y el botón «Grabar reunión» o «Detener» |
  | Batería | Porcentaje, estado, límite y temperatura. Sin ayudante: «Instala el ayudante para controlar la carga» |
  | Finder | «Cortar y pegar: encendido» o «apagado» |

- Debajo de las tarjetas, dos botones: **General** y **Módulos**.
- **Al pulsar una tarjeta** se entra en el módulo. La barra lateral enseña solo sus páginas y, arriba, «‹ Inicio».
- **Del menú a la ventana:**
  - «Historial…» abre Dictado → Historial;
  - «Ajustes…» (⌘,) abre General;
  - «Reuniones pendientes» abre Reuniones.

### 3.2 Panel del menú

El icono de Sintecla en la barra de menú abre un **panel** en lugar del menú de ahora. El icono sigue igual: en reposo o grabando.

- **Arriba:** una línea con el estado («Sintecla: lista» o «faltan permisos») y el micrófono.
- **Un bloque por módulo encendido:**
  - **Batería:**
    - el porcentaje y el estado (§4.1);
    - un deslizador para el límite, del 20 al 100 %;
    - los botones **Top Up** y **Descargar**. Mientras descarga, Descargar pasa a **Parar**.
    - Sin ayudante, en su lugar, «Instalar ayudante…».
  - **Dictado:**
    - el idioma, «Traducir a» (como menús) y el modo susurro;
    - «Pegar último resultado» y «Añadir selección al diccionario»;
    - «Notas sin procesar (N)…», si hay.
  - **Reuniones:** «● Grabar reunión» o «■ Detener reunión (N min)», y «Reuniones pendientes (N)…» si hay.
- **Pie:** Abrir Sintecla… (⌘O) · Ajustes… (⌘,) · Salir (⌘Q). Los atajos funcionan con el panel abierto.
- **Cerrar:** el panel se cierra al pulsar fuera o con Esc.

## 4. Batería: qué hace

### 4.1 Estados

| Estado | Qué pasa |
|---|---|
| **Cargando** | Enchufado, por debajo del límite |
| **Pausada** | Enchufado, en el límite o por encima: el Mac tira del cargador y la batería no se carga |
| **Sailing** | Enchufado, dentro del margen de Sailing (§4.4): pausada hasta bajar del margen |
| **Descargando** | El ayudante ha desconectado el cargador por dentro: el Mac tira de la batería |
| **Top Up** | Cargando al 100 % una vez |
| **Calor** | Pausada por la protección por calor |
| **Calibrando (paso N)** | En el ciclo de calibración |
| **Con batería** | Desenchufado |
| **macOS** | La carga la lleva macOS: módulo apagado, sin ayudante, AlDente funcionando o Mac no compatible. El panel dice el motivo |

### 4.2 Límite y porcentaje

- **Límite de carga:** del 20 al 100 %, **80 % de fábrica**.
  - **Por debajo del límite:** carga.
  - **En el límite o por encima:** pausa y se queda donde está. Para bajar hasta el límite están Descargar y la descarga automática.
- **Porcentaje que manda:** el de macOS (`CurrentCapacity`).
  - Con el interruptor **«Usar el porcentaje real de la batería»** (apagado de fábrica), manda el del hardware: `BatteryData.StateOfCharge` o, si falta, `AppleRawCurrentCapacity / AppleRawMaxCapacity`.
  - Suelen diferir entre un 2 y un 7 %. En la prueba del 2026-09-25: macOS 80 %, hardware 76 %.

### 4.3 Descargar y Top Up

- **Descargar** (botón): desconecta el cargador por dentro hasta llegar al límite.
  - Luego vuelve a tirar del cargador y el estado pasa a Pausada.
  - Se para también al desenchufar o con **Parar**.
- **Descarga automática** (apagada de fábrica): si se está enchufado y por encima del límite, descarga sola hasta el límite. Con ella encendida, el botón Descargar no sale.
- **Suelo:** nunca se descarga por debajo del 20 %, el límite más bajo. Solo la calibración baja al 10 % (§6.1).
- **Top Up:** pone el objetivo en el 100 % una vez.
  - Al desenchufar, vuelve al límite de antes.
  - Pulsarlo otra vez lo cancela.

### 4.4 Sailing

- Un margen de **0 a 20 %, 5 % de fábrica.** Con 0, no hay Sailing.
- Tras llegar al límite, no vuelve a cargar hasta bajar de **límite − margen**. Ejemplo: con el límite en 80 % y el margen en 5 %, recarga por debajo del 75 %.
- **Al enchufar dentro del margen** (por ejemplo, al 77 % con el límite en 80 %), se queda en Sailing y no carga.
- **Se desactiva** durante Top Up y la calibración.

### 4.5 Protección por calor

- **De fábrica:** encendida a **35 °C**. El umbral se elige entre 30 y 45 °C.
- **Qué mide:** la temperatura de la batería (`Temperature` / 100, en °C).
- **Si la pasa:** la carga se pausa (estado Calor) y empieza una cuenta de **5 minutos**.
- **Al acabar la cuenta:**
  - si sigue por encima, otros 5 minutos en pausa;
  - si ha bajado, carga **al menos 5 minutos**, aunque vuelva a subir.
- **Durante la calibración** no actúa.
- **Descarga:** no la frena. Descargar desconecta el cargador, y eso no calienta la batería.

### 4.6 Reposo

Las apps no se ejecutan con el Mac dormido. Si el Mac se duerme cargando, llega al 100 %. Dos opciones:
- **«Parar la carga antes de dormir»** (encendida de fábrica):
  - justo antes de dormir, si está cargando, pausa la carga;
  - al despertar, sigue.
- **«No dormir hasta llegar al límite»** (apagada de fábrica):
  - enchufado y cargando hacia el límite, impide el reposo del sistema;
  - al llegar al límite o al desenchufar, lo vuelve a permitir.
  - Tiene prioridad sobre la anterior.
- **Si se estaba descargando,** antes de dormir se vuelve a conectar el cargador y la descarga sigue al despertar. La excepción es el modo tapa cerrada con monitor externo: ahí la descarga impide el reposo, igual que en AlDente.

### 4.7 Siempre activo

- El ayudante mantiene el límite **con Sintecla cerrada, al cambiar de usuario y desde el arranque**, antes de iniciar sesión.
- Con el Mac apagado, el SMC vuelve a cargar hasta que arranca el ayudante.

### 4.8 Convivencia

- **AlDente:** si está abierto o funciona su ayudante (`com.apphousekitchen.aldente-pro.helper`), Sintecla no toca la carga.
  - El estado es macOS, con el aviso «AlDente controla la carga: ciérralo para usar la de Sintecla».
- **Carga optimizada de macOS:** si está encendida, Batería → Ajustes sugiere apagarla en Ajustes del Sistema → Batería. Sintecla no la cambia.
- **Mac no compatible:** si faltan las claves del SMC (§5.4), Batería dice «Este Mac no es compatible» y no toca nada.

## 5. El ayudante

### 5.1 Piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `SinteclaBattery` | Librería nueva, pura, con tests | Toda la decisión: estado, qué escribir (cargar, pausar, cargador, LED), Sailing, calor, reposo, Top Up, ciclo de calibración, fechas de la programación y los mensajes entre la app y el ayudante |
| `sintecla-battery` | Ejecutable nuevo (el ayudante, con permisos de root) | Lee la batería (IOKit, `AppleSmartBattery`), escribe en el SMC, recibe los avisos de energía y de reposo, sirve el socket y aplica lo que decide `SinteclaBattery` |
| App | `Sintecla` | Cliente del socket, instalador, páginas de Batería, bloque del panel, enlaces `sintecla://` y consultas por línea de órdenes |

### 5.2 Cuándo decide

- cada **20 s**;
- al **enchufar o desenchufar** (aviso de fuentes de energía);
- **antes de dormir y al despertar** (avisos de reposo del sistema);
- cuando la app cambia un ajuste o pide una acción.

### 5.3 Instalación

- **En Batería:** «Instalar ayudante…».
  - macOS pide la contraseña de administrador una sola vez.
  - Se ejecuta un script que va dentro de la app (`Contents/Resources/install-battery-helper.sh`).
- **Qué instala el script:**
  - el binario, de `Contents/MacOS/sintecla-battery` a `/Library/PrivilegedHelperTools/local.sintecla.battery`;
  - `/Library/LaunchDaemons/local.sintecla.battery.plist`, con `RunAtLoad` y `KeepAlive`, y lo arranca con `launchctl bootstrap system`;
  - el UID del usuario que instala, apuntado como el único que puede mandar órdenes.
- **Ajustes y estado:** en `/Library/Application Support/Sintecla/battery.json` (de root).
- **Versiones:** el ayudante dice su versión. Si no coincide con la de la app, sale «Actualizar ayudante…», con la contraseña otra vez.
- **Desinstalar** (Batería → Ajustes): devuelve la carga a macOS, para el servicio y borra el binario, el plist y los ajustes.
- `scripts/build-app.sh` mete `sintecla-battery` en `Contents/MacOS` y lo firma igual que la app.

### 5.4 SMC

Solo se escriben tres claves, con estos valores permitidos. Nada más:

| Clave | Para qué | Valores |
|---|---|---|
| `CHTE` (`ui32`) | Pausar la carga | 0 = cargar, 1 = pausar |
| `CHIE` (`hex_`, 1 byte) | Desconectar el cargador por dentro (descargar) | 0x00 = conectado, 0x08 = desconectado |
| `ACLC` (`ui8`) | LED del MagSafe | Sistema, apagado, verde, naranja y naranja parpadeando (los modos de §7.1) |

- **Claves obligatorias:** `CHTE` y `CHIE`. Si faltan, el Mac no es compatible.
- **`ACLC`:** si falta, no hay opciones de LED.
- **Leídas el 2026-09-25 en un MacBook con Apple Silicon y macOS 26.6, sin permisos:** `CHTE` = 0, `CHIE` = 00, `ACLC` = 02. Las claves antiguas (`CH0B`, `CH0C`, `CH0I`, `CH0J`, `BCLM`) no existen.
- **Valores exactos por confirmar:** los de `CHIE` son los que usan otras herramientas, y los de `ACLC` aún no se conocen. Se confirman en el prototipo con escrituras cortas, cada una con permiso del usuario (§9.2).

### 5.5 Seguridad

- **Devolver la carga a macOS** (`CHTE` = 0, `CHIE` = 0x00, `ACLC` al valor de sistema) en cualquiera de estos casos:
  - no se puede leer la batería;
  - el ayudante recibe `SIGTERM`;
  - se apaga el módulo;
  - se desinstala;
  - AlDente funciona.
- **Al arrancar,** el ayudante pone siempre `CHIE` = 0x00 antes de decidir. Así, si se cae descargando, el cargador vuelve a conectarse al reiniciarse.
- **Socket:** `/var/run/local.sintecla.battery.sock`. Solo acepta al UID apuntado en la instalación y a root (se comprueba con `getpeereid`).
- **Qué se acepta:** los mensajes de §5.6. Los valores se comprueban: límite 20–100, Sailing 0–20, calor 30–45 y descarga hasta 20–100.
- **El ayudante no ejecuta órdenes del sistema ni escribe otras claves.**

### 5.6 Mensajes

JSON, un mensaje por conexión.

| Mensaje | Respuesta |
|---|---|
| `status` | Estado, porcentajes (macOS y real), enchufado, temperatura, vatios del cargador, del Mac y de la batería, motivo si el estado es macOS, paso de calibración, versión |
| `settings` / `setSettings` | Ajustes de §4 y §7 |
| `topUp`, `discharge`, `stop`, `calibrate`, `cancelCalibration` | Estado tras la acción |
| `schedule` / `setSchedule`, `history` | Tareas (§6.2) y últimas 50 ejecuciones |
| `version` | Versión del ayudante |

## 6. Calibración y programación

### 6.1 Calibración

Con el botón «Calibrar» (Batería → Calibración y programación) o una tarea programada:

1. Carga al 100 %.
2. Descarga al 10 %, aunque esté enchufado.
3. Vuelve a cargar al 100 %.
4. Se mantiene al 100 % una hora.
5. Vuelve al límite, descargando si hace falta.

- **Mientras calibra:** la protección por calor y el Sailing se desactivan, y el Mac no se duerme.
- **Si se desenchufa,** espera en el paso donde iba y sigue al volver a enchufar.
- **«Cancelar calibración»** vuelve al límite.
- **La calibración se guarda** en `battery.json`, así que sigue si el ayudante se reinicia.

### 6.2 Programación

Cada tarea tiene estos datos:

| Dato | Valores |
|---|---|
| Acción | Poner el límite en X · Top Up · Calibrar · Pausar la carga (límite = porcentaje actual) · Descargar hasta X |
| Repetición | Una vez · Diaria · Laborables · Semanal · Quincenal · Mensual |
| Día y hora | Los que elija el usuario |
| Activa | Sí o no |
| «Ejecutar en la próxima ocasión» | Sí o no |

- **Las lleva el ayudante:** funcionan con Sintecla cerrada.
- **Tareas perdidas:** con el Mac dormido o apagado a esa hora, se ejecutan al despertar si tienen «Ejecutar en la próxima ocasión»; si no, se saltan.
- **Si un mes no tiene el día elegido** (el 31, por ejemplo), va el último día del mes.
- **Historial de tareas:** las últimas 50 ejecuciones, con la hora, la acción y si se hizo o se saltó.

## 7. Extras

### 7.1 LED del MagSafe

En Batería → Ajustes, tres modos:
- **Como macOS**, el de fábrica.
- **Según Sintecla:** verde en Pausada o Sailing, o en Top Up al llegar al 100 %; naranja cargando, descargando, en Calor o calibrando. Opción «Naranja parpadeando al descargar».
- **Siempre apagado.**

Los valores de `ACLC` se confirman en el prototipo (§5.4).

### 7.2 Flujo de energía

- **Dónde:** Batería → Estado, un diagrama con dos columnas.
  - **Izquierda, de dónde sale la energía:** el cargador (vatios que entran) o la batería (vatios que da).
  - **Derecha, adónde va:** el Mac (consumo) y, si carga, la batería.
- **De dónde salen los datos:** `PowerTelemetryData` (`SystemPowerIn`, `SystemLoad`, `BatteryPower`, en mW) y `AdapterDetails.Watts`.
- **Cuándo se actualiza:** cada 2 s mientras está a la vista.
- **No necesita el ayudante:** la app lee IOKit directamente.
- **Salud y ciclos, en la misma página:** capacidad máxima = `NominalChargeCapacity / DesignCapacity`, hasta 100 %; ciclos = `CycleCount`.

### 7.3 Atajos

- **Acciones,** con la acción «Abrir URL» de Atajos:
  - `sintecla://bateria/limite?valor=80`;
  - `sintecla://bateria/topup`;
  - `sintecla://bateria/descargar?hasta=70`;
  - `sintecla://bateria/pausar`;
  - `sintecla://bateria/calibrar`;
  - `sintecla://bateria/parar`.
  - Se registra el esquema en `Info.plist`.
  - Los valores fuera de rango se rechazan, con un aviso en la pastilla.
- **Consultas,** con «Ejecutar script de shell»: `/Applications/Sintecla.app/Contents/MacOS/Sintecla --bateria porcentaje|limite|estado|temperatura`.
  - Escribe el valor y sale.
  - Sin ayudante, `estado` devuelve `macOS`.

## 8. Otras piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `Module` y su visibilidad | Core | Los módulos, sus páginas, qué tarjetas y bloques se ven según los interruptores, y el paso de ajustes desde la 0.9.0. Puro, con tests |
| `AppSettings` | App | Interruptores de módulo (`moduleDictation`, `moduleMeetings`, `moduleBattery`; Finder usa `finderCut`) |
| `MainWindow` y páginas | App | Inicio, Módulos, General y la barra lateral por módulo. Las páginas de ahora se mueven, no se rehacen |
| Panel del menú | App | Sustituye el `NSMenu` de `MenuBar.swift`: SwiftUI en un panel anclado al icono |
| `DictationController` | App | Con Dictado apagado, no atiende los atajos de dictado. Finder sigue funcionando |
| `Package.swift` | — | Targets `SinteclaBattery` y `sintecla-battery`; `SinteclaCoreTests` depende también de `SinteclaBattery` |
| `AppInfo`, `Info.plist`, `SmokeTests` | Core / app / tests | Versión 0.10.0 (build 11); esquema `sintecla` |
| README y spec principal | Docs | Módulos, Batería, instalación del ayudante y cómo desinstalarlo |

## 9. Pruebas

### 9.1 Tests automáticos

- **`SinteclaBattery`:**
  - estados y órdenes: límite, porcentaje real, Sailing (también al enchufar dentro del margen), Top Up (y su vuelta al desenchufar), descarga manual y automática, suelo;
  - calor: cuenta de 5 minutos y los 5 minutos mínimos de carga;
  - reposo: las dos opciones y la descarga;
  - calibración paso a paso: también desenchufar a medias y cancelar;
  - fechas de la programación: laborables, quincenal, mensual con el 31, tareas perdidas;
  - valores fuera de rango;
  - mensajes: codificar y decodificar;
  - devolver la carga a macOS en cada caso de §5.5.
- **`Module`:** qué se ve según los interruptores y el paso desde la 0.9.0.
- **Enlaces `sintecla://`:** se leen bien y rechazan los valores fuera de rango.

### 9.2 Pruebas del SMC en el prototipo

- **Antes de cada prueba:** con AlDente cerrado y **cada una con permiso explícito del usuario**.
- **Cada prueba dura segundos** y deja la carga como estaba:
  1. pausar y reanudar la carga (`CHTE`);
  2. desconectar el cargador unos segundos y volver a conectarlo (`CHIE`), mirando que el Mac pasa a tirar de la batería;
  3. cambiar el LED y volver al de sistema (`ACLC`).

### 9.3 Aceptación a mano (al final de cada plan)

**Plan 1:**
- Inicio con las tarjetas.
- Encender y apagar cada módulo: desaparece y deja de funcionar.
- Las páginas movidas funcionan.
- El panel del menú hace todo lo del menú de antes.
- El dictado, como en la 0.9.0.

**Plan 2** (con permiso, AlDente cerrado):
- instalar el ayudante;
- el límite en 80 % para la carga;
- Descargar baja hasta el límite y vuelve al cargador;
- Top Up llega al 100 % y vuelve al límite al desenchufar;
- Sailing;
- el límite sigue con Sintecla cerrada y tras reiniciar el Mac;
- dormir cargando no pasa del porcentaje;
- con AlDente abierto, el aviso;
- desinstalar el ayudante devuelve la carga a macOS.

**Plan 3:**
- una calibración completa (tarda horas: la lanza el usuario cuando quiera);
- una tarea programada;
- el LED en los tres modos;
- el flujo de energía enchufado y desenchufado;
- un atajo con un enlace y otro con una consulta.

## 10. Entrega

Una versión, **0.10.0**, en la rama `bateria`, con tres planes seguidos. Cada uno acaba con su aceptación:

1. **Ventana por módulos y panel del menú** (§2, §3). Sin batería: la tarjeta y el bloque de Batería llegan con el plan 2.
2. **Batería básica** (§4, §5): `SinteclaBattery`, el ayudante y su instalación, las páginas Estado, Carga y Ajustes, y el bloque del panel.
3. **Calibración, programación y extras** (§6, §7), versión 0.10.0, README y spec principal.

## 11. Riesgos

| Riesgo | Mitigación |
|---|---|
| Otras claves o valores del SMC según el firmware | El ayudante comprueba las claves al arrancar. Los valores se confirman en el prototipo con permiso (§9.2). Sin las claves: «Este Mac no es compatible» |
| El reposo no es predecible (AlDente lo reconoce) | Lo peor: carga hasta el 100 % esa noche. La aceptación del plan 2 lo prueba |
| Ayudante con permisos de root | Solo tres claves con valores cerrados, solo el UID del usuario, sin órdenes del sistema, y la carga vuelve a macOS ante cualquier error (§5.5) |
| Firma sin certificado (ad-hoc) | Los servicios del sistema funcionan con ella. macOS avisa de que Sintecla añadió un elemento en segundo plano |
| Dos apps controlando la carga | Con AlDente funcionando, Sintecla no toca nada (§4.8) |
| Enlaces `sintecla://` abiertos desde una web | El navegador pregunta antes de abrir la app, y los valores están acotados: como mucho, se descarga hasta el 20 % |
| Descarga que no se para | Suelo del 20 % (10 % en calibración), se para al desenchufar, y al reiniciar el ayudante el cargador vuelve a conectarse |
