import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { HabitStatus, HabitType } from "../../src/generated/prisma/enums.js";
import {
  createTestUser,
  disconnect,
  getBaseUnit,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import {
  daysExceptToday,
  seedHabit,
  seedTimerSession,
} from "../helpers/factories.js";
import { authedRequest } from "../helpers/http.js";

describe("timer middlewares", () => {
  let user: TestUser;
  let client: ReturnType<typeof authedRequest>;

  const body = () => ({
    startDate: new Date(Date.now() - 60_000).toISOString(),
    selectedMinutes: 25,
  });

  const quantityHabit = async (overrides = {}) => {
    const uds = await getBaseUnit("uds");
    return seedHabit(user.userId, {
      type: HabitType.QUANTITY,
      dailyGoal: 5,
      unitId: uds.id,
      ...overrides,
    });
  };

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
    client = authedRequest(user.token);
  });

  afterAll(disconnect);

  describe("validatHabitForTimer", () => {
    it("da error si el hábito no existe", async () => {
      const res = await client.post("/api/v1/timer/999999").send(body());
      expect(res.status).toBe(404);
    });

    it("da error si el hábito no es del usuario", async () => {
      const other = await createTestUser("Otro");
      const habit = await seedHabit(other.userId, {
        type: HabitType.QUANTITY,
        dailyGoal: 5,
      });

      const res = await client.post(`/api/v1/timer/${habit.id}`).send(body());
      expect(res.status).toBe(403);
    });

    it("da error si el hábito es booleano", async () => {
      const habit = await seedHabit(user.userId); // BOOLEAN por defecto

      const res = await client.post(`/api/v1/timer/${habit.id}`).send(body());
      expect(res.status).toBe(400);
    });

    it("da error si el hábito está archivado", async () => {
      const habit = await quantityHabit({ status: HabitStatus.ARCHIVED });

      const res = await client.post(`/api/v1/timer/${habit.id}`).send(body());
      expect(res.status).toBe(400);
    });

    it("da error si el hábito no está programado para hoy", async () => {
      const habit = await quantityHabit({ scheduledDays: daysExceptToday() });

      const res = await client.post(`/api/v1/timer/${habit.id}`).send(body());
      expect(res.status).toBe(400);
    });
  });

  it("validateNotRunningSession da error si ya hay una sesión activa", async () => {
    await seedTimerSession(user.userId, {
      startDate: new Date(),
      selectedMinutes: 60, // sigue en curso
    });

    const res = await client.post("/api/v1/timer").send(body());
    expect(res.status).toBe(400);
  });

  it("validateThereIsAnActiveSession da error si no hay sesión activa", async () => {
    const res = await client.post("/api/v1/timer/finish");
    expect(res.status).toBe(400);
  });
});
