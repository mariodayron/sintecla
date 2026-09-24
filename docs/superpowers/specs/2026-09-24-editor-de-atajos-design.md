# Editor de atajos (F4c) — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-09-24.
- **Relación con la spec principal:** `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§4 Atajos y máquina de estados, §7 Interfaz, §12 Fases). Es la tercera parte de la F4; queda la identificación de hablantes (junto con la F3b).
- **Versión:** 0.6.0.

## 1. Objetivo

Hoy cada modo tiene una tecla acompañante fija junto a la tecla base: ⇧ traduce, Espacio es Ask, ⌃ son notas y ⌥ (o ⌘ con ⌥ derecha) es la reunión. Ajustes → General solo las enseña. Con la F4c, **cada modo puede usar la acompañante que quieras**.

No-objetivos: cambiar la tecla base (sigue siendo 🌐, ⌥ derecha o las dos, §4.1 de la spec principal); combinaciones libres tipo ⌃⌥D; desactivar modos; cambiar Dictar (la base sola) o Cancelar (Esc); cambiar las reglas de pulsar y mantener (§4.2).

## 2. Qué se puede cambiar

- **Modos configurables:** Traducir, Ask Anything, Notas y Reunión.
- **Acompañantes posibles:** ⇧, ⌃, ⌥, ⌘ y Espacio. Son 5 para 4 modos: siempre sobra una.
- **Sin repeticiones:** si eliges para un modo una tecla que ya tiene otro, **se intercambian** (el otro se queda con la que tenía el primero). Nunca hay dos modos con la misma tecla ni mensajes de error.
- **Valores por defecto** (los de ahora): Traducir ⇧, Ask Espacio, Notas ⌃, Reunión ⌥. Botón «Restaurar atajos».
- Cada modo conserva su forma de grabar: Traducir, Ask y Notas se mantienen o se pulsan (manos libres); la Reunión es un conmutador que actúa al soltar la base (§4.2 de la spec principal).

## 3. Cómo se decide el modo (`HotkeyLayout`)

Con la base abajo, al pasar a grabación (o al soltar, en la reunión):

1. Si se pulsó **Espacio** y Espacio es de un modo → ese modo.
2. Si no, se miran los **modificadores** activos en este orden: ⇧, ⌃, ⌥, ⌘. El primero que sea de un modo decide.
3. **Regla de ⌥ con ⌥ derecha:** si la tecla base es ⌥ derecha o «las dos», ⌥ no puede acompañar a la ⌥ derecha (es la propia base). Por eso, con esas dos bases, el modo que tiene ⌥ **también se activa con ⌘**, siempre que ⌘ no sea de otro modo. Con los valores por defecto da lo mismo que hoy: la reunión es `🌐 + ⌥` y `⌥ der + ⌘`.
4. Si nada coincide → Dictado.

**La tecla que sobra no hace nada especial:**
- Un modificador libre se ignora (base + ese modificador = Dictado).
- Si la que sobra es **Espacio**, base + Espacio se trata como cualquier otra tecla: cancela en silencio y el Espacio llega a la app (§4.2, «no estorbar»).

## 4. Textos de los atajos

`HotkeyLayout.shortcut(for:baseKey:)` da el texto de cada modo, que usan Ajustes y el aviso «Reunión en curso: termínala con …». Los símbolos son ⇧, ⌃, ⌥, ⌘ y «Espacio».

| Base | Modo con tecla X (no ⌥) | Modo con ⌥ (⌘ libre) | Modo con ⌥ (⌘ de otro modo) |
|---|---|---|---|
| 🌐 | `🌐 + X` | `🌐 + ⌥` | `🌐 + ⌥` |
| ⌥ derecha | `⌥ der + X` | `⌥ der + ⌘` | sin atajo |
| Las dos | `🌐 o ⌥ der + X` | `🌐 + ⌥ o ⌥ der + ⌘` | `🌐 + ⌥` (solo con 🌐) |

Dictar sigue siendo `🌐`, `⌥ der` o `🌐 o ⌥ der`.

## 5. Ajustes → General → Atajos

- La sección «Atajos (mantener, o pulsar para manos libres)» pasa a tener un **selector por modo** con las 5 teclas: «⇧ Mayúsculas», «⌃ Control», «⌥ Opción», «⌘ Comando», «Espacio».
- Bajo cada selector, en pequeño, el atajo resultante con la base elegida (§4).
- Si con la base elegida un modo se queda **sin atajo**, se avisa bajo su selector: «Con ⌥ derecha, Reunión no tiene atajo: ⌥ es la propia tecla base. Ponle otra tecla o deja ⌘ libre». Con «Las dos», el aviso dice que solo funciona con 🌐.
- Dictar y Cancelar siguen fijos, como texto.
- Botón «Restaurar atajos», desactivado si ya están los de por defecto.
- Los cambios se aplican al momento (como la tecla base).

## 6. Datos

- `AppSettings.hotkeys: HotkeyLayout`, guardado en las preferencias (`UserDefaults`, clave `hotkeys`) como JSON `{"translation":"shift","ask":"space","notes":"control","meeting":"option"}`.
- Al leer: si falta, no se puede leer o no asigna los 4 modos a teclas distintas → valores por defecto.

## 7. Piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `HotkeyCompanion` | Core | Las 5 acompañantes, con su símbolo y su nombre |
| `HotkeyLayout` | Core | Modo → acompañante, intercambio, decidir el modo (§3), textos (§4), qué modo se queda sin atajo, Codable con validación. Puro. |
| `HotkeyStateMachine` | Core | Usa `HotkeyLayout` en vez de las teclas fijas; Espacio libre = otra tecla |
| `AppSettings.hotkeys` | App | Guardar y leer (§6) |
| `DictationController` | App | Pasa la tabla a la máquina; aviso de la reunión con `shortcut(for:baseKey:)` |
| `Windows.swift` (`GeneralTab`) | App | Selectores, atajo resultante, avisos y «Restaurar atajos» (§5) |
| `AppInfo`, `SmokeTests` | Core / tests | Versión 0.6.0 |

## 8. Pruebas

- **Tests automáticos** (`swift run sintecla-tests`):
  - Con los valores por defecto, el modo sale igual que hoy con las tres bases, y todos los tests actuales de `HotkeyStateMachine` siguen en verde.
  - Intercambio al repetir tecla; «Restaurar».
  - Orden Espacio → ⇧ → ⌃ → ⌥ → ⌘ con varias a la vez.
  - ⌘ activa el modo de ⌥ con ⌥ derecha y con «las dos», no con 🌐, y no si ⌘ es de otro modo.
  - Modificador libre → Dictado; Espacio libre → cancela y el Espacio pasa.
  - Textos de la tabla de §4 y «sin atajo».
  - JSON: ida y vuelta; falta, roto o con repeticiones → valores por defecto.
- **Aceptación a mano:**
  1. Ajustes → General: poner ⌥ en Notas → Reunión pasa a ⌃ (se intercambian); los textos cambian al momento.
  2. `🌐 + ⌥` graba notas y `🌐 + ⌃` inicia y termina la reunión.
  3. Con la base en «Las dos», desde el Logitech: `⌥ der + ⌘` hace notas y la reunión va con `⌥ der + ⌃`.
  4. Poner Espacio en Traducir: `🌐 + Espacio` traduce y Ask pasa a ⇧.
  5. «Restaurar atajos» vuelve a lo de siempre.
  6. Con la reunión en marcha, el aviso de otro atajo dice la combinación nueva.
  7. Reiniciar Sintecla: los atajos se conservan.

## 9. Riesgos

| Riesgo | Mitigación |
|---|---|
| Romper los atajos que ya funcionan | Valores por defecto idénticos a los de hoy, con tests que lo comprueban con las tres bases |
| Un modo sin atajo con ⌥ derecha | Aviso en Ajustes (§5) |
| Olvidar qué atajo tiene cada modo | Cada selector enseña el atajo resultante; «Restaurar atajos» |
