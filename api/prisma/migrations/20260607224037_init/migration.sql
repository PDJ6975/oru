-- CreateEnum
CREATE TYPE "HabitType" AS ENUM ('BOOLEAN', 'QUANTITY');

-- CreateEnum
CREATE TYPE "HabitStatus" AS ENUM ('ACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "WeekDay" AS ENUM ('MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY');

-- CreateTable
CREATE TABLE "Assignment" (
    "id" SERIAL NOT NULL,
    "completedAt" TIMESTAMP(3),
    "progress" INTEGER NOT NULL,
    "revealedPhase" INTEGER NOT NULL,
    "userId" INTEGER NOT NULL,
    "origamiId" INTEGER NOT NULL,

    CONSTRAINT "Assignment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Compliance" (
    "id" SERIAL NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "isCompleted" BOOLEAN NOT NULL,
    "recordedAmount" DOUBLE PRECISION,
    "habitId" INTEGER NOT NULL,

    CONSTRAINT "Compliance_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Habit" (
    "id" SERIAL NOT NULL,
    "icon" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" "HabitType" NOT NULL,
    "dailyGoal" DOUBLE PRECISION,
    "note" TEXT,
    "status" "HabitStatus" NOT NULL DEFAULT 'ACTIVE',
    "isConsolidated" BOOLEAN NOT NULL DEFAULT false,
    "userId" INTEGER NOT NULL,
    "unitId" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "archivedAt" TIMESTAMP(3),

    CONSTRAINT "Habit_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "HabitStats" (
    "id" SERIAL NOT NULL,
    "year" INTEGER NOT NULL,
    "currentStreak" INTEGER NOT NULL,
    "bestStreak" INTEGER NOT NULL,
    "totalCompletions" INTEGER NOT NULL,
    "totalAccumulation" DOUBLE PRECISION NOT NULL,
    "recordedDays" INTEGER NOT NULL,
    "habitId" INTEGER NOT NULL,

    CONSTRAINT "HabitStats_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Origami" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "phases" INTEGER NOT NULL,

    CONSTRAINT "Origami_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ScheduledDay" (
    "id" SERIAL NOT NULL,
    "day" "WeekDay" NOT NULL,
    "habitId" INTEGER NOT NULL,

    CONSTRAINT "ScheduledDay_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" SERIAL NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "userId" INTEGER NOT NULL,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TimerSession" (
    "id" SERIAL NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "selectedMinutes" INTEGER NOT NULL,
    "isCompleted" BOOLEAN NOT NULL DEFAULT false,
    "userId" INTEGER NOT NULL,
    "habitId" INTEGER,

    CONSTRAINT "TimerSession_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Unit" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "userId" INTEGER,

    CONSTRAINT "Unit_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "User" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "lastComputedDay" TIMESTAMP(3),
    "dailyBonusAplied" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserStats" (
    "id" SERIAL NOT NULL,
    "year" INTEGER NOT NULL,
    "currentStreak" INTEGER NOT NULL,
    "bestStreak" INTEGER NOT NULL,
    "habitsCompleted" INTEGER NOT NULL,
    "perfectDays" INTEGER NOT NULL,
    "totalScheduled" INTEGER NOT NULL,
    "userId" INTEGER NOT NULL,

    CONSTRAINT "UserStats_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Assignment_userId_origamiId_key" ON "Assignment"("userId", "origamiId");

-- CreateIndex
CREATE UNIQUE INDEX "Compliance_habitId_date_key" ON "Compliance"("habitId", "date");

-- CreateIndex
CREATE UNIQUE INDEX "HabitStats_habitId_year_key" ON "HabitStats"("habitId", "year");

-- CreateIndex
CREATE UNIQUE INDEX "ScheduledDay_habitId_day_key" ON "ScheduledDay"("habitId", "day");

-- CreateIndex
CREATE UNIQUE INDEX "Session_tokenHash_key" ON "Session"("tokenHash");

-- CreateIndex
CREATE UNIQUE INDEX "UserStats_userId_year_key" ON "UserStats"("userId", "year");

-- AddForeignKey
ALTER TABLE "Assignment" ADD CONSTRAINT "Assignment_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Assignment" ADD CONSTRAINT "Assignment_origamiId_fkey" FOREIGN KEY ("origamiId") REFERENCES "Origami"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Compliance" ADD CONSTRAINT "Compliance_habitId_fkey" FOREIGN KEY ("habitId") REFERENCES "Habit"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Habit" ADD CONSTRAINT "Habit_unitId_fkey" FOREIGN KEY ("unitId") REFERENCES "Unit"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Habit" ADD CONSTRAINT "Habit_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "HabitStats" ADD CONSTRAINT "HabitStats_habitId_fkey" FOREIGN KEY ("habitId") REFERENCES "Habit"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ScheduledDay" ADD CONSTRAINT "ScheduledDay_habitId_fkey" FOREIGN KEY ("habitId") REFERENCES "Habit"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TimerSession" ADD CONSTRAINT "TimerSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TimerSession" ADD CONSTRAINT "TimerSession_habitId_fkey" FOREIGN KEY ("habitId") REFERENCES "Habit"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Unit" ADD CONSTRAINT "Unit_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserStats" ADD CONSTRAINT "UserStats_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
