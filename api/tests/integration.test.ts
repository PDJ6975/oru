import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { prisma } from "../src/db/prisma.js";
import { HabitType } from "../src/generated/prisma/enums.js";
import * as habitService from "../src/services/habit.service.js";
import * as origamiService from "../src/services/origami.service.js";
import {
  createTestUser,
  disconnect,
  getBaseUnit,
  resetDb,
  type TestUser,
} from "./helpers/db.js";
import {
  ALL_DAYS,
  daysExceptToday,
  seedAssignment,
  seedCompliance,
  seedHabit,
  today,
} from "./helpers/factories.js";

describe("integración hábitos <-> origami (bonus diario)", () => {
  let user: TestUser;

  const bonusApplied = async (userId: number) =>
    (await prisma.user.findUniqueOrThrow({ where: { id: userId } }))
      .dailyBonusAplied;
  const activeProgress = async (userId: number) =>
    (await origamiService.getActiveAssignmentRaw(userId))!.progress;
  const setBonusApplied = (userId: number) =>
    prisma.user.update({
      where: { id: userId },
      data: { dailyBonusAplied: true },
    });

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
  });

  afterAll(disconnect);

  it("crear un hábito (incompleto) retira el bonus aplicado", async () => {
    await seedAssignment(user.userId, { progress: 3 });
    const completed = await seedHabit(user.userId);
    await seedCompliance(completed.id, today(), true);
    await setBonusApplied(user.userId);

    await habitService.createHabit(user.userId, {
      icon: "🧪",
      name: "Nuevo",
      type: HabitType.BOOLEAN,
      scheduledDays: ALL_DAYS,
    });

    expect(await bonusApplied(user.userId)).toBe(false);
    expect(await activeProgress(user.userId)).toBe(0);
  });

  it("editar un hábito incompleto a programado hoy retira el bonus", async () => {
    await seedAssignment(user.userId, { progress: 3 });
    const completed = await seedHabit(user.userId);
    await seedCompliance(completed.id, today(), true);
    const resting = await seedHabit(user.userId, {
      scheduledDays: daysExceptToday(),
    });
    await setBonusApplied(user.userId);

    await habitService.updateHabit(user.userId, resting.id, {
      scheduledDays: ALL_DAYS,
    });

    expect(await bonusApplied(user.userId)).toBe(false);
    expect(await activeProgress(user.userId)).toBe(0);
  });

  it("borrar un hábito dejando otro incompleto retira el bonus", async () => {
    await seedAssignment(user.userId, { progress: 3 });
    const completed = await seedHabit(user.userId);
    await seedCompliance(completed.id, today(), true);
    await seedHabit(user.userId); // incompleto, programado hoy
    await setBonusApplied(user.userId);

    await habitService.deleteHabit(user.userId, completed.id);

    expect(await bonusApplied(user.userId)).toBe(false);
    expect(await activeProgress(user.userId)).toBe(0);
  });

  it("togglear un hábito booleano aplica el bonus", async () => {
    await seedAssignment(user.userId, { progress: 0 });
    const habit = await seedHabit(user.userId);

    await habitService.toggleHabit(user.userId, habit.id, 0);

    expect(await bonusApplied(user.userId)).toBe(true);
    expect(await activeProgress(user.userId)).toBe(3);
  });

  it("poner amount 0 en un hábito de cantidad completado retira el bonus", async () => {
    const uds = await getBaseUnit("uds");
    await seedAssignment(user.userId, { progress: 3 });
    const habit = await seedHabit(user.userId, {
      type: HabitType.QUANTITY,
      dailyGoal: 5,
      unitId: uds.id,
    });
    await seedCompliance(habit.id, today(), true, 5);
    await setBonusApplied(user.userId);

    await habitService.toggleHabit(user.userId, habit.id, 0);

    expect(await bonusApplied(user.userId)).toBe(false);
    expect(await activeProgress(user.userId)).toBe(0);
  });
});
