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
