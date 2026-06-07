import Foundation

struct ComplianceDto: Decodable, Equatable {
    let id: Int
    let date: Date
    let isCompleted: Bool
    let recordedAmount: Double?
    let habitId: Int
}
