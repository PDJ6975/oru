import Foundation

/// Dependencias de la app (composition root). Centraliza la capa de red
final class AppDependencies {
    let tokenStore: TokenStore
    let authService: AuthService
    let userService: UserService

    init() {
        let tokenStore = TokenStore()
        self.tokenStore = tokenStore
        let client = APIClient(tokenStore: tokenStore)
        self.authService = AuthService(client: client, tokenStore: tokenStore)
        self.userService = UserService(client: client)
    }
}
