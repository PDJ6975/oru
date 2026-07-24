import Foundation

/// Respuesta de `GET /stats`: resumen global, estadística por hábito y serie diaria del mapa anual.
struct StatsDTO: Decodable {
    let userStats: UserStatsDTO
    let habitStats: [HabitStatsDTO]
    let yearActivity: [DayActivityDTO]
}

/// Métricas globales del año.
struct UserStatsDTO: Decodable {
    let complianceRate: Double
    let currentStreak: Int
    let bestStreak: Int
    let habitsCompleted: Int
    let perfectDays: Int
}

/// Estadística de un hábito concreto, ordenados ya por score.
struct HabitStatsDTO: Decodable, Identifiable {
    let habitId: Int
    let habitName: String
    let habitIcon: String
    let habitType: HabitType
    let habitStatus: HabitStatus
    let habitUnit: String?
    let currentStreak: Int
    let bestStreak: Int
    let totalCompletions: Int
    let totalAccumulation: Double
    let dailyAverage: Double

    var id: Int { habitId }
}

/// Actividad de un día del calendario anual.
struct DayActivityDTO: Decodable {
    let date: Date
    let scheduled: Int
    let completed: Int
}
