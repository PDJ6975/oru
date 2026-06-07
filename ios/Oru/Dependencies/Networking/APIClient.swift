import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Cliente HTTP de la app.
final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: TokenStore

    init(baseURL: URL = APIConfig.baseURL, session: URLSession = .shared, tokenStore: TokenStore) {
        self.baseURL = baseURL
        self.session = session
        self.tokenStore = tokenStore
    }

    /// Realiza una petición y decodifica la respuesta JSON.
    /// - Throws: `APIError`.
    func send<Response: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        body: (any Encodable)? = nil,
        authorized: Bool
    ) async throws -> Response {
        let request = try buildRequest(path: path, method: method, body: body, authorized: authorized)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            // Interceptor de conectividad
            throw Self.mapTransportError(urlError)
        } catch {
            throw APIError.unknown
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try Self.decoder.decode(Response.self, from: data)
            } catch {
                throw APIError.decoding
            }
        case 400..<500:
            throw APIError.validation(Self.extractMessage(from: data) ?? "Solicitud inválida.")
        default:
            throw APIError.server(status: http.statusCode)
        }
    }

    private func buildRequest(
        path: String,
        method: HTTPMethod,
        body: (any Encodable)?,
        authorized: Bool
    ) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.unknown
            }
        }

        if authorized, let token = tokenStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    /// Decoder compartido para las fechas de la API, que llegan en ISO8601.
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            guard let date = formatter.date(from: string) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath,
                          debugDescription: "Fecha ISO8601 no válida: \(string)")
                )
            }
            return date
        }
        return decoder
    }()

    /// Mapea los errores de `URLSession` que indican que no se alcanzó el backend.
    private static func mapTransportError(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost,
             .timedOut, .networkConnectionLost, .dataNotAllowed:
            return .backendUnreachable
        default:
            return .unknown
        }
    }

    /// Extrae el mensaje de error del cuerpo JSON.
    private static func extractMessage(from data: Data) -> String? {
        guard let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) else {
            return nil
        }
        // Prioriza el mensaje del primer campo inválido, si lo hay.
        return envelope.error.errors?.first?.msg ?? envelope.error.message
    }
}

// MARK: - Cuerpo de error de la API

private struct APIErrorEnvelope: Decodable {
    let error: Body

    struct Body: Decodable {
        let message: String?
        let errors: [FieldError]?
    }

    struct FieldError: Decodable {
        let msg: String?
    }
}
