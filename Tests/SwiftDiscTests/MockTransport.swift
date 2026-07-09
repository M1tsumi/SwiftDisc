import Foundation
@testable import SwiftDisc

/// A mock HTTP transport that returns pre-configured responses.
actor MockHTTPTransport: HTTPTransport {
    private var responseQueues: [String: [(data: Data, statusCode: Int, headers: [String: String])]] = [:]
    private var requestedPaths: [String] = []

    func addResponse(for path: String, data: Data, statusCode: Int = 200, headers: [String: String] = [:]) {
        var queue = responseQueues[path] ?? []
        queue.append((data, statusCode, headers))
        responseQueues[path] = queue
    }

    func request(method: String, url: URL, body: Data?, headers: [String: String]?) async throws -> HTTPResponse {
        let path = url.path
        requestedPaths.append("\(method):\(path)")
        guard var queue = responseQueues[path], !queue.isEmpty else {
            throw DiscordError.http(404, "No mock response for \(path)")
        }
        let response = queue.removeFirst()
        if queue.isEmpty {
            responseQueues.removeValue(forKey: path)
        } else {
            responseQueues[path] = queue
        }
        return HTTPResponse(data: response.data, statusCode: response.statusCode, headers: response.headers)
    }

    func getRequestedPaths() -> [String] { requestedPaths }

    func reset() {
        responseQueues.removeAll()
        requestedPaths.removeAll()
    }
}

/// A mock WebSocket transport that simulates gateway events.
final class MockWebSocketTransport: @unchecked Sendable, WebSocketTransport {
    private let lock = NSLock()
    private var _messages: [WebSocketMessage] = []
    private var _sentMessages: [String] = []
    private var _closeCode: Int? = nil
    private var _shouldThrowOnReceive = false

    var closeCode: Int? { lock.withLock { _closeCode } }

    func addMessage(_ message: WebSocketMessage) { lock.withLock { _messages.append(message) } }
    func addString(_ text: String) { lock.withLock { _messages.append(.string(text)) } }

    func receive() async throws -> WebSocketMessage {
        try Task.checkCancellation()
        if lock.withLock({ _shouldThrowOnReceive }) {
            throw DiscordError.gateway("Simulated receive error")
        }
        if let msg = lock.withLock({ _messages.isEmpty ? nil : _messages.removeFirst() }) {
            return msg
        }
        throw DiscordError.gateway("No mock messages")
    }

    func send(_ message: WebSocketMessage) async throws {
        if case .string(let text) = message { lock.withLock { _sentMessages.append(text) } }
    }

    func sendPing() async throws {}
    func close() async { lock.withLock { _closeCode = 1000 } }
    func forceClose() async { lock.withLock { _closeCode = 1006 } }

    func getSentMessages() -> [String] { lock.withLock { _sentMessages } }
    func setThrowOnReceive(_ shouldThrow: Bool) { lock.withLock { _shouldThrowOnReceive = shouldThrow } }
}

/// Minimal VoiceState struct for API compliance (voice not yet planned).
public struct VoiceState: Codable, Sendable, Hashable {
    public let guild_id: GuildID?
    public let channel_id: ChannelID?
    public let user_id: UserID
    public let member: GuildMember?
    public let session_id: String
    public let deaf: Bool
    public let mute: Bool
    public let self_deaf: Bool
    public let self_mute: Bool
    public let self_stream: Bool?
    public let self_video: Bool?
    public let suppress: Bool
    public let request_to_speak_timestamp: String?

    public init(
        guild_id: GuildID? = nil,
        channel_id: ChannelID? = nil,
        user_id: UserID,
        member: GuildMember? = nil,
        session_id: String,
        deaf: Bool = false,
        mute: Bool = false,
        self_deaf: Bool = false,
        self_mute: Bool = false,
        self_stream: Bool? = nil,
        self_video: Bool? = nil,
        suppress: Bool = false,
        request_to_speak_timestamp: String? = nil
    ) {
        self.guild_id = guild_id
        self.channel_id = channel_id
        self.user_id = user_id
        self.member = member
        self.session_id = session_id
        self.deaf = deaf
        self.mute = mute
        self.self_deaf = self_deaf
        self.self_mute = self_mute
        self.self_stream = self_stream
        self.self_video = self_video
        self.suppress = suppress
        self.request_to_speak_timestamp = request_to_speak_timestamp
    }
}
