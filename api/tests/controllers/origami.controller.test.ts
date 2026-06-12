import { afterAll, beforeEach, describe, expect, it } from "vitest";
import {
  createTestUser,
  disconnect,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import { seedAssignment } from "../helpers/factories.js";
import { authedRequest } from "../helpers/http.js";

describe("origami controller (E2E)", () => {
  let user: TestUser;
  let client: ReturnType<typeof authedRequest>;

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
    client = authedRequest(user.token);
  });

  afterAll(disconnect);

  it("GET /origami devuelve el origami activo", async () => {
    const res = await client.get("/api/v1/origami");

    expect(res.status).toBe(200);
    expect(res.body.origamiName).toBeDefined();
  });

  it("POST /origami/next-phase avanza de fase", async () => {
    // Umbral de la fase 1 = 25; progreso 25 -> se puede avanzar.
    await seedAssignment(user.userId, {
      origamiName: "mariposa",
      revealedPhase: 0,
      progress: 25,
    });

    const res = await client.post("/api/v1/origami/next-phase");

    expect(res.status).toBe(200);
  });

  it("POST /origami/new asigna un nuevo origami", async () => {
    await seedAssignment(user.userId, { origamiName: "mariposa" });

    const res = await client.post("/api/v1/origami/new");

    expect(res.status).toBe(200);
  });

  it("GET /origamis/completed lista los completados del año", async () => {
    await seedAssignment(user.userId, {
      origamiName: "mariposa",
      completedAt: new Date(2024, 0, 1),
    });

    const res = await client.get("/api/v1/origamis/completed?year=2024");

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
  });
});
