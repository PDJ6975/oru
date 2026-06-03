import { NextFunction, Request, Response } from "express";
import * as habitService from "../services/habit.service.js";

export const getUserHabits = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const userId = res.locals.userId;
    const habits = await habitService.getUserHabits(userId);
    res.status(200).json(habits);
  } catch (error) {
    next(error);
  }
};
