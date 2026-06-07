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
}
