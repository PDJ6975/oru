import request from "supertest";
import { afterAll, beforeEach, describe, expect, it } from "vitest";
import app from "../../src/app.js";
import {
  createTestUser,
  disconnect,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import { authedRequest } from "../helpers/http.js";

describe("user controller (E2E)", () => {
  let user: TestUser;

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
  });

  afterAll(disconnect);

  it("POST /users crea un usuario y devuelve token", async () => {
    const res = await request(app)
      .post("/api/v1/users")
      .send({ name: "Nuevo" });

    expect(res.status).toBe(201);
    expect(res.body.token).toBeDefined();
  });

  it("GET /users/me devuelve la información del usuario", async () => {
    const res = await authedRequest(user.token).get("/api/v1/users/me");

    expect(res.status).toBe(200);
    expect(res.body.user.id).toBe(user.userId);
  });
});
