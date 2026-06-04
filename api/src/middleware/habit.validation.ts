import { body, query } from "express-validator";
import { HabitType, WeekDay } from "../generated/prisma/enums.js";
import { NextFunction, Request, Response } from "express";
import * as unitService from "../services/unit.service.js";
import createError from "http-errors";
import { validateRequest } from "./validateRequest.js";
import {
  HABIT_FILTER_SCHEDULE,
  HABIT_FILTER_STATUS,
} from "../types/habit.types.js";

const iconValidation = body("icon")
  .isString()
  .withMessage("Icon must be a string")
  .trim()
  .isLength({ min: 1 })
  .withMessage("Icon cannot be empty")
  .isLength({ max: 16 })
  .withMessage("Icon must be at most 16 characters");

const nameValidation = body("name")
  .isString()
  .withMessage("Name must be a string")
  .trim()
  .isLength({ min: 1 })
  .withMessage("Name cannot be empty")
  .isLength({ max: 20 })
  .withMessage("Name must be at most 20 characters");

const typeValidation = body("type")
  .isString()
  .withMessage("Type must be a string")
  .trim()
  .isIn(Object.values(HabitType))
  .withMessage("Type must be either BOOLEAN or QUANTITY");

const dailyGoalValidationTypes = body("dailyGoal").custom((value, { req }) => {
  if (req.body.type === HabitType.BOOLEAN && "dailyGoal" in req.body) {
    throw new createError.BadRequest(
      "Daily goal must not be provided for BOOLEAN type",
    );
  }
  if (req.body.type === HabitType.QUANTITY && !("dailyGoal" in req.body)) {
    throw new createError.BadRequest(
      "Daily goal must be provided for QUANTITY type",
    );
  }
  if (req.body.type === HabitType.QUANTITY) {
    if (typeof value !== "number") {
      throw new createError.BadRequest("Daily goal must be a number");
    }
    if (value <= 0 || value >= 100000) {
      throw new createError.BadRequest(
        "Daily goal must be a positive number less than 100000",
      );
    }
  }
  return true;
});

const noteValidation = body("note")
  .optional()
  .isString()
  .withMessage("Note must be a string")
  .trim()
  .isLength({ max: 200 })
  .withMessage("Note must be at most 200 characters");

const scheduledDaysValidation = body("scheduledDays")
  .isArray({ min: 1 })
  .withMessage("Scheduled days must be a non-empty array")
  .custom((days: string[]) => {
    // All days must be valid week days
    if (!days.every((day) => Object.values(WeekDay).includes(day as WeekDay))) {
      throw new createError.BadRequest(
        "Scheduled days must be valid week days: MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY, SUNDAY",
      );
    }
    // No duplicate days allowed
    const uniqueDays = new Set(days);
    if (uniqueDays.size !== days.length) {
      throw new createError.BadRequest(
        "Scheduled days must not contain duplicates",
      );
    }
    return true;
  });

const unitValidation = body("unitId")
  .optional()
  .isInt({ gt: 0 })
  .withMessage("Unit ID must be a positive integer");

export const validateUnitForHabit = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const unitId = req.body.unitId;
    if (unitId) {
      const unitExists = await unitService.getUnit(unitId);
      if (!unitExists) {
        throw new createError.NotFound("Unit does not exist");
      }
      // Si la unidad tiene usuario, comprobar que el usuario de la unidad es el mismo que el de la sesión
      if (unitExists.userId && unitExists.userId !== res.locals.userId) {
        throw new createError.Forbidden("You are not the owner of this unit");
      }
    }
    next();
  } catch (error) {
    next(error);
  }
};

const validateStatusQuery = query("status")
  .optional()
  .isString()
  .withMessage("Status must be a string")
  .trim()
  .isIn(Object.values(HABIT_FILTER_STATUS))
  .withMessage("Status must be either active, archived, or all");

const validateFilterQuery = query("filter")
  .optional()
  .isString()
  .withMessage("Filter must be a string")
  .trim()
  .isIn(Object.values(HABIT_FILTER_SCHEDULE))
  .withMessage("Filter must be either all, scheduled, or rest");

const validateDayQuery = query("day")
  .optional()
  .isString()
  .withMessage("Day must be a string")
  .trim()
  .isIn(Object.values(WeekDay))
  .withMessage(
    "Day must be a valid week day: MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY, SUNDAY",
  );

const validateQueriesCombinations = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const day = req.query.day;
    const status = req.query.status ?? "all";
    const filter = req.query.filter ?? "all";

    if (status === "active" && filter !== "all" && !day) {
      throw new createError.BadRequest(
        "Day is required when filtering by active habits with a schedule",
      );
    }

    if (status === "archived" && filter !== "all") {
      throw new createError.BadRequest(
        "Schedule filter is not allowed when filtering by archived habits",
      );
    }

    if (status === "all" && filter !== "all") {
      throw new createError.BadRequest(
        "Schedule filter is not allowed when filtering by all habits",
      );
    }

    next();
  } catch (error) {
    next(error);
  }
};

export const validateCreateHabit = [
  iconValidation,
  nameValidation,
  typeValidation,
  dailyGoalValidationTypes,
  noteValidation,
  scheduledDaysValidation,
  unitValidation,
  validateRequest,
];

export const validateGetHabits = [
  validateStatusQuery,
  validateFilterQuery,
  validateDayQuery,
  validateQueriesCombinations,
  validateRequest,
];
