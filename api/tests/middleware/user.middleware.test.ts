import request from "supertest";
import { afterAll, beforeEach, describe, expect, it } from "vitest";
import app from "../../src/app.js";
import { createTestUser, disconnect, resetDb } from "../helpers/db.js";
import { authedRequest } from "../helpers/http.js";

describe("user middlewares", () => {
  beforeEach(async () => {
    await resetDb();
    await createTestUser();
  });

  afterAll(disconnect);

  it("getUserToken da error si no se manda token", async () => {
    const res = await request(app).get("/api/v1/users/me");
    expect(res.status).toBe(401);
  });

  it("verifyUser da error si el token no es válido", async () => {
    const res = await authedRequest("token-invalido").get("/api/v1/users/me");
    expect(res.status).toBe(401);
  });
});
