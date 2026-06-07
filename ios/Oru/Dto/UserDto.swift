import Foundation

struct UserDto: Decodable {
    let id: Int
    let name: String
    let lastComputedDay: Date?
    let dailyBonusAplied: Bool
}
