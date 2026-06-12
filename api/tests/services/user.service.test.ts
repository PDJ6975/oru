import { afterAll, beforeEach, describe, expect, it } from "vitest";
import * as userService from "../../src/services/user.service.js";
import {
  createTestUser,
  disconnect,
  resetDb,
  type TestUser,
} from "../helpers/db.js";

describe("user.service", () => {
  let user: TestUser;

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
  });

  afterAll(disconnect);

  it("createUser crea el usuario y devuelve un token con sesión", async () => {
    const token = await userService.createUser("Nuevo");

    expect(typeof token).toBe("string");
    const session = await userService.getSessionByToken(token);
    expect(session).not.toBeNull();
  });

  it("getSessionByToken devuelve la sesión del token", async () => {
    const session = await userService.getSessionByToken(user.token);

    expect(session!.userId).toBe(user.userId);
  });

  it("getUserById devuelve el usuario", async () => {
    const found = await userService.getUserById(user.userId);

    expect(found!.id).toBe(user.userId);
  });

  it("updateLastComputedDay actualiza la fecha", async () => {
    const date = new Date(2024, 0, 15);

    await userService.updateLastComputedDay(user.userId, date);

    const found = await userService.getUserById(user.userId);
    expect(found!.lastComputedDay).toEqual(date);
  });

  it("setDailyBonus actualiza el flag del bonus", async () => {
    await userService.setDailyBonus(user.userId, true);

    const found = await userService.getUserById(user.userId);
    expect(found!.dailyBonusAplied).toBe(true);
  });
});
