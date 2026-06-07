import { query } from "express-validator";
import { validateRequest } from "./validateRequest.js";

export const yearValidation = query("year")
  .isInt({ min: 1900, max: new Date().getFullYear() })
  .withMessage(
    "Year must be a valid integer between 1900 and the current year.",
  );

export const validateStats = [yearValidation, validateRequest];
