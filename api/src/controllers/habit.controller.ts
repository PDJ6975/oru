import { NextFunction, Request, Response } from "express";
import * as habitService from "../services/habit.service.js";
import {
  HabitFilterSchedule,
  HabitFilterStatus,
  HabitInput,
} from "../types/habit.types.js";
import { WeekDay } from "../generated/prisma/enums.js";

export const getUserHabits = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const userId = res.locals.userId;
    const status = (req.query.status ?? "all") as HabitFilterStatus;
    const filter = (req.query.filter ?? "all") as HabitFilterSchedule;
    const day = req.query.day as WeekDay;
    const habits = await habitService.getUserHabits(
      userId,
      status,
      filter,
      day,
    );
    res.status(200).json(habits);
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

    const habitInput: HabitInput = {
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
