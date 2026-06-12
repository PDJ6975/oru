import { afterAll, beforeEach, describe, expect, it } from "vitest";
import {
  createTestUser,
  disconnect,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import { seedAssignment } from "../helpers/factories.js";
import { authedRequest } from "../helpers/http.js";

const CATALOG = ["mariposa", "bailarina", "flor", "luna"];

describe("origami middlewares", () => {
  let user: TestUser;
  let client: ReturnType<typeof authedRequest>;

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
    client = authedRequest(user.token);
  });

  afterAll(disconnect);

  it("validateActiveAssignment da error si no hay asignación activa", async () => {
    const res = await client.post("/api/v1/origami/next-phase");
    expect(res.status).toBe(400);
  });

  describe("validateNextPhase", () => {
    it("da error si el umbral es null (origami completado)", async () => {
      await seedAssignment(user.userId, {
        origamiName: "mariposa",
        revealedPhase: 4,
        progress: 100,
      });

      const res = await client.post("/api/v1/origami/next-phase");
      expect(res.status).toBe(400);
    });

    it("da error si no se ha alcanzado el umbral", async () => {
      // Umbral de la fase 1 = 25; progreso 10 < 25.
      await seedAssignment(user.userId, {
        origamiName: "mariposa",
        revealedPhase: 0,
        progress: 10,
      });

      const res = await client.post("/api/v1/origami/next-phase");
      expect(res.status).toBe(400);
    });
  });

  it("validateMoreOrigamisAvailable da error si no quedan origamis", async () => {
    for (const origamiName of CATALOG) {
      await seedAssignment(user.userId, { origamiName });
    }

    const res = await client.post("/api/v1/origami/new");
    expect(res.status).toBe(409);
  });
});
