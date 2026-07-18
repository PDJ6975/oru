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
        queryItems: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil,
        authorized: Bool
    ) async throws -> Response {
        let request = try buildRequest(
            path: path, method: method, queryItems: queryItems, body: body, authorized: authorized
        )
        let data = try await perform(request)
        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    /// Realiza una petición que no devuelve cuerpo (ej. DELETE con 204).
    /// - Throws: `APIError`.
    func sendVoid(
        _ path: String,
        method: HTTPMethod,
        body: (any Encodable)? = nil,
        authorized: Bool
    ) async throws {
        let request = try buildRequest(
            path: path, method: method, queryItems: nil, body: body, authorized: authorized
        )
        _ = try await perform(request)
    }

    /// Envía la request, mapea errores de transporte y valida el status.
    /// - Returns: el cuerpo crudo de la respuesta.
    /// - Throws: `APIError`.
    private func perform(_ request: URLRequest) async throws -> Data {
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
            return data
        case 400..<500:
            throw APIError.validation(Self.extractMessage(from: data) ?? "Solicitud inválida.")
        default:
            throw APIError.server(status: http.statusCode)
        }
    }

    private func buildRequest(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem]?,
        body: (any Encodable)?,
        authorized: Bool
    ) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: try Self.appendingQuery(queryItems, to: url))
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

    /// Añade los query items a la URL, si los hay.
    private static func appendingQuery(_ queryItems: [URLQueryItem]?, to url: URL) throws -> URL {
        guard let queryItems, !queryItems.isEmpty else { return url }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.unknown
        }
        components.queryItems = queryItems
        guard let finalURL = components.url else { throw APIError.unknown }
        return finalURL
    }

    /// Decoder compartido para las fechas de la API, que llegan en ISO8601.
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let format = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            guard let date = try? format.parse(string) else {
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
