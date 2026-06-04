import { WeekDay } from "../generated/prisma/enums.js";
import * as habitRepository from "../repositories/habit.repository.js";
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
  return await habitRepository.getUserHabits(userId, status, filter, day);
};

export const createHabit = async (userId: number, habitInput: HabitInput) => {
  const { scheduledDays, ...habitData } = habitInput;
  return await habitRepository.createHabit(userId, habitData, scheduledDays);
};
