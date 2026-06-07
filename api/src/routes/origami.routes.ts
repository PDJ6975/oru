import { Router } from "express";
import { verifyUser } from "../middleware/user.validation.js";
import * as origamiController from "../controllers/origami.controller.js";
import {
  validateChangeOrigami,
  validateGetOrigamisCompletedInAYear,
  validateNextPhaseOrigami,
} from "../middleware/origami.validator.js";

export const origamiRoutes = Router();

origamiRoutes.get("/origami", verifyUser, origamiController.getOrigami);
origamiRoutes.post(
  "/origami/next-phase",
  verifyUser,
  validateNextPhaseOrigami,
  origamiController.nextPhase,
);
origamiRoutes.post(
  "/origami/new",
  verifyUser,
  validateChangeOrigami,
  origamiController.assignNewOrigami,
);
origamiRoutes.get(
  "/origamis/completed",
  verifyUser,
  validateGetOrigamisCompletedInAYear,
  origamiController.getOrigamisCompletedInAYear,
);
