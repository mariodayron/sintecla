# Tono «Prompt para IA» — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-09-25.
- **Relación:** amplía `2026-09-24-ordenar-dictado-design.md` y entra en la misma versión, 0.8.0 (rama `ordenar`). Tonos por app y por web: spec principal §6 y `2026-09-24-tono-por-web-design.md`.

## 1. Objetivo

Cuando se dicta a una IA (Claude, ChatGPT, Codex, Gemini), el tono técnico deja un párrafo limpio, pero no un buen prompt. El tono nuevo **ordena y estructura** lo dictado como prompt:

1. primero lo que se pide y después el contexto;
2. si hay 2 o más requisitos, condiciones o pasos, en lista bajo una etiqueta corta;
3. términos técnicos, código, rutas y palabras en inglés tal cual;
4. **sin añadir** nada que no se haya dicho: ni requisitos, ni roles («actúa como…»), ni formatos de respuesta, ni peticiones.

Ejemplo, dictado a Claude:

```
oye quiero que me hagas una función en swift que, o sea, que lea un json de la carpeta de documentos, y que si el json está roto pues que no pete, que lo mueva a otro sitio, y bueno que tenga tests
```

```
Haz una función en Swift que lea un JSON de la carpeta de Documentos.

Requisitos:
- Si el JSON está roto, que no falle: muévelo a otra carpeta.
- Incluye tests.
```

No-objetivos: completar el prompt con lo que suele faltar (formato de respuesta, «pregúntame si falta información»); detectar solo que se habla con una IA dentro de apps que no son de IA; tratar Terminal, iTerm, Warp, VS Code y Cursor como IA (siguen en Técnico, porque ahí también se dictan comandos y código).

## 2. El tono

- `Tone.prompt`, con el nombre «Prompt para IA». En los selectores de Ajustes → Tonos va detrás de Técnico.
- **Por defecto** (`ToneRules.defaults`):
  - apps: `com.anthropic.claudefordesktop` (Claude), `com.openai.chat` (ChatGPT) y `com.openai.codex` (Codex);
  - webs, en Safari: `claude.ai`, `chatgpt.com` y `gemini.google.com`.
- **Paso a la 0.8.0:** los `tones.json` de antes guardan esas apps y webs en Técnico porque era el valor por defecto.
  - Al leer un `tones.json` sin `version` (o con `version` < 2), las de esa lista que sigan en Técnico pasan a Prompt; las que tengan otro tono se respetan.
  - `ToneRules.version` = 2 se guarda con el archivo, así que el cambio se hace una sola vez. Si luego alguien vuelve a poner Técnico, se queda en Técnico.
- **Notas** (`NotesFormat.forApp`): con el tono Prompt, en Markdown, igual que con Técnico.

## 3. Instrucciones

- **Gemini** (`ToneFormatter.cloudInstruction(for: .prompt)`):

  ```
  prompt para una IA: empieza por lo que se pide y después el contexto; si hay 2 o más requisitos, condiciones o pasos, ponlos en lista con «- » bajo una etiqueta corta («Requisitos:», «Pasos:» o «Contexto:»); conserva literalmente términos técnicos, código, rutas y palabras en inglés; no añadas requisitos, roles, formatos ni peticiones que no haya dicho
  ```

- **Apple** (`ToneFormatter.instruction(for: .prompt)`), más simple porque el modelo local no estructura bien:

  ```
  Es un mensaje para una IA: pon primero lo que se pide y conserva literalmente términos técnicos, código, rutas y palabras en inglés.
  ```

- **Ajuste final** (`ToneFormatter.postProcess`): ninguno, como con Técnico.
- Lo demás, igual que en `2026-09-24-ordenar-dictado-design.md`: si la IA recibe una orden («resúmeme este texto…»), devuelve la orden sin ejecutarla, y una pregunta sigue siendo pregunta.

## 4. Filtro

Con el tono Prompt, las etiquetas **Requisitos, Contexto, Pasos y Objetivo** cuentan como palabras dichas: `DictationRewriter` las añade a las palabras permitidas (`ToneFormatter.allowedLabels(for:)`). El resto del filtro no cambia.

## 5. Piezas

| Pieza | Qué cambia |
|---|---|
| `Tone` | Caso `prompt` («Prompt para IA») |
| `ToneRules` | Valores por defecto de §2, `version` y el paso a la 0.8.0 |
| `ToneFormatter` | `instruction`, `cloudInstruction`, `postProcess` y `allowedLabels(for:)` |
| `NotesFormat.forApp` | Markdown también con Prompt |
| `DictationRewriter` | Etiquetas permitidas con el tono Prompt |
| `Resources/eval/ordenar_es.json` | 3 casos con `"tono": "prompt"` |
| README, spec principal §6 | El tono nuevo |

## 6. Pruebas

- **Tests automáticos:**
  - `ToneRules`: valores por defecto; un `tones.json` sin `version` pasa Claude y chatgpt.com de Técnico a Prompt, respeta una app de IA que estaba en Informal y deja Terminal en Técnico; con `version` 2 no cambia nada; ida y vuelta.
  - `ToneFormatter`: las dos líneas de Prompt, `postProcess` sin cambios y las etiquetas.
  - `NotesFormat`: Markdown con Prompt.
  - `DictationRewriter`: con tono Prompt se acepta una salida con «Requisitos:» que sin la etiqueta permitida superaría el 25 % de palabras nuevas.
- **Banco** (`ordenar_es.json`, ahora con 15 casos):
  - una función con requisitos;
  - una orden a la IA sobre un texto («resúmeme este texto…»), que no se ejecuta;
  - una pregunta técnica, que sigue siendo pregunta.
  - Objetivos: con Apple, al menos 10/15 (el listón del 66 % de `--ordenar`); con Gemini (`Sintecla --rewrite-bench`), al menos 13/15; y los demás bancos igual (42/42 y 20/20).
- **Aceptación a mano:** en Claude (la app), dictar el ejemplo de §1: sale con la petición primero y los requisitos en lista, sin nada inventado. En ChatGPT (la web, en Safari), una pregunta: se pega la pregunta, ordenada.
