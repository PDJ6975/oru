import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { prisma } from "../../src/db/prisma.js";
import { HabitStatus, HabitType } from "../../src/generated/prisma/enums.js";
import {
  createTestUser,
  disconnect,
  getBaseUnit,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import { ALL_DAYS, daysExceptToday, seedHabit } from "../helpers/factories.js";
import { authedRequest } from "../helpers/http.js";

describe("habit middlewares", () => {
  let user: TestUser;
  let client: ReturnType<typeof authedRequest>;

  const createBody = (overrides: Record<string, unknown> = {}) => ({
    icon: "🧪",
    name: "Test",
    type: HabitType.BOOLEAN,
    scheduledDays: ALL_DAYS,
    ...overrides,
  });

  const create = (overrides?: Record<string, unknown>) =>
    client.post("/api/v1/habits").send(createBody(overrides));

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
    client = authedRequest(user.token);
  });

  afterAll(disconnect);

  describe("ensureTypeAndDailyGoalAndUnitConsistency", () => {
    it("BOOLEAN con dailyGoal da error", async () => {
      const res = await create({ type: HabitType.BOOLEAN, dailyGoal: 5 });
      expect(res.status).toBe(400);
    });

    it("BOOLEAN con unidad da error", async () => {
      const uds = await getBaseUnit("uds");
      const res = await create({ type: HabitType.BOOLEAN, unitId: uds.id });
      expect(res.status).toBe(400);
    });

    it("QUANTITY sin dailyGoal da error", async () => {
      const uds = await getBaseUnit("uds");
      const res = await create({ type: HabitType.QUANTITY, unitId: uds.id });
      expect(res.status).toBe(400);
    });

    it("QUANTITY sin unidad da error", async () => {
      const res = await create({ type: HabitType.QUANTITY, dailyGoal: 5 });
      expect(res.status).toBe(400);
    });

    it("QUANTITY con dailyGoal >= 100000 da error", async () => {
      const uds = await getBaseUnit("uds");
      const res = await create({
        type: HabitType.QUANTITY,
        dailyGoal: 100000,
        unitId: uds.id,
      });
      expect(res.status).toBe(400);
    });
  });

  describe("validateUnitForHabit", () => {
    it("unidad inexistente da error", async () => {
      const res = await create({
        type: HabitType.QUANTITY,
        dailyGoal: 5,
        unitId: 999999,
      });
      expect(res.status).toBe(404);
    });

    it("unidad personalizada de otro usuario da error", async () => {
      const other = await createTestUser("Otro");
      const unit = await prisma.unit.create({
        data: { name: "ajena", userId: other.userId },
      });

      const res = await create({
        type: HabitType.QUANTITY,
        dailyGoal: 5,
        unitId: unit.id,
      });
      expect(res.status).toBe(403);
    });
  });

  describe("validateQueriesCombinations", () => {
    it("status=archived con filter distinto de all da error", async () => {
      const res = await client.get(
        "/api/v1/habits?status=archived&filter=scheduled",
      );
      expect(res.status).toBe(400);
    });

    it("status=all con filter distinto de all da error", async () => {
      const res = await client.get(
        "/api/v1/habits?status=all&filter=scheduled",
      );
      expect(res.status).toBe(400);
    });
  });

  describe("validateHabitOwner", () => {
    it("hábito de otro usuario da error", async () => {
      const other = await createTestUser("Otro");
      const habit = await seedHabit(other.userId);

      const res = await client.get(`/api/v1/habits/${habit.id}`);
      expect(res.status).toBe(403);
    });

    it("hábito inexistente da error", async () => {
      const res = await client.get("/api/v1/habits/999999");
      expect(res.status).toBe(404);
    });
  });

  describe("validateHabitCanBeArchived", () => {
    it("hábito ya archivado da error", async () => {
      const habit = await seedHabit(user.userId, {
        status: HabitStatus.ARCHIVED,
        isConsolidated: true,
      });

      const res = await client.post(`/api/v1/habits/${habit.id}/archive`);
      expect(res.status).toBe(400);
    });

    it("hábito no consolidado da error", async () => {
      const habit = await seedHabit(user.userId);

      const res = await client.post(`/api/v1/habits/${habit.id}/archive`);
      expect(res.status).toBe(400);
    });
  });

  describe("validateAmountWithHabitType", () => {
    it("BOOLEAN con cantidad presente da error", async () => {
      const habit = await seedHabit(user.userId);

      const res = await client
        .post(`/api/v1/habits/${habit.id}/toggle`)
        .send({ amount: 5 });
      expect(res.status).toBe(400);
    });

    it("QUANTITY sin amount da error", async () => {
      const uds = await getBaseUnit("uds");
      const habit = await seedHabit(user.userId, {
        type: HabitType.QUANTITY,
        dailyGoal: 5,
        unitId: uds.id,
      });

      const res = await client
        .post(`/api/v1/habits/${habit.id}/toggle`)
        .send({});
      expect(res.status).toBe(400);
    });
  });

  describe("validateHabitStatusForToggle", () => {
    it("hábito archivado da error", async () => {
      const habit = await seedHabit(user.userId, {
        status: HabitStatus.ARCHIVED,
      });

      const res = await client
        .post(`/api/v1/habits/${habit.id}/toggle`)
        .send({});
      expect(res.status).toBe(400);
    });

    it("hábito no programado para hoy da error", async () => {
      const habit = await seedHabit(user.userId, {
        scheduledDays: daysExceptToday(),
      });

      const res = await client
        .post(`/api/v1/habits/${habit.id}/toggle`)
        .send({});
      expect(res.status).toBe(400);
    });
  });
});
