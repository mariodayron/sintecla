# Tono por web (F4b) — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-09-24.
- **Relación con la spec principal:** `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§6 Tono por app, §7 Interfaz, §12 Fases). Es la segunda parte de la F4; quedan el editor de atajos y la identificación de hablantes (esta, junto con la F3b).
- **Versión:** 0.5.0.

## 1. Objetivo

Hoy el tono sale solo de la app (bundle id): todo lo que se dicta en Safari usa el tono de Safari (Neutro), sea Gmail o WhatsApp Web. Con la F4b, en **Safari** el tono sale del **dominio** de la pestaña: Gmail formal, WhatsApp Web informal, GitHub técnico…

No-objetivos: Chrome y otros navegadores; instrucciones propias por web (solo los 4 tonos de siempre); formato Markdown por web (el tono Técnico ya lo activa en las notas, §5 de la spec principal); las «apps web» del Dock de Safari, que son apps con su propio bundle id y ya se configuran en «Tono por app».

## 2. Cómo se sabe la web (`SafariSite`, app)

Por **Accesibilidad**, el permiso que Sintecla ya tiene. No hace falta ningún permiso nuevo.

1. Solo si la app de destino es Safari (`com.apple.Safari`).
2. Desde el elemento con el foco se sube por `AXParent` (como mucho 40 niveles) hasta la ventana y se lee el `AXURL` del `AXWebArea` más externo del camino: el de la página, no el de un `iframe` incrustado (el mismo que muestra la barra de direcciones).
3. Si el foco no está dentro de la página (p. ej., en la barra de direcciones), se busca el primer `AXWebArea` dentro de la ventana con el foco de Safari (`AXFocusedWindow` o, si no hay, `AXMainWindow`): recorrido en anchura, como mucho 10 niveles y 500 elementos.
4. De la dirección solo se queda el **dominio** (`host`), y solo si es `http` o `https`. Nunca se guarda la dirección completa; el dominio vive en memoria y no va al historial.
5. Cada llamada de Accesibilidad tiene 0,5 s de tiempo máximo (como `ContextReader`) y todo se hace fuera del hilo principal.

La misma función, con el pid de Safari en vez del foco del sistema (solo el paso 3), sirve para el botón «Añadir la web abierta en Safari» de Ajustes, cuando Safari no está delante.

## 3. Reglas (`ToneRules`, núcleo)

- `ToneRules` gana `bySite: [String: Tone]` (dominio → tono), junto a `byBundleID`.
- **Normalizar un dominio** (`SiteRules.normalize`): recorta espacios, pasa a minúsculas, quita el esquema (`https://`), la ruta, el puerto y un `www.` inicial. Válido solo si tiene al menos un punto, solo letras, cifras, `.` y `-`, y no empieza ni acaba en punto. Si no es válido → nil. Ejemplos: `https://www.LinkedIn.com/feed/` → `linkedin.com`; `hola` → nil.
- **Coincidencia:** una regla vale para su dominio y sus subdominios: `slack.com` cubre `miempresa.slack.com`, pero `mail.google.com` no cubre `xmail.google.com`. Si coinciden varias, gana la más larga (`gemini.google.com` antes que `google.com`).
- **Qué tono se usa** (`tone(for:host:)`):
  1. Si la app es Safari, hay dominio y alguna regla de web coincide → el tono de esa web.
  2. Si no → el tono de la app (lo de siempre; Safari, Neutro si no se cambia).
- **Lista inicial:**

| Tono | Webs |
|---|---|
| Formal | `mail.google.com`, `outlook.live.com`, `outlook.office.com`, `outlook.office365.com`, `docs.google.com` |
| Informal | `web.whatsapp.com`, `web.telegram.org`, `slack.com`, `discord.com`, `messenger.com` |
| Técnico | `github.com`, `chatgpt.com`, `claude.ai`, `gemini.google.com` |

- **Datos:** mismo archivo `tones.json`. Si no tiene `bySite` (archivos de antes de la 0.5.0), se añade la lista inicial sin tocar los tonos de apps. Si el usuario borra todas las webs, se guarda la lista vacía y no vuelve a salir la inicial.

## 4. Cuándo se lee

- **Dictado, traducción y Ask:** al pulsar la tecla base, junto a la app de destino (`arm()`), se lanza la lectura en segundo plano. No frena el micro ni la grabación.
- **Notas:** al soltar, igual que la app de destino de las notas (se pegan donde estés al terminar).
- La lectura se abandona a los **0,5 s** de empezar (cada llamada de Accesibilidad tiene además su tope de 0,5 s). Al procesar se espera su resultado; si no hay dominio, se usa el tono de la app.
- El precalentamiento del modelo local (`prewarm`) se hace cuando ya se conoce el dominio, con las instrucciones del tono resuelto.
- `Recording` gana el dominio (`site`); `ModeRunner` usa `tone(for:host:)` en todos los modos que usan tono.

## 5. Ajustes → Tonos

- La sección actual pasa a llamarse **«Tono por app»** (sin cambios).
- Nueva sección **«Tono por web (Safari)»**: una fila por dominio, ordenadas alfabéticamente, con su selector de tono y un botón para quitarla.
- Para añadir:
  - **«Añadir la web abierta en Safari (mail.google.com)»**: lee la pestaña de delante de Safari al abrir la pestaña Tonos y cada vez que la ventana de Sintecla vuelve a primer plano. Desactivado si Safari no está abierto, no hay web o ya está en la lista. Sirve también para ver qué detecta Sintecla.
  - **Campo «otra web»** + «Añadir»: se normaliza (§3); si no es válido, el botón queda desactivado. Una web nueva entra como Neutro.

## 6. Piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `SiteRules` | Core | Normaliza dominios y busca la regla más larga que coincide (§3). Puro. |
| `ToneRules.bySite`, `tone(for:host:)`, lista inicial y lectura de `tones.json` antiguos | Core | Reglas por web (§3) |
| `SafariSite` | App | Dominio de la pestaña de Safari por Accesibilidad (§2) |
| `DictationController` / `ModeRunner` | App | Lanza la lectura, espera con límite y pasa el dominio (§4) |
| `Windows.swift` (Tonos) | App | Sección «Tono por web (Safari)» (§5) |
| `AppInfo`, `SmokeTests` | Core / tests | Versión 0.5.0 |

## 7. Pruebas

- **Tests automáticos** (`swift run sintecla-tests`):
  - `SiteRules.normalize`: dirección completa, `www.`, puerto, mayúsculas, espacios, sin punto, caracteres raros.
  - Coincidencia: dominio exacto, subdominio, sufijo que no es subdominio (`xmail.google.com`), la más larga gana, sin reglas.
  - `tone(for:host:)`: web en Safari, web que no está en la lista (tono de Safari), dominio en otra app (no cuenta), sin dominio.
  - `tones.json` de antes de la 0.5.0 → lista inicial de webs y apps intactas; lista vacía se conserva.
- **Aceptación a mano** (en Safari):
  1. Con Gmail abierto, Ajustes → Tonos muestra «Añadir la web abierta en Safari (mail.google.com)».
  2. Dictar en un correo nuevo de Gmail «hola Juan te escribo para confirmar la reunión del jueves un saludo» → tono formal (saludo y despedida en su línea).
  3. Dictar en WhatsApp Web un mensaje de una frase → sin punto final.
  4. Dictar en una web que no está en la lista → tono de Safari (Neutro).
  5. Escribir `https://www.linkedin.com/feed` en «otra web» → se añade `linkedin.com`; cambiarle el tono y quitarla.
  6. Mail y WhatsApp (apps) siguen con su tono de siempre.

## 8. Riesgos

| Riesgo | Mitigación |
|---|---|
| Safari no da `AXURL` en algún caso (página rara) | Se sube por padres hasta el `AXWebArea` y, si no, se busca en la ventana; si aun así no hay dominio, se usa el tono de la app. Si en la prueba real falla en general, plan B: AppleScript (`URL of current tab of front window`), que pide el permiso «Sintecla quiere controlar Safari»; solo con el visto bueno del usuario. |
| Safari lento o colgado | 0,5 s por llamada y la lectura se abandona a los 0,5 s; nunca en el hilo principal |
| Un `iframe` con otro dominio (p. ej. un editor incrustado) | Cuenta el `AXWebArea` más externo: el dominio de la barra de direcciones, el mismo que ofrece «Añadir la web abierta» |
| Privacidad de lo que navegas | Solo el dominio, solo en memoria, solo en Safari y solo al dictar |

## 9. Ajuste tras la primera prueba

En Gmail, el texto formal salía igual que el neutro: el modelo local ignora «saludo y despedida en su propia línea» (probado: mismas frases, mismo resultado con los dos tonos; también pasaba en Mail desde la F1). Ahora lo hace una regla fija en `ToneFormatter.postProcess` para el tono formal, después de la IA:

- **Saludo** al principio («Hola», «Buenos días», «Estimado/a», «Querido/a», «Hi», «Dear»…, con el nombre y su signo) → en su línea.
- **Despedida** como última frase («Un saludo», «Saludos», «Un abrazo», «Atentamente», «Gracias», «Best regards»…, con la firma si la hay) → en su línea.
- Líneas separadas por una línea en blanco; el cuerpo empieza en mayúscula. Si el texto ya trae saltos de línea, no se toca.
