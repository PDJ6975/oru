import type { HabitStatsComp, UserStatsComp } from "../types/stats.types.js";

// Construye el DTO de respuesta a partir de la forma común (acumulador o lectura de BD
// normalizada). Los derivados (dailyAverage, score, complianceRate) se calculan aquí,
// no se almacenan, y los hábitos se ordenan por score descendente.
export const toDtoStats = (
  userStats: UserStatsComp | null,
  habitStats: HabitStatsComp[],
) => {
  return {
    userStats: {
      complianceRate:
        userStats && userStats.totalScheduled > 0
          ? (userStats.habitsCompleted / userStats.totalScheduled) * 100
          : 0,
      currentStreak: userStats?.currentStreak ?? 0,
      bestStreak: userStats?.bestStreak ?? 0,
      habitsCompleted: userStats?.habitsCompleted ?? 0,
      perfectDays: userStats?.perfectDays ?? 0,
    },
    habitStats: habitStats
      .map((stat) => ({
        habitId: stat.habitId,
        habitName: stat.habitName,
        habitIcon: stat.habitIcon,
        habitType: stat.habitType,
        habitStatus: stat.habitStatus,
        habitUnit: stat.habitUnit,
        currentStreak: stat.currentStreak,
        bestStreak: stat.bestStreak,
        totalCompletions: stat.totalCompletions,
        totalAccumulation: stat.totalAccumulation,
        dailyAverage:
          stat.recordedDays > 0
            ? stat.totalAccumulation / stat.recordedDays
            : 0,
        score: stat.totalCompletions * (1 + stat.currentStreak / 10),
      }))
      .sort((a, b) => b.score - a.score), // Sort by score descending
  };
};
