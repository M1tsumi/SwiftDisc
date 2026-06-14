import Foundation

/// An HTTP response returned by a transport implementation.
public struct HTTPResponse: Sendable {
    public let data: Data
    public let statusCode: Int
    public let headers: [String: String]

    public init(data: Data, statusCode: Int, headers: [String: String] = [:]) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
    }
}

/// A protocol defining the interface for HTTP transport implementations.
///
/// This protocol allows different HTTP client implementations to be used
/// interchangeably, enabling custom transports like AsyncHTTPClient,
/// URLSession, or other networking libraries.
public protocol HTTPTransport: Sendable {
    /// Makes an HTTP request and returns the response.
    ///
    /// - Parameters:
    ///   - method: The HTTP method (e.g. "GET", "POST")
    ///   - url: The URL to request
    ///   - body: Optional request body data
    ///   - headers: Optional HTTP headers
    /// - Returns: An `HTTPResponse` containing the response data, status code, and headers.
    /// - Throws: An error if the request fails.
    func request(method: String, url: URL, body: Data?, headers: [String: String]?) async throws -> HTTPResponse
}

/// A protocol defining the interface for WebSocket transport implementations.
///
/// This protocol allows different WebSocket client implementations to be used
/// interchangeably, enabling custom transports like AsyncHTTPClient's WebSocket
/// support or other networking libraries.
public protocol WebSocketTransport: WebSocketClient, Sendable {
}

/// A type-erased WebSocket connection. All conforming types must be safe to use
/// across actor/task boundaries (`Sendable`).
public protocol WebSocketClient: Sendable {
    func send(_ message: WebSocketMessage) async throws
    func receive() async throws -> WebSocketMessage
    func close() async
    /// Drop the connection without sending a clean WebSocket close frame.
    /// Used when reconnecting and resuming so Discord does not invalidate the session.
    func forceClose() async
    var closeCode: Int? { get }
    /// Sends a platform-level WebSocket ping to detect network drops faster
    /// than the gateway heartbeat alone.
    func sendPing() async throws
}

public enum WebSocketMessage: Sendable {
    case string(String)
    case data(Data)
}

extension WebSocketClient {
    /// Default implementation: throws an error indicating ping is not supported.
    public func sendPing() async throws {
        throw DiscordError.gateway("WebSocket ping not supported by this transport.")
    }
}


