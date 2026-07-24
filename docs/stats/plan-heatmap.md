# Plan — Calendario anual de actividad (mapa de calor estilo GitHub)

## Objetivo

Añadir al endpoint `GET /stats` una **serie diaria** que alimente el mapa de calor anual
del cliente (`YearHeatmapView`): por cada día del año, cuántos hábitos estaban
programados y cuántos se completaron. Con eso, el cliente pinta cada celda:

| Estado                                   | Regla (en el cliente)          | Color        |
| ---------------------------------------- | ------------------------------ | ------------ |
| Descanso (nada programado)               | `scheduled == 0`               | gris oscuro  |
| Sin completar / futuro                   | `scheduled > 0 && completed == 0`, o día ausente | gris claro |
| Parcial                                  | `0 < completed < scheduled`    | azul claro   |
| Completo                                 | `completed >= scheduled`       | azul oscuro  |

El backend **no** envía colores ni niveles: solo la terna `{ date, scheduled, completed }`
por día. Toda la semántica visual ya vive en `YearHeatmapView.CellLevel`.

## Decisión de diseño (acordada)

**Se calcula al vuelo y se envía en la respuesta; no se persiste ni se toca el modelo.**

Razones:

1. Es un **derivado puro**, igual que `complianceRate`, `dailyAverage` y `score`, que el
   mapper ya calcula al vuelo. Encaja con la convención existente.
2. **Cero migración, cero tabla, cero cambio en la maquinaria de consolidación** (que es
   delicada). Se añade como una función aislada y aditiva.
3. **Sin riesgo de desincronización**: si el usuario cambia `scheduledDays`, archiva o
   borra un hábito, el mapa siempre refleja el estado actual. Persistir por día congelaría
   los valores y multiplicaría por 365 la incoherencia latente de los agregados anuales.
4. **Volumen trivial**: ≤366 objetos diminutos por año.

Persistir a nivel de modelo se pospone a una iteración futura y solo si un problema de
rendimiento *medido* lo justifica (ver §Rendimiento).

### Sub-decisiones confirmadas

- **Ubicación de la serie**: dentro de `GET /stats`, campo nuevo `yearActivity` del DTO.
- **Rango de días**: `[max(1-ene, primer hábito) … min(hoy, 31-dic)]`. Los días futuros no
  se incluyen (el cliente los pinta gris claro). Los días con `scheduled == 0` **sí** se
  incluyen (descanso). Un periodo sin ningún hábito activo sale como descanso: aceptado.
- **Coherencia con las métricas**: se reutiliza la condición `isActive && isScheduled` de
  `accumulateRange` extrayendo dos helpers puros usados en ambos sitios.
- **Formato de fecha**: `Date` serializada por Express (ISO 8601, ver §Zona horaria).
- **Rendimiento**: cálculo ingenuo reutilizando `getComplianceForDay`. Guard `from > to`
  antes de la query para cortocircuitar años vacíos.

## Contrato de la API

`GET /stats?year=YYYY` pasa a devolver:

```jsonc
{
  "userStats":   { /* … igual que ahora … */ },
  "habitStats":  [ /* … igual que ahora … */ ],
  "yearActivity": [
    { "date": "2026-01-01T00:00:00.000Z", "scheduled": 3, "completed": 3 },
    { "date": "2026-01-02T00:00:00.000Z", "scheduled": 0, "completed": 0 },
    // … un elemento por día del rango, en orden ascendente …
  ]
}
```

`yearActivity` va **ordenado por fecha ascendente** (orden de recorrido).

---

## Cambios en el backend

### 1. `src/types/stats.types.ts`

Ampliar la interfaz `Stats` con la serie y añadir `DayActivityDto`:

```ts
// Actividad de un día del calendario anual (mapa de calor). Derivado efímero:
// se calcula al vuelo en cada lectura y no se persiste.
export interface DayActivityDto {
  date: Date; // se serializa a ISO 8601 en la respuesta
  scheduled: number; // hábitos activos y programados ese día
  completed: number; // de esos, cuántos se completaron
}

// Respuesta completa de GET /stats: métricas + serie diaria del mapa anual.
export interface Stats {
  userStats: UserStatsDto;
  habitStats: HabitStatsDto[];
  yearActivity: DayActivityDto[];
}
```

### 2. `src/utils/stats.mapper.ts`

`toDtoStats` sigue construyendo **solo las métricas** (`{ userStats, habitStats }`); la
serie se añade después, en `getStats`. Como ya no produce el objeto completo, se le quita
la anotación de retorno `: Stats` (TypeScript infiere el parcial y `getStats` valida el
contrato al componer) y se deja de importar `Stats`:

```ts
import type { HabitStatsComp, UserStatsComp } from "../types/stats.types.js";

export const toDtoStats = (
  userStats: UserStatsComp | null,
  habitStats: HabitStatsComp[],
) => {
  // … cuerpo idéntico al actual …
};
```

### 3. `src/services/stats.service.ts`

**3.1. Imports nuevos**

```ts
import type { DayActivityDto, Stats } from "../types/stats.types.js";
import type { WeekDay } from "../generated/prisma/enums.js";
```

**3.2. Helpers puros extraídos** (junto a `habitKey`), reutilizados por `accumulateRange`
y por `buildYearActivity`:

```ts
// Un hábito está activo un día si ya se había creado y aún no se había archivado.
// Se normaliza a startOfDay porque createdAt/archivedAt llevan hora y `day` es medianoche.
const isHabitActiveOn = (habit: HabitWithData, day: Date): boolean => {
  const createdDay = startOfDay(habit.createdAt);
  const archivedDay = habit.archivedAt ? startOfDay(habit.archivedAt) : null;
  return archivedDay
    ? createdDay <= day && day <= archivedDay
    : createdDay <= day;
};

const isHabitScheduledOn = (habit: HabitWithData, weekDay: WeekDay): boolean =>
  habit.scheduledDays.some((sd) => sd.day === weekDay);
```

**3.3. Refactor de `accumulateRange`** — sustituir el bloque de cálculo de `isActive` /
`isScheduled` (actuales líneas 144-156) por:

```ts
    for (const habit of habits) {
      // Si no estaba activo ni programado ese día, no afecta a sus stats
      if (!isHabitActiveOn(habit, day) || !isHabitScheduledOn(habit, weekDay)) {
        continue;
      }

      dayScheduled++;
      // … resto igual (getOrInitHabitStatsAcc, compliance, rachas) …
```

**3.4. Nueva función `buildYearActivity`** (exportada, para poder testearla en aislado):

```ts
// ── Serie diaria del mapa anual (derivado efímero, no se persiste) ───────────
// Recorre [max(1-ene, primer hábito) … min(hoy, 31-dic)] y cuenta, por día,
// hábitos programados y completados. Reutiliza la misma condición que las métricas.
export const buildYearActivity = async (
  userId: number,
  year: number,
  today: Date,
): Promise<DayActivityDto[]> => {
  const yearStart = startOfDay(new Date(year, 0, 1));
  const yearEnd = startOfDay(new Date(year, 11, 31));

  const earliest = await habitService.getEarliestHabitDate(userId);
  if (!earliest) return [];

  const from = earliest > yearStart ? earliest : yearStart;
  const to = today < yearEnd ? today : yearEnd; // nunca incluir días futuros
  if (from > to) return []; // año anterior al primer hábito

  const habits = await habitService.getUserHabitsWithCompliancesInRange(
    userId,
    from,
    to,
  );

  const series: DayActivityDto[] = [];
  for (let day = from; day <= to; day = addDays(day, 1)) {
    const weekDay = toWeekDay(day);
    let scheduled = 0;
    let completed = 0;

    for (const habit of habits) {
      if (!isHabitActiveOn(habit, day) || !isHabitScheduledOn(habit, weekDay)) {
        continue;
      }
      scheduled++;
      if (getComplianceForDay(habit.compliances, day)?.isCompleted) {
        completed++;
      }
    }

    series.push({ date: day, scheduled, completed });
  }

  return series;
};
```

**3.5. Composición en `getStats`** — tras la consolidación, añadir la serie a la
respuesta. `readYear` y `buildYearActivity` son lecturas independientes → en paralelo:

```ts
export const getStats = async (
  userId: number,
  year: number,
): Promise<Stats> => {
  const user = await userService.getUserById(userId);
  const today = startOfDay(new Date());
  const yesterday = addDays(today, -1);

  const lastComputedDay = user!.lastComputedDay;
  const from = lastComputedDay
    ? addDays(startOfDay(lastComputedDay), 1)
    : await habitService.getEarliestHabitDate(userId);

  // 1. Consolidar la ventana [from … ayer]
  if (from && from <= yesterday) {
    await consolidate(userId, from, yesterday, today);
    await userService.updateLastComputedDay(userId, yesterday);
  }

  // 2. Métricas del año + serie del mapa anual (lecturas independientes)
  const [summary, yearActivity] = await Promise.all([
    readYear(userId, year, today),
    buildYearActivity(userId, year, today),
  ]);
  return { ...summary, yearActivity };
};
```

> Nota: `buildYearActivity` carga los hábitos por su cuenta (una query extra respecto a
> `readYear`, que solo carga hoy). Se acepta por claridad; fusionar ambas cargas queda
> como posible optimización futura si importara.

Ningún otro archivo cambia: `stats.controller.ts` ya hace `res.json(stats)`,
`stats.routes.ts` y `stats.validator.ts` siguen igual (el validador ya acota
`year ∈ [1900, año actual]`).

---

## Zona horaria (riesgo preexistente, **no** se resuelve aquí)

El día se calcula con `startOfDay`/`new Date(year, …)` en la **zona del servidor**
(el entorno actual es `Europe/Madrid`, no UTC). Al serializar, un día se emite como su
instante UTC (p. ej. medianoche en Madrid → `…T22:00:00.000Z` en verano). El cliente lo
decodifica con `Date.ISO8601FormatStyle(includingFractionalSeconds: true)` (ya soportado)
y extrae mes/día con `Calendar.current` (zona del dispositivo).

- Si dispositivo y servidor comparten zona → el día coincide.
- Si difieren, un día puede desplazarse. **Es exactamente el mismo comportamiento que ya
  tienen los `Compliance`** (el toggle guarda `startOfDay` del servidor), así que el mapa
  es internamente consistente con el resto de la app.

Recomendación (fuera de alcance): desplegar producción con `TZ=UTC` para que
«día servidor == día UTC». Endurecer el contrato de fechas es un trabajo transversal aparte.

---

## Rendimiento

- **Años vacíos** (pedir un año anterior al primer hábito): el guard `from > to` devuelve
  `[]` **sin** consultar compliances (solo el `getEarliestHabitDate`, trivial).
- **Año completo** (año pasado): rango de hasta 365 días. La query trae `nº hábitos × ≤365`
  filas pequeñas, indexadas por `Compliance.@@unique([habitId, date])`. El recorrido es
  `365 × nº hábitos`. Coste real: decenas de ms en el peor caso realista.
- El `find` lineal de `getComplianceForDay` dentro del doble bucle es cuadrático en
  teoría, pero con volúmenes reales (miles de filas) es imperceptible. **Se deja ingenuo**
  (KISS). Si algún día hiciera falta, se pre-indexan los compliances por día en un `Map`
  (lookup O(1), ~3 líneas) — iteración futura.

---

## Pruebas

La lógica de conteo que reutiliza `buildYearActivity` (`isHabitActiveOn`,
`isHabitScheduledOn`, `getComplianceForDay`) ya la cubren las pruebas de `getStats`
(`PA-001`, `PA-002`, consolidación…), que además validan el refactor de
`accumulateRange` al mantenerse en verde. `buildYearActivity` solo reexpone ese mismo
cálculo día a día.

Además se añaden **dos casos de frontera** en `tests/services/stats.service.test.ts`:

1. Año anterior al primer hábito → `yearActivity === []` (guard `from > to`).
2. Año en curso: el último elemento es hoy y no hay fechas posteriores
   (`to = min(hoy, 31-dic)`).

---

## Seguimiento en el cliente iOS

Conectado al endpoint:

1. [x] `DayActivityDTO: Decodable` con `date`, `scheduled`, `completed` (ISO 8601 vía `APIClient`).
2. [x] `let yearActivity: [DayActivityDTO]` en `StatsDTO`.
3. [x] En `StatsViewModel.apply`, `yearActivity = stats.yearActivity`; eliminados mock y
   datos simulados (`DayActivity.mock`, `SeededGenerator`). `YearHeatmapView` consume
   `[DayActivityDTO]` directamente.

---

## Checklist de implementación

- [x] `stats.types.ts`: `DayActivityDto` + campo `yearActivity` en `Stats`.
- [x] `stats.mapper.ts`: quitar anotación de retorno `: Stats` (y su import).
- [x] `stats.service.ts`: imports (`DayActivityDto`, `Stats`, `WeekDay`).
- [x] `stats.service.ts`: helpers `isHabitActiveOn` / `isHabitScheduledOn`.
- [x] `stats.service.ts`: refactor de `accumulateRange` para usar los helpers.
- [x] `stats.service.ts`: `buildYearActivity`.
- [x] `stats.service.ts`: composición en `getStats` (`Promise.all` + spread).
- [x] Fronteras de `yearActivity` en `stats.service.test.ts` (año vacío + sin días futuros).
- [x] `npm test` en verde (las pruebas actuales de `getStats` validan el refactor de `accumulateRange`).
- [x] Cliente iOS: `DayActivityDTO` + `yearActivity` en `StatsDTO` / `StatsViewModel` / `YearHeatmapView`.

## Fuera de alcance / iteraciones futuras

- Pre-indexar compliances por día si el rendimiento lo pidiera.
- Distinguir «sin hábitos activos» de «descanso» (hoy ambos son gris oscuro).
- Persistir la serie a nivel de modelo (solo si se mide un cuello de botella).
- Endurecer el contrato de fechas / zona horaria (transversal a toda la app).
