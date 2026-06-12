import { afterAll, beforeEach, describe, expect, it } from "vitest";
import {
  createTestUser,
  disconnect,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import { authedRequest } from "../helpers/http.js";

describe("stats controller (E2E)", () => {
  let user: TestUser;
  let client: ReturnType<typeof authedRequest>;

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
    client = authedRequest(user.token);
  });

  afterAll(disconnect);

  it("GET /stats devuelve las estadísticas del año", async () => {
    const year = new Date().getFullYear();

    const res = await client.get(`/api/v1/stats?year=${year}`);

    expect(res.status).toBe(200);
    expect(res.body.userStats).toBeDefined();
    expect(Array.isArray(res.body.habitStats)).toBe(true);
  });
});
