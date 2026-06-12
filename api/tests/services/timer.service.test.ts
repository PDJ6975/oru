import { afterAll, beforeEach, describe, expect, it } from "vitest";
import * as timerRepository from "../../src/repositories/timer.repository.js";
import * as timerService from "../../src/services/timer.service.js";
import {
  createTestUser,
  disconnect,
  resetDb,
  type TestUser,
} from "../helpers/db.js";
import { seedTimerSession } from "../helpers/factories.js";

const HOUR_MS = 60 * 60 * 1000;

describe("timer.service", () => {
  let user: TestUser;

  beforeEach(async () => {
    await resetDb();
    user = await createTestUser();
  });

  afterAll(disconnect);

  describe("createTimerSession", () => {
    it("crea una sesión correctamente", async () => {
      const session = await timerService.createTimerSession(
        user.userId,
        new Date(),
        25,
      );

      expect(session.userId).toBe(user.userId);
      expect(session.selectedMinutes).toBe(25);
      expect(session.isCompleted).toBe(false);
    });

    it("cierra una sesión anterior caducada al crear una nueva", async () => {
      // Sesión activa caducada (empezó hace 1h, duraba 10 min).
      const old = await seedTimerSession(user.userId, {
        startDate: new Date(Date.now() - HOUR_MS),
        selectedMinutes: 10,
      });

      await timerService.createTimerSession(user.userId, new Date(), 25);

      const oldRefreshed = await timerRepository.getNotCompletedSessions(
        user.userId,
      );
      // La antigua quedó completada; la activa es la nueva.
      expect(oldRefreshed.map((s) => s.id)).not.toContain(old.id);
      const active = await timerService.getActiveSession(user.userId);
      expect(active!.selectedMinutes).toBe(25);
    });
  });

  it("getActiveSession devuelve la sesión activa del usuario", async () => {
    await seedTimerSession(user.userId, { isCompleted: true }); // descartada
    const active = await seedTimerSession(user.userId);

    const result = await timerService.getActiveSession(user.userId);

    expect(result!.id).toBe(active.id);
  });

  it("getNotCompletedSessions devuelve las sesiones no completadas", async () => {
    const open = await seedTimerSession(user.userId);
    await seedTimerSession(user.userId, { isCompleted: true });

    const result = await timerRepository.getNotCompletedSessions(user.userId);

    expect(result).toHaveLength(1);
    expect(result[0].id).toBe(open.id);
  });

  it("getEndDate calcula la fecha de fin", async () => {
    const start = new Date(2024, 0, 1, 10, 0, 0);

    const end = timerService.getEndDate(start, 30);

    expect(end).toEqual(new Date(2024, 0, 1, 10, 30, 0));
  });

  it("finishTimerSession finaliza la sesión activa", async () => {
    await seedTimerSession(user.userId);

    await timerService.finishTimerSession(user.userId);

    expect(await timerService.getActiveSession(user.userId)).toBeNull();
  });

  describe("getOrRecoverTimerSession", () => {
    it("finaliza y devuelve null si la sesión ya ha caducado", async () => {
      await seedTimerSession(user.userId, {
        startDate: new Date(Date.now() - HOUR_MS),
        selectedMinutes: 10, // caducó hace 50 min
      });

      const result = await timerService.getOrRecoverTimerSession(user.userId);

      expect(result).toBeNull();
    });

    it("devuelve la sesión si todavía está en curso", async () => {
      const session = await seedTimerSession(user.userId, {
        startDate: new Date(),
        selectedMinutes: 60, // termina dentro de 60 min
      });

      const result = await timerService.getOrRecoverTimerSession(user.userId);

      expect(result!.id).toBe(session.id);
    });
  });

  it("cancelTimerSession elimina la sesión activa", async () => {
    await seedTimerSession(user.userId);

    await timerService.cancelTimerSession(user.userId);

    expect(await timerService.getActiveSession(user.userId)).toBeNull();
  });
});
