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
        do { data = try JSONEncoder().encode(body) } catch { throw DiscordError.encoding(error) }
        return try await request(method: "POST", path: path, body: data)
    }

    func patch<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        let data: Data
        do { data = try JSONEncoder().encode(body) } catch { throw DiscordError.encoding(error) }
        return try await request(method: "PATCH", path: path, body: data)
    }

    func delete<T: Decodable>(path: String) async throws -> T {
        try await request(method: "DELETE", path: path, body: Optional<Data>.none)
    }

    func delete(path: String) async throws {
        let _: EmptyResponse = try await request(method: "DELETE", path: path, body: Optional<Data>.none)
    }

    private struct EmptyResponse: Decodable {}

    private func request<T: Decodable>(method: String, path: String, body: Data?) async throws -> T {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let routeKey = makeRouteKey(method: method, path: trimmed)

        var attempt = 0
        let maxAttempts = 4

        while true {
            attempt += 1
            try await rateLimiter.waitTurn(routeKey: routeKey)

            var url = configuration.restBase
            url.appendPathComponent(trimmed)
            var req = URLRequest(url: url)
            req.httpMethod = method
            req.httpBody = body

            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw DiscordError.network(NSError(domain: "InvalidResponse", code: -1)) }

                // propagate rate limit header updates
                rateLimiter.updateFromHeaders(routeKey: routeKey, headers: http.allHeaderFields)

                if (200..<300).contains(http.statusCode) {
                    do { return try JSONDecoder().decode(T.self, from: data) } catch { throw DiscordError.decoding(error) }
                }

                // 429 rate limit
                if http.statusCode == 429 {
                    let retryAfter = parseRetryAfter(headers: http.allHeaderFields, data: data)
                    await rateLimiter.backoff(after: retryAfter)
                    if attempt < maxAttempts { continue }
                }

                // 5xx transient errors with small backoff
                if (500..<600).contains(http.statusCode) && attempt < maxAttempts {
                    let backoff = min(2.0 * pow(2.0, Double(attempt - 1)), 8.0)
                    await rateLimiter.backoff(after: backoff)
                    continue
                }

                // Detailed API error decoding
                struct APIError: Decodable { let message: String; let code: Int? }
                if let apiErr = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw DiscordError.api(message: apiErr.message, code: apiErr.code)
                }
                let message = String(data: data, encoding: .utf8) ?? ""
                throw DiscordError.http(http.statusCode, message)
            } catch {
                if (error as? URLError)?.code == .cancelled { throw DiscordError.cancelled }
                if attempt < maxAttempts {
                    let backoff = min(0.5 * pow(2.0, Double(attempt - 1)), 4.0)
                    await rateLimiter.backoff(after: backoff)
                    continue
                }
                throw DiscordError.network(error)
            }
        }
    }

    private func makeRouteKey(method: String, path: String) -> String {
        // Approximate Discord route buckets by replacing numeric IDs with :id
        let pattern = #"/([0-9]{5,})"#
        let replaced: String
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: path.utf16.count)
            replaced = regex.stringByReplacingMatches(in: 
                path, options: [], range: range, withTemplate: "/:id")
        } else {
            replaced = path
        }
        return "\(method) \(replaced)"
    }

    private func parseRetryAfter(headers: [AnyHashable: Any], data: Data) -> TimeInterval {
        // Prefer Retry-After header, fallback to JSON body 'retry_after'
        for (k, v) in headers {
            if String(describing: k).lowercased() == "retry-after" {
                if let secs = Double(String(describing: v)) { return secs }
            }
        }
        struct RL: Decodable { let retry_after: Double? }
        if let rl = try? JSONDecoder().decode(RL.self, from: data), let s = rl.retry_after { return s }
        return 1.0
    }
}
