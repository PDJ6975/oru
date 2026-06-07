import Foundation

struct ComplianceDto: Decodable {
    let id: Int
    let date: Date
    let isCompleted: Bool
    let recordedAmount: Double?
    let habitId: Int
}
