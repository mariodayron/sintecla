# Vistas del Dock — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-10-03.
- **Relación:** un módulo más de `2026-09-25-bateria-modulos-design.md` (§2). Es el primer paso del «dock útil configurable». Reutiliza la lista de ventanas, las miniaturas y el salto de `2026-10-03-alt-tab-design.md`.
- **Versión:** 0.13.0 (build 14), rama `dock`, un solo plan.
- **Después:** la muesca (0.14.0, con su propio diseño): la pastilla de Sintecla, música y notificaciones. Con este módulo aceptado, se desinstala DockDoor (§9).

## 1. Objetivo

Al pasar el ratón por el icono de una app abierta en el Dock, ver sus ventanas con una miniatura de cada una. Desde ahí, saltar a una, cerrarla o minimizarla. Sustituye a DockDoor.

Para cambiar entre dos ventanas de la misma app basta con esto: el usuario no quiere un atajo nuevo.

**No-objetivos:**
- un Dock propio o cambiar el de macOS (es el «dock configurable», más adelante);
- vistas de carpetas, de la Papelera o de apps cerradas;
- ventanas de otros escritorios;
- salir de la app, o cerrar todas sus ventanas, desde la vista;
- un atajo para las ventanas de la app de delante (ya está ⌘º de macOS);
- ajustes de tiempos o tamaños: se fijan aquí y se ajustan con el prototipo.

## 2. El módulo

- **Módulo «Dock»:** UserDefaults `moduleDock`, **apagado de fábrica**. Es el sexto en Módulos. Su símbolo es `dock.rectangle`.
- **Permisos:**
  - **Accesibilidad:** el que ya usa Sintecla. Sirve para saber qué icono del Dock tiene el ratón, y para poner delante, cerrar y minimizar ventanas.
  - **Grabación de pantalla:** para las miniaturas, como en Alt-Tab. Sin él, las tarjetas llevan el icono de la app y la página lo avisa.
- **Página «Dock»:**
  - cómo se usa;
  - el estado de los dos permisos;
  - el aviso de cerrar DockDoor u otras apps que hagan lo mismo, para que no salgan dos vistas.
- **Tarjeta de Inicio:** «Ventanas al pasar por el Dock»; sin el permiso de Grabación de pantalla, «Sin miniaturas: falta el permiso de Grabación de pantalla».
- **Menú de la barra:** sin bloque.

## 3. Uso

- **Aparecer:** con el ratón **0,3 s** sobre el icono de una app abierta, sale la vista con sus ventanas, pegada al icono y hacia dentro de la pantalla.
- **Pasar a otro icono** con la vista ya abierta: cambia al momento, sin volver a esperar.
- **Tarjetas:**
  - pasar el ratón por una la marca;
  - un **clic** la pone delante (la restaura si estaba minimizada) y la vista se cierra;
  - en la tarjeta marcada salen dos botoncitos arriba a la izquierda, **cerrar** y **minimizar** (o **restaurar** si está minimizada).
- **Cerrar** es cerrar la ventana, no salir de la app. Si la ventana tiene cambios sin guardar, la app saca su aviso de guardar, como siempre.
- **Tras cerrar o minimizar,** la vista se actualiza sin irse. Si ya no queda ninguna ventana, se cierra.
- **Desaparecer:** al salir el ratón del icono y de la vista, tras **0,25 s** de margen, que es lo que da tiempo a ir del icono a la vista. También al hacer clic en el Dock, al pulsar Esc o al abrirse Alt-Tab.
- **Sin vista:**
  - apps sin ventanas en el escritorio actual;
  - apps cerradas, carpetas, Papelera y separadores.

  En todos esos casos, el Dock hace lo de siempre.
- **El clic en el icono** no cambia: lo atiende el Dock como siempre.

## 4. Qué ventanas salen y en qué orden

Las mismas que Alt-Tab (§4 de su spec), solo las de esa app. Primero las del escritorio actual, de la más reciente a la más antigua. Al final, las minimizadas, atenuadas.

Una ventana sin título enseña el nombre de su app.

## 5. La vista

- **Dónde:**
  - pegada al icono, del lado de dentro de la pantalla (encima si el Dock está abajo, a la derecha si está a la izquierda, a la izquierda si está a la derecha), con 8 puntos de hueco;
  - centrada en el icono;
  - si se saliera de la pantalla, se corre hasta caber.
- **Cristal** (Liquid Glass), como el selector de Alt-Tab. No activa Sintecla y está por encima del Dock.
- **Tarjetas:**
  - las mismas de Alt-Tab, más pequeñas: unos **160 puntos** de ancho;
  - en **una fila** si el Dock está abajo y en **una columna** si está a un lado;
  - si no caben en el 80 % de la pantalla, se encogen.
- **Miniaturas:** la vista sale con iconos y cada miniatura llega en cuanto se captura, como en Alt-Tab.
- **La marcada:** con borde y fondo resaltados, como en Alt-Tab.

## 6. Cómo se sabe qué icono tiene el ratón

1. Sintecla lee por Accesibilidad la lista de iconos del Dock (la app `com.apple.dock`, su `AXList`).
2. Se apunta al aviso de cambio de elegido de esa lista (`kAXSelectedChildrenChangedNotification`). El Dock marca como elegido el icono que tiene el ratón encima.
3. De cada icono saca:
   - su tipo (`AXSubrole`: `AXApplicationDockItem` es una app);
   - su app (`AXURL` → identificador de la app → app abierta con ese identificador);
   - su sitio en pantalla (`AXPosition` y `AXSize`).

   El sitio se lee en cada cambio, porque la lupa del Dock mueve los iconos.
4. El lado del Dock sale de su lista (`AXOrientation`) o, si no, de comparar el icono con los bordes de la pantalla.
5. **Si el Dock se reinicia** (al cambiar sus ajustes, por ejemplo), Sintecla vuelve a apuntarse en cuanto el Dock arranca de nuevo.

**Si el aviso no llegara** en macOS 27 (se comprueba lo primero en el prototipo), la alternativa es mirar el ratón cuando se mueve cerca del borde del Dock y preguntar a Accesibilidad qué hay debajo (`AXUIElementCopyElementAtPosition`).

## 7. Piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `Module.dock`, `ModulePage.dock`, `ModuleSwitches.dock` | Core | El módulo, su página y su interruptor |
| `DockItem` | Core | Un icono del Dock a partir de su tipo y su URL: si es una app y cuál |
| `DockEdge`, `DockPreviewPlacement` | Core | El lado del Dock y dónde va la vista (§5), sin salirse de la pantalla |
| `DockHoverTimer` | Core | Los tiempos de §3: aparecer a los 0,3 s, cambiar de icono al momento con la vista abierta y desaparecer tras 0,25 s fuera |
| `AppSettings.moduleDock` | App | El interruptor |
| `DockWatcher` | App | Escucha el Dock por Accesibilidad (§6) y se reengancha si se reinicia |
| `WindowCatalog` (+) | App | La lista de una sola app; cerrar una ventana (`kAXCloseButtonAttribute` y pulsarlo); minimizar y restaurar |
| `WindowCard` | App | La tarjeta, sacada del selector de Alt-Tab para compartirla, con los botoncitos opcionales |
| `DockPreviewPanel` | App | La vista de cristal junto al icono |
| `DockPreviewController` | App | Une el Dock, los tiempos, la lista y la vista |
| `DockPage`, tarjeta de Inicio | App | §2 |
| `AppInfo`, `Info.plist`, `SmokeTests`, README, spec principal | — | 0.13.0 (build 14) |

## 8. Pruebas y riesgos

### 8.1 Tests automáticos

- **`DockItem`:** una app con su identificador; carpeta, Papelera, separador y app sin URL no son app.
- **`DockPreviewPlacement`:**
  - Dock abajo: encima del icono, centrada;
  - Dock a la izquierda y a la derecha: al lado de dentro;
  - cerca de un borde de la pantalla: se corre hasta caber.
- **`DockHoverTimer`:**
  - no aparece antes de 0,3 s;
  - aparece a los 0,3 s;
  - con la vista abierta, otro icono cambia al momento;
  - fuera del icono y de la vista, desaparece a los 0,25 s;
  - volver a tiempo a la vista la mantiene.
- **Módulos:** `dock` apagado de fábrica, su página y su lugar en `enabled`.

### 8.2 Aceptación a mano

Con DockDoor cerrado:

1. Módulos → encender Dock. Pasar por el icono de una app con una ventana: sale su vista con la miniatura.
2. Safari con dos ventanas: salen las dos; un clic en cada una la pone delante.
3. Ir del icono a la vista sin que se cierre; salir y que se cierre.
4. Pasar de un icono a otro con la vista abierta: cambia al momento.
5. Minimizar desde la vista: la tarjeta pasa a atenuada; restaurar desde ella.
6. Cerrar una ventana desde la vista: desaparece su tarjeta. Con cambios sin guardar, sale el aviso de la app.
7. Una app sin ventanas, una carpeta y la Papelera: no sale nada.
8. Dock a la izquierda (Ajustes del Sistema): la vista sale a la derecha del icono. Volver a ponerlo abajo.
9. Alt-Tab, dictado, Finder, Capturas y el resto, como antes.

### 8.3 Riesgos

| Riesgo | Mitigación |
|---|---|
| macOS 27 no avisa del icono bajo el ratón | Se prueba primero en el prototipo; si no, la alternativa de §6 |
| La lupa del Dock mueve los iconos | El sitio se lee en cada cambio |
| El Dock se reinicia y se pierde el aviso | Se vuelve a apuntar al arrancar el Dock |
| Una app no responde a Accesibilidad | El tiempo máximo de 0,1 s de Alt-Tab |
| DockDoor abierto a la vez | La página avisa; en la aceptación está cerrado |

## 9. Entrega

Un plan en la rama `dock`, versión **0.13.0**, con la aceptación al final.

Cuando el usuario acepte el módulo, **se desinstala DockDoor**: `/Applications/DockDoor.app` va a la Papelera. Lo pidió el usuario el 2026-10-03.
