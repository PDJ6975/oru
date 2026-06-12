import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { prisma } from "../../src/db/prisma.js";
import * as origamiService from "../../src/services/origami.service.js";
import {
  createTestUser,
  disconnect,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import {
  seedAssignment,
  seedCompliance,
  seedHabit,
  today,
} from "../helpers/factories.js";

describe("origami.service", () => {
  let user: TestUser;

  const bonusApplied = async (userId: number) =>
    (await prisma.user.findUniqueOrThrow({ where: { id: userId } }))
      .dailyBonusAplied;
  const activeProgress = async (userId: number) =>
    (await origamiService.getActiveAssignmentRaw(userId))!.progress;
  const setBonusApplied = (userId: number) =>
    prisma.user.update({
      where: { id: userId },
      data: { dailyBonusAplied: true },
    });

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
  });

  afterAll(disconnect);

  describe("getActiveAssignment", () => {
    it("usuario nuevo: asigna un origami (assignOrigami)", async () => {
      const result = await origamiService.getActiveAssignment(user.userId);

      expect(
        await origamiService.getActiveAssignmentRaw(user.userId),
      ).not.toBeNull();
      expect(result.progress).toBe(0);
      expect(result.origamiName.endsWith("_fase0")).toBe(true);
    });

    it("usuario con asignación: devuelve nombre, umbral y disponibilidad", async () => {
      await seedAssignment(user.userId, {
        origamiName: "mariposa",
        revealedPhase: 2,
        progress: 40,
      });

      const result = await origamiService.getActiveAssignment(user.userId);

      expect(result.origamiName).toBe("mariposa_fase2"); // getOrigamiName
      expect(result.nextThreshold).toBe(75); // getNextThreshold(5, 2)
      expect(result.progress).toBe(40);
      expect(result.hasNextOrigami).toBe(true); // 3 origamis sin asignar
      expect(result.isCompleted).toBe(false);
    });
  });

  it("getActiveAssignmentRaw devuelve la asignación activa en crudo", async () => {
    const seeded = await seedAssignment(user.userId, { progress: 20 });

    const raw = await origamiService.getActiveAssignmentRaw(user.userId);

    expect(raw!.id).toBe(seeded.id);
    expect(raw!.completedAt).toBeNull();
    expect(raw!.origami.name).toBe("mariposa");
  });

  describe("getNextThreshold", () => {
    it("devuelve null si nextPhase >= totalPhases", () => {
      expect(origamiService.getNextThreshold(5, 4)).toBeNull();
    });

    it("calcula el umbral con redondeo", () => {
      // 4 fases -> 100/3 = 33,33; nextPhase 2 -> 66,66 -> round -> 67
      expect(origamiService.getNextThreshold(4, 1)).toBe(67);
    });
  });

  it("getOrigamiName construye el nombre a partir de origami y fase", async () => {
    await seedAssignment(user.userId, {
      origamiName: "flor",
      revealedPhase: 3,
    });

    const result = await origamiService.getActiveAssignment(user.userId);

    expect(result.origamiName).toBe("flor_fase3");
  });

  it("assignOrigami crea la asignación correctamente", async () => {
    const assignment = await origamiService.assignOrigami(user.userId);

    expect(assignment.progress).toBe(0);
    expect(assignment.revealedPhase).toBe(0);
    expect(assignment.origami).toBeDefined();
    expect((await origamiService.getActiveAssignmentRaw(user.userId))!.id).toBe(
      assignment.id,
    );
  });

  it("changeOrigami completa la actual y asigna otro origami", async () => {
    const original = await seedAssignment(user.userId, {
      origamiName: "mariposa",
    });

    await origamiService.changeOrigami(user.userId);

    const old = await prisma.assignment.findUniqueOrThrow({
      where: { id: original.id },
    });
    expect(old.completedAt).not.toBeNull();

    const active = await origamiService.getActiveAssignmentRaw(user.userId);
    expect(active!.id).not.toBe(original.id);
    expect(active!.origami.name).not.toBe("mariposa");
  });

  it("getUnassignedOrigamis devuelve los origamis no asignados", async () => {
    expect(
      await origamiService.getUnassignedOrigamis(user.userId),
    ).toHaveLength(4);

    await seedAssignment(user.userId, { origamiName: "mariposa" });

    const rest = await origamiService.getUnassignedOrigamis(user.userId);
    expect(rest).toHaveLength(3);
    expect(rest.map((o) => o.name)).not.toContain("mariposa");
  });

  describe("evaluateProgress", () => {
    it("sin asignación activa no hace nada", async () => {
      // Usuario nuevo: no tiene asignación todavía.
      expect(
        await origamiService.evaluateProgress(user.userId),
      ).toBeUndefined();
    });
  });

  it("applyDailyBonus aumenta el progreso y marca el bonus", async () => {
    await seedAssignment(user.userId, { progress: 10 });
    const habit = await seedHabit(user.userId);
    await seedCompliance(habit.id, today(), true);

    await origamiService.evaluateProgress(user.userId);

    expect(await activeProgress(user.userId)).toBe(13); // 10 + 3
    expect(await bonusApplied(user.userId)).toBe(true);
  });

  it("removeDailyBonus disminuye el progreso y desmarca el bonus", async () => {
    await seedAssignment(user.userId, { progress: 10 });
    await seedHabit(user.userId); // activo, programado, incompleto
    await setBonusApplied(user.userId);

    await origamiService.evaluateProgress(user.userId);

    expect(await activeProgress(user.userId)).toBe(7); // 10 - 3
    expect(await bonusApplied(user.userId)).toBe(false);
  });

  it("nextPhase avanza la fase revelada", async () => {
    await seedAssignment(user.userId, { revealedPhase: 1 });

    await origamiService.nextPhase(user.userId);

    const raw = await origamiService.getActiveAssignmentRaw(user.userId);
    expect(raw!.revealedPhase).toBe(2);
  });

  describe("applyBonusForSession", () => {
    const cases = [
      [10, 1],
      [20, 2],
      [40, 3],
      [50, 4],
      [70, 5],
    ] as const;

    it.each(
      cases,
    )("una sesión de %i minutos suma %i de progreso", async (minutes, bonus) => {
      await seedAssignment(user.userId, { progress: 0 });

      await origamiService.applyBonusForSession(user.userId, minutes);

      expect(await activeProgress(user.userId)).toBe(bonus);
    });
  });

  it("getOrigamisCompletedInAYear devuelve los completados del año", async () => {
    const year = 2024;
    await seedAssignment(user.userId, {
      origamiName: "mariposa",
      completedAt: new Date(year, 0, 1), // 1 de enero (límite inferior)
    });
    await seedAssignment(user.userId, {
      origamiName: "flor",
      completedAt: new Date(year, 11, 30), // 30 de diciembre (límite superior)
    });
    await seedAssignment(user.userId, {
      origamiName: "luna",
      completedAt: new Date(2023, 5, 1), // otro año: excluido
    });

    const result = await origamiService.getOrigamisCompletedInAYear(
      user.userId,
      year,
    );

    expect(result).toHaveLength(2);
    expect(result.map((o) => o.name).sort()).toEqual(["flor", "mariposa"]);
    const mariposa = result.find((o) => o.name === "mariposa");
    expect(mariposa!.illustration).toBe("mariposa_fase4"); // phases - 1
  });
});
