import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { BASE_UNITS } from "../../prisma/utils.js";
import {
  createTestUser,
  disconnect,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import { seedUnit } from "../helpers/factories.js";
import { authedRequest } from "../helpers/http.js";

describe("unit controller (E2E)", () => {
  let user: TestUser;
  let client: ReturnType<typeof authedRequest>;

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
    client = authedRequest(user.token);
  });

  afterAll(disconnect);

  it("POST /units crea una unidad", async () => {
    const res = await client.post("/api/v1/units").send({ name: "pasos" });

    expect(res.status).toBe(201);
    expect(res.body.name).toBe("pasos");
  });

  it("GET /units/me lista las unidades del usuario", async () => {
    await seedUnit(user.userId, "pasos");

    const res = await client.get("/api/v1/units/me");

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
  });

  it("GET /units/base lista las unidades base", async () => {
    const res = await client.get("/api/v1/units/base");

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(BASE_UNITS.length);
  });

  it("DELETE /units/:id elimina una unidad", async () => {
    const unit = await seedUnit(user.userId, "pasos");

    const res = await client.delete(`/api/v1/units/${unit.id}`);

    expect(res.status).toBe(204);
  });

  it("PATCH /units/:id renombra una unidad", async () => {
    const unit = await seedUnit(user.userId, "pasos");

    const res = await client
      .patch(`/api/v1/units/${unit.id}`)
      .send({ name: "zanc" });

    expect(res.status).toBe(204);
  });
});
