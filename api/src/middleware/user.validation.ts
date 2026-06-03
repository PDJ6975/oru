import { type Request, type Response, type NextFunction } from "express";
import { body } from "express-validator";
import createError from "http-errors";
import * as userService from "../services/user.service.js";
import { validateRequest } from "./validateRequest.js";

const nameValidation = body("name")
  .isString()
  .withMessage("Name must be a string")
  .trim()
  .isLength({ min: 1 })
  .withMessage("Name cannot be empty")
  .isLength({ max: 30 })
  .withMessage("Name must be at most 30 characters");

const getUserToken = (req: Request) => {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    throw new createError.Unauthorized("Missing authorization token");
  }
  const token = authHeader.split(" ")[1];
  return token;
};

export const verifyUser = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const token = getUserToken(req);
    const session = await userService.getSessionByToken(token);
    if (!session) {
      throw new createError.Unauthorized("Invalid token");
    }
    res.locals.userId = session.userId;
    next();
  } catch (error) {
    next(error);
  }
};

export const validateCreateUser = [nameValidation, validateRequest];
