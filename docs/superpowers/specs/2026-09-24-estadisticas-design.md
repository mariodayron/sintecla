# Estadísticas — Diseño

- **Estado:** diseño aprobado por el usuario el 2026-09-24.
- **Relación con la spec principal:** `docs/superpowers/specs/2026-09-23-sintecla-design.md` (§7 Interfaz: ventana Sintecla; §8 Datos; §12 Fases).
- **Versión:** 0.7.0.

## 1. Objetivo

Hoy, arriba del Historial, hay 5 cifras (hoy, 7 días, total, palabras por minuto y minutos ahorrados), calculadas con el historial. Como el historial se recorta a las **últimas 500 entradas** al arrancar, «Total» y «Min ahorrados» no son totales de verdad. Con esta pieza:

1. **Totales de verdad:** un resumen por día que no se recorta.
2. **Evolución en el tiempo:** gráfica, racha, tiempo ahorrado acumulado y mejor día.
3. **Dónde y cómo dictas:** reparto por app y por modo.

Todo en una sección nueva de la ventana, **Estadísticas**.

No-objetivos: rendimiento y calidad (latencia, motor usado, Gemini, palabras aprendidas); contar las reuniones (no las dictas tú y ya tienen su lista); exportar datos; cambiar el recorte del historial (sigue en 500).

## 2. Qué cuenta

- **Un uso** es cada entrada que se guarda en el historial: dictado, traducción, Ask y notas.
- **Palabras de un uso:** las del texto final (lo pegado). En **Ask** cuentan las de lo que dijiste (`rawText`), porque la respuesta no la escribes tú.
- **Minutos hablando:** la duración del audio (`audioSeconds`).
- **Día:** el día natural en la zona horaria del Mac en el momento del uso.
- Las reuniones no cuentan.

## 3. El resumen (`UsageStats`, núcleo)

- Por cada día: palabras, segundos de audio y número de usos, en total y repartidos **por app** (bundle id) y **por modo**.
- Nombre de cada app: el último conocido para su bundle id. Sin bundle id → «Otra».
- **Solo números:** nunca texto dictado.
- **Archivo:** `~/Library/Application Support/Sintecla/stats.json`. Pesa unos pocos KB al año y no se recorta nunca.
- **Al guardar una entrada en el historial** se suma también al resumen, en el mismo sitio del código (`DictationController`, donde hoy se llama a `history.append`).
- **Primera vez** (no existe `stats.json`): se rellena con todo lo que haya en el historial **antes** de recortarlo al arrancar, y se guarda. Desde ahí, «desde el …» es la fecha del uso más antiguo.
- Si `stats.json` está roto al leerlo: se aparta como `stats.json.roto` y se rehace con el historial, como la primera vez.

## 4. Cifras

| Cifra | Cálculo |
|---|---|
| **Hoy** | Palabras de hoy |
| **Racha** | Días seguidos con al menos un uso, contando hacia atrás desde hoy; si hoy aún no hay usos, desde ayer. Debajo, el **récord** (la racha más larga de todas) |
| **Tiempo ahorrado** | max(0, palabras totales ÷ 40 − minutos hablando totales), en «X h Y min» (40 palabras por minuto es lo que se tardaría tecleando) |
| **Mejor día** | El día con más palabras, con su fecha |
| **Pie** | Palabras por minuto al dictar (palabras totales ÷ minutos hablando) y palabras en total; y «desde el …» con el número de usos |

## 5. Gráfica

- Barras de palabras, con un selector de tres escalas:
  - **Días:** los últimos 30 días, hoy incluido.
  - **Semanas:** las últimas 12 semanas, de lunes a domingo.
  - **Meses:** los últimos 12 meses.
- Los periodos sin usos salen a cero.
- La barra del periodo con más palabras va más oscura.
- Swift Charts (`Charts.framework`, está en el SDK de las Command Line Tools), en grises.

## 6. Reparto por app y por modo

- Selector de periodo común: **7 días**, **30 días** (por defecto) o **Siempre**.
- **Por app:** las 5 con más palabras y «Otras» con el resto, con barra y porcentaje.
- **Por modo:** Dictado, Traducir, Ask y Notas, con barra y porcentaje. Los modos sin palabras no salen.
- Sin usos en el periodo → «Aún no hay dictados en este periodo».

## 7. Interfaz

- Nueva sección **Estadísticas** en la barra lateral de la ventana Sintecla, con icono de gráfica, entre Historial y Ajustes.
- Orden de la página: título con «desde el …», las 4 cifras (§4), la gráfica (§5), el selector de periodo y los dos repartos (§6), y el pie.
- Mismo estilo que el resto de la ventana: blanco, negro y grises.
- Se recarga al abrir la sección y cuando llega un uso nuevo.
- La fila de 5 cifras de arriba del **Historial desaparece**: el Historial queda con el buscador y la lista.

## 8. Piezas

| Pieza | Target | Qué hace |
|---|---|---|
| `UsageStats` | Core | Resumen por día (por app y por modo), sumar un uso, rellenar desde el historial, cifras (§4), series de la gráfica (§5) y repartos (§6). Puro y Codable. |
| `UsageStatsStore` | Core | Leer y guardar `stats.json`; rehacerlo si falta o está roto |
| `AppPaths.statsURL` | Core | Ruta de `stats.json` |
| `DictationController` | App | Rellenar antes de recortar el historial; sumar cada uso nuevo |
| `StatsView` | App | La página (§7), con Swift Charts |
| `MainWindow` | App | Sección «Estadísticas» en la barra lateral |
| `HistoryView` | App | Sin la fila de cifras |
| `AppInfo`, `SmokeTests` | Core / tests | Versión 0.7.0 |

`HistoryStore.stats` y `HistoryStats` dejan de usarse y se quitan.

## 9. Pruebas

- **Tests automáticos** (`swift run sintecla-tests`):
  - Sumar usos: por día, por app y por modo; Ask cuenta `rawText`; «Otra» sin bundle id.
  - Rellenar desde un historial: mismo resultado que sumarlos uno a uno.
  - Racha con hoy, sin hoy, con un hueco, y el récord.
  - Tiempo ahorrado, que nunca es negativo; mejor día; palabras por minuto.
  - Series: 30 días, 12 semanas de lunes a domingo y 12 meses, con ceros.
  - Repartos: top 5 más «Otras», porcentajes y periodos.
  - `stats.json`: ida y vuelta; falta o roto → se rehace con el historial y se aparta el roto.
- **Aceptación a mano:**
  1. Al abrir la 0.7.0, Estadísticas enseña los datos del historial que había, con su «desde el …».
  2. Dictar algo: suben Hoy, la gráfica y el reparto de esa app al volver a la sección.
  3. Cambiar Días, Semanas y Meses, y 7 días, 30 días y Siempre.
  4. Tras más de 500 usos, el total sigue creciendo (no se queda en lo que cabe en el historial).
  5. El Historial ya no tiene la fila de cifras y lo demás funciona igual.

## 10. Riesgos

| Riesgo | Mitigación |
|---|---|
| Lo dictado antes de la 0.7.0 que ya se recortó del historial no se puede recuperar | Se dice «desde el …» con la primera fecha que hay |
| `stats.json` se estropea | Se aparta y se rehace con el historial (se pierde lo que ya no esté en él) |
| Cambio de zona horaria | Cada uso se apunta en el día local de ese momento; no se recoloca después |
