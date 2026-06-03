import { prisma } from "../db/prisma.js";

export const getUserHabits = async (userId: number) => {
  return await prisma.habit.findMany({
    where: {
      userId,
    },
  });
};
