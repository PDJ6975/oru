import SwiftUI

@Observable
@MainActor
final class HomeViewModel {

    private static let defaultName = "user"

    private(set) var userName = defaultName
    var connectionErrorPresented = false

    private let userService: UserService

    init(userService: UserService) {
        self.userService = userService
    }

    /// Carga los datos de la pantalla de inicio.
    func load() async {
        do {
            try await loadUserName()
            // Aquí irán futuros GETs de la home (hábitos, origami...).
        } catch let error as APIError where error.isBackendUnreachable {
            connectionErrorPresented = true
        } catch {
            // Otros errores ya quedan resueltos en cada sub-carga.
        }
    }

    /// Carga el nombre del usuario para el saludo.
    private func loadUserName() async throws {
        do {
            userName = try await userService.fetchMe().name
        } catch let error as APIError where error.isBackendUnreachable {
            throw error
        } catch {
            userName = Self.defaultName
        }
    }
}
