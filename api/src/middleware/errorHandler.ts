import { NextFunction, Request, Response } from "express";
import { logger } from "../config/logger.js";
import createHttpError, { HttpError } from "http-errors";

export function errorHandler(
  err: Error | HttpError,
  _req: Request,
  res: Response,
  _next: NextFunction,
) {
  logger.error(err.message);
  if (createHttpError.isHttpError(err)) {
    return res.status(err.statusCode).json({
      error: {
        message: err.message,
        status: err.statusCode,
        ...("errors" in err ? { errors: err.errors } : {}),
      },
    });
  }

  return res.status(500).json({
    error: {
      message: "Internal server error",
      status: 500,
    },
  });
}
