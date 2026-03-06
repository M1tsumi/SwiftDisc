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
            parts.index(after: webhookIdx) < parts.endIndex,
            parts.index(webhookIdx, offsetBy: 2) < parts.endIndex
        else { return nil }

        let rawId = parts[parts.index(after: webhookIdx)]
        let rawToken = parts[parts.index(webhookIdx, offsetBy: 2)]
        self.id = WebhookID(rawId)
        self.token = rawToken
    }

    // MARK: - Execute

    /// Post a message through the webhook.
    ///
    /// - Parameters:
    ///   - content: Plain-text body.
    ///   - username: Override the webhook's display name for this message.
    ///   - avatarUrl: Override the webhook's avatar URL for this message.
    ///   - embeds: Rich embeds.
    ///   - components: Message components (buttons, selects, etc.).
    ///   - wait: When `true`, Discord returns the created ``Message`` object;
    ///     otherwise returns `nil`.
    ///   - files: Binary file attachments.
    /// - Returns: The sent ``Message`` if `wait == true`, otherwise `nil`.
    @discardableResult
    public func execute(
        content: String? = nil,
        username: String? = nil,
        avatarUrl: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        wait: Bool = false,
        files: [FileAttachment] = []
    ) async throws -> Message? {
        var urlStr = "\(Self.apiBase)/webhooks/\(id)/\(token)"
        if wait { urlStr += "?wait=true" }
        guard let url = URL(string: urlStr) else {
            throw WebhookError.invalidURL(urlStr)
        }

        struct Body: Encodable {
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

        if files.isEmpty {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try Self.encoder.encode(body)
        } else {
            let boundary = "WebhookBoundary-\(UUID().uuidString)"
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            req.httpBody = buildMultipart(jsonBody: try Self.encoder.encode(body), files: files, boundary: boundary)
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            if data.isEmpty { throw WebhookError.httpError(httpResponse.statusCode, nil) }
            let msg = String(data: data, encoding: .utf8)
            throw WebhookError.httpError(httpResponse.statusCode, msg)
        }

        if !wait || data.isEmpty { return nil }
        return try Self.decoder.decode(Message.self, from: data)
    }

    // MARK: - Edit Message

    /// Edit a previously sent webhook message.
    ///
    /// Pass `@original` as `messageId` to edit the most recent message sent in
    /// an interaction context.
    @discardableResult
    public func editMessage(
        messageId: String,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        files: [FileAttachment] = []
    ) async throws -> Message {
        let urlStr = "\(Self.apiBase)/webhooks/\(id)/\(token)/messages/\(messageId)"
        guard let url = URL(string: urlStr) else {
            throw WebhookError.invalidURL(urlStr)
        }

        struct PatchBody: Encodable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
        }
        let body = PatchBody(content: content, embeds: embeds, components: components)

        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"

        if files.isEmpty {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try Self.encoder.encode(body)
        } else {
            let boundary = "WebhookBoundary-\(UUID().uuidString)"
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            req.httpBody = buildMultipart(jsonBody: try Self.encoder.encode(body), files: files, boundary: boundary)
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

    // MARK: - Private helpers

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

// MARK: - Error type

/// Errors thrown by ``WebhookClient``.
public enum WebhookError: Error, Sendable {
    case invalidURL(String)
    case httpError(Int, String?)
}

// MARK: - String → Data helper (private)

private extension String {
    var utf8Data: Data { Data(utf8) }
}
