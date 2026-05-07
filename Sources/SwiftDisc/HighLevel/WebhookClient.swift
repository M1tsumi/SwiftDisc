import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A lightweight Discord webhook client that operates without a bot token.
///
/// Create a `WebhookClient` from a webhook URL or by supplying the ID and token
/// directly, then call ``execute(content:username:avatarUrl:embeds:wait:)`` to
/// post messages, or ``editMessage(messageId:)`` / ``deleteMessage(messageId:)``
/// to manage previously-sent webhook messages.
///
/// ```swift
/// let hook = WebhookClient(url: "https://discord.com/api/webhooks/12345/abcdef")!
/// let sent = try await hook.execute(content: "Hello from Swift!")
/// try await hook.deleteMessage(messageId: sent!.id.rawValue)
/// ```
public struct WebhookClient: Sendable {
    public let id: WebhookID
    public let token: String

    private static let apiBase = "https://discord.com/api/v10"
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
    
    // Rate limiter: Discord allows 5 webhook executions per second per webhook
    private static let rateLimiter = WebhookRateLimiter()

    // MARK: - Init

    /// Create from a known webhook ID and token.
    public init(id: WebhookID, token: String) {
        self.id = id
        self.token = token
    }

    /// Parse a standard Discord webhook URL of the form
    /// `https://discord.com/api/webhooks/<id>/<token>`.
    ///
    /// Returns `nil` if the URL cannot be parsed.
    public init?(url: String) {
        // Matches both discord.com and canary/ptb variants.
        guard let parsed = URL(string: url) else { return nil }
        let parts = parsed.pathComponents
        // pathComponents example: ["/", "api", "webhooks", "12345", "token"]
        guard
            let webhookIdx = parts.firstIndex(of: "webhooks"),
            webhookIdx + 2 < parts.count,
            let idStr = parts[webhookIdx + 1] as String?,
            let token = parts.last as String?
        else { return nil }
        
        let idParts = idStr.split(separator: "-").joined()
        guard let idVal = UInt64(idParts) else { return nil }
        self.id = WebhookID(String(idVal))
        self.token = token
    }

    // MARK: - Execute Message

    /// Execute a webhook message.
    ///
    /// - Parameters:
    ///   - content: Message content
    ///   - username: Override the webhook username
    ///   - avatarUrl: Override the webhook avatar
    ///   - embeds: Array of embeds
    ///   - components: Message components
    ///   - files: File attachments
    ///   - threadId: Send to a specific thread
    /// - Returns: The created message
    public func execute(
        content: String? = nil,
        username: String? = nil,
        avatarUrl: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        files: [FileAttachment]? = nil,
        threadId: String? = nil
    ) async throws -> Message {
        await Self.rateLimiter.waitForAvailability()
        
        var urlStr = "\(Self.apiBase)/webhooks/\(id)/\(token)"
        if let threadId = threadId {
            urlStr += "?thread_id=\(threadId)"
        }
        guard let url = URL(string: urlStr) else {
            throw WebhookError.invalidURL(urlStr)
        }

        struct Body: Encodable, Sendable {
            let content: String?
            let username: String?
            let avatar_url: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
        }
        let body = Body(
            content: content,
            username: username,
            avatar_url: avatarUrl,
            embeds: embeds,
            components: components
        )

        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        if let files = files, !files.isEmpty {
            let boundary = "WebhookBoundary-\(UUID().uuidString)"
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            req.httpBody = buildMultipart(jsonBody: try Self.encoder.encode(body), files: files, boundary: boundary)
        } else {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try Self.encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            let msg = data.isEmpty ? nil : String(data: data, encoding: .utf8)
            throw WebhookError.httpError(httpResponse.statusCode, msg)
        }
        return try Self.decoder.decode(Message.self, from: data)
    }

    // MARK: - Edit Message

    /// Edit a previously sent webhook message.
    ///
    /// - Parameters:
    ///   - messageId: The message to edit
    ///   - content: New message content
    ///   - embeds: New embeds
    ///   - components: New components
    ///   - files: New file attachments
    /// - Returns: The updated message
    public func editMessage(
        messageId: String,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        files: [FileAttachment]? = nil
    ) async throws -> Message {
        await Self.rateLimiter.waitForAvailability()
        
        let urlStr = "\(Self.apiBase)/webhooks/\(id)/\(token)/messages/\(messageId)"
        guard let url = URL(string: urlStr) else {
            throw WebhookError.invalidURL(urlStr)
        }

        struct PatchBody: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
        }
        let body = PatchBody(content: content, embeds: embeds, components: components)

        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"

        if let files = files, !files.isEmpty {
            let boundary = "WebhookBoundary-\(UUID().uuidString)"
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            req.httpBody = buildMultipart(jsonBody: try Self.encoder.encode(body), files: files, boundary: boundary)
        } else {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try Self.encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            let msg = data.isEmpty ? nil : String(data: data, encoding: .utf8)
            throw WebhookError.httpError(httpResponse.statusCode, msg)
        }
        return try Self.decoder.decode(Message.self, from: data)
    }

    // MARK: - Delete Message

    /// Delete a previously sent webhook message.
    ///
    /// Pass `@original` as `messageId` to delete the original interaction response.
    public func deleteMessage(messageId: String) async throws {
        await Self.rateLimiter.waitForAvailability()
        
        let urlStr = "\(Self.apiBase)/webhooks/\(id)/\(token)/messages/\(messageId)"
        guard let url = URL(string: urlStr) else {
            throw WebhookError.invalidURL(urlStr)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        let (data, response) = try await URLSession.shared.data(for: req)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            let msg = data.isEmpty ? nil : String(data: data, encoding: .utf8)
            throw WebhookError.httpError(httpResponse.statusCode, msg)
        }
    }
    
    // MARK: - Get Message
    
    /// Get a webhook message.
    ///
    /// - Parameter messageId: The message to retrieve
    /// - Returns: The message
    public func getMessage(messageId: String) async throws -> Message {
        await Self.rateLimiter.waitForAvailability()
        
        let urlStr = "\(Self.apiBase)/webhooks/\(id)/\(token)/messages/\(messageId)"
        guard let url = URL(string: urlStr) else {
            throw WebhookError.invalidURL(urlStr)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: req)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            let msg = data.isEmpty ? nil : String(data: data, encoding: .utf8)
            throw WebhookError.httpError(httpResponse.statusCode, msg)
        }
        return try Self.decoder.decode(Message.self, from: data)
    }

    // MARK: - Private utilities

    private func buildMultipart(jsonBody: Data, files: [FileAttachment], boundary: String) -> Data {
        var body = Data()
        let crlf = "\r\n"

        // JSON payload part
        body.append("--\(boundary)\(crlf)".utf8Data)
        body.append("Content-Disposition: form-data; name=\"payload_json\"\(crlf)".utf8Data)
        body.append("Content-Type: application/json\(crlf)\(crlf)".utf8Data)
        body.append(jsonBody)
        body.append(crlf.utf8Data)

        for (index, file) in files.enumerated() {
            body.append("--\(boundary)\(crlf)".utf8Data)
            body.append("Content-Disposition: form-data; name=\"files[\(index)]\"; filename=\"\(file.filename)\"\(crlf)".utf8Data)
            let ct = file.contentType ?? "application/octet-stream"
            body.append("Content-Type: \(ct)\(crlf)\(crlf)".utf8Data)
            body.append(file.data)
            body.append(crlf.utf8Data)
        }

        body.append("--\(boundary)--\(crlf)".utf8Data)
        return body
    }
}

// MARK: - Rate Limiter

/// Simple rate limiter for webhook requests.
/// Discord allows 5 webhook executions per second per webhook.
private actor WebhookRateLimiter {
    private var timestamps: [Date] = []
    private let maxRequests: Int = 5
    private let window: TimeInterval = 1.0 // 1 second window
    
    func waitForAvailability() async {
        let now = Date()
        // Remove timestamps older than the window
        timestamps = timestamps.filter { now.timeIntervalSince($0) < window }
        
        if timestamps.count >= maxRequests {
            // Wait until the oldest request is outside the window
            if let oldest = timestamps.first {
                let waitTime = window - now.timeIntervalSince(oldest)
                if waitTime > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }
        }
        
        timestamps.append(now)
    }
}

// MARK: - Error type

/// Errors thrown by ``WebhookClient``.
public enum WebhookError: Error, Sendable {
    case invalidURL(String)
    case httpError(Int, String?)
}

// MARK: - String to Data utility (private)

private extension String {
    var utf8Data: Data { Data(utf8) }
}
