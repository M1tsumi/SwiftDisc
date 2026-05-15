import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum WebSocketMessage: Sendable {
    case string(String)
    case data(Data)
}

/// A type-erased WebSocket connection. All conforming types must be safe to use
/// across actor/task boundaries (`Sendable`).
protocol WebSocketClient: Sendable {
    func send(_ message: WebSocketMessage) async throws
    func receive() async throws -> WebSocketMessage
    func close() async
    /// Drop the connection without sending a clean WebSocket close frame.
    /// Used when reconnecting and resuming so Discord does not invalidate the session.
    func forceClose() async
    var closeCode: Int? { get }
}

final class URLSessionWebSocketAdapter: WebSocketClient, @unchecked Sendable {
    private let task: URLSessionWebSocketTask
    private let session: URLSession
    private(set) var closeCode: Int?

    deinit {
        // Ensure FoundationNetworking tears down socket resources deterministically.
        session.invalidateAndCancel()
    }

    init(url: URL) {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 8
        self.session = URLSession(configuration: config)
        self.task = session.webSocketTask(with: url)
        self.task.maximumMessageSize = 16 * 1024 * 1024 // 16 MiB to handle large GUILD_CREATE payloads
        self.task.resume()
    }

    func send(_ message: WebSocketMessage) async throws {
        switch message {
        case .string(let text):
            try await task.send(.string(text))
        case .data(let data):
            try await task.send(.data(data))
        }
    }

    func receive() async throws -> WebSocketMessage {
        let msg = try await task.receive()
        switch msg {
        case .string(let text):
            return .string(text)
        case .data(let data):
            return .data(data)
        @unknown default:
            throw DiscordError.gateway("Unknown WebSocket message type received")
        }
    }

    func close() async {
        task.cancel(with: .normalClosure, reason: nil)
        closeCode = Int(task.closeCode.rawValue)
        session.invalidateAndCancel()
    }

    func forceClose() async {
        // Cancel the session without sending a clean close frame (1000/1001)
        // so Discord preserves the session for resume.
        session.invalidateAndCancel()
    }
}

final class UnavailableWebSocketAdapter: WebSocketClient, Sendable {
    var closeCode: Int? { nil }
    func send(_ message: WebSocketMessage) async throws { throw DiscordError.gateway("WebSocket unavailable on this platform") }
    func receive() async throws -> WebSocketMessage { throw DiscordError.gateway("WebSocket unavailable on this platform") }
    func close() async { }
    func forceClose() async { }
}
