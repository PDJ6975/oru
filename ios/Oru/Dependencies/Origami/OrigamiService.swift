import Foundation

final class OrigamiService {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    /// Obtiene el origami activo del usuario (`GET /origami`).
    func fetchOrigami() async throws -> OrigamiDto {
        try await client.send("origami", authorized: true)
    }

    /// Revela la siguiente fase de la figura (`POST /origami/next-phase`).
    func advancePhase() async throws -> OrigamiDto {
        try await client.send("origami/next-phase", method: .post, authorized: true)
    }

    /// Guarda la figura terminada y asigna una nueva (`POST /origami/new`).
    func assignNewOrigami() async throws -> OrigamiDto {
        try await client.send("origami/new", method: .post, authorized: true)
    }

    /// Obtiene las figuras completadas en un año (`GET /origami/completed?year=`).
    func fetchCompletedOrigamis(year: Int) async throws -> [CompletedOrigamiDto] {
        try await client.send(
            "origamis/completed",
            queryItems: [URLQueryItem(name: "year", value: String(year))],
            authorized: true
        )
    }
}
