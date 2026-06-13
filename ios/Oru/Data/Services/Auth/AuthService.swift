import Foundation

/// Registro y sesión contra la API.
final class AuthService {
    private let client: APIClient
    private let tokenStore: TokenStore

    init(client: APIClient, tokenStore: TokenStore) {
        self.client = client
        self.tokenStore = tokenStore
    }

    /// Indica si ya hay una sesión guardada.
    var hasSession: Bool {
        tokenStore.token != nil
    }

    // DEMO (BORRAR tras grabar): token de la cuenta de test del seed.
    // Pega aquí el token que imprime `seedDevData` en el log.
    private static let demoTestToken = "1e2df259ddd7336d16a3cf53ee6950b0a4ae58311c9eb8b82a25cde0d25a0f88"

    /// Registra al usuario por su nombre y persiste el token devuelto.
    /// - Throws: `APIError` si la petición falla.
    func register(name: String) async throws {
        // DEMO (BORRAR tras grabar): no crea usuario, inicia sesión con la
        // cuenta de test. Se activa con el argumento de lanzamiento -demoLogin.
        if CommandLine.arguments.contains("-demoLogin") {
            tokenStore.save(Self.demoTestToken)
            return
        }

        struct RegisterRequest: Encodable { let name: String }
        struct TokenResponse: Decodable { let token: String }

        let response: TokenResponse = try await client.send(
            "users",
            method: .post,
            body: RegisterRequest(name: name),
            authorized: false
        )
        tokenStore.save(response.token)
    }
}
