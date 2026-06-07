import Foundation

/// Acceso a los hábitos del usuario contra la API.
final class HabitService {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    /// Obtiene los hábitos del usuario (`GET /habits`).
    func fetchHabits(status: String = "active") async throws -> [HabitDto] {
        try await client.send(
            "habits",
            queryItems: [URLQueryItem(name: "status", value: status)],
            authorized: true
        )
    }

    /// Crea un nuevo hábito (`POST /habits`).
    func createHabit(_ request: CreateHabitRequest) async throws -> HabitDto {
        try await client.send(
            "habits",
            method: .post,
            body: request,
            authorized: true
        )
    }

    /// Elimina un hábito (`DELETE /habits/:habitId`).
    func deleteHabit(id: Int) async throws {
        try await client.sendVoid(
            "habits/\(id)",
            method: .delete,
            authorized: true
        )
    }

    func updateHabit(id: Int, request: UpdateHabitRequest) async throws -> HabitDto {
        try await client.send(
            "habits/\(id)",
            method: .patch,
            body: request,
            authorized: true
        )
    }

    /// Marca/registra el cumplimiento de hoy (`POST /habits/:habitId/toggle`).
    func toggleHabit(id: Int, amount: Double? = nil) async throws -> HabitDto {
        var body: (any Encodable)?
        if let amount {
            body = ToggleHabitRequest(amount: amount)
        }
        return try await client.send(
            "habits/\(id)/toggle",
            method: .post,
            body: body,
            authorized: true
        )
    }

    /// Archiva un hábito (`POST /habits/:habitId/archive`).
    func archiveHabit(id: Int) async throws {
        try await client.sendVoid(
            "habits/\(id)/archive",
            method: .post,
            authorized: true
        )
    }
}
