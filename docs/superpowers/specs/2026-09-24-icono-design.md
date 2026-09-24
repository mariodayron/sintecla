# Icono de Sintecla — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-09-24.
- **Relación con la spec principal:** `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§3 estructura: `Resources/AppIcon.icns`, que se preveía y nunca se hizo; §7 Interfaz: barra de menú).
- **Versión:** 0.5.1.

## 1. Objetivo

Sintecla no tiene icono: Finder, Ajustes del Sistema (Privacidad, Ítems de inicio), Spotlight y el Dock (con la ventana abierta) muestran el genérico, y la barra de menú usa el micro de SF Symbols (`mic` / `mic.fill`). Con esta pieza:

- La app tiene su icono: **«onda que escribe»** (una onda de voz que acaba en un cursor de texto), **en claro**.
- La barra de menú usa el mismo dibujo en vez del micro.

No-objetivos: variantes oscura y tintada hechas a mano y cristal dinámico de macOS 26 (formato `.icon` de Icon Composer), porque necesitan Xcode; macOS genera solo las variantes a partir del icono claro. Tampoco cambian la pastilla ni la tarjeta de Ask.

## 2. El dibujo (`BrandMark`)

Una sola descripción geométrica en el núcleo, en coordenadas de un cuadrado unidad (0–1, origen arriba a la izquierda), que usan el icono y la barra de menú. Cada pieza es un rectángulo de esquinas redondas (radio = mitad del lado corto) con su opacidad.

**Variante grande** (icono de 64 px en adelante), medidas dentro del squircle:

| Pieza | x | ancho | alto (centrado en y = 0,5) | opacidad |
|---|---|---|---|---|
| Barra 1 | 0,183 | 0,050 | 0,100 | 0,40 |
| Barra 2 | 0,267 | 0,050 | 0,233 | 0,55 |
| Barra 3 | 0,350 | 0,050 | 0,367 | 0,70 |
| Barra 4 | 0,433 | 0,050 | 0,200 | 0,85 |
| Barra 5 | 0,517 | 0,050 | 0,133 | 1 |
| Cursor: palo | 0,683 | 0,050 | 0,500 | 1 |
| Cursor: remate de arriba y de abajo | 0,625 | 0,167 | 0,042 (arriba en y = 0,233; abajo en y = 0,725) | 1 |

**Variante pequeña** (16 y 32 px, donde 5 barras finas se emborronan): tres barras en x = 0,267 / 0,383 / 0,500, de ancho 0,067 y altos 0,233 / 0,400 / 0,167, más el palo del cursor en x = 0,683, de ancho 0,075 y alto 0,567, sin remates. Todo con opacidad 1.

**Barra de menú** (16 × 16 pt, imagen plantilla; en el cuadrado unidad, las barras ocupan de x = 0 a 0,70 y el cursor de 0,75 a 1):
- *Reposo*: cuatro barras al 45 % y el cursor (palo y remates) entero.
- *Grabando*: las cuatro barras enteras y más altas, y el cursor igual.

## 3. Icono de la app

- **Lienzo** de 1024 × 1024 con el **squircle estándar de macOS**: 824 × 824 centrado (margen de 100), esquinas continuas de radio 185,4. Así macOS 26 no lo mete en su marco gris de «icono antiguo».
- **Cristal claro:**
  - Relleno: degradado vertical de `#FFFFFF` arriba a `#E4E4E8` abajo.
  - Brillo: media elipse blanca en la mitad de arriba, del 35 % a transparente.
  - Borde fino por dentro: blanco arriba y `#C8C8CE` abajo.
- **Dibujo** (§2) en `#1C1C1E`, dentro del squircle.
- **Tamaños:** 16, 32, 128, 256 y 512 px, con sus @2x (32 a 1024). La variante pequeña se usa cuando el lado en píxeles es de 32 o menos.
- **Cómo se genera:**
  1. `Sintecla --make-icon <carpeta.iconset>` (nueva orden de `DebugCommands`) dibuja los PNG con el mismo código que la barra de menú.
  2. `scripts/make-icon.sh` compila, llama a esa orden en una carpeta temporal y junta los PNG con `iconutil -c icns` en `Resources/AppIcon.icns`.
  3. El `.icns` va en git: solo se regenera si cambia el diseño.
- **Empaquetado:** `Info.plist` gana `CFBundleIconFile = AppIcon`, y `scripts/build-app.sh` copia `Resources/AppIcon.icns` a `Contents/Resources/`.

## 4. Barra de menú

- `MenuBar.setRecording(_:)` usa el dibujo de §2 (reposo o grabando) en vez de `mic` / `mic.fill`.
- Imagen plantilla (`isTemplate = true`): macOS la pinta en negro o blanco según la barra y al resaltarla. Las opacidades del reposo salen del canal alfa.
- La descripción de accesibilidad sigue siendo «Sintecla».

## 5. Piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `BrandMark` | Core | Geometría de las variantes grande, pequeña, reposo y grabando (§2). Pura. |
| `BrandMarkRenderer` | App | Dibuja una variante en un `CGContext`; icono de la app a un tamaño (§3) e imagen de la barra (§4) |
| `DebugCommands` | App | `--make-icon <carpeta>` |
| `MenuBar` | App | Imagen de la barra con `BrandMarkRenderer` |
| `scripts/make-icon.sh`, `Resources/AppIcon.icns` | — | Generar y guardar el icono |
| `Resources/Info.plist`, `scripts/build-app.sh` | — | `CFBundleIconFile` y copia del `.icns` |
| `AppInfo`, `SmokeTests` | Core / tests | Versión 0.5.1 |

## 6. Pruebas

- **Tests automáticos** (`swift run sintecla-tests`): `BrandMark` deja todas las piezas dentro del cuadrado unidad; las barras no se solapan entre sí ni con el cursor. Las barras van a la izquierda del cursor y oscurecen de izquierda a derecha en la variante grande. La pequeña tiene 3 barras. Al grabar, las barras están enteras y son más altas que en reposo.
- **Comprobación visual (Claude):**
  - Mirar los PNG de 16, 32, 128 y 1024 px.
  - Tras instalar, pedir a macOS el icono tal como lo muestra Finder (`NSWorkspace.icon(forFile:)`) y comprobar que no sale dentro del marco gris.
- **Aceptación a mano (usuario):**
  1. El icono sale en Finder (Aplicaciones), en Spotlight, en el Dock con la ventana abierta y en Ajustes del Sistema → Privacidad y seguridad → Accesibilidad.
  2. En la barra de menú, la onda en reposo, y encendida y más alta al dictar. Se ve bien con la barra clara y con la oscura.
  3. Todo lo demás, igual que en la 0.5.0.

## 7. Riesgos

| Riesgo | Mitigación |
|---|---|
| macOS 26 mete el icono en el marco gris | Squircle estándar a tamaño exacto; se comprueba con `NSWorkspace.icon(forFile:)` y se ajusta antes de entregar |
| Finder o el Dock siguen enseñando el icono genérico (caché) | `touch` de la app al instalar; si no basta, cerrar sesión o reiniciar el Dock (`killall Dock`), solo si el usuario quiere |
| A 16 px no se lee | Variante pequeña de 3 barras gruesas (§2) |
