import Foundation

/// Configuración de acceso a la API.
enum APIConfig {
    // En desarrollo apunta a la API local. Al desplegar, cambiar
    // por la URL del servidor. El simulador resuelve `localhost` contra
    // la máquina anfitriona; en un dispositivo físico habría
    // que usar la IP de la máquina en la red local.
    // swiftlint:disable:next force_unwrapping
    static let baseURL = URL(string: "http://localhost:3000/api/v1")!
}
