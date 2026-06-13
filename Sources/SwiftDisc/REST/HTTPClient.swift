import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Decodes a non-2xx response body into the most specific `DiscordError` case.
///
/// - Returns: `.apiValidation(...)` if Discord's nested `errors` tree is
///   present, `.api(...)` for plain `{message, code}` bodies, or `.http(...)`
///   when the body is unparseable JSON.
@inline(__always)
private func makeAPIError(statusCode: Int, data: Data, debugContext: String? = nil) -> DiscordError {
    let body = String(data: data, encoding: .utf8) ?? ""
    let parsed = DiscordAPIErrorBody.parse(from: data)
    let message = parsed?.message ?? body
    switch statusCode {
    case 429:
        return .rateLimited(retryAfter: parseRetryAfter(data: data), debugContext: debugContext)
    case 403:
        return .forbidden(message, debugContext: debugContext)
    case 404:
        return .notFound(message, debugContext: debugContext)
    default:
        break
    }
    if let parsed {
        if !parsed.validationErrors.isEmpty {
            return .apiValidation(message: parsed.message, code: parsed.code, errors: parsed.validationErrors, debugContext: debugContext)
        }
        return .api(message: parsed.message, code: parsed.code, debugContext: debugContext)
    }
    return .http(statusCode, body, debugContext: debugContext)
}

@inline(__always)
private func parseRetryAfter(data: Data) -> TimeInterval {
    struct RL: Decodable, Sendable {
        let retry_after: Double?
    }
    if let rl = try? JSONDecoder().decode(RL.self, from: data), let s = rl.retry_after {
        return s
    }
    return 1.0
}

/// A simple async semaphore for limiting concurrent operations
private actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        if value > 0 {
            value -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(Linux) || os(Windows)

final class HTTPClient: @unchecked Sendable {
    // Keep this aligned with historical route-key behavior (`([0-9]{5,})`).
    private static let minimumSnowflakeDigits = 5
    private let token: RedactedToken
    private let configuration: DiscordConfiguration
    private let session: URLSession
    private let rateLimiter: RateLimiter
    private let retryPolicy: RetryPolicy
    private let serverErrorRetryPolicy: RetryPolicy
    
    // Per-bucket semaphores to serialize concurrent requests before bucket limits are known
    // Default to 50 concurrent requests per bucket (Discord's typical limit)
    private actor BucketSemaphores {
        private var semaphores: [String: AsyncSemaphore] = [:]
        private let defaultPermits: Int
        
        init(defaultPermits: Int = 50) {
            self.defaultPermits = defaultPermits
        }
        
        func semaphore(for key: String) -> AsyncSemaphore {
            if let existing = semaphores[key] {
                return existing
            }
            let newSemaphore = AsyncSemaphore(value: defaultPermits)
            semaphores[key] = newSemaphore
            return newSemaphore
        }
        
        func updatePermits(for key: String, to permits: Int) {
            semaphores[key] = AsyncSemaphore(value: permits)
        }
    }
    private let bucketSemaphores = BucketSemaphores()

    deinit {
        // Explicit shutdown avoids libcurl worker-thread crashes during Linux test teardown.
        session.invalidateAndCancel()
    }

    init(token: String, configuration: DiscordConfiguration) {
        self.token = RedactedToken(token)
        self.configuration = configuration
        self.rateLimiter = RateLimiter(onRateLimit: configuration.onRateLimit)
        self.retryPolicy = .default
        self.serverErrorRetryPolicy = .serverError
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = configuration.httpMaxConnectionsPerHost
        var headers: [AnyHashable: Any] = [
            "Authorization": self.token.authorizationHeaderValue,
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "DiscordBot (https://github.com/M1tsumi/SwiftDisc, \(DiscordConfiguration.version))"
        ]
        if let existing = config.httpAdditionalHeaders {
            for (k, v) in existing { headers[k] = v }
        }
        config.httpAdditionalHeaders = headers
        if let proxy = configuration.proxy {
            config.connectionProxyDictionary = proxy.urlSessionProxyDictionary
        }
        self.session = URLSession(configuration: config)
    }

    func get<T: Decodable>(path: String, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) -> T {
        try await request(method: "GET", path: path, body: Optional<Data>.none, query: query, headers: headers, reason: reason, isIdempotent: true)
    }

    /// Fetch raw response bytes without JSON decoding. Useful for non-JSON endpoints (e.g. CSV).
    func getRaw(path: String, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) -> Data {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let routeKey = makeRouteKey(method: "GET", path: trimmed)
        let (data, http) = try await executeWithRetry(routeKey: routeKey, isIdempotent: true) {
            var url = configuration.restBase
            url.appendPathComponent(trimmed)
            url = buildURLWithQuery(url: url, query: query)
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            applyCustomHeaders(req: &req, headers: headers, auditReason: reason)
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw DiscordError.network(NSError(domain: "InvalidResponse", code: -1)) }
            return (data, http)
        }
        if (200..<300).contains(http.statusCode) { return data }
        throw makeAPIError(statusCode: http.statusCode, data: data)
    }

    func post<B: Encodable, T: Decodable>(path: String, body: B, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) -> T {
        let data: Data
        do { data = try JSONCoders.encoder.encode(body) } catch { throw DiscordError.encoding(error, debugContext: "Endpoint: POST \(path)") }
        return try await request(method: "POST", path: path, body: data, query: query, headers: headers, reason: reason, isIdempotent: false)
    }

    func patch<B: Encodable, T: Decodable>(path: String, body: B, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) -> T {
        let data: Data
        do { data = try JSONCoders.encoder.encode(body) } catch { throw DiscordError.encoding(error, debugContext: "Endpoint: PATCH \(path)") }
        return try await request(method: "PATCH", path: path, body: data, query: query, headers: headers, reason: reason, isIdempotent: false)
    }

    func put<B: Encodable, T: Decodable>(path: String, body: B, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) -> T {
        let data: Data
        do { data = try JSONCoders.encoder.encode(body) } catch { throw DiscordError.encoding(error, debugContext: "Endpoint: PUT \(path)") }
        return try await request(method: "PUT", path: path, body: data, query: query, headers: headers, reason: reason, isIdempotent: false)
    }

    // Use this for endpoints that accept an empty PUT and return 204 No Content.
    func put(path: String, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) {
        let _: EmptyResponse = try await request(method: "PUT", path: path, body: Optional<Data>.none, query: query, headers: headers, reason: reason, isIdempotent: false)
    }

    func delete<T: Decodable>(path: String, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) -> T {
        try await request(method: "DELETE", path: path, body: Optional<Data>.none, query: query, headers: headers, reason: reason, isIdempotent: false)
    }

    func delete(path: String, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) {
        let _: EmptyResponse = try await request(method: "DELETE", path: path, body: Optional<Data>.none, query: query, headers: headers, reason: reason, isIdempotent: false)
    }

    private struct EmptyResponse: Decodable, Sendable {
    }

    private func request<T: Decodable>(method: String, path: String, body: Data?, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil, isIdempotent: Bool = true) async throws(DiscordError) -> T {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let routeKey = makeRouteKey(method: method, path: trimmed)
        let (data, http) = try await executeWithRetry(routeKey: routeKey, isIdempotent: isIdempotent) {
            var url = configuration.restBase
            url.appendPathComponent(trimmed)
            url = buildURLWithQuery(url: url, query: query)
            var req = URLRequest(url: url)
            req.httpMethod = method
            req.httpBody = body
            applyCustomHeaders(req: &req, headers: headers, auditReason: reason)
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw DiscordError.network(NSError(domain: "InvalidResponse", code: -1)) }
            return (data, http)
        }
        if (200..<300).contains(http.statusCode) {
            do { return try JSONCoders.decoder.decode(T.self, from: data) } catch { throw DiscordError.decoding(error, debugContext: "Endpoint: \(method) \(path)") }
        }
        throw makeAPIError(statusCode: http.statusCode, data: data, debugContext: "Endpoint: \(method) \(path)")
    }

    // MARK: - Query parameter support
    private func buildURLWithQuery(url: URL, query: [String: String]?) -> URL {
        guard let query = query, !query.isEmpty else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components?.url ?? url
    }

    // MARK: - Custom headers support
    private func applyCustomHeaders(req: inout URLRequest, headers: [String: String]?, auditReason: String? = nil) {
        guard let headers = headers else { return }
        for (key, value) in headers {
            req.setValue(value, forHTTPHeaderField: key)
        }
        // Add X-Audit-Log-Reason header if provided (URL-encoded)
        if let reason = auditReason {
            if let encoded = reason.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                req.setValue(encoded, forHTTPHeaderField: "X-Audit-Log-Reason")
            }
        }
    }

    // MARK: - Multipart support
    private func makeBoundary() -> String { "Boundary-" + UUID().uuidString }

    private func guessMimeType(filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "apng": return "image/apng"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "svg": return "image/svg+xml"
        case "ogg": return "audio/ogg"
        case "flac": return "audio/flac"
        case "m4a": return "audio/mp4"
        case "webm": return "video/webm"
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

        // Collect attachment descriptors for files with descriptions
        struct AttachmentDescriptor: Encodable, Sendable {
            let id: Int
            let description: String
            let filename: String
        }
        var descriptors: [AttachmentDescriptor] = []
        for (idx, file) in files.enumerated() {
            if let desc = file.description {
                descriptors.append(AttachmentDescriptor(id: idx, description: desc, filename: file.filename))
            }
        }

        // If there are descriptors, modify the JSON payload to include them
        var finalJsonPayload = jsonPayload
        if !descriptors.isEmpty, let originalJson = jsonPayload {
            // Parse the original JSON and add attachments array
            if var jsonObj = try? JSONSerialization.jsonObject(with: originalJson) as? [String: Any] {
                jsonObj["attachments"] = descriptors.map { desc in
                    ["id": desc.id, "description": desc.description, "filename": desc.filename]
                }
                if let modifiedData = try? JSONSerialization.data(withJSONObject: jsonObj) {
                    finalJsonPayload = modifiedData
                }
            }
        }

        if let json = finalJsonPayload {
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
        }

        append("--\(boundary)--\r\n")
        return body
    }

    func postMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment], reason: String? = nil) async throws(DiscordError) -> T {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let routeKey = makeRouteKey(method: "POST", path: trimmed)
        for file in files {
            if file.data.count > configuration.maxUploadBytes {
                throw DiscordError.validation("File \(file.filename) exceeds maxUploadBytes=\(configuration.maxUploadBytes)")
            }
        }
        let boundary = makeBoundary()
        let jsonData = try? jsonBody.map { try JSONCoders.encoder.encode($0) }
        let (data, http) = try await executeWithRetry(routeKey: routeKey, isIdempotent: false) {
            var url = configuration.restBase
            url.appendPathComponent(trimmed)
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.httpBody = buildMultipartBody(jsonPayload: jsonData ?? nil, files: files, boundary: boundary)
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            applyCustomHeaders(req: &req, headers: nil, auditReason: reason)
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw DiscordError.network(NSError(domain: "InvalidResponse", code: -1)) }
            return (data, http)
        }
        if (200..<300).contains(http.statusCode) {
            do { return try JSONCoders.decoder.decode(T.self, from: data) } catch { throw DiscordError.decoding(error, debugContext: "Endpoint: POST \(path)") }
        }
        throw makeAPIError(statusCode: http.statusCode, data: data, debugContext: "Endpoint: POST \(path)")
    }

    func patchMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment]?, reason: String? = nil) async throws(DiscordError) -> T {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let routeKey = makeRouteKey(method: "PATCH", path: trimmed)
        for file in files ?? [] {
            if file.data.count > configuration.maxUploadBytes {
                throw DiscordError.validation("File \(file.filename) exceeds maxUploadBytes=\(configuration.maxUploadBytes)")
            }
        }
        let boundary = makeBoundary()
        let jsonData = try? jsonBody.map { try JSONCoders.encoder.encode($0) }
        let (data, http) = try await executeWithRetry(routeKey: routeKey, isIdempotent: false) {
            var url = configuration.restBase
            url.appendPathComponent(trimmed)
            var req = URLRequest(url: url)
            req.httpMethod = "PATCH"
            req.httpBody = buildMultipartBody(jsonPayload: jsonData ?? nil, files: files ?? [], boundary: boundary)
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            applyCustomHeaders(req: &req, headers: nil, auditReason: reason)
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw DiscordError.network(NSError(domain: "InvalidResponse", code: -1)) }
            return (data, http)
        }
        if (200..<300).contains(http.statusCode) {
            do { return try JSONCoders.decoder.decode(T.self, from: data) } catch { throw DiscordError.decoding(error, debugContext: "Endpoint: PATCH \(path)") }
        }
        throw makeAPIError(statusCode: http.statusCode, data: data, debugContext: "Endpoint: PATCH \(path)")
    }

    func deleteMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment]?, reason: String? = nil) async throws(DiscordError) -> T {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let routeKey = makeRouteKey(method: "DELETE", path: trimmed)
        for file in files ?? [] {
            if file.data.count > configuration.maxUploadBytes {
                throw DiscordError.validation("File \(file.filename) exceeds maxUploadBytes=\(configuration.maxUploadBytes)")
            }
        }
        let boundary = makeBoundary()
        let jsonData = try? jsonBody.map { try JSONCoders.encoder.encode($0) }
        let (data, http) = try await executeWithRetry(routeKey: routeKey, isIdempotent: false) {
            var url = configuration.restBase
            url.appendPathComponent(trimmed)
            var req = URLRequest(url: url)
            req.httpMethod = "DELETE"
            req.httpBody = buildMultipartBody(jsonPayload: jsonData ?? nil, files: files ?? [], boundary: boundary)
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            applyCustomHeaders(req: &req, headers: nil, auditReason: reason)
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw DiscordError.network(NSError(domain: "InvalidResponse", code: -1)) }
            return (data, http)
        }
        if (200..<300).contains(http.statusCode) {
            do { return try JSONCoders.decoder.decode(T.self, from: data) } catch { throw DiscordError.decoding(error, debugContext: "Endpoint: DELETE \(path)") }
        }
        throw makeAPIError(statusCode: http.statusCode, data: data, debugContext: "Endpoint: DELETE \(path)")
    }

    // MARK: - Sticker-specific multipart (uses individual form-data fields, not payload_json)
    func postStickerMultipart<T: Decodable>(path: String, name: String, description: String?, tags: String, file: FileAttachment, reason: String? = nil) async throws(DiscordError) -> T {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let routeKey = makeRouteKey(method: "POST", path: trimmed)
        if file.data.count > configuration.maxUploadBytes {
            throw DiscordError.validation("File \(file.filename) exceeds maxUploadBytes=\(configuration.maxUploadBytes)")
        }
        let boundary = makeBoundary()
        let (data, http) = try await executeWithRetry(routeKey: routeKey, isIdempotent: false) {
            var url = configuration.restBase
            url.appendPathComponent(trimmed)
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.httpBody = buildStickerMultipartBody(name: name, description: description, tags: tags, file: file, boundary: boundary)
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            applyCustomHeaders(req: &req, headers: nil, auditReason: reason)
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw DiscordError.network(NSError(domain: "InvalidResponse", code: -1)) }
            return (data, http)
        }
        if (200..<300).contains(http.statusCode) {
            do { return try JSONCoders.decoder.decode(T.self, from: data) } catch { throw DiscordError.decoding(error, debugContext: "Endpoint: POST \(path)") }
        }
        throw makeAPIError(statusCode: http.statusCode, data: data, debugContext: "Endpoint: POST \(path)")
    }

    // Discord sticker uploads use individual form-data fields, not payload_json
    private func buildStickerMultipartBody(name: String, description: String?, tags: String, file: FileAttachment, boundary: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        func append(_ string: String) { body.append(Data(string.utf8)) }

        // name field
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"name\"\r\n\r\n")
        append(name)
        append(lineBreak)

        // description field (optional)
        if let desc = description {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"description\"\r\n\r\n")
            append(desc)
            append(lineBreak)
        }

        // tags field
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"tags\"\r\n\r\n")
        append(tags)
        append(lineBreak)

        // file field
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(file.filename)\"\r\n")
        let ct = file.contentType ?? guessMimeType(filename: file.filename)
        append("Content-Type: \(ct)\r\n\r\n")
        body.append(file.data)
        append(lineBreak)

        append("--\(boundary)--\r\n")
        return body
    }

    private func makeRouteKey(method: String, path: String) -> String {
        // Discord's bucket model is per-route-per-major-param.
        // Extract major params (channel_id, guild_id, webhook_id) for proper bucket isolation.
        let components = path.split(separator: "/").map { String($0) }
        var majorParam: String?
        var majorParamIndex: Int?
        
        // Find the first major parameter in the path
        for (index, component) in components.enumerated() {
            if index > 0 {
                let prev = components[index - 1]
                if prev == "channels" || prev == "guilds" || prev == "webhooks" {
                    majorParam = component
                    majorParamIndex = index
                    break
                }
            }
        }
        
        // Normalize non-major snowflakes to :id, but keep the major param
        let joinedPath = components.enumerated().map { index, component in
            if index == majorParamIndex { return component }
            return Self.isRouteSnowflakeComponent(component) ? ":id" : component
        }.joined(separator: "/")
        let major = majorParam ?? "global"
        let normalizedPath = path.hasPrefix("/") ? "/\(joinedPath)" : joinedPath
        return "\(method):\(normalizedPath)|major=\(major)"
    }

    private static func isRouteSnowflakeComponent(_ component: String) -> Bool {
        guard component.count >= minimumSnowflakeDigits else { return false }
        return component.allSatisfy { $0.isWholeNumber }
    }

    private func parseRetryAfter(headers: [AnyHashable: Any], data: Data) -> TimeInterval {
        // Check Retry-After header first (more efficient single lookup)
        if let retryAfterValue = headers["Retry-After"] ?? headers["retry-after"] {
            if let secs = Double(String(describing: retryAfterValue)) { return secs }
        }
        // Fallback to JSON body
        struct RL: Decodable, Sendable {
            let retry_after: Double?
        }
        if let rl = try? JSONCoders.decoder.decode(RL.self, from: data), let s = rl.retry_after { return s }
        return 1.0
    }

    private func executeWithRetry(routeKey: String, isIdempotent: Bool = true, _ request: @Sendable () async throws(any Error) -> (data: Data, http: HTTPURLResponse)) async throws(DiscordError) -> (data: Data, http: HTTPURLResponse) {
        let maxAttempts = retryPolicy.maxAttempts
        var attempt = 0
        while true {
            attempt += 1
            try await rateLimiter.waitTurn(routeKey: routeKey)
            
            // Acquire semaphore to limit concurrent requests per bucket
            let semaphore = await bucketSemaphores.semaphore(for: routeKey)
            await semaphore.wait()
            defer { Task { await semaphore.signal() } }
            
            do {
                let (data, http) = try await request()
                let headerStrings = Dictionary(uniqueKeysWithValues: http.allHeaderFields.map { (String(describing: $0.key), String(describing: $0.value)) })
                await rateLimiter.updateFromHeaders(routeKey: routeKey, headers: headerStrings)
                
                // Update semaphore permits based on actual bucket limit from headers
                if let limit = headerStrings["X-RateLimit-Limit"], let limitInt = Int(limit) {
                    await bucketSemaphores.updatePermits(for: routeKey, to: limitInt)
                }
                
                // Handle 429 rate limit errors — always safe to retry
                if http.statusCode == 429 {
                    let retryAfter = parseRetryAfter(headers: http.allHeaderFields, data: data)
                    try await rateLimiter.backoff(after: retryAfter)
                    if attempt < maxAttempts { continue }
                    throw makeAPIError(statusCode: http.statusCode, data: data, debugContext: "Route: \(routeKey)")
                }
                
                // Handle 5xx server errors with exponential backoff (only for idempotent requests)
                if (500..<600).contains(http.statusCode) && isIdempotent && attempt < maxAttempts {
                    try await rateLimiter.backoff(after: serverErrorRetryPolicy.backoffDelay(forAttempt: attempt))
                    continue
                }
                
                return (data, http)
            } catch let de as DiscordError {
                if case .network(let underlying, _) = de,
                   let urlError = underlying as? URLError,
                   urlError.code == .cancelled {
                    throw DiscordError.cancelled
                }
                // Only retry on network errors for idempotent requests
                if isIdempotent && attempt < maxAttempts {
                    try await rateLimiter.backoff(after: retryPolicy.backoffDelay(forAttempt: attempt))
                    continue
                }
                throw de
            } catch {
                // Handle non-DiscordError network errors
                if (error as? URLError)?.code == .cancelled { throw DiscordError.cancelled }
                // Only retry network errors for idempotent requests
                if isIdempotent && attempt < maxAttempts {
                    try await rateLimiter.backoff(after: retryPolicy.backoffDelay(forAttempt: attempt))
                    continue
                }
                throw DiscordError.network(error)
            }
        }
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

    func get<T: Decodable>(path: String, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func post<B: Encodable, T: Decodable>(path: String, body: B, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func patch<B: Encodable, T: Decodable>(path: String, body: B, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func put<B: Encodable, T: Decodable>(path: String, body: B, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func put(path: String, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) {
        throw DiscordError.unavailable
    }

    func delete<T: Decodable>(path: String, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func delete(path: String, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) {
        throw DiscordError.unavailable
    }

    func postMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment], reason: String? = nil) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func patchMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment]?, reason: String? = nil) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func deleteMultipart<T: Decodable, B: Encodable>(path: String, jsonBody: B?, files: [FileAttachment]?, reason: String? = nil) async throws(DiscordError) -> T {
        throw DiscordError.unavailable
    }

    func getRaw(path: String, query: [String: String]? = nil, headers: [String: String]? = nil, reason: String? = nil) async throws(DiscordError) -> Data {
        throw DiscordError.unavailable
    }
}

#endif
