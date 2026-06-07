import Foundation

/// Acceso al temporizador del usuario contra la API.
final class TimerService {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    /// Hábitos compatibles con el temporizador (`GET /habits/timer/load`).
    func loadCompatibleHabits() async throws -> [TimerHabitDto] {
        try await client.send("habits/timer/load", authorized: true)
    }

    /// Crea una sesión de temporizador (`POST /timer{/:habitId}`).
    func createSession(
        startDate: Date,
        selectedMinutes: Int,
        habitId: Int? = nil
    ) async throws -> TimerSessionDto {
        let path = habitId.map { "timer/\($0)" } ?? "timer"
        let body = CreateTimerSessionRequest(
            startDate: startDate.ISO8601Format(),
            selectedMinutes: selectedMinutes
        )
        return try await client.send(path, method: .post, body: body, authorized: true)
    }

    /// Cancela la sesión activa (`DELETE /timer`).
    func cancelSession() async throws {
        try await client.sendVoid("timer", method: .delete, authorized: true)
    }

    /// Finaliza la sesión activa (`POST /timer/finish`).
    func finishSession() async throws {
        try await client.sendVoid("timer/finish", method: .post, authorized: true)
    }

    /// Recupera la sesión activa, o `nil` si no hay ninguna (`GET /timer`).
    func getActiveSession() async throws -> TimerSessionDto? {
        try await client.send("timer", authorized: true)
    }
}
