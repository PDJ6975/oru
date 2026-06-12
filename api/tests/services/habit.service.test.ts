import { isSameDay, subDays } from "date-fns";
import { afterAll, beforeEach, describe, expect, it } from "vitest";
import {
  HabitStatus,
  HabitType,
  WeekDay,
} from "../../src/generated/prisma/enums.js";
import * as habitService from "../../src/services/habit.service.js";
import {
  createTestUser,
  disconnect,
  getBaseUnit,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import {
  ALL_DAYS,
  daysExceptToday,
  seedCompletedDays,
  seedCompliance,
  seedHabit,
  today,
  todayCompliance,
} from "../helpers/factories.js";

describe("habit.service", () => {
  let user: TestUser;

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
  });

  afterAll(disconnect);

  it("getUserHabits filtra por estado y día programado", async () => {
    await seedHabit(user.userId); // activo, programado hoy
    await seedHabit(user.userId, { scheduledDays: daysExceptToday() }); // activo, descanso hoy
    await seedHabit(user.userId, { status: HabitStatus.ARCHIVED }); // archivado

    const active = await habitService.getUserHabits(
      user.userId,
      "active",
      "all",
    );
    expect(active).toHaveLength(2);

    const archived = await habitService.getUserHabits(
      user.userId,
      "archived",
      "all",
    );
    expect(archived).toHaveLength(1);

    const scheduledToday = await habitService.getUserHabits(
      user.userId,
      "active",
      "scheduled",
    );
    expect(scheduledToday).toHaveLength(1);

    const restToday = await habitService.getUserHabits(
      user.userId,
      "active",
      "rest",
    );
    expect(restToday).toHaveLength(1);
  });

  it("loadHabitsForTimer devuelve solo los hábitos compatibles con el temporizador", async () => {
    const min = await getBaseUnit("min");
    const hours = await getBaseUnit("h");
    const uds = await getBaseUnit("uds");
    const quantity = { type: HabitType.QUANTITY, dailyGoal: 30 };

    const valid1 = await seedHabit(user.userId, {
      ...quantity,
      unitId: min.id,
    });
    const valid2 = await seedHabit(user.userId, {
      ...quantity,
      unitId: hours.id,
    });
    await seedHabit(user.userId, { scheduledDays: ALL_DAYS }); // booleano
    await seedHabit(user.userId, { ...quantity, unitId: uds.id }); // unidad no temporal
    await seedHabit(user.userId, {
      ...quantity,
      unitId: min.id,
      scheduledDays: daysExceptToday(),
    }); // no programado hoy
    await seedHabit(user.userId, {
      ...quantity,
      unitId: min.id,
      status: HabitStatus.ARCHIVED,
    }); // archivado

    const result = await habitService.loadHabitsForTimer(user.userId);

    expect(result.map((h) => h.id).sort()).toEqual(
      [valid1.id, valid2.id].sort(),
    );
  });

  it("countHabitsByUnitId cuenta los hábitos de una unidad", async () => {
    const uds = await getBaseUnit("uds");
    const min = await getBaseUnit("min");
    const quantity = { type: HabitType.QUANTITY, dailyGoal: 5 };

    await seedHabit(user.userId, { ...quantity, unitId: uds.id });
    await seedHabit(user.userId, { ...quantity, unitId: uds.id });
    await seedHabit(user.userId, { ...quantity, unitId: min.id });

    expect(await habitService.countHabitsByUnitId(uds.id)).toBe(2);
  });

  it("crea, actualiza y elimina un hábito", async () => {
    const created = await habitService.createHabit(user.userId, {
      icon: "📖",
      name: "Leer",
      type: HabitType.BOOLEAN,
      scheduledDays: [WeekDay.MONDAY, WeekDay.WEDNESDAY],
    });
    expect(created.name).toBe("Leer");

    const updated = await habitService.updateHabit(user.userId, created.id, {
      name: "Leer más",
    });
    expect(updated.name).toBe("Leer más");

    await habitService.deleteHabit(user.userId, created.id);
    expect(await habitService.getHabitById(created.id)).toBeNull();
  });

  it("consolidateHabit marca el hábito como consolidado", async () => {
    const habit = await seedHabit(user.userId);

    const consolidated = await habitService.consolidateHabit(habit.id);

    expect(consolidated.isConsolidated).toBe(true);
  });

  it("archiveHabit archiva un hábito consolidado", async () => {
    const habit = await seedHabit(user.userId, { isConsolidated: true });

    await habitService.archiveHabit(user.userId, habit.id);

    const archived = await habitService.getHabitById(habit.id);
    expect(archived?.status).toBe(HabitStatus.ARCHIVED);
  });

  it("getEarliestHabitDate devuelve la fecha del hábito más antiguo", async () => {
    const earliest = subDays(today(), 5);
    await seedHabit(user.userId, { createdAt: earliest });
    await seedHabit(user.userId, { createdAt: subDays(today(), 2) });

    const result = await habitService.getEarliestHabitDate(user.userId);

    expect(result && isSameDay(result, earliest)).toBe(true);
  });

  it("getEarliestHabitDate devuelve null si el usuario no tiene hábitos", async () => {
    expect(await habitService.getEarliestHabitDate(user.userId)).toBeNull();
  });

  it("getUserHabitsWithCompliancesInRange devuelve las compliances del rango", async () => {
    const habit = await seedHabit(user.userId);
    await seedCompliance(habit.id, today(), true); // dentro del rango
    await seedCompliance(habit.id, subDays(today(), 10), true); // fuera del rango

    const result = await habitService.getUserHabitsWithCompliancesInRange(
      user.userId,
      subDays(today(), 3),
      today(),
    );

    expect(result).toHaveLength(1);
    expect(result[0].compliances).toHaveLength(1);
    expect(isSameDay(result[0].compliances[0].date, today())).toBe(true);
  });

  describe("toggleHabit", () => {
    it("booleano: desmarcar la compliance 66 la elimina y desconsolida", async () => {
      const habit = await seedHabit(user.userId, { isConsolidated: true });
      await seedCompletedDays(habit.id, 65);
      await seedCompliance(habit.id, today(), true); // la 66

      const result = await habitService.toggleHabit(user.userId, habit.id, 0);

      expect(todayCompliance(result!)).toBeUndefined();
      expect(result!.isConsolidated).toBe(false);
    });

    it("booleano: marcar la compliance 66 la crea y consolida", async () => {
      const habit = await seedHabit(user.userId);
      await seedCompletedDays(habit.id, 65);

      const result = await habitService.toggleHabit(user.userId, habit.id, 0);

      expect(todayCompliance(result!)).toBeDefined();
      expect(result!.isConsolidated).toBe(true);
    });

    it("cantidad: amount 0 borra la compliance", async () => {
      const uds = await getBaseUnit("uds");
      const habit = await seedHabit(user.userId, {
        type: HabitType.QUANTITY,
        dailyGoal: 5,
        unitId: uds.id,
      });
      await seedCompliance(habit.id, today(), true, 5);

      const result = await habitService.toggleHabit(user.userId, habit.id, 0);

      expect(todayCompliance(result!)).toBeUndefined();
    });

    it("cantidad: un amount menor al objetivo actualiza y descompleta", async () => {
      const uds = await getBaseUnit("uds");
      const habit = await seedHabit(user.userId, {
        type: HabitType.QUANTITY,
        dailyGoal: 20,
        unitId: uds.id,
      });
      await seedCompliance(habit.id, today(), true, 20);

      const result = await habitService.toggleHabit(user.userId, habit.id, 10);

      const compliance = todayCompliance(result!);
      expect(compliance?.recordedAmount).toBe(10);
      expect(compliance?.isCompleted).toBe(false);
    });

    it("cantidad: un amount que supera el objetivo crea y completa", async () => {
      const uds = await getBaseUnit("uds");
      const habit = await seedHabit(user.userId, {
        type: HabitType.QUANTITY,
        dailyGoal: 10,
        unitId: uds.id,
      });

      const result = await habitService.toggleHabit(user.userId, habit.id, 20);

      const compliance = todayCompliance(result!);
      expect(compliance?.recordedAmount).toBe(20);
      expect(compliance?.isCompleted).toBe(true);
    });
  });

  describe("recordSessionTime", () => {
    it("cantidad sin compliance: una sesión igual al objetivo crea y completa", async () => {
      const uds = await getBaseUnit("uds");
      const habit = await seedHabit(user.userId, {
        type: HabitType.QUANTITY,
        dailyGoal: 10,
        unitId: uds.id,
      });

      await habitService.recordSessionTime(habit.id, 10);

      const compliance = todayCompliance(
        (await habitService.getHabitById(habit.id))!,
      );
      expect(compliance?.recordedAmount).toBe(10);
      expect(compliance?.isCompleted).toBe(true);
    });

    it("unidad en horas: convierte los minutos de la sesión a horas", async () => {
      const hours = await getBaseUnit("h");
      const habit = await seedHabit(user.userId, {
        type: HabitType.QUANTITY,
        dailyGoal: 30,
        unitId: hours.id,
      });
      await seedCompliance(habit.id, today(), true, 30);

      await habitService.recordSessionTime(habit.id, 30);

      const compliance = todayCompliance(
        (await habitService.getHabitById(habit.id))!,
      );
      expect(compliance?.recordedAmount).toBeCloseTo(30.5);
      expect(compliance?.isCompleted).toBe(true);
    });
  });
});
