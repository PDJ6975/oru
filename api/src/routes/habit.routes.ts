import { Router } from "express";
import * as habitController from "../controllers/habit.controller.js";
import { verifyUser } from "../middleware/user.validation.js";

export const habitRoutes = Router();

habitRoutes.get("/habits", verifyUser, habitController.getUserHabits);
