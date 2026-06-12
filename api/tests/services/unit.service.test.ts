import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { BASE_UNITS } from "../../prisma/utils.js";
import * as unitService from "../../src/services/unit.service.js";
import {
  createTestUser,
  disconnect,
  resetDb,
  type TestUser,
} from "../helpers/db.js";

describe("unit.service", () => {
  let user: TestUser;

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
  });

  afterAll(disconnect);

  it("createUnit crea una unidad personalizada", async () => {
    const unit = await unitService.createUnit(user.userId, "pasos");

    expect(unit.name).toBe("pasos");
    expect(unit.userId).toBe(user.userId);
  });

  it("getUnit devuelve la unidad por id", async () => {
    const created = await unitService.createUnit(user.userId, "pasos");

    const unit = await unitService.getUnit(created.id);

    expect(unit!.id).toBe(created.id);
    expect(unit!.name).toBe("pasos");
  });

  it("getUserUnits devuelve solo las unidades del usuario", async () => {
    await unitService.createUnit(user.userId, "pasos");

    const units = await unitService.getUserUnits(user.userId);

    expect(units).toHaveLength(1);
    expect(units[0].name).toBe("pasos");
  });

  it("getBaseUnits devuelve las unidades base", async () => {
    const units = await unitService.getBaseUnits();

    expect(units).toHaveLength(BASE_UNITS.length);
    expect(units.every((u) => u.userId === null)).toBe(true);
  });

  it("editUserUnit renombra la unidad", async () => {
    const created = await unitService.createUnit(user.userId, "pasos");

    await unitService.editUserUnit(created.id, "zanc");

    expect((await unitService.getUnit(created.id))!.name).toBe("zanc");
  });

  it("deleteUserUnit elimina la unidad", async () => {
    const created = await unitService.createUnit(user.userId, "pasos");

    await unitService.deleteUserUnit(created.id);

    expect(await unitService.getUnit(created.id)).toBeNull();
  });
});
