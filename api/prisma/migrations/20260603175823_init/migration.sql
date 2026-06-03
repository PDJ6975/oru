-- CreateEnum
CREATE TYPE "HabitType" AS ENUM ('BOOLEAN', 'QUANTITY');

-- CreateEnum
CREATE TYPE "HabitStatus" AS ENUM ('ACTIVE', 'CONSOLIDATED', 'ARCHIVED');

-- CreateTable
CREATE TABLE "Habit" (
    "id" SERIAL NOT NULL,
    "icon" TEXT NOT NULL,
    "type" "HabitType" NOT NULL,
    "dailyGoal" DECIMAL(65,30),
    "note" TEXT,
    "status" "HabitStatus" NOT NULL,
    "userId" INTEGER NOT NULL,

    CONSTRAINT "Habit_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" SERIAL NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "userId" INTEGER NOT NULL,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "User" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Session_tokenHash_key" ON "Session"("tokenHash");

-- AddForeignKey
ALTER TABLE "Habit" ADD CONSTRAINT "Habit_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
