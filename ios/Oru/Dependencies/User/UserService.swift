import Foundation

/// Acceso a los datos del usuario contra la API.
final class UserService {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    /// Obtiene los datos del usuario autenticado (`GET /users/me`).
    /// - Throws: `APIError` si la petición falla.
    func fetchMe() async throws -> UserDto {
        struct UserResponse: Decodable { let user: UserDto }

        let response: UserResponse = try await client.send("users/me", authorized: true)
        return response.user
    }
}
