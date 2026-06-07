import Foundation

/// Sesión de temporizador devuelta por la API (`POST /timer`, `GET /timer`).
struct TimerSessionDto: Decodable, Equatable {
    let id: Int
    let startDate: Date
    let selectedMinutes: Int
    let isCompleted: Bool
    let userId: Int
    let habitId: Int?
}
