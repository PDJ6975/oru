import Foundation

struct HabitDto: Decodable, Identifiable {
    let id: Int
    let icon: String
    let name: String
    let type: HabitType
    let dailyGoal: Double?
    let note: String?
    let status: HabitStatus
    let isConsolidated: Bool
    let userId: Int
    let unitId: Int?
    let createdAt: Date
    let archivedAt: Date?
    let scheduledDays: [ScheduledDayDto]
    let compliances: [ComplianceDto]
}

enum HabitType: String, Decodable {
    case boolean = "BOOLEAN"
    case quantity = "QUANTITY"
}

enum HabitStatus: String, Decodable {
    case active = "ACTIVE"
    case archived = "ARCHIVED"
}
