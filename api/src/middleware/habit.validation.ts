import { body, query, param } from "express-validator";
import { HabitType, WeekDay } from "../generated/prisma/enums.js";
import { NextFunction, Request, Response } from "express";
import * as unitService from "../services/unit.service.js";
import createError from "http-errors";
import { validateRequest } from "./validateRequest.js";
import {
  HABIT_FILTER_SCHEDULE,
  HABIT_FILTER_STATUS,
} from "../types/habit.types.js";
import * as habitService from "../services/habit.service.js";
import { endOfDay, startOfDay } from "date-fns";
import { getComplianceForDay } from "../utils/today.compliances.js";
import { toWeekDay } from "../utils/weekday.js";

const iconValidation = (optional = false) => {
  const validator = body("icon");
  if (optional) validator.optional();

  return validator
    .isString()
    .withMessage("Icon must be a string")
    .trim()
    .isLength({ min: 1 })
    .withMessage("Icon cannot be empty")
    .isLength({ max: 16 })
    .withMessage("Icon must be at most 16 characters");
};

const nameValidation = (optional = false) => {
  const validator = body("name");
  if (optional) validator.optional();

  return validator
    .isString()
    .withMessage("Name must be a string")
    .trim()
    .isLength({ min: 1 })
    .withMessage("Name cannot be empty")
    .isLength({ max: 20 })
    .withMessage("Name must be at most 20 characters");
};

const noteValidation = (optional = false) => {
  const validator = body("note");
  if (optional) validator.optional();

  return validator
    .isString()
    .withMessage("Note must be a string")
    .trim()
    .isLength({ max: 200 })
    .withMessage("Note must be at most 200 characters");
};

const scheduledDaysValidation = (optional = false) => {
  const validator = body("scheduledDays");
  if (optional) validator.optional();

  return validator
    .isArray({ min: 1 })
    .withMessage("Scheduled days must be a non-empty array")
    .custom((days: string[]) => {
      // All days must be valid week days
      if (
        !days.every((day) => Object.values(WeekDay).includes(day as WeekDay))
      ) {
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
};

const unitValidation = (optional = false) => {
  const validator = body("unitId");
  if (optional) validator.optional();

  return validator
    .isInt({ gt: 0 })
    .withMessage("Unit ID must be a positive integer");
};

const typeValidation = body("type")
  .isString()
  .withMessage("Type must be a string")
  .trim()
  .isIn(Object.values(HabitType))
  .withMessage("Type must be either BOOLEAN or QUANTITY");

const amountValidation = body("amount")
  .optional()
  .isNumeric()
  .withMessage("Amount must be a number")
  .custom((value) => {
    if (value < 0 || value >= 100000) {
      throw new createError.BadRequest(
        "Amount must be a positive number less than 100000",
      );
    }
    return true;
  });

const ensureTypeAndDailyGoalAndUnitConsistency = (
  type: HabitType,
  dailyGoal: unknown,
  hasDailyGoal: boolean,
  hasUnit: boolean,
  requireForQuantity: boolean,
) => {
  // BOOLEAN: ni objetivo diario ni unidad
  if (type === HabitType.BOOLEAN && hasDailyGoal) {
    throw new createError.BadRequest(
      "Daily goal must not be provided for BOOLEAN type",
    );
  }

  if (type === HabitType.BOOLEAN && hasUnit) {
    throw new createError.BadRequest(
      "Unit must not be provided for BOOLEAN type",
    );
  }

  // QUANTITY (creación): objetivo diario y unidad obligatorios
  if (type === HabitType.QUANTITY && requireForQuantity && !hasDailyGoal) {
    throw new createError.BadRequest(
      "Daily goal must be provided for QUANTITY type",
    );
  }

  if (type === HabitType.QUANTITY && requireForQuantity && !hasUnit) {
    throw new createError.BadRequest("Unit must be provided for QUANTITY type");
  }

  if (type === HabitType.QUANTITY && hasDailyGoal) {
    if (typeof dailyGoal !== "number") {
      throw new createError.BadRequest("Daily goal must be a number");
    }

    if (dailyGoal <= 0 || dailyGoal >= 100000) {
      throw new createError.BadRequest(
        "Daily goal must be a positive number less than 100000",
      );
    }
  }
};

const dailyGoalValidationTypes = body("dailyGoal").custom((value, { req }) => {
  ensureTypeAndDailyGoalAndUnitConsistency(
    req.body.type,
    value,
    "dailyGoal" in req.body,
    "unitId" in req.body,
    true,
  );
  return true;
});

export const validateDailyGoalForUpdate = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const habitId = Number(req.params.habitId);
    const habit = await habitService.getHabitById(habitId);

    ensureTypeAndDailyGoalAndUnitConsistency(
      habit!.type,
      req.body.dailyGoal,
      "dailyGoal" in req.body,
      "unitId" in req.body,
      false,
    );
    next();
  } catch (error) {
    next(error);
  }
};

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
    const status = req.query.status ?? "all";
    const filter = req.query.filter ?? "all";

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

const validateHabitIdParam = param("habitId")
  .isInt({ gt: 0 })
  .withMessage("Habit ID must be a positive integer");

export const validateHabitOwner = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const habitId = Number(req.params.habitId);
    const userId = res.locals.userId;

    const habit = await habitService.getHabitById(habitId);

    if (!habit) {
      throw new createError.NotFound("Habit not found with id: " + habitId);
    }

    if (habit.userId !== userId) {
      throw new createError.Forbidden("You are not the owner of this habit");
    }

    next();
  } catch (error) {
    next(error);
  }
};

export const validateHabitCanBeArchived = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const habitId = Number(req.params.habitId);
    const habit = await habitService.getHabitById(habitId);

    if (habit!.status === "ARCHIVED") {
      throw new createError.BadRequest("Habit is already archived");
    }

    if (!habit!.isConsolidated) {
      throw new createError.BadRequest(
        "Only consolidated habits can be archived",
      );
    }
    next();
  } catch (error) {
    next(error);
  }
};

export const validateAmountWithHabitType = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const habitId = Number(req.params.habitId);
    const amount = req.body?.amount;
    const habit = await habitService.getHabitById(habitId);

    if (habit!.type === HabitType.BOOLEAN && amount !== undefined) {
      throw new createError.BadRequest(
        "Amount must not be provided for BOOLEAN type habits",
      );
    }

    if (habit!.type === HabitType.QUANTITY && amount === undefined) {
      throw new createError.BadRequest(
        "Amount must be provided for QUANTITY type habits",
      );
    }
    next();
  } catch (error) {
    next(error);
  }
};

export const validateHabitStatusForToggle = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const habitId = Number(req.params.habitId);
    const habit = await habitService.getHabitById(habitId);

    if (habit!.status === "ARCHIVED") {
      throw new createError.BadRequest("Cannot toggle an archived habit");
    }

    const today = toWeekDay(startOfDay(new Date()));
    const isScheduledToday = habit!.scheduledDays.some(
      (sd) => sd.day === today,
    );

    if (!isScheduledToday) {
      throw new createError.BadRequest(
        "Can only toggle habits scheduled for today",
      );
    }

    next();
  } catch (error) {
    next(error);
  }
};

export const validateCreateHabit = [
  iconValidation(),
  nameValidation(),
  typeValidation,
  dailyGoalValidationTypes,
  noteValidation(true),
  scheduledDaysValidation(),
  unitValidation(true),
  validateRequest,
  validateUnitForHabit,
];

export const validateGetHabits = [
  validateStatusQuery,
  validateFilterQuery,
  validateDayQuery,
  validateRequest,
  validateQueriesCombinations,
];

export const validateGetHabitById = [
  validateHabitIdParam,
  validateRequest,
  validateHabitOwner,
];

export const validateUpdateHabit = [
  validateHabitIdParam,
  iconValidation(true),
  nameValidation(true),
  noteValidation(true),
  scheduledDaysValidation(true),
  unitValidation(true),
  validateRequest,
  validateUnitForHabit,
  validateHabitOwner,
  validateDailyGoalForUpdate,
];

export const validateDeleteHabit = [
  validateHabitIdParam,
  validateRequest,
  validateHabitOwner,
];

export const validateArchiveHabit = [
  validateHabitIdParam,
  validateRequest,
  validateHabitOwner,
  validateHabitCanBeArchived,
];

export const validateToggleHabit = [
  validateHabitIdParam,
  amountValidation,
  validateRequest,
  validateHabitOwner,
  validateAmountWithHabitType,
  validateHabitStatusForToggle,
];
