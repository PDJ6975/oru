import { NextFunction, Request, Response } from "express";
import { validationResult } from "express-validator";
import createHttpError from "http-errors";

export const validateRequest = (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  const errors = validationResult(req);

  if (!errors.isEmpty()) {
    return next(
      createHttpError(400, "Invalid request body", {
        errors: errors.array(),
      }),
    );
  }

  next();
};
