import * as habitRepository from "../repositories/habit.repository.js";

export const getUserHabits = async (userId: number) => {
  return await habitRepository.getUserHabits(userId);
};
