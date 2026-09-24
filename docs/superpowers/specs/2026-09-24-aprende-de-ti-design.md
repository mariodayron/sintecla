# Aprende de ti (F4a) — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-09-24.
- **Relación con la spec principal:** `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§6 Diccionario, §7 Interfaz, §12 Fases). Es la primera parte de la F4; el resto (tono por web, editor de atajos, identificación de hablantes) se diseña aparte.
- **Versión:** 0.4.0.

## 1. Objetivo

Que Sintecla mejore sola con el uso:

1. **Diccionario que aprende de tus correcciones.** Si después de dictar corriges una palabra mal reconocida ("brisa" → "Brisenta"), la próxima vez sale bien sin que abras Ajustes.
2. **Estilo sacado de tu historial.** Un botón propone el texto de "Mi estilo" a partir de cómo dictas de verdad; tú lo revisas y lo guardas.

No-objetivos: aprender reglas de gramática o de puntuación, reescribir el historial, aplicar "Mi estilo" a la limpieza del dictado (sigue solo en edición, notas y actas, §6 de la spec principal).

## 2. Diccionario que aprende

### 2.1 Cómo se detecta una corrección (automático)

- **Qué se vigila:** solo el texto que acaba de pegar Sintecla en **dictado, traducción o notas**, y solo en el campo donde lo pegó (el elemento con el foco al pegar, por Accesibilidad). Nunca campos seguros (contraseñas: rol `AXSecureTextField`). Un pegado nuevo sustituye al anterior: solo se vigila uno a la vez.
- **Cuándo se relee el campo:** cada **2 s** se lee su valor (`kAXValueAttribute`) y se guarda la última lectura que aún contiene lo pegado (ver 2.2). La vigilancia termina con la primera de estas condiciones:
  - el foco pasa a otro campo u otra app;
  - empieza otra grabación de Sintecla;
  - el campo ya no existe o ya no contiene lo pegado (p. ej., se envió el mensaje y el campo se vació);
  - pasan **90 s** desde el pegado.

  Al terminar se compara lo pegado con la última lectura buena. Si nunca hubo una lectura legible (apps que no exponen su texto), no se aprende nada, sin avisos.
- **Límites:** campos de más de **50.000 caracteres** no se vigilan (documentos largos). La lectura se hace fuera del hilo principal con el mismo tiempo máximo de Accesibilidad que `ContextReader` (0,5 s).
- **Privacidad:** lo leído solo vive en memoria mientras dura la vigilancia. Solo se guarda la pareja aprendida en el diccionario.

### 2.2 Qué cuenta como corrección (`CorrectionLearner`, núcleo, función pura)

Entrada: el texto pegado y la última lectura del campo. Salida: una lista de correcciones `{dictado, corregido}` (puede estar vacía).

1. **Palabras:** ambos textos se parten en palabras (letras y números). Para comparar se pliegan mayúsculas y tildes.
2. **Localizar lo pegado:** se busca en la lectura el tramo que mejor se alinea con lo pegado (alineado por palabras, tipo diff). Si menos de **2/3** de las palabras pegadas aparecen en orden en ese tramo, "ya no está": no hay correcciones.
3. **Reescritura:** si más de **1/3** de las palabras pegadas cambiaron, se considera que el usuario reescribió el texto: no hay correcciones.
4. **Candidatas:** cada sustitución de **1 a 3 palabras** pegadas por **1 a 3 palabras** nuevas, rodeada de palabras que no cambiaron (inserciones y borrados puros no cuentan).
5. **Filtros** (la candidata se descarta si):
   - solo cambian mayúsculas, tildes o signos ("que" → "qué", "madrid" → "Madrid"): la grafía de los términos ya la restaura el diccionario;
   - lo corregido tiene menos de 3 letras;
   - no se parecen: la distancia de edición normalizada entre las dos formas **unidas sin espacios** y simplificadas al oído (sin tildes ni mayúsculas; v → b, z → s, c ante e-i → s, ll → y, h muda, qu → k, g ante e-i → j) es mayor que **0,5**. Así "brosanta" → "Brisenta" y "bri senta" → "Brisenta" cuentan, y "mañana" → "el lunes" no;
   - lo corregido contiene dígitos y lo dictado no (o al revés): son cifras cambiadas, no nombres.

### 2.3 Qué se guarda (`PersonalDictionary.learn`, núcleo)

Para cada corrección `{dictado, corregido}`:

- **Término:** se añade `corregido` a los términos (marcado como *aprendido*) si no estaba ya y si **no es una palabra corriente** (el corrector del sistema no la conoce) o **empieza por mayúscula** (nombres propios, marcas). Así "Brisenta" entra y "baca" no llena el diccionario.
- **Regla** `dictado → corregido` (marcada como *aprendida*):
  - si alguna palabra de `dictado` **no es una palabra real** ("brosanta", "bri senta"): se crea ya;
  - si todas son palabras reales ("brisa"): la primera vez se guarda como **candidata** con cuenta 1 y la regla solo se crea la **segunda vez** que se corrige lo mismo. Así un caso suelto no cambia todas las "brisa".
  - Si ya existe una regla con el mismo `dictado`, se sustituye su destino (la última corrección manda).
- Una corrección que coincide exactamente con lo que el diccionario ya hace no cambia nada ni avisa.

### 2.4 Aviso

- En la pastilla, **2 s**: "Aprendido: Brisenta" (solo término) o "Aprendido: brisa → Brisenta" (regla). Si la pastilla está ocupada (grabando o procesando), el aviso sale cuando quede libre.
- Una candidata vista una sola vez no avisa (si además se añadió el término, avisa del término).

### 2.5 Añadir a mano

- **Ask Anything** con una selección: "añádelo al diccionario", "añade esto al diccionario", "guárdalo en el diccionario" y variantes (reconocidas por reglas, como "tradúcelo al…", antes de clasificar la intención). Sin selección: mensaje "Selecciona antes la palabra bien escrita".
- **Menú de la barra:** "Añadir selección al diccionario" (lee la selección igual que Ask).
- La selección se añade como **término** (no aprendido: es manual) si tiene como mucho 3 palabras y 40 caracteres; si no: "Selecciona una palabra o un nombre corto". Aviso: "Añadido al diccionario: Brisenta".

### 2.6 Ajustes

- Ajustes › Diccionario: interruptor **"Aprender de mis correcciones"** (activado por defecto). Apagado, no se vigila ningún campo; lo añadido a mano sigue funcionando.
- Los términos y reglas aprendidos llevan la etiqueta **"aprendido"** en las listas y se borran como los demás.
- Las candidatas no se muestran (son internas); borrar una regla aprendida borra también su candidata.

### 2.7 Datos

`dictionary.json` añade campos opcionales; los diccionarios actuales se leen igual:

```json
{"terms": ["Brisenta"], "rules": [{"from": "brosanta", "to": "Brisenta", "learned": true}],
 "learnedTerms": ["Brisenta"],
 "candidates": [{"from": "brisa", "to": "Brisenta", "count": 1}]}
```

## 3. Estilo sacado del historial

### 3.1 Flujo

- Ajustes › IA, debajo de "Mi estilo": botón **"Aprender de mi historial"**. Sin clave de Gemini está desactivado, con la nota "Necesita la clave de Gemini".
- Al pulsarlo: "Leyendo tus dictados…" y, al terminar, un cuadro con la propuesta **editable**, la línea "Basado en tus últimos N dictados, enviados a Gemini" y los botones **Guardar** / **Cancelar**. Nada cambia hasta Guardar, que sustituye "Mi estilo".

### 3.2 Qué se envía (`StyleLearner`, núcleo)

- Entradas del historial con modo **dictado** (no traducción, Ask, notas ni reuniones: ese texto no lo escribe el usuario) y al menos **4 palabras**, de la más reciente a la más antigua, hasta **15.000 caracteres** en total.
- Mínimo **20** dictados. Si hay menos: "Aún hay pocos dictados (N): vuelve cuando tengas 20".
- Formato del texto enviado: una línea por dictado, `[Nombre de la app] texto final`.
- También se envía el "Mi estilo" actual, para conservar lo que el usuario escribió a mano (p. ej., "sin emojis").

### 3.3 Respuesta

- Gemini con salida JSON `{"estilo": "…"}` (esquema `estilo`), tiempo máximo **60 s**.
- Instrucciones: describir en segunda persona y frases cortas cómo escribe el usuario (tuteo o usted, saludos y despedidas habituales, longitud de frase, puntuación, emojis), distinguiendo por tipo de app si cambia (correo, chat, código); como mucho **300 caracteres**; conservar las preferencias del estilo actual; no inventar nada que no se vea en los dictados; no copiar datos personales (nombres de clientes, direcciones, cifras).
- Si la respuesta pasa de **400 caracteres**, se corta en la última frase completa.
- Errores: sin red, tiempo agotado o JSON inválido → mensaje con el motivo (`CloudError.userMessage`) y "Mi estilo" sin cambios.

## 4. Piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `CorrectionLearner` | Core | Alinea lo pegado con el texto final y devuelve las correcciones (2.2). Puro. |
| `PersonalDictionary.learn(_:isKnownWord:)` | Core | Decide término, regla o candidata (2.3) y devuelve qué se aprendió para el aviso |
| `DictionaryCommand` | Core | Reconoce "añádelo al diccionario" y variantes (2.5) |
| `StyleLearner` | Core | Elige los dictados, prepara la petición y lee el JSON (3.2–3.3) |
| `PromptLibrary.styleInstructions` | Core | Instrucciones del estilo |
| `CorrectionWatcher` | App | Relee el campo por Accesibilidad cada 2 s y avisa al terminar (2.1) |
| `DictationController` | App | Arranca la vigilancia tras pegar; aviso en la pastilla; orden de Ask y menú "Añadir selección…" |
| `Windows.swift` (Diccionario, IA) | App | Interruptor, etiqueta "aprendido", botón y cuadro del estilo |

## 5. Pruebas

- **Tests automáticos** (`swift run sintecla-tests`):
  - `CorrectionLearner`: una palabra ("brisa" → "Brisenta"), palabras unidas ("bri senta" → "Brisenta"), el campo con más texto alrededor, reescritura (más de 1/3), solo mayúsculas o tildes, sustitución que no se parece, cifras, lo pegado ya no está, inserciones y borrados puros.
  - `PersonalDictionary.learn`: término solo si no es palabra corriente o empieza por mayúscula; regla inmediata con palabra inexistente; candidata y regla a la segunda con palabra real; sustitución de destino; sin cambios si ya lo hacía; lectura de un `dictionary.json` antiguo.
  - `DictionaryCommand`: variantes reconocidas y frases que no lo son ("busca diccionario de inglés").
  - `StyleLearner`: solo dictados de ≥ 4 palabras, orden y tope de 15.000 caracteres, mínimo de 20, petición con el estilo actual, JSON válido e inválido (con un Gemini falso), recorte a 400.
- **Aceptación a mano:**
  1. Dictar "mañana me reúno con brisenta" en Notas, corregir la palabra y cambiar de campo → aviso "Aprendido…"; el siguiente dictado sale bien.
  2. Lo mismo en Mail, en WhatsApp (enviando el mensaje en menos de 90 s) y en Gmail con Chrome.
  3. Corregir una palabra real una vez (sin regla) y otra vez (regla creada).
  4. Reescribir una frase entera → no aprende nada.
  5. Seleccionar "Brisenta" y `🌐 + Espacio` "añádelo al diccionario"; y con el menú de la barra.
  6. Apagar "Aprender de mis correcciones" → no aprende.
  7. "Aprender de mi historial" con ≥ 20 dictados → propuesta razonable; Guardar la cambia, Cancelar no.

## 6. Riesgos

| Riesgo | Mitigación |
|---|---|
| Aprender algo que no era una corrección | Filtros de 2.2, regla a la segunda con palabras reales, aviso visible y borrado en Diccionario |
| Apps que no exponen su texto (algunas Electron) | No se aprende nada ahí; queda el "añádelo al diccionario" manual |
| Coste de releer campos | Solo un campo, cada 2 s, como mucho 90 s, y nunca de más de 50.000 caracteres |
| Enviar dictados a Gemini | Solo al pulsar el botón, con el número de dictados a la vista y sin guardar nada hasta Guardar |
