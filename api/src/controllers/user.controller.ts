import { NextFunction, Request, Response } from "express";
import * as userService from "../services/user.service.js";
import { User } from "../generated/prisma/client.js";

const toDTO = (user: User) => {
  return {
    name: user.name,
  };
};

export const createUser = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const { name } = req.body;
    const token = await userService.createUser(name);

    res.status(201).json({ token });
  } catch (error) {
    next(error);
  }
};

export const getUser = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const userId = res.locals.userId;
    const user = await userService.getUserById(userId);

    res.status(200).json({ user: toDTO(user!) });
  } catch (error) {
    next(error);
  }
};
