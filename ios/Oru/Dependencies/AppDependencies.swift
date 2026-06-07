import Foundation

/// Dependencias de la app (composition root). Centraliza la capa de red
final class AppDependencies {
    let tokenStore: TokenStore
    let authService: AuthService

    init() {
        let tokenStore = TokenStore()
        self.tokenStore = tokenStore
        self.authService = AuthService(
            client: APIClient(tokenStore: tokenStore),
            tokenStore: tokenStore
        )
    }
}
