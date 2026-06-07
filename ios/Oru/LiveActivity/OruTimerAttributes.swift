import ActivityKit
import Foundation

nonisolated struct OruTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let endDate: Date
    }

    let habitName: String?
    let habitIcon: String?
    let totalMinutes: Int
}
