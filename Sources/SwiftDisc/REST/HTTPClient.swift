import Foundation

final class HTTPClient {
    private let token: String
    private let configuration: DiscordConfiguration
    private let session: URLSession
    private let rateLimiter = RateLimiter()

    init(token: String, configuration: DiscordConfiguration) {
        self.token = token
        self.configuration = configuration
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Authorization": "Bot \(token)", "Content-Type": "application/json"]
        self.session = URLSession(configuration: config)
    }

    func get<T: Decodable>(path: String) async throws -> T {
        try await request(method: "GET", path: path, body: Optional<Data>.none)
    }

    func post<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        let data: Data
        do {
            data = try JSONEncoder().encode(body)
        } catch {
            throw DiscordError.encoding(error)
        }
        return try await request(method: "POST", path: path, body: data)
    }

    private func request<T: Decodable>(method: String, path: String, body: Data?) async throws -> T {
        try await rateLimiter.waitTurn()
        var url = configuration.restBase
        url.appendPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw DiscordError.network(NSError(domain: "InvalidResponse", code: -1)) }
            if (200..<300).contains(http.statusCode) {
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    throw DiscordError.decoding(error)
                }
            } else {
                // Attempt to decode Discord API error schema
                struct APIError: Decodable { let message: String; let code: Int? }
                if let apiErr = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw DiscordError.api(message: apiErr.message, code: apiErr.code)
                }
                let message = String(data: data, encoding: .utf8) ?? ""
                throw DiscordError.http(http.statusCode, message)
            }
        } catch {
            if (error as? URLError)?.code == .cancelled {
                throw DiscordError.cancelled
            }
            throw DiscordError.network(error)
        }
    }
}
