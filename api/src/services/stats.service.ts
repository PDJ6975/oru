import { addDays, startOfDay } from "date-fns";
import type {
  HabitStats,
  Prisma,
  UserStats,
} from "../generated/prisma/client.js";
import type { WeekDay } from "../generated/prisma/enums.js";
import * as statsRepository from "../repositories/stats.repository.js";
import type {
  DayActivityDto,
  HabitStatsComp,
  Stats,
  UserStatsComp,
} from "../types/stats.types.js";
import { toDtoStats } from "../utils/stats.mapper.js";
import { getComplianceForDay } from "../utils/today.compliances.js";
import { toWeekDay } from "../utils/weekday.js";
import * as habitService from "./habit.service.js";
import * as userService from "./user.service.js";

export type HabitWithData = Prisma.HabitGetPayload<{
  include: {
    scheduledDays: true;
    compliances: true;
    unit: { select: { name: true } };
  };
}>;

type HabitStatsAcc = Map<string, HabitStatsComp>; // `${habitId}-${year}` -> stats
type UserStatsAcc = Map<number, UserStatsComp>; // year -> stats
type DbHabitMap = Map<string, HabitStats>; // `${habitId}-${year}` -> fila BD
type DbUserMap = Map<number, UserStats>; // year -> fila BD

const habitKey = (habitId: number, year: number) => `${habitId}-${year}`;

const isHabitActiveOn = (habit: HabitWithData, day: Date): boolean => {
  const createdDay = startOfDay(habit.createdAt);
  const archivedDay = habit.archivedAt ? startOfDay(habit.archivedAt) : null;
  return archivedDay
    ? createdDay <= day && day <= archivedDay
    : createdDay <= day;
};

const isHabitScheduledOn = (habit: HabitWithData, weekDay: WeekDay): boolean =>
  habit.scheduledDays.some((sd) => sd.day === weekDay);

// ── Punto de entrada ────────────────────────────────────────────────────────
// 1. Consolida los días ya cerrados (hasta ayer) y avanza el puntero.
// 2. Devuelve las stats del año pedido, con overlay del día de hoy si es el año actual.
export const getStats = async (
  userId: number,
  year: number,
): Promise<Stats> => {
  const user = await userService.getUserById(userId);
  const today = startOfDay(new Date());
  const yesterday = addDays(today, -1);

  // Si hay puntero, desde el día siguiente; si es nuevo, desde el primer hábito (o null).
  const lastComputedDay = user!.lastComputedDay;
  const from = lastComputedDay
    ? addDays(startOfDay(lastComputedDay), 1)
    : await habitService.getEarliestHabitDate(userId);

  // 1. Consolidar la ventana [from … ayer]
  if (from && from <= yesterday) {
    await consolidate(userId, from, yesterday, today);
    await userService.updateLastComputedDay(userId, yesterday);
  }

  // 2. Métricas del año + serie del mapa anual
  const [summary, yearActivity] = await Promise.all([
    readYear(userId, year, today),
    buildYearActivity(userId, year, today),
  ]);
  return { ...summary, yearActivity };
};

// ── Consolidación: calcula la franja y la persiste ───────────────────────────
const consolidate = async (
  userId: number,
  from: Date,
  to: Date,
  today: Date,
) => {
  const habits = await habitService.getUserHabitsWithCompliancesInRange(
    userId,
    from,
    to,
  );
  const { dbHabitMap, dbUserMap } = await loadDbMaps(userId);

  const habitStatsAcc: HabitStatsAcc = new Map();
  const userStatsAcc: UserStatsAcc = new Map();

  accumulateRange(
    habits,
    from,
    to,
    today,
    habitStatsAcc,
    userStatsAcc,
    dbHabitMap,
    dbUserMap,
  );

  await persistStats(userId, habitStatsAcc, userStatsAcc);
};

// ── Lectura de un año (con overlay de hoy si es el año actual) ────────────────
const readYear = async (userId: number, year: number, today: Date) => {
  const habits = await habitService.getUserHabitsWithCompliancesInRange(
    userId,
    today,
    today,
  );
  const { dbHabitMap, dbUserMap } = await loadDbMaps(userId);

  const habitStatsAcc: HabitStatsAcc = new Map();
  const userStatsAcc: UserStatsAcc = new Map();

  // Sembrar la base consolidada del año
  seedYearBase(
    year,
    habits,
    dbHabitMap,
    dbUserMap,
    habitStatsAcc,
    userStatsAcc,
  );

  // Overlay del día de hoy solo si se pide el año en curso (no se persiste)
  if (year === today.getFullYear()) {
    accumulateRange(
      habits,
      today,
      today,
      today,
      habitStatsAcc,
      userStatsAcc,
      dbHabitMap,
      dbUserMap,
    );
  }

  return toDtoStats(userStatsAcc.get(year) ?? null, [
    ...habitStatsAcc.values(),
  ]);
};

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

// ── Lógica del cálculo: muta los acumuladores con la franja [from, to] ──────
const accumulateRange = (
  habits: HabitWithData[],
  from: Date,
  to: Date,
  today: Date,
  habitStatsAcc: HabitStatsAcc,
  userStatsAcc: UserStatsAcc,
  dbHabitMap: DbHabitMap,
  dbUserMap: DbUserMap,
) => {
  for (let day = from; day <= to; day = addDays(day, 1)) {
    const year = day.getFullYear();
    const weekDay = toWeekDay(day);
    let dayScheduled = 0;
    let dayCompleted = 0;

    for (const habit of habits) {
      // Si no estaba activo ni programado ese día, no afecta a sus stats
      if (!isHabitActiveOn(habit, day) || !isHabitScheduledOn(habit, weekDay)) {
        continue;
      }

      dayScheduled++;
      const h = getOrInitHabitStatsAcc(habitStatsAcc, habit, year, dbHabitMap);
      const compliance = getComplianceForDay(habit.compliances, day);

      // Acumulación de cantidad: cuenta toda actividad registrada, completada o no
      if (compliance?.recordedAmount != null) {
        h.totalAccumulation += compliance.recordedAmount;
        h.recordedDays++;
      }

      if (compliance?.isCompleted) {
        h.totalCompletions++;
        h.currentStreak++;
        h.bestStreak = Math.max(h.bestStreak, h.currentStreak);
        dayCompleted++;
      } else if (day < today) {
        // Hoy no rompe la racha porque el día aún no ha terminado
        h.currentStreak = 0;
      }
    }

    // Métricas globales del día
    const u = getOrInitUserStatsAcc(userStatsAcc, year, dbUserMap);
    u.habitsCompleted += dayCompleted;
    u.totalScheduled += dayScheduled;
    if (dayScheduled > 0 && dayScheduled === dayCompleted) {
      u.perfectDays++;
      u.currentStreak++;
      u.bestStreak = Math.max(u.bestStreak, u.currentStreak);
    } else if (dayScheduled > 0 && day < today) {
      u.currentStreak = 0;
    }
    // Los días sin nada programado no rompen la racha global
  }
};

// ── Persistencia ─────────────────────────────
const persistStats = async (
  userId: number,
  habitStatsAcc: HabitStatsAcc,
  userStatsAcc: UserStatsAcc,
) => {
  await Promise.all([
    ...[...habitStatsAcc.entries()].map(([key, c]) => {
      const [habitId, year] = key.split("-").map(Number);
      return statsRepository.upsertHabitStats(habitId, year, {
        currentStreak: c.currentStreak,
        bestStreak: c.bestStreak,
        totalCompletions: c.totalCompletions,
        totalAccumulation: c.totalAccumulation,
        recordedDays: c.recordedDays,
      });
    }),
    ...[...userStatsAcc.entries()].map(([year, c]) =>
      statsRepository.upsertUserStats(userId, year, c),
    ),
  ]);
};

// ── Carga de filas previas para inicializar acumuladores ─────────────────────
const loadDbMaps = async (userId: number) => {
  const [dbHabitStats, dbUserStats] = await Promise.all([
    statsRepository.getHabitStatsByUser(userId),
    statsRepository.getUserStatsByUser(userId),
  ]);
  const dbHabitMap: DbHabitMap = new Map(
    dbHabitStats.map((s) => [habitKey(s.habitId, s.year), s]),
  );
  const dbUserMap: DbUserMap = new Map(dbUserStats.map((s) => [s.year, s]));
  return { dbHabitMap, dbUserMap };
};

// Siembra el acumulador con la base consolidada de un año (todos sus hábitos)
const seedYearBase = (
  year: number,
  habits: HabitWithData[],
  dbHabitMap: DbHabitMap,
  dbUserMap: DbUserMap,
  habitStatsAcc: HabitStatsAcc,
  userStatsAcc: UserStatsAcc,
) => {
  const habitInfo = new Map(habits.map((h) => [h.id, h]));

  for (const [key, row] of dbHabitMap) {
    if (row.year !== year) continue;
    const info = habitInfo.get(row.habitId);
    if (!info) continue;
    habitStatsAcc.set(key, {
      habitId: row.habitId,
      habitName: info.name,
      habitIcon: info.icon,
      habitType: info.type,
      habitStatus: info.status,
      habitUnit: info.unit?.name ?? null,
      currentStreak: row.currentStreak,
      bestStreak: row.bestStreak,
      totalCompletions: row.totalCompletions,
      totalAccumulation: row.totalAccumulation ?? 0,
      recordedDays: row.recordedDays,
    });
  }

  const userRow = dbUserMap.get(year);
  if (userRow) {
    userStatsAcc.set(year, {
      currentStreak: userRow.currentStreak,
      bestStreak: userRow.bestStreak,
      habitsCompleted: userRow.habitsCompleted,
      perfectDays: userRow.perfectDays,
      totalScheduled: userRow.totalScheduled,
    });
  }
};

// ── getOrInit: inicializa desde la fila de BD (o ceros) ──────────────────────
const getOrInitHabitStatsAcc = (
  acc: HabitStatsAcc,
  habit: HabitWithData,
  year: number,
  dbMap: DbHabitMap,
): HabitStatsComp => {
  const key = habitKey(habit.id, year);
  if (!acc.has(key)) {
    const prev = dbMap.get(key);
    acc.set(key, {
      habitId: habit.id,
      habitName: habit.name,
      habitIcon: habit.icon,
      habitType: habit.type,
      habitStatus: habit.status,
      habitUnit: habit.unit?.name ?? null,
      currentStreak: prev?.currentStreak ?? 0,
      bestStreak: prev?.bestStreak ?? 0,
      totalCompletions: prev?.totalCompletions ?? 0,
      totalAccumulation: prev?.totalAccumulation ?? 0,
      recordedDays: prev?.recordedDays ?? 0,
    });
  }
  return acc.get(key)!;
};

const getOrInitUserStatsAcc = (
  acc: UserStatsAcc,
  year: number,
  dbMap: DbUserMap,
): UserStatsComp => {
  if (!acc.has(year)) {
    const prev = dbMap.get(year);
    acc.set(year, {
      currentStreak: prev?.currentStreak ?? 0,
      bestStreak: prev?.bestStreak ?? 0,
      habitsCompleted: prev?.habitsCompleted ?? 0,
      perfectDays: prev?.perfectDays ?? 0,
      totalScheduled: prev?.totalScheduled ?? 0,
    });
  }
  return acc.get(year)!;
};
