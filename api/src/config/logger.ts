import pino from "pino";
import { bootEnv } from "./bootConfig.js";

export const logger = pino({
  level: bootEnv.ORU_LOG_LEVEL,
  transport:
    bootEnv.NODE_ENV === "development"
      ? {
          target: "pino-pretty",
          options: {
            colorize: true,
            translateTime: "HH:MM:ss",
            ignore: "pid,hostname",
          },
        }
      : undefined,
});
