import { NextFunction, Request, Response } from "express";
import * as origamiService from "../services/origami.service.js";

export const getOrigami = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const userId = res.locals.userId;
    const origami = await origamiService.getActiveAssignment(userId);
    res.status(200).json(origami);
  } catch (error) {
    next(error);
  }
};

export const nextPhase = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const userId = res.locals.userId;
    const origami = await origamiService.nextPhase(userId);
    res.status(204).json(origami);
  } catch (error) {
    next(error);
  }
};
