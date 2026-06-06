import { Router } from "express";
import * as habitController from "../controllers/habit.controller.js";
import { verifyUser } from "../middleware/user.validation.js";
import {
  validateArchiveHabit,
  validateCreateHabit,
  validateDeleteHabit,
  validateGetHabitById,
  validateGetHabits,
  validateToggleHabit,
  validateUnitForHabit,
  validateUpdateHabit,
} from "../middleware/habit.validation.js";

export const habitRoutes = Router();

habitRoutes.get(
  "/habits",
  verifyUser,
  validateGetHabits,
  habitController.getUserHabits,
);
habitRoutes.get(
  "/habits/:habitId",
  verifyUser,
  validateGetHabitById,
  habitController.getHabitById,
);
habitRoutes.post(
  "/habits",
  verifyUser,
  validateCreateHabit,
  validateUnitForHabit,
  habitController.createHabit,
);

habitRoutes.patch(
  "/habits/:habitId",
  verifyUser,
  validateUpdateHabit,
  habitController.updateHabit,
);

habitRoutes.delete(
  "/habits/:habitId",
  verifyUser,
  validateDeleteHabit,
  habitController.deleteHabit,
);

habitRoutes.post(
  "/habits/:habitId/archive",
  verifyUser,
  validateArchiveHabit,
  habitController.archiveHabit,
);

habitRoutes.post(
  "/habits/:habitId/toggle",
  verifyUser,
  validateToggleHabit,
  habitController.toggleHabit,
);
