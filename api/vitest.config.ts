import { defineConfig } from "vitest/config";
import { bootEnv } from "./src/config/bootConfig.js";

export default defineConfig({
  test: {
    environment: "node",
    globals: false,
    include: ["tests/**/*.{test,spec}.ts"],
    globalSetup: ["tests/helpers/globalSetup.ts"],
    fileParallelism: false,
    env: {
      DATABASE_URL: bootEnv.DATABASE_URL_TEST as string,
      NODE_ENV: "test",
      ORU_LOG_LEVEL: "silent",
    },
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      include: ["src/**/*.ts"],
      exclude: ["src/generated/**", "src/server.ts", "src/**/*.d.ts"],
    },
  },
});
