import Foundation

final class UnitService {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchAllUnits() async throws -> [UnitDto] {
        async let base: [UnitDto] = client.send("units/base", authorized: true)
        async let user: [UnitDto] = client.send("units/me", authorized: true)
        return try await base + user
    }
}
