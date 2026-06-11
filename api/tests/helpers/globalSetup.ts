import { execSync } from "node:child_process";
import { Client } from "pg";
import { bootEnv } from "../../src/config/bootConfig.js";

const TEST_DATABASE_URL = bootEnv.DATABASE_URL_TEST as string;
const TEST_DB_NAME = new URL(TEST_DATABASE_URL).pathname.slice(1);

// Conexión a la base administrativa "postgres" para poder crear la BD de test.
const adminUrl = new URL(TEST_DATABASE_URL);
adminUrl.pathname = "/postgres";

const createTestDatabaseIfNeeded = async () => {
  const client = new Client({ connectionString: adminUrl.toString() });
  await client.connect();
  try {
    const { rowCount } = await client.query(
      "SELECT 1 FROM pg_database WHERE datname = $1",
      [TEST_DB_NAME],
    );
    if (rowCount === 0) {
      await client.query(`CREATE DATABASE "${TEST_DB_NAME}"`);
    }
  } finally {
    await client.end();
  }
};

export default async function setup() {
  await createTestDatabaseIfNeeded();

  // Aplicar las migraciones
  execSync("pnpm exec prisma migrate deploy", {
    stdio: "inherit",
    env: { ...process.env, DATABASE_URL: TEST_DATABASE_URL },
  });
}
