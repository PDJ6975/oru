import Foundation

struct CreateHabitRequest: Encodable {
    let icon: String
    let name: String
    let type: HabitType
    let dailyGoal: Double?
    let note: String?
    let unitId: Int?
    let scheduledDays: [WeekDay]
}
