import { endOfDay, startOfDay } from "date-fns";
import { prisma } from "../db/prisma.js";
import { HabitStatus, HabitType, WeekDay } from "../generated/prisma/enums.js";
import {
  HabitFilterSchedule,
  HabitFilterStatus,
  HabitCreationInput,
  HabitUpdateInput,
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
      compliances: true,
      unit: {
        select: { name: true, id: true },
      },
    },
  });
};

export const getHabitsForTimer = async (userId: number, today: WeekDay) => {
  return await prisma.habit.findMany({
    where: {
      userId,
      status: HabitStatus.ACTIVE,
      type: HabitType.QUANTITY,
      scheduledDays: {
        some: {
          day: today,
        },
      },
    },
  });
};

export const getHabitById = async (habitId: number) => {
  return await prisma.habit.findUnique({
    where: { id: habitId },
    include: {
      scheduledDays: true,
      compliances: true,
      unit: {
        select: { name: true, id: true },
      },
    },
  });
};

export const countHabitsByUnitId = async (unitId: number) => {
  return await prisma.habit.count({
    where: { unitId },
  });
};

export const createHabit = async (
  userId: number,
  habitData: Omit<HabitCreationInput, "scheduledDays">,
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
    include: {
      scheduledDays: true,
      compliances: true,
      unit: {
        select: { name: true, id: true },
      },
    },
  });
};

export const updateHabit = async (
  habitId: number,
  habitData: HabitUpdateInput,
  scheduledDays?: WeekDay[],
) => {
  return await prisma.habit.update({
    where: { id: habitId },
    data: {
      ...habitData,
      scheduledDays: scheduledDays
        ? {
            deleteMany: {},
            create: scheduledDays.map((day) => ({ day })),
          }
        : {},
    },
    include: {
      scheduledDays: true,
      compliances: true,
      unit: {
        select: { name: true, id: true },
      },
    },
  });
};

export const deleteHabit = async (habitId: number) => {
  return await prisma.habit.delete({
    where: { id: habitId },
  });
};

export const consolidateHabit = async (habitId: number) => {
  return await prisma.habit.update({
    where: { id: habitId },
    data: {
      isConsolidated: true,
    },
  });
};

export const deconsolidateHabit = async (habitId: number) => {
  return await prisma.habit.update({
    where: { id: habitId },
    data: {
      isConsolidated: false,
    },
  });
};

export const archiveHabit = async (habitId: number) => {
  return await prisma.habit.update({
    where: { id: habitId },
    data: {
      status: "ARCHIVED",
    },
  });
};

export const getEarliestHabitDate = async (userId: number) => {
  return await prisma.habit.findFirst({
    where: { userId },
    orderBy: { createdAt: "asc" },
    select: { createdAt: true },
  });
};

export const getUserHabitsWithCompliances = async (
  userId: number,
  from: Date,
  to: Date,
) => {
  return await prisma.habit.findMany({
    where: {
      userId,
    },
    include: {
      scheduledDays: true,
      unit: {
        select: { name: true },
      },
      compliances: {
        where: {
          date: {
            gte: startOfDay(from),
            lte: endOfDay(to),
          },
        },
      },
    },
  });
};

export const getHabitsWithCompletedCompliances = async (habitId: number) => {
  return await prisma.habit.findUnique({
    where: { id: habitId },
    include: {
      compliances: {
        where: {
          isCompleted: true,
        },
      },
    },
  });
};

export const getHabitsWithCompletedCompliancesAndUnit = async (
  habitId: number,
) => {
  return await prisma.habit.findUnique({
    where: { id: habitId },
    include: {
      compliances: {
        where: {
          isCompleted: true,
        },
      },
      unit: true,
    },
  });
};

export const createCompliance = async (
  habitId: number,
  date: Date,
  isCompleted: boolean,
) => {
  return await prisma.compliance.create({
    data: {
      habitId,
      date,
      isCompleted,
    },
  });
};

export const upsertCompliance = async (
  habitId: number,
  date: Date,
  isCompleted: boolean,
  recordedAmount: number,
) => {
  return await prisma.compliance.upsert({
    where: {
      habitId_date: {
        habitId,
        date,
      },
    },
    update: {
      isCompleted,
      recordedAmount,
    },
    create: {
      habitId,
      date,
      isCompleted,
      recordedAmount,
    },
  });
};

export const deleteCompliance = async (habitId: number, day?: Date) => {
  return await prisma.compliance.deleteMany({
    // deleteMany para evitar error si no hay compliance esa fecha (puede pasar con Quantity)
    where: { habitId, date: day },
  });
};
