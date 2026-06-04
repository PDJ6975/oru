import { HabitType, WeekDay } from "../generated/prisma/enums.js";

export const HABIT_FILTER_STATUS = ["active", "archived", "all"] as const;
export const HABIT_FILTER_SCHEDULE = ["all", "scheduled", "rest"] as const;
export type HabitFilterStatus = (typeof HABIT_FILTER_STATUS)[number];
export type HabitFilterSchedule = (typeof HABIT_FILTER_SCHEDULE)[number];

export type HabitInput = {
  icon: string;
  name: string;
  type: HabitType;
  dailyGoal?: number;
  note?: string;
  unitId?: number;
  scheduledDays: WeekDay[];
};
