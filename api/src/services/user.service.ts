import * as userRepository from "../repositories/user.repository.js";
import crypto from "crypto";

export const getSessionByToken = async (token: string) => {
  const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
  const session = await userRepository.getSessionByTokenHash(tokenHash);
  return session;
};

export const createUser = async (name: string) => {
  const token = crypto.randomBytes(32).toString("hex");
  const tokenHash = crypto.createHash("sha256").update(token).digest("hex");

  await userRepository.createUser(tokenHash, name);

  return token;
};

export const getUserById = async (userId: number) => {
  return await userRepository.getUserById(userId);
};

export const updateLastComputedDay = async (
  userId: number,
  lastComputedDay: Date,
) => {
  return await userRepository.updateLastComputedDay(userId, lastComputedDay);
};

export const setDailyBonus = async (userId: number, applied: boolean) => {
  return await userRepository.setDailyBonus(userId, applied);
};
