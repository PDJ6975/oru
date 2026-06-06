import { NextFunction, Request, Response } from "express";
import * as origamiService from "../services/origami.service.js";
import createError from "http-errors";

export const validateActiveAssignment = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const userId = res.locals.userId;
    const assignment = await origamiService.getActiveAssignmentRaw(userId);

    if (!assignment) {
      throw new createError.BadRequest("User has no active origami assignment");
    }

    next();
  } catch (error) {
    next(error);
  }
};

export const validateNextPhase = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const userId = res.locals.userId;
    const assignment = await origamiService.getActiveAssignmentRaw(userId);
    const threshold = origamiService.getNextThreshold(
      assignment!.origami.phases,
      assignment!.revealedPhase,
    );

    // Validar que el origami no esté completado (treshold null)
    // Validar que se ha llegado al umbral de cambio de fase
    if (threshold === null || assignment!.progress < threshold) {
      throw new createError.BadRequest("Cannot advance to next phase");
    }
    next();
  } catch (error) {
    next(error);
  }
};

export const validateNextPhaseOrigami = [
  validateActiveAssignment,
  validateNextPhase,
];
