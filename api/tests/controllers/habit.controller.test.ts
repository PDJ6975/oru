import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { HabitType } from "../../src/generated/prisma/enums.js";
import {
  createTestUser,
  disconnect,
  getBaseUnit,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import { ALL_DAYS, seedHabit } from "../helpers/factories.js";
import { authedRequest } from "../helpers/http.js";

describe("habit controller (E2E)", () => {
  let user: TestUser;
  let client: ReturnType<typeof authedRequest>;

  const seedQuantityHabit = async (overrides = {}) => {
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

  it("POST /habits crea un hábito", async () => {
    const res = await client.post("/api/v1/habits").send({
      icon: "📖",
      name: "Leer",
      type: HabitType.BOOLEAN,
      scheduledDays: ALL_DAYS,
    });

    expect(res.status).toBe(201);
    expect(res.body.name).toBe("Leer");
  });

  it("GET /habits lista los hábitos", async () => {
    await seedHabit(user.userId);

    const res = await client.get("/api/v1/habits");

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
  });

  it("GET /habits/:id devuelve un hábito", async () => {
    const habit = await seedHabit(user.userId);

    const res = await client.get(`/api/v1/habits/${habit.id}`);

    expect(res.status).toBe(200);
    expect(res.body.id).toBe(habit.id);
  });

  it("PATCH /habits/:id actualiza un hábito", async () => {
    const habit = await seedHabit(user.userId);

    const res = await client
      .patch(`/api/v1/habits/${habit.id}`)
      .send({ name: "Nuevo" });

    expect(res.status).toBe(200);
    expect(res.body.name).toBe("Nuevo");
  });

  it("DELETE /habits/:id elimina un hábito", async () => {
    const habit = await seedHabit(user.userId);

    const res = await client.delete(`/api/v1/habits/${habit.id}`);

    expect(res.status).toBe(204);
  });

  it("POST /habits/:id/archive archiva un hábito consolidado", async () => {
    const habit = await seedHabit(user.userId, { isConsolidated: true });

    const res = await client.post(`/api/v1/habits/${habit.id}/archive`);

    expect(res.status).toBe(204);
  });

  it("POST /habits/:id/toggle marca un hábito", async () => {
    const habit = await seedHabit(user.userId);

    const res = await client.post(`/api/v1/habits/${habit.id}/toggle`).send({});

    expect(res.status).toBe(200);
  });

  it("GET /habits/timer/load lista los hábitos del temporizador", async () => {
    const min = await getBaseUnit("min");
    await seedQuantityHabit({ unitId: min.id });

    const res = await client.get("/api/v1/habits/timer/load");

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
  });
});
