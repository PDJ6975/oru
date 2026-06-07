import Foundation

/// Cuerpo para crear una sesión de temporizador (`POST /timer{/:habitId}`).
struct CreateTimerSessionRequest: Encodable {
    let startDate: String
    let selectedMinutes: Int
}
