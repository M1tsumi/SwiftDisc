import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private struct APIErrorBody: Decodable { let message: String; let code: Int? }

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

final class HTTPClient: @unchecked Sendable {
    private let token: String
    private let configuration: DiscordConfiguration
    private let session: URLSession
    private let rateLimiter: RateLimiter

    deinit {
        // Explicit shutdown avoids libcurl worker-thread crashes during Linux test teardown.
        session.invalidateAndCancel()
    }

    init(token: String, configuration: DiscordConfiguration) {
        self.token = token
        self.configuration = configuration
        self.rateLimiter = RateLimiter(onRateLimit: configuration.onRateLimit)
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 8
        var headers: [AnyHashable: Any] = [
            "Authorization": "Bot \(token)",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "DiscordBot (SwiftDisc, \(DiscordConfiguration.version), https://github.com/M1tsumi/SwiftDisc)"
        ]
        if let existing = config.httpAdditionalHeaders {
            for (k, v) in existing { headers[k] = v }
        }
        config.httpAdditionalHeaders = headers
        self.session = URLSession(configuration: config)
    }

    func get<T: Decodable>(path: String) async throws(DiscordError) -> T {
        try await request(method: "GET", path: path, body: Optional<Data>.none)
    }

    /// Fetch raw response bytes without JSON decoding. Useful for non-JSON endpoints (e.g. CSV).
    func getRaw(path: String) async throws(DiscordError) -> Data {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let routeKey = makeRouteKey(method: "GET", path: trimmed)
        var attempt = 0; let maxAttempts = 4
        while true {
            attempt += 1
            try await rateLimiter.waitTurn(routeKey: routeKey)
            var url = configuration.restBase
            url.appendPathComponent(trimmed)
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw DiscordError.network(NSError(domain: "InvalidResponse", code: -1)) }
                await rateLimiter.updateFromHeaders(routeKey: routeKey, headers: http.allHeaderFields)
                if (200..<300).contains(http.statusCode) { return data }
                if http.statusCode == 429 {
                    let retryAfter = parseRetryAfter(headers: http.allHeaderFields, data: data)
                    await rateLimiter.backoff(after: retryAfter)
                    if attempt < maxAttempts { continue }
                }
                if (500..<600).contains(http.statusCode) && attempt < maxAttempts {
                    await rateLimiter.backoff(after: min(2.0 * pow(2.0, Double(attempt - 1)), 8.0))
                    continue
                }
                if let apiErr = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
                    throw DiscordError.api(message: apiErr.message, code: apiErr.code)
                }
                throw DiscordError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
            } catch let de as DiscordError {
                throw de
            } catch {
                if (error as? URLError)?.code == .cancelled { throw DiscordError.cancelled }
                if attempt < maxAttempts {
                    await rateLimiter.backoff(after: min(0.5 * pow(2.0, Double(attempt - 1)), 4.0))
                    continue
                }
                throw DiscordError.network(error)
            }
        }
    }

    func post<B: Encodable, T: Decodable>(path: String, body: B) async throws(DiscordError) -> T {
        let data: Data
        do { data = try JSONEncoder().encode(body) } catch { throw DiscordError.encoding(error, debugContext: "Endpoint: POST \(path)") }
        return try await request(method: "POST", path: path, body: data)
    }

    func patch<B: Encodable, T: Decodable>(path: String, body: B) async throws(DiscordError) -> T {
        let data: Data
        do { data = try JSONEncoder().encode(body) } catch { throw DiscordError.encoding(error, debugContext: "Endpoint: PATCH \(path)") }
        return try await request(method: "PATCH", path: path, body: data)
    }

    func put<B: Encodable, T: Decodable>(path: String, body: B) async throws(DiscordError) -> T {
        let data: Data
        do { data = try JSONEncoder().encode(body) } catch { throw DiscordError.encoding(error, debugContext: "Endpoint: PUT \(path)") }
        return try await request(method: "PUT", path: path, body: data)
    }

    // Use this for endpoints that accept an empty PUT and return 204 No Content.
    func put(path: String) async throws(DiscordError) {
        let _: EmptyResponse = try await request(method: "PUT", path: path, body: Optional<Data>.none)
    }

    func delete<T: Decodable>(path: String) async throws(DiscordError) -> T {
        try await request(method: "DELETE", path: path, body: Optional<Data>.none)
    }

    func delete(path: String) async throws(DiscordError) {
        let _: EmptyResponse = try await request(method: "DELETE", path: path, body: Optional<Data>.none)
    }

    private struct EmptyResponse: Decodable {}

    private func request<T: Decodable>(method: String, path: String, body: Data?) async throws(DiscordError) -> T {
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

                // Feed response headers back into the limiter so the next request can wait correctly.
                await rateLimiter.updateFromHeaders(routeKey: routeKey, headers: http.allHeaderFields)

                if (200..<300).contains(http.statusCode) {
                    do { return try JSONDecoder().decode(T.self, from: data) } catch { throw DiscordError.decoding(error, debugContext: "Endpoint: \(method) \(path)") }
                }

                // Discord asked us to slow down. Wait and retry.
                if http.statusCode == 429 {
                    let retryAfter = parseRetryAfter(headers: http.allHeaderFields, data: data)
                    await rateLimiter.backoff(after: retryAfter)
                    if attempt < maxAttempts { continue }
                }

                // Transient server errors are retried with bounded exponential backoff.
                if (500..<600).contains(http.statusCode) && attempt < maxAttempts {
                    let backoff = min(2.0 * pow(2.0, Double(attempt - 1)), 8.0)
                    await rateLimiter.backoff(after: backoff)
                    continue
                }

                // Prefer Discord's structured error body so callers get useful messages and codes.
                if let apiErr = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
                    throw DiscordError.api(message: apiErr.message, code: apiErr.code)
                }
                let message = String(data: data, encoding: .utf8) ?? ""
                throw DiscordError.http(http.statusCode, message)
            } catch let de as DiscordError {
                // Keep existing DiscordError values intact instead of wrapping and losing context.
                throw de
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

    // MARK: - Multipart support
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
                // Attachment descriptors must use the same index as files[idx].
                struct Desc: Encodable { let id: Int; let description: String }
                let descObj = [Desc(id: idx, description: desc)]
                if let data = try? JSONEncoder().encode(descObj) { body.append(data) }
                append(lineBreak)
            }
        }

        append("--\(boundary)--\r\n")
        return body
    }

    func postMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment]) async throws(DiscordError) -> T {
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
            // Fail fast on oversized uploads before building the multipart body.
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
                    do { return try JSONDecoder().decode(T.self, from: data) } catch { throw DiscordError.decoding(error, debugContext: "Endpoint: POST \(path)") }
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
            } catch let de as DiscordError {
                throw de
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

    func patchMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment]?) async throws(DiscordError) -> T {
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
            // Fail fast on oversized uploads before building the multipart body.
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
                    do { return try JSONDecoder().decode(T.self, from: data) } catch { throw DiscordError.decoding(error, debugContext: "Endpoint: PATCH \(path)") }
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
            } catch let de as DiscordError {
                throw de
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
        // Normalize resource IDs to keep related routes in the same limiter bucket.
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
        // Retry-After header is preferred; some payloads also include retry_after in JSON.
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

final class HTTPClient: @unchecked Sendable {
    private let token: String
    private let configuration: DiscordConfiguration

    init(token: String, configuration: DiscordConfiguration) {
        self.token = token
        self.configuration = configuration
    }

    func get<T: Decodable>(path: String) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func post<B: Encodable, T: Decodable>(path: String, body: B) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func patch<B: Encodable, T: Decodable>(path: String, body: B) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func put<B: Encodable, T: Decodable>(path: String, body: B) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func put(path: String) async throws(DiscordError) {
        throw DiscordError.unavailable
    }

    func delete<T: Decodable>(path: String) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func delete(path: String) async throws(DiscordError) {
        throw DiscordError.unavailable
    }

    func postMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment]) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func patchMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment]?) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func getRaw(path: String) async throws(DiscordError) -> Data {
        throw DiscordError.unavailable
    }
}

#endif
