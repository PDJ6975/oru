import { previousMonday, startOfDay, subDays, subWeeks } from "date-fns";
import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { prisma } from "../../src/db/prisma.js";
import { WeekDay } from "../../src/generated/prisma/enums.js";
import * as statsService from "../../src/services/stats.service.js";
import {
  createTestUser,
  disconnect,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import { seedCompliance, seedHabit, today } from "../helpers/factories.js";

const YEAR = new Date().getFullYear();
const day = (n: number) => subDays(today(), n); // hace n días (a las 00:00)

describe("stats.service · getStats", () => {
  let user: TestUser;

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
  });

  afterAll(disconnect);

  it("consolida y persiste las estadísticas de los días cerrados", async () => {
    const habit = await seedHabit(user.userId, { createdAt: day(3) });
    // Tres días consecutivos completados (anteayer-2,...,ayer).
    for (const n of [3, 2, 1]) {
      await seedCompliance(habit.id, day(n), true);
    }

    const stats = await statsService.getStats(user.userId, YEAR);

    expect(stats.habitStats[0].currentStreak).toBe(3);
    expect(stats.habitStats[0].bestStreak).toBe(3);
    expect(stats.habitStats[0].totalCompletions).toBe(3);
    expect(stats.userStats.perfectDays).toBe(3);

    const persisted = await prisma.habitStats.findFirstOrThrow({
      where: { habitId: habit.id, year: YEAR },
    });
    expect(persisted.totalCompletions).toBe(3);
    const refreshed = await prisma.user.findUniqueOrThrow({
      where: { id: user.userId },
    });
    expect(refreshed.lastComputedDay).toEqual(startOfDay(day(1)));
  });

  it("una segunda llamada no recalcula los días ya consolidados", async () => {
    const habit = await seedHabit(user.userId, { createdAt: day(3) });
    for (const n of [3, 2, 1]) {
      await seedCompliance(habit.id, day(n), true);
    }

    const first = await statsService.getStats(user.userId, YEAR);
    const second = await statsService.getStats(user.userId, YEAR);

    expect(second.habitStats[0].totalCompletions).toBe(
      first.habitStats[0].totalCompletions,
    );
    expect(second.habitStats[0].currentStreak).toBe(3);
  });

  it("PA-001 - distingue la mejor racha de la actual y no rompe por el día en curso", async () => {
    const habit = await seedHabit(user.userId, { createdAt: day(7) });
    // Racha de 4 (-7…-4), ruptura en -3 (sin compliance), racha actual de 2 (-2,-1).
    for (const n of [7, 6, 5, 4, 2, 1]) {
      await seedCompliance(habit.id, day(n), true);
    }
    // Hoy está programado (ALL_DAYS) pero sin completar: no debe romper la racha.

    const stats = await statsService.getStats(user.userId, YEAR);

    expect(stats.habitStats[0].bestStreak).toBe(4);
    expect(stats.habitStats[0].currentStreak).toBe(2);
    expect(stats.habitStats[0].totalCompletions).toBe(6);
  });

  it("PA-002 - ignora los días no programados al calcular la racha global", async () => {
    const monday3 = startOfDay(previousMonday(new Date())); // último lunes pasado
    const monday2 = subWeeks(monday3, 1);
    const monday1 = subWeeks(monday3, 2);

    const habit = await seedHabit(user.userId, {
      scheduledDays: [WeekDay.MONDAY],
      createdAt: monday1,
    });
    for (const monday of [monday1, monday2, monday3]) {
      await seedCompliance(habit.id, monday, true);
    }

    const stats = await statsService.getStats(user.userId, YEAR);

    expect(stats.userStats.currentStreak).toBe(3);
    expect(stats.userStats.bestStreak).toBe(3);
    expect(stats.userStats.perfectDays).toBe(3);
    expect(stats.habitStats[0].currentStreak).toBe(3);
  });

  it("yearActivity es [] si el año pedido es anterior al primer hábito", async () => {
    await seedHabit(user.userId, { createdAt: day(3) });

    const stats = await statsService.getStats(user.userId, YEAR - 1);

    expect(stats.yearActivity).toEqual([]);
  });

  it("yearActivity del año en curso termina en hoy y no incluye días futuros", async () => {
    await seedHabit(user.userId, { createdAt: day(3) });

    const stats = await statsService.getStats(user.userId, YEAR);
    const last = stats.yearActivity.at(-1);

    expect(last).toBeDefined();
    expect(last!.date).toEqual(today());
    expect(
      stats.yearActivity.every((entry) => entry.date <= today()),
    ).toBe(true);
  });
});
