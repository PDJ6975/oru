import { startOfDay } from "date-fns";
import { prisma } from "../db/prisma.js";

export const getActiveAssignment = async (userId: number) => {
  return prisma.assignment.findFirst({
    where: { userId, completedAt: null },
    include: { origami: true },
  });
};

export const getUnassignedOrigamis = async (userId: number) => {
  return prisma.origami.findMany({
    where: {
      assignments: {
        none: { userId },
      },
    },
  });
};

export const createAssignment = async (userId: number, origamiId: number) => {
  return prisma.assignment.create({
    data: {
      userId,
      origamiId,
      progress: 0,
      revealedPhase: 0,
    },
    include: { origami: true },
  });
};

export const updateProgress = async (
  assignmentId: number,
  newProgress: number,
) => {
  return prisma.assignment.update({
    where: { id: assignmentId },
    data: { progress: newProgress },
  });
};

export const updateAssignment = async (
  assignmentId: number,
  assignmentData: { newPhase?: number; completedAt?: Date },
) => {
  return prisma.assignment.update({
    where: { id: assignmentId },
    data: {
      revealedPhase: assignmentData.newPhase,
      completedAt: assignmentData.completedAt,
    },
    include: { origami: true },
  });
};

export const getOrigamisCompletedInAYear = async (
  userId: number,
  startOfYear: Date,
  endOfYear: Date,
) => {
  return prisma.assignment.findMany({
    where: {
      userId,
      completedAt: {
        gte: startOfYear,
        lt: endOfYear,
      },
    },
    include: { origami: true },
  });
};
