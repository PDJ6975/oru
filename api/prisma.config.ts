import { defineConfig } from "prisma/config";
import { bootEnv } from "./src/config/bootConfig.js";

export default defineConfig({
  schema: "src/models",
  migrations: {
    path: "prisma/migrations",
    seed: "tsx prisma/seed.ts",
  },
  datasource: {
    url: bootEnv.DATABASE_URL,
  },
});
