import Foundation

/// Acceso a las estadísticas del usuario contra la API.
final class StatsService {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    /// Obtiene las estadísticas del año indicado (`GET /stats?year=`).
    func fetchStats(year: Int) async throws -> StatsDto {
        try await client.send(
            "stats",
            queryItems: [URLQueryItem(name: "year", value: String(year))],
            authorized: true
        )
    }
}
