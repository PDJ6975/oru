import { prisma } from "../../src/db/prisma.js";
import * as userService from "../../src/services/user.service.js";
import { seedBaseData } from "../../prisma/utils.js";

const TABLES = [
  "TimerSession",
  "Compliance",
  "ScheduledDay",
  "HabitStats",
  "UserStats",
  "Assignment",
  "Habit",
  "Unit",
  "Session",
  "Origami",
  "User",
];

export const resetDb = async () => {
  const tableList = TABLES.map((t) => `"${t}"`).join(", ");
  await prisma.$executeRawUnsafe(
    `TRUNCATE TABLE ${tableList} RESTART IDENTITY CASCADE`,
  );

  await seedBaseData();
};

export type TestUser = { userId: number; token: string };

export const createTestUser = async (name = "Tester"): Promise<TestUser> => {
  const token = await userService.createUser(name);
  const session = await userService.getSessionByToken(token);

  return { userId: session!.userId, token };
};

export const getBaseUnit = async (name: string) => {
  return prisma.unit.findFirstOrThrow({ where: { name, userId: null } });
};

export const disconnect = async () => {
  await prisma.$disconnect();
};
