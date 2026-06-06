import dotenv from "dotenv";
import path from "node:path";

const envPath =
  process.env.ORU_BOOT_ENV_PATH ?? path.resolve(process.cwd(), ".env");
dotenv.config({ path: envPath, quiet: true });

export const bootEnv = {
  // Configuration
  NODE_ENV: process.env.NODE_ENV || "development",
  PORT: process.env.PORT || 3000,
  ORU_LOG_LEVEL: process.env.ORU_LOG_LEVEL || "info",

  // Database
  DATABASE_URL: process.env.DATABASE_URL,

  // Bussiness Rules
  MAX_UNITS_PER_USER: parseInt(process.env.MAX_UNITS_PER_USER || "20", 10),
  CONSOLIDATION_THRESHOLD_DAYS: parseInt(
    process.env.CONSOLIDATION_THRESHOLD_DAYS || "66",
    10,
  ),
  DAILY_BONUS_PROGRESS: parseInt(process.env.DAILY_BONUS_PROGRESS || "3", 10),
};
