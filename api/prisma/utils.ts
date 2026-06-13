import { addDays, startOfDay } from "date-fns";
import { bootEnv } from "../src/config/bootConfig.js";
import { logger } from "../src/config/logger.js";
import { prisma } from "../src/db/prisma.js";
import { WeekDay } from "../src/generated/prisma/enums.js";
import { getNextThreshold } from "../src/services/origami.service.js";
import * as userService from "../src/services/user.service.js";
import { toWeekDay } from "../src/utils/weekday.js";

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
  await prisma.user.deleteMany({ where: { name: "Test User" } });

  const token = await userService.createUser("Test User");
  const session = await userService.getSessionByToken(token);

  const userId = session!.userId;
  await userService.updateLastComputedDay(userId, new Date());

  const allDays = [
    WeekDay.MONDAY,
    WeekDay.TUESDAY,
    WeekDay.WEDNESDAY,
    WeekDay.THURSDAY,
    WeekDay.FRIDAY,
    WeekDay.SATURDAY,
    WeekDay.SUNDAY,
  ] as const;
  const weekdays = allDays.slice(0, 5);

  const currentYear = new Date().getFullYear();
  const previousYear = currentYear - 1;

  const createdAtPrev = new Date(previousYear, 0, 1);
  const createdAtCurr = new Date(currentYear, 0, 1);
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const today = startOfDay(new Date());
  const todayWeekday = toWeekDay(today);
  const daysExceptToday = allDays.filter((day) => day !== todayWeekday);

  type TodayCompliance = {
    isCompleted: boolean;
    recordedAmount: number | null;
  };

  type YearStats = {
    currentStreak: number;
    bestStreak: number;
    totalCompletions: number;
    totalAccumulation: number;
    recordedDays: number;
  };
  type SeedHabit = {
    icon: string;
    name: string;
    type: "QUANTITY" | "BOOLEAN";
    dailyGoal: number | null;
    unitName: string | null;
    note: string | null;
    today: TodayCompliance | null;
    statsPrev?: YearStats;
    statsCurr: YearStats;
    notScheduledToday?: boolean;
    isConsolidated?: boolean;
    pastCompletedCompliances?: number;
    randomPastCompliances?: boolean;
  };

  const activeHabits: SeedHabit[] = [
    {
      icon: "📖",
      name: "Leer",
      type: "QUANTITY",
      dailyGoal: 30,
      unitName: "min",
      note: "El príncipe cruel",
      today: { isCompleted: true, recordedAmount: 30 },
      randomPastCompliances: true,
      statsPrev: {
        currentStreak: 7,
        bestStreak: 40,
        totalCompletions: 251,
        totalAccumulation: 9180,
        recordedDays: 290,
      },
      statsCurr: {
        currentStreak: 7,
        bestStreak: 26,
        totalCompletions: 108,
        totalAccumulation: 4050,
        recordedDays: 129,
      },
    },
    {
      icon: "🌸",
      name: "Cuidar jardín",
      type: "BOOLEAN",
      dailyGoal: null,
      unitName: null,
      note: null,
      today: { isCompleted: true, recordedAmount: null },
      randomPastCompliances: true,
      statsPrev: {
        currentStreak: 18,
        bestStreak: 63,
        totalCompletions: 300,
        totalAccumulation: 0,
        recordedDays: 0,
      },
      statsCurr: {
        currentStreak: 18,
        bestStreak: 34,
        totalCompletions: 132,
        totalAccumulation: 0,
        recordedDays: 0,
      },
    },
    {
      icon: "💻",
      name: "Programar",
      type: "QUANTITY",
      dailyGoal: 20,
      unitName: "min",
      note: "API de hábitos",
      today: { isCompleted: true, recordedAmount: 25 },
      randomPastCompliances: true,
      statsCurr: {
        currentStreak: 5,
        bestStreak: 22,
        totalCompletions: 110,
        totalAccumulation: 3050,
        recordedDays: 130,
      },
    },
    {
      icon: "🏀",
      name: "Entrenar baloncesto",
      type: "BOOLEAN",
      dailyGoal: null,
      unitName: null,
      note: null,
      today: null,
      pastCompletedCompliances: 65,
      statsCurr: {
        currentStreak: 9,
        bestStreak: 28,
        totalCompletions: 120,
        totalAccumulation: 0,
        recordedDays: 0,
      },
    },
    {
      icon: "🧘🏻",
      name: "Meditar",
      type: "BOOLEAN",
      dailyGoal: null,
      unitName: null,
      note: null,
      today: null,
      notScheduledToday: true,
      statsCurr: {
        currentStreak: 0,
        bestStreak: 14,
        totalCompletions: 60,
        totalAccumulation: 0,
        recordedDays: 0,
      },
    },
    {
      icon: "🏃🏻",
      name: "Correr",
      type: "QUANTITY",
      dailyGoal: 3,
      unitName: "km",
      note: null,
      today: null,
      notScheduledToday: true,
      statsCurr: {
        currentStreak: 0,
        bestStreak: 16,
        totalCompletions: 70,
        totalAccumulation: 255,
        recordedDays: 80,
      },
    },
  ];

  const archivedHabits: SeedHabit[] = [
    {
      icon: "🎸",
      name: "Practicar guitarra",
      type: "QUANTITY",
      dailyGoal: 20,
      unitName: "min",
      note: null,
      today: null,
      statsPrev: {
        currentStreak: 0,
        bestStreak: 23,
        totalCompletions: 178,
        totalAccumulation: 3760,
        recordedDays: 205,
      },
      statsCurr: {
        currentStreak: 0,
        bestStreak: 16,
        totalCompletions: 58,
        totalAccumulation: 1240,
        recordedDays: 70,
      },
    },
    {
      icon: "✍️",
      name: "Escribir diario",
      type: "BOOLEAN",
      dailyGoal: null,
      unitName: null,
      note: null,
      today: null,
      statsPrev: {
        currentStreak: 0,
        bestStreak: 52,
        totalCompletions: 212,
        totalAccumulation: 0,
        recordedDays: 0,
      },
      statsCurr: {
        currentStreak: 0,
        bestStreak: 21,
        totalCompletions: 69,
        totalAccumulation: 0,
        recordedDays: 0,
      },
    },
    {
      icon: "✏️",
      name: "Dibujar",
      type: "BOOLEAN",
      dailyGoal: null,
      unitName: null,
      note: null,
      today: null,
      statsCurr: {
        currentStreak: 0,
        bestStreak: 12,
        totalCompletions: 40,
        totalAccumulation: 0,
        recordedDays: 0,
      },
    },
    {
      icon: "🍳",
      name: "Cocinar saludable",
      type: "BOOLEAN",
      dailyGoal: null,
      unitName: null,
      note: null,
      today: null,
      statsCurr: {
        currentStreak: 0,
        bestStreak: 10,
        totalCompletions: 35,
        totalAccumulation: 0,
        recordedDays: 0,
      },
    },
  ];

  const resolveUnitId = async (unitName: string | null) => {
    if (!unitName) return null;
    const unit = await prisma.unit.findFirst({
      where: { name: unitName, userId: null },
    });
    return unit?.id ?? null;
  };

  const seedHabit = async (
    h: SeedHabit,
    status: "ACTIVE" | "ARCHIVED",
    scheduledDays: readonly WeekDay[],
  ) => {
    const habit = await prisma.habit.create({
      data: {
        icon: h.icon,
        name: h.name,
        type: h.type,
        dailyGoal: h.dailyGoal,
        note: h.note,
        status,
        isConsolidated: h.isConsolidated ?? status === "ARCHIVED",
        createdAt: h.statsPrev ? createdAtPrev : createdAtCurr,
        archivedAt: status === "ARCHIVED" ? thirtyDaysAgo : null,
        userId,
        unitId: await resolveUnitId(h.unitName),
        scheduledDays: {
          create: scheduledDays.map((day) => ({ day })),
        },
        stats: {
          create: [
            ...(h.statsPrev ? [{ year: previousYear, ...h.statsPrev }] : []),
            { year: currentYear, ...h.statsCurr },
          ],
        },
      },
    });

    if (status === "ACTIVE" && h.today) {
      await prisma.compliance.create({
        data: {
          date: today,
          isCompleted: h.today.isCompleted,
          recordedAmount: h.today.recordedAmount,
          habitId: habit.id,
        },
      });
    }

    if (h.pastCompletedCompliances) {
      await prisma.compliance.createMany({
        data: Array.from({ length: h.pastCompletedCompliances }, (_, i) => ({
          date: addDays(today, -(i + 1)),
          isCompleted: true,
          recordedAmount: null,
          habitId: habit.id,
        })),
      });
    }

    if (h.randomPastCompliances) {
      const windowDays = 90;
      const goal = h.dailyGoal ?? 0;
      const data: Array<{
        date: Date;
        isCompleted: boolean;
        recordedAmount: number | null;
        habitId: number;
      }> = [];
      for (let i = 1; i <= windowDays; i++) {
        if (Math.random() > 0.4) continue;
        if (h.type === "QUANTITY") {
          const amount = Math.round(goal * (0.4 + Math.random() * 1.1));
          data.push({
            date: addDays(today, -i),
            isCompleted: amount >= goal,
            recordedAmount: amount,
            habitId: habit.id,
          });
        } else {
          data.push({
            date: addDays(today, -i),
            isCompleted: true,
            recordedAmount: null,
            habitId: habit.id,
          });
        }
      }
      if (data.length > 0) await prisma.compliance.createMany({ data });
    }
  };

  for (const h of activeHabits) {
    const days = h.notScheduledToday ? daysExceptToday : allDays;
    await seedHabit(h, "ACTIVE", days);
  }
  for (const h of archivedHabits) await seedHabit(h, "ARCHIVED", weekdays);

  await prisma.userStats.createMany({
    data: [
      {
        year: previousYear,
        currentStreak: 9,
        bestStreak: 57,
        habitsCompleted: 1432,
        perfectDays: 118,
        totalScheduled: 1980,
        userId,
      },
      {
        year: currentYear,
        currentStreak: 12,
        bestStreak: 33,
        habitsCompleted: 1240,
        perfectDays: 34,
        totalScheduled: 1820,
        userId,
      },
    ],
  });

  const bailarinaPhases =
    ORIGAMI_CATALOG.find((o) => o.name === "bailarina")?.phases ?? 6;
  const bailarinaRevealedPhase = 0;
  const bailarinaThreshold =
    getNextThreshold(bailarinaPhases, bailarinaRevealedPhase) ?? 100;

  const origamiProgress: Array<{
    name: string;
    completedAt: Date | null;
    progress?: number;
    revealedPhase?: number;
  }> = [
    { name: "flor", completedAt: new Date(previousYear, 8, 20) },
    { name: "mariposa", completedAt: new Date(currentYear, 1, 10) },
    { name: "luna", completedAt: new Date(currentYear, 3, 5) },
    {
      name: "bailarina",
      completedAt: null,
      revealedPhase: bailarinaRevealedPhase,
      progress: bailarinaThreshold - bootEnv.DAILY_BONUS_PROGRESS,
    },
  ];

  for (const op of origamiProgress) {
    const origami = await prisma.origami.findFirst({
      where: { name: op.name },
    });
    if (!origami) continue;

    const completed = op.completedAt != null;
    await prisma.assignment.create({
      data: {
        progress: completed ? 100 : (op.progress ?? 0),
        revealedPhase: completed ? origami.phases - 1 : (op.revealedPhase ?? 0),
        completedAt: op.completedAt,
        userId,
        origamiId: origami.id,
      },
    });
  }

  logger.info(`Usuario de prueba creado con id: ${userId}`);
  logger.info(`Token del usuario de prueba: ${token}`);
}
