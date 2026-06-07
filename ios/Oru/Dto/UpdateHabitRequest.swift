import Foundation

struct UpdateHabitRequest: Encodable {
    let icon: String?
    let name: String?
    let dailyGoal: Double?
    let note: String?
    let unitId: Int?
    let scheduledDays: [WeekDay]?
}
