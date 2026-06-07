import Foundation

/// Configuración de acceso a la API.
///
enum APIConfig {
    static let baseURL: URL = {
        guard
            // URL inyectada en runtime desde el entorno Bundle
            let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let url = URL(string: raw)
        else {
            fatalError("API_BASE_URL ausente o inválida.")
        }
        return url
    }()
}
