import Foundation

/// Hábito compatible con el temporizador (`GET /habits/timer/load`).
struct TimerHabitDto: Decodable, Equatable, Identifiable {
    let id: Int
    let icon: String
    let name: String
}
