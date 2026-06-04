import { prisma } from "../db/prisma.js";
import { WeekDay } from "../generated/prisma/enums.js";
import {
  HabitFilterSchedule,
  HabitFilterStatus,
  HabitInput,
} from "../types/habit.types.js";

export const getUserHabits = async (
  userId: number,
  status: HabitFilterStatus,
  filter: HabitFilterSchedule,
  day: WeekDay,
) => {
  const where: any = { userId };

  if (status === "active") {
    where.status = "ACTIVE";
  }

  if (status === "archived") {
    where.status = "ARCHIVED";
  }

  if (filter === "scheduled") {
    where.scheduledDays = {
      some: {
        day,
      },
    };
  }

  if (filter === "rest") {
    where.scheduledDays = {
      none: {
        day,
      },
    };
  }

  return await prisma.habit.findMany({
    where,
    include: {
      scheduledDays: true,
    },
  });
};

export const createHabit = async (
  userId: number,
  habitData: Omit<HabitInput, "scheduledDays">,
  scheduledDays: WeekDay[],
) => {
  return await prisma.habit.create({
    data: {
      ...habitData,
      userId,
      scheduledDays: {
        create: scheduledDays.map((day) => ({ day })),
      },
    },
  });
};
