# Grabadora portátil de reuniones — Diseño

- **Estado:** arquitectura aprobada el 2026-09-23. El diseño detallado (secciones marcadas como *pendiente*) se termina antes de escribir su plan, **después de la F3**, porque reutiliza su acta en PDF.
- **Relación con la spec principal:** `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§5.5 Reunión y §12).

## 1. Objetivo

Grabar reuniones y charlas **lejos del Mac** con un aparato de bolsillo, y que Sintecla convierta cada grabación en un acta o un resumen, igual que las reuniones del Mac.

Usos (elegidos por el usuario):
- Reuniones en la oficina o con clientes: alrededor de una mesa, 2–6 personas, sin mucho ruido.
- Charlas o formaciones: una persona habla y el resto escucha, en una sala grande.

Fuera de alcance: grabar llamadas del móvil y visitas a obra con ruido.

## 2. Decisiones

| Tema | Decisión | Motivo |
|---|---|---|
| Aparato | **M5Stack CoreS3** (no la SE, que no trae batería, ni la Lite, que trae 200 mAh), sin soldar | ESP32-S3 con USB nativo (OTG), dos micrófonos (ES7210), ranura microSD (hasta 16 GB), batería interna de 500 mAh, pantalla táctil de 2", 54 × 54 × 15,5 mm. 59,90 $ en la tienda oficial |
| Qué hace el aparato | **Solo graba** | Un ESP32 no puede transcribir una hora de audio; el Mac sí (y gratis) |
| Controles | En la pantalla: elegir **Reunión** o **Charla** y Grabar. Mientras graba, pantalla roja con cronómetro | La CoreS3 no tiene botones de usuario; el rojo también avisa a los asistentes |
| Audio | 16 kHz, mono, más una ficha con tipo, inicio y duración | ~115 MB/h en WAV: una microSD de 16 GB da para unas 140 h |
| Transferencia | **v1:** USB-C, el aparato aparece como un pendrive; Sintecla copia lo nuevo, pone el reloj en hora y el aparato se carga. **v2:** Wi-Fi a Sintecla en redes conocidas, en cuanto termina la grabación. **Futuro:** subida a la nube desde cualquier sitio (punto de acceso del móvil) | Lo ideal para el usuario es que salga sola al terminar; se llega por pasos, de lo más simple a lo más cómodo |
| Quién habla | **Gemini** transcribe el audio separando voces ("Persona 1", "Persona 2"…). Sin conexión o sin clave: transcripción local en el Mac, sin voces | Actas con responsables. Coste con `gemini-3.5-flash-lite`: audio a 0,30 $/M tokens y 32 tokens por segundo, unos 7 céntimos por hora contando la transcripción de salida |
| Salida | Reunión → **acta** (la de §5.5 de la spec principal). Charla → **resumen de charla** (ideas clave, conceptos, preguntas). PDF y Markdown en `~/Documents/Sintecla/` con aviso; si falla, queda pendiente para reintentar | Reutiliza `MeetingSummary` y el PDF de la F3 |
| Legal | Avisar a los asistentes de que se graba | En España se puede grabar una conversación en la que participas, pero difundirla puede no ser legal, y hay datos de terceros (RGPD) |

## 3. Arquitectura

```text
Aparato (CoreS3)                          Mac (Sintecla)
┌──────────────────────────┐   USB-C     ┌───────────────────────────────────────────┐
│ Pantalla: Reunión/Charla │ ──────────▶ │ Detecta el aparato, copia lo nuevo,       │
│ Micrófonos → WAV 16 kHz  │  (v2: Wi-Fi)│ pone el reloj en hora                     │
│ + ficha JSON en microSD  │             │ → Gemini: transcripción con voces         │
│ Cierre seguro del archivo│             │   (sin red/clave: local, sin voces)       │
└──────────────────────────┘             │ → acta o resumen de charla → PDF + .md    │
                                         └───────────────────────────────────────────┘
```

## 4. Pendiente de diseñar (antes del plan)

- **Programa del aparato:** Arduino con M5Unified; pantallas; formato del archivo y de la ficha; cierre del WAV si se corta la corriente; qué pasa si se enchufa mientras graba (sigue grabando y solo carga); pendrive (USB MSC) solo cuando no graba.
- **Sintecla:** detección del volumen del aparato, importación sin duplicados, puesta en hora, cola de pendientes.
- **Gemini con audio:** esquema de la transcripción con voces; audio largo (límite del envío directo → Files API o trozos); esquema del resumen de charla.
- **Pruebas:** banco con una reunión real grabada con el aparato (calidad de voces y latencia); consumo real de batería.

## 5. Riesgos

| Riesgo | Mitigación |
|---|---|
| En una sala grande el micro capta poco al ponente | Colocar el aparato cerca del ponente; comprobarlo en el banco |
| Calidad de la separación de voces de Flash-Lite, sin medir | Banco antes de cerrar el diseño; si no basta, probar `gemini-3.5-flash` |
| Batería de 500 mAh justa en charlas largas | Medirla; con una batería externa por USB-C graba sin límite |
| microSD de más de 16 GB | Usar tarjetas de hasta 16 GB (lo que indica M5Stack) |

## Fuentes

- [CoreS3 — documentación de M5Stack](https://docs.m5stack.com/en/core/CoreS3)
- [CoreS3 SE — documentación de M5Stack](https://docs.m5stack.com/en/core/M5CoreS3%20SE)
- [CoreS3 — tienda oficial de M5Stack](https://shop.m5stack.com/products/m5stack-cores3-esp32s3-iotdevelopment-kit)
- [Precios de la API de Gemini](https://ai.google.dev/gemini-api/docs/pricing)
