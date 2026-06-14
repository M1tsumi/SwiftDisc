import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class UnavailableWebSocketAdapter: WebSocketTransport {
    var closeCode: Int? { nil }
    func send(_ message: WebSocketMessage) async throws { throw DiscordError.gateway("WebSocket unavailable on this platform") }
    func receive() async throws -> WebSocketMessage { throw DiscordError.gateway("WebSocket unavailable on this platform") }
    func close() async { }
    func forceClose() async { }
    func sendPing() async throws {
        throw DiscordError.gateway("WebSocket unavailable on this platform")
    }
}
