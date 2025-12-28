import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private struct APIErrorBody: Decodable { let message: String; let code: Int? }

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

final class HTTPClient {
    private let token: String
    private let configuration: DiscordConfiguration
    private let session: URLSession
    private let rateLimiter = RateLimiter()

    init(token: String, configuration: DiscordConfiguration) {
        self.token = token
        self.configuration = configuration
        let config = URLSessionConfiguration.ephemeral
        #if !os(Windows)
        config.waitsForConnectivity = true
        #endif
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 8
        var headers: [AnyHashable: Any] = [
            "Authorization": "Bot \(token)",
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        if let existing = config.httpAdditionalHeaders {
            for (k, v) in existing { headers[k] = v }
        }
        config.httpAdditionalHeaders = headers
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

    func put<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        let data: Data
        do { data = try JSONEncoder().encode(body) } catch { throw DiscordError.encoding(error) }
        return try await request(method: "PUT", path: path, body: data)
    }

    // Convenience: PUT with no body and expecting no content (204)
    func put(path: String) async throws {
        let _: EmptyResponse = try await request(method: "PUT", path: path, body: Optional<Data>.none)
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
                await rateLimiter.updateFromHeaders(routeKey: routeKey, headers: http.allHeaderFields)

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
                if let apiErr = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
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

    // MARK: - Multipart Support
    private func makeBoundary() -> String { "Boundary-" + UUID().uuidString }

    private func guessMimeType(filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "txt": return "text/plain"
        case "json": return "application/json"
        case "pdf": return "application/pdf"
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        default: return "application/octet-stream"
        }
    }

    private func buildMultipartBody(jsonPayload: Data?, files: [FileAttachment], boundary: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        func append(_ string: String) { body.append(Data(string.utf8)) }

        if let json = jsonPayload {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"payload_json\"\r\n")
            append("Content-Type: application/json\r\n\r\n")
            body.append(json)
            append(lineBreak)
        }

        for (idx, file) in files.enumerated() {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"files[\(idx)]\"; filename=\"\(file.filename)\"\r\n")
            let ct = file.contentType ?? guessMimeType(filename: file.filename)
            append("Content-Type: \(ct)\r\n\r\n")
            body.append(file.data)
            append(lineBreak)
            if let desc = file.description {
                append("--\(boundary)\r\n")
                append("Content-Disposition: form-data; name=\"attachments\"\r\n")
                append("Content-Type: application/json\r\n\r\n")
                // Provide matching attachment descriptors with id index
                struct Desc: Encodable { let id: Int; let description: String }
                let descObj = [Desc(id: idx, description: desc)]
                if let data = try? JSONEncoder().encode(descObj) { body.append(data) }
                append(lineBreak)
            }
        }

        append("--\(boundary)--\r\n")
        return body
    }

    func postMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment]) async throws -> T {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let routeKey = makeRouteKey(method: "POST", path: trimmed)

        var attempt = 0
        let maxAttempts = 4
        while true {
            attempt += 1
            try await rateLimiter.waitTurn(routeKey: routeKey)

            var url = configuration.restBase
            url.appendPathComponent(trimmed)
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            // Guardrails: file size limit
            for file in files {
                if file.data.count > configuration.maxUploadBytes {
                    throw DiscordError.validation("File \(file.filename) exceeds maxUploadBytes=\(configuration.maxUploadBytes)")
                }
            }
            let boundary = makeBoundary()
            let jsonData = try? jsonBody.map { try JSONEncoder().encode($0) }
            req.httpBody = buildMultipartBody(jsonPayload: jsonData ?? nil, files: files, boundary: boundary)
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw DiscordError.network(NSError(domain: "InvalidResponse", code: -1)) }
                await rateLimiter.updateFromHeaders(routeKey: routeKey, headers: http.allHeaderFields)
                if (200..<300).contains(http.statusCode) {
                    do { return try JSONDecoder().decode(T.self, from: data) } catch { throw DiscordError.decoding(error) }
                }
                if http.statusCode == 429 {
                    let retryAfter = parseRetryAfter(headers: http.allHeaderFields, data: data)
                    await rateLimiter.backoff(after: retryAfter)
                    if attempt < maxAttempts { continue }
                }
                if (500..<600).contains(http.statusCode) && attempt < maxAttempts {
                    let backoff = min(2.0 * pow(2.0, Double(attempt - 1)), 8.0)
                    await rateLimiter.backoff(after: backoff)
                    continue
                }
                if let apiErr = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
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

    func patchMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment]?) async throws -> T {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let routeKey = makeRouteKey(method: "PATCH", path: trimmed)

        var attempt = 0
        let maxAttempts = 4
        while true {
            attempt += 1
            try await rateLimiter.waitTurn(routeKey: routeKey)

            var url = configuration.restBase
            url.appendPathComponent(trimmed)
            var req = URLRequest(url: url)
            req.httpMethod = "PATCH"
            // Guardrails: file size limit
            for file in files ?? [] {
                if file.data.count > configuration.maxUploadBytes {
                    throw DiscordError.validation("File \(file.filename) exceeds maxUploadBytes=\(configuration.maxUploadBytes)")
                }
            }
            let boundary = makeBoundary()
            let jsonData = try? jsonBody.map { try JSONEncoder().encode($0) }
            let body = buildMultipartBody(jsonPayload: jsonData ?? nil, files: files ?? [], boundary: boundary)
            req.httpBody = body
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw DiscordError.network(NSError(domain: "InvalidResponse", code: -1)) }
                await rateLimiter.updateFromHeaders(routeKey: routeKey, headers: http.allHeaderFields)
                if (200..<300).contains(http.statusCode) {
                    do { return try JSONDecoder().decode(T.self, from: data) } catch { throw DiscordError.decoding(error) }
                }
                if http.statusCode == 429 {
                    let retryAfter = parseRetryAfter(headers: http.allHeaderFields, data: data)
                    await rateLimiter.backoff(after: retryAfter)
                    if attempt < maxAttempts { continue }
                }
                if (500..<600).contains(http.statusCode) && attempt < maxAttempts {
                    let backoff = min(2.0 * pow(2.0, Double(attempt - 1)), 8.0)
                    await rateLimiter.backoff(after: backoff)
                    continue
                }
                if let apiErr = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
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

#else

final class HTTPClient {
    private let token: String
    private let configuration: DiscordConfiguration

    init(token: String, configuration: DiscordConfiguration) {
        self.token = token
        self.configuration = configuration
    }

    struct HTTPUnavailable: Error {}

    func get<T: Decodable>(path: String) async throws -> T {
        throw HTTPUnavailable()
    }

    func post<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        throw HTTPUnavailable()
    }

    func patch<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        throw HTTPUnavailable()
    }

    func put<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        throw HTTPUnavailable()
    }

    func put(path: String) async throws {
        throw HTTPUnavailable()
    }

    func delete<T: Decodable>(path: String) async throws -> T {
        throw HTTPUnavailable()
    }

    func delete(path: String) async throws {
        throw HTTPUnavailable()
    }

    func postMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment]) async throws -> T {
        throw HTTPUnavailable()
    }

    func patchMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment]?) async throws -> T {
        throw HTTPUnavailable()
    }
}

#endif
