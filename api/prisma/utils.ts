import { logger } from "../src/config/logger.js";
import { prisma } from "../src/db/prisma.js";

// Datos base sembrados en la BD. Compartidos entre prisma/seed.ts y los tests.
export const BASE_UNITS = [
  "uds",
  "min",
  "h",
  "km",
  "m",
  "kg",
  "g",
  "l",
  "cal",
  "págs",
];

export const ORIGAMI_CATALOG = [
  { name: "mariposa", phases: 5 },
  { name: "bailarina", phases: 6 },
  { name: "flor", phases: 6 },
  { name: "luna", phases: 6 },
];

// Siembra idempotente de los datos base (unidades base y catálogo de origamis).
// Reutilizada por el seed de producción y por el reseteo de la BD de test.
export async function seedBaseData() {
  for (const name of BASE_UNITS) {
    const existingUnit = await prisma.unit.findFirst({
      where: { name, userId: null },
    });
    if (!existingUnit) {
      await prisma.unit.create({ data: { name, userId: null } });
    }
  }

  for (const { name, phases } of ORIGAMI_CATALOG) {
    const existingOrigami = await prisma.origami.findFirst({
      where: { name },
    });
    if (!existingOrigami) {
      await prisma.origami.create({ data: { name, phases } });
    }
  }
}

export async function seedDevData() {
  const existingUser = await prisma.user.findFirst({
    where: { name: "Test User" },
  });
  if (existingUser) return;

  const user = await prisma.user.create({
    data: {
      name: "Test User",
      lastComputedDay: new Date(),
    },
  });

  const allDays = [
    "MONDAY",
    "TUESDAY",
    "WEDNESDAY",
    "THURSDAY",
    "FRIDAY",
    "SATURDAY",
    "SUNDAY",
  ] as const;
  const weekdays = allDays.slice(0, 5);

  const activeHabits = [
    {
      icon: "🏃",
      name: "Correr",
      type: "QUANTITY" as const,
      dailyGoal: 5,
      unitName: "km",
    },
    {
      icon: "📖",
      name: "Leer",
      type: "QUANTITY" as const,
      dailyGoal: 30,
      unitName: "min",
    },
    {
      icon: "🧘",
      name: "Meditar",
      type: "BOOLEAN" as const,
      dailyGoal: null,
      unitName: null,
    },
    {
      icon: "💧",
      name: "Beber agua",
      type: "QUANTITY" as const,
      dailyGoal: 8,
      unitName: "uds",
    },
  ];

  const archivedHabits = [
    {
      icon: "🎸",
      name: "Practicar guitarra",
      type: "QUANTITY" as const,
      dailyGoal: 20,
      unitName: "min",
    },
    {
      icon: "✍️",
      name: "Escribir diario",
      type: "BOOLEAN" as const,
      dailyGoal: null,
      unitName: null,
    },
  ];

  for (const h of activeHabits) {
    const unit = h.unitName
      ? await prisma.unit.findFirst({
          where: { name: h.unitName, userId: null },
        })
      : null;

    await prisma.habit.create({
      data: {
        icon: h.icon,
        name: h.name,
        type: h.type,
        dailyGoal: h.dailyGoal,
        status: "ACTIVE",
        userId: user.id,
        unitId: unit?.id ?? null,
        scheduledDays: {
          create: allDays.map((day) => ({ day })),
        },
      },
    });
  }

  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  for (const h of archivedHabits) {
    const unit = h.unitName
      ? await prisma.unit.findFirst({
          where: { name: h.unitName, userId: null },
        })
      : null;

    await prisma.habit.create({
      data: {
        icon: h.icon,
        name: h.name,
        type: h.type,
        dailyGoal: h.dailyGoal,
        status: "ARCHIVED",
        archivedAt: thirtyDaysAgo,
        userId: user.id,
        unitId: unit?.id ?? null,
        scheduledDays: {
          create: weekdays.map((day) => ({ day })),
        },
      },
    });
  }

  const previousYear = new Date().getFullYear() - 1;
  const habits = await prisma.habit.findMany({ where: { userId: user.id } });

  for (const habit of habits) {
    await prisma.habitStats.create({
      data: {
        year: previousYear,
        currentStreak: Math.floor(Math.random() * 15) + 1,
        bestStreak: Math.floor(Math.random() * 30) + 10,
        totalCompletions: Math.floor(Math.random() * 200) + 50,
        totalAccumulation: habit.dailyGoal
          ? Math.floor(Math.random() * 1000) + 100
          : 0,
        recordedDays: Math.floor(Math.random() * 200) + 50,
        habitId: habit.id,
      },
    });
  }

  await prisma.userStats.create({
    data: {
      year: previousYear,
      currentStreak: Math.floor(Math.random() * 20) + 5,
      bestStreak: Math.floor(Math.random() * 40) + 15,
      habitsCompleted: Math.floor(Math.random() * 500) + 100,
      perfectDays: Math.floor(Math.random() * 60) + 10,
      totalScheduled: Math.floor(Math.random() * 800) + 300,
      userId: user.id,
    },
  });

  const origamis = await prisma.origami.findMany({
    where: { name: { in: ["mariposa", "flor"] } },
  });

  for (const origami of origamis) {
    await prisma.assignment.create({
      data: {
        progress: origami.phases,
        revealedPhase: origami.phases,
        completedAt: new Date(),
        userId: user.id,
        origamiId: origami.id,
      },
    });
  }

  logger.info("Dev seed data created for Test User");
}
