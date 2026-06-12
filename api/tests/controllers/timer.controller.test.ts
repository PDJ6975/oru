import { afterAll, beforeEach, describe, expect, it } from "vitest";
import {
  createTestUser,
  disconnect,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import { seedTimerSession } from "../helpers/factories.js";
import { authedRequest } from "../helpers/http.js";

describe("timer controller (E2E)", () => {
  let user: TestUser;
  let client: ReturnType<typeof authedRequest>;

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
    client = authedRequest(user.token);
  });

  afterAll(disconnect);

  it("POST /timer crea una sesión", async () => {
    const res = await client.post("/api/v1/timer").send({
      startDate: new Date(Date.now() - 60_000).toISOString(),
      selectedMinutes: 25,
    });

    expect(res.status).toBe(201);
    expect(res.body.selectedMinutes).toBe(25);
  });

  it("GET /timer devuelve la sesión activa", async () => {
    const session = await seedTimerSession(user.userId, {
      startDate: new Date(),
      selectedMinutes: 60,
    });

    const res = await client.get("/api/v1/timer");

    expect(res.status).toBe(200);
    expect(res.body.id).toBe(session.id);
  });

  it("POST /timer/finish finaliza la sesión activa", async () => {
    await seedTimerSession(user.userId);

    const res = await client.post("/api/v1/timer/finish");

    expect(res.status).toBe(204);
  });

  it("DELETE /timer cancela la sesión activa", async () => {
    await seedTimerSession(user.userId);

    const res = await client.delete("/api/v1/timer");

    expect(res.status).toBe(204);
  });
});
