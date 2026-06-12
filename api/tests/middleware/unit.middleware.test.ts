import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { prisma } from "../../src/db/prisma.js";
import { HabitType } from "../../src/generated/prisma/enums.js";
import {
  createTestUser,
  disconnect,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import { seedHabit, seedUnit } from "../helpers/factories.js";
import { authedRequest } from "../helpers/http.js";

describe("unit middlewares", () => {
  let user: TestUser;
  let client: ReturnType<typeof authedRequest>;

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
    client = authedRequest(user.token);
  });

  afterAll(disconnect);

  it("validateUserLimit da error al alcanzar el límite de unidades", async () => {
    await prisma.unit.createMany({
      data: Array.from({ length: 20 }, (_, i) => ({
        name: `u${i}`,
        userId: user.userId,
      })),
    });

    const res = await client.post("/api/v1/units").send({ name: "extra" });
    expect(res.status).toBe(409);
  });

  describe("validateUniqueUnitName", () => {
    it("da error si choca con una unidad base", async () => {
      // "km" es una unidad base sembrada.
      const res = await client.post("/api/v1/units").send({ name: "km" });
      expect(res.status).toBe(409);
    });

    it("da error si el usuario ya tiene esa unidad", async () => {
      await seedUnit(user.userId, "pasos");

      const res = await client.post("/api/v1/units").send({ name: "pasos" });
      expect(res.status).toBe(409);
    });
  });

  describe("validateUnitOwner", () => {
    it("da error si la unidad no existe", async () => {
      const res = await client.delete("/api/v1/units/999999");
      expect(res.status).toBe(404);
    });

    it("da error si la unidad no es del usuario", async () => {
      const other = await createTestUser("Otro");
      const unit = await seedUnit(other.userId, "ajena");

      const res = await client.delete(`/api/v1/units/${unit.id}`);
      expect(res.status).toBe(403);
    });
  });

  it("validateUnitUse impide borrar una unidad con hábitos asociados", async () => {
    const unit = await seedUnit(user.userId, "pasos");
    await seedHabit(user.userId, {
      type: HabitType.QUANTITY,
      dailyGoal: 5,
      unitId: unit.id,
    });

    const res = await client.delete(`/api/v1/units/${unit.id}`);
    expect(res.status).toBe(409);
  });
});
