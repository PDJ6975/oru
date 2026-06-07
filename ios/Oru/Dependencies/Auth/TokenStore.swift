import Foundation

/// Guarda el token de sesión en `UserDefaults`.
struct TokenStore {
    private let defaults: UserDefaults
    private let key = "authToken"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Token guardado, o `nil` si no hay sesión.
    var token: String? {
        defaults.string(forKey: key)
    }

    /// Guarda (o reemplaza) el token.
    func save(_ token: String) {
        defaults.set(token, forKey: key)
    }

    /// Borra el token (cierre de sesión).
    func clear() {
        defaults.removeObject(forKey: key)
    }
}
