import SwiftUI

@Observable
@MainActor
final class WelcomeViewModel {
    var name = ""
    var errorMessage: String?
    var isRegistering = false
    var connectionErrorPresented = false

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isNameValid: Bool {
        let length = trimmedName.count
        return length >= 2 && length <= 30
    }

    /// Registra al usuario contra la API.
    /// - Returns: `true` si el registro fue correcto y se guardó el token.
    func register() async -> Bool {
        guard !isRegistering else { return false }

        guard isNameValid else {
            errorMessage = trimmedName.count < 2
                ? "El nombre debe tener al menos 2 caracteres."
                : "El nombre no puede superar los 30 caracteres."
                return false
        }

        isRegistering = true
        defer { isRegistering = false }

        do {
            try await authService.register(name: trimmedName)
            errorMessage = nil
            return true
        } catch let error as APIError where error.isBackendUnreachable {
            connectionErrorPresented = true
            return false
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = "No se pudo completar el registro. Inténtalo de nuevo."
            return false
        }
    }
}
