import { bootEnv } from "../src/config/bootConfig.js";
import { logger } from "../src/config/logger.js";
import { prisma } from "../src/db/prisma.js";
import { seedBaseData, seedDevData } from "../prisma/utils.js";

async function main() {
  await seedBaseData();

  if (bootEnv.NODE_ENV === "development") {
    await seedDevData();
  }
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    logger.error(error, "Error seeding database");
    await prisma.$disconnect();
    process.exit(1);
  });
