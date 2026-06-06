import * as origamiRepository from "../repositories/origami.repository.js";
import createError from "http-errors";
import * as userService from "./user.service.js";
import * as habitService from "./habit.service.js";
import { startOfDay } from "date-fns";
import { bootEnv } from "../config/bootConfig.js";
import { Prisma } from "../generated/prisma/client.js";
import { getComplianceForDay } from "../utils/today.compliances.js";

export const getActiveAssignment = async (userId: number) => {
  // Obtener asignación con fecha de completado a null (origami activo)
  let activeAssignment = await origamiRepository.getActiveAssignment(userId);

  // Si no tiene -> usuario nuevo -> asignar origami
  if (!activeAssignment) {
    activeAssignment = await assignOrigami(userId);
  }

  // Obtener nombre del origami vinculado al nombre de los recursos
  const origamiName = getOrigamiName(
    activeAssignment!.origami.name,
    activeAssignment!.revealedPhase,
  );

  // Obtener siguiente umbral -> Para mostrar animación de avance al llegar
  const nextThreshold = getNextThreshold(
    activeAssignment!.origami.phases,
    activeAssignment!.revealedPhase,
  );

  // Ver si hay más origamis disponibles para mostrar botón de cambio
  // cuando el progreso es 100 y hasNextOrigamiAvailable sea true
  const unassigned = await getUnassignedOrigamis(userId);
  const hasNextOrigamiAvailable = unassigned.length > 0;

  return {
    origamiName,
    progress: activeAssignment!.progress,
    nextThreshold,
    isCompleted: nextThreshold === null && activeAssignment!.progress >= 100,
    hasNextOrigami: hasNextOrigamiAvailable,
  };
};

export const getActiveAssignmentRaw = async (userId: number) => {
  return await origamiRepository.getActiveAssignment(userId);
};

export const getNextThreshold = (
  totalPhases: number,
  revealedPhase: number,
) => {
  const nextPhase = revealedPhase + 1;

  if (nextPhase >= totalPhases) {
    return null;
  }

  // redondeo para que el umbral sea entero y no de problemas con el progreso
  return Math.round(nextPhase * (100 / (totalPhases - 1))); // -1 para representar el nº de saltos entre fases
};

const getOrigamiName = (name: string, phase: number) => {
  return name + "_fase" + phase;
};

export const assignOrigami = async (userId: number) => {
  // Filtrar por no asignados para permitir nueva asignación o asignación inicial
  const unassignedOrigamis = await getUnassignedOrigamis(userId);

  // Si quedan origamis disponibles, asignamos uno aleatorio
  if (unassignedOrigamis.length === 0) {
    throw new createError.Conflict("No more origamis available to assign");
  }

  const randomIndex = Math.floor(Math.random() * unassignedOrigamis.length);
  const origamiToAssign = unassignedOrigamis[randomIndex];

  const createdAssignment = await origamiRepository.createAssignment(
    userId,
    origamiToAssign.id,
  );

  return createdAssignment;
};

const getUnassignedOrigamis = async (userId: number) => {
  return await origamiRepository.getUnassignedOrigamis(userId);
};

export const evaluateProgress = async (userId: number) => {
  const user = await userService.getUserById(userId);
  const assignment = await origamiRepository.getActiveAssignment(userId);
  if (!assignment) return; // No hay asignación activa (usuario con todos los origamis completados), no se hace nada
  const activeHabits = await habitService.getUserHabits(
    userId,
    "active",
    "scheduled",
  );
  const today = startOfDay(new Date());
  const numberOfActiveHabits = activeHabits.length;
  let numberOfCompletedHabits = activeHabits.filter(
    (habit) => getComplianceForDay(habit.compliances, today)?.isCompleted,
  ).length;

  // Si se completan todos los hábitos activos del día se aplica el bonus
  if (
    numberOfCompletedHabits === numberOfActiveHabits &&
    !user!.dailyBonusAplied
  )
    await applyDailyBonus(assignment);
  // Si se descompleta uno de los hábitos activos del día se quita el bonus
  else if (
    numberOfCompletedHabits < numberOfActiveHabits &&
    user!.dailyBonusAplied
  )
    await removeDailyBonus(assignment);
};

const applyDailyBonus = async (
  assignment: Prisma.AssignmentGetPayload<{ include: { origami: true } }>,
) => {
  const bonus = bootEnv.DAILY_BONUS_PROGRESS;
  const nextThreshold = getNextThreshold(
    assignment!.origami.phases,
    assignment!.revealedPhase,
  );
  const newProgress = Math.min(
    assignment!.progress + bonus,
    nextThreshold ?? 100,
  );

  await Promise.all([
    userService.setDailyBonus(assignment.userId, true),
    origamiRepository.updateProgress(assignment.id, newProgress),
  ]);
};

const removeDailyBonus = async (
  assignment: Prisma.AssignmentGetPayload<{ include: { origami: true } }>,
) => {
  const bonus = bootEnv.DAILY_BONUS_PROGRESS;
  const newProgress = Math.max(assignment!.progress - bonus, 0);

  await Promise.all([
    userService.setDailyBonus(assignment.userId, false),
    origamiRepository.updateProgress(assignment.id, newProgress),
  ]);
};

export const nextPhase = async (userId: number) => {
  const assignment = await origamiRepository.getActiveAssignment(userId);
  const newPhase = assignment!.revealedPhase + 1;
  await origamiRepository.updateAssignment(assignment!.id, newPhase);
  return getActiveAssignment(userId);
};
