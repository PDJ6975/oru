import { NextFunction, Request, Response } from "express";
import * as habitService from "../services/habit.service.js";
import {
  HabitFilterSchedule,
  HabitFilterStatus,
  HabitCreationInput,
} from "../types/habit.types.js";
import { toHabitUpdateInput } from "../utils/habit.mapper.js";

export const getUserHabits = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const userId = res.locals.userId;
    const status = (req.query.status ?? "all") as HabitFilterStatus;
    const filter = (req.query.filter ?? "all") as HabitFilterSchedule;
    const habits = await habitService.getUserHabits(userId, status, filter);
    res.status(200).json(habits);
  } catch (error) {
    next(error);
  }
};

export const getHabitById = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const habitId = Number(req.params.habitId);
    const habit = await habitService.getHabitById(habitId);
    res.status(200).json(habit);
  } catch (error) {
    next(error);
  }
};

export const createHabit = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const { icon, name, type, dailyGoal, note, unitId, scheduledDays } =
      req.body;

    const habitInput: HabitCreationInput = {
      icon,
      name,
      type,
      dailyGoal,
      note,
      unitId,
      scheduledDays,
    };
    const userId = res.locals.userId;

    const newHabit = await habitService.createHabit(userId, habitInput);
    res.status(201).json(newHabit);
  } catch (error) {
    next(error);
  }
};

export const updateHabit = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const habitId = Number(req.params.habitId);
    const habitInput = toHabitUpdateInput(req.body);

    const updatedHabit = await habitService.updateHabit(habitId, habitInput);
    res.status(200).json(updatedHabit);
  } catch (error) {
    next(error);
  }
};

export const deleteHabit = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const habitId = Number(req.params.habitId);
    await habitService.deleteHabit(habitId);
    res.status(204).send();
  } catch (error) {
    next(error);
  }
};

export const archiveHabit = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const habitId = Number(req.params.habitId);
    await habitService.archiveHabit(habitId);
    return res.status(204).send();
  } catch (error) {
    next(error);
  }
};

export const toggleHabit = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const habitId = Number(req.params.habitId);
    const { amount } = req.body;
    const userId = res.locals.userId;

    const updatedHabit = await habitService.toggleHabit(
      userId,
      habitId,
      amount,
    );
    res.status(200).json(updatedHabit);
  } catch (error) {
    next(error);
  }
};
