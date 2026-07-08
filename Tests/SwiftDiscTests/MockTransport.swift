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
            throw DiscordError.http(statusCode: 404, message: "No mock response for \(path)")
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
actor MockWebSocketTransport: WebSocketTransport {
    private var messages: [WebSocketMessage] = []
    private var sentMessages: [String] = []
    private var _closeCode: Int? = nil
    private var _shouldThrowOnReceive = false

    var closeCode: Int? { _closeCode }

    func addMessage(_ message: WebSocketMessage) { messages.append(message) }
    func addString(_ text: String) { messages.append(.string(text)) }

    func receive() async throws -> WebSocketMessage {
        if _shouldThrowOnReceive { throw DiscordError.gateway("Simulated receive error") }
        guard !messages.isEmpty else { throw DiscordError.gateway("No mock messages") }
        return messages.removeFirst()
    }

    func send(_ message: WebSocketMessage) async throws {
        if case .string(let text) = message { sentMessages.append(text) }
    }

    func sendPing() async throws {}
    func close() async { _closeCode = 1000 }
    func forceClose() async { _closeCode = 1006 }

    func getSentMessages() -> [String] { sentMessages }
    func setThrowOnReceive(_ shouldThrow: Bool) { _shouldThrowOnReceive = shouldThrow }
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
