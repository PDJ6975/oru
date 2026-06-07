import Foundation

struct HabitDto: Decodable, Equatable, Identifiable {
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
    let unit: HabitUnitDto?
    let createdAt: Date
    let archivedAt: Date?
    let scheduledDays: [ScheduledDayDto]
    let compliances: [ComplianceDto]

    static let consolidationThreshold = 66
    static let maxNameLength = 20
    static let maxGoalLength = 5
    static let maxNoteLength = 200
}

struct HabitUnitDto: Decodable, Equatable {
    let id: Int
    let name: String
}

enum HabitType: String, Codable {
    case boolean = "BOOLEAN"
    case quantity = "QUANTITY"
}

enum HabitStatus: String, Decodable {
    case active = "ACTIVE"
    case archived = "ARCHIVED"
}
