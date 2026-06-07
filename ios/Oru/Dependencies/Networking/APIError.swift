import Foundation

/// La capa de red traduce cualquier fallo a uno de estos casos
/// para abstraer los detalles a la UI de `URLSession`.
enum APIError: Error, LocalizedError {
    /// No se pudo contactar con el backend.
    case backendUnreachable
    /// La petición fue rechazada por el servidor con un mensaje de validación (4xx).
    case validation(String)
    /// Error del servidor (5xx) u otro estado no esperado.
    case server(status: Int)
    /// La respuesta no se pudo decodificar al tipo esperado.
    case decoding
    /// Cualquier otro fallo no contemplado.
    case unknown

    var errorDescription: String? {
        switch self {
        case .backendUnreachable:
            return "No se pudo conectar con el servidor. Comprueba tu conexión e inténtalo de nuevo."
        case .validation(let message):
            return message
        case .server:
            return "Algo salió mal. Inténtalo de nuevo más tarde."
        case .decoding:
            return "Respuesta inesperada del servidor."
        case .unknown:
            return "Ha ocurrido un error inesperado."
        }
    }

    /// Indica si el error corresponde a un backend inalcanzable (para mostrar el popup).
    var isBackendUnreachable: Bool {
        if case .backendUnreachable = self { return true }
        return false
    }
}
