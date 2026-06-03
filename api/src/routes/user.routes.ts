import { Router } from "express";
import * as userController from "../controllers/user.controller.js";
import {
  validateCreateUser,
  verifyUser,
} from "../middleware/user.validation.js";

export const userRoutes = Router();

userRoutes.post("/users", validateCreateUser, userController.createUser);
userRoutes.get("/users/me", verifyUser, userController.getUserInfo);
