import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A URLSession-based implementation of HTTPTransport.
///
/// This is the default transport implementation that uses URLSession for HTTP requests.
/// It supports proxy configuration and maintains the existing behavior.
final class URLSessionHTTPTransport: HTTPTransport {
    let session: URLSession

    init(proxy: ProxyConfiguration? = nil, maxConnectionsPerHost: Int = 8) {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = maxConnectionsPerHost
        var headers: [AnyHashable: Any] = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "DiscordBot (https://github.com/M1tsumi/SwiftDisc, 2.4.0)"
        ]
        if let existing = config.httpAdditionalHeaders {
            for (k, v) in existing { headers[k] = v }
        }
        config.httpAdditionalHeaders = headers
        if let proxy {
            config.connectionProxyDictionary = proxy.urlSessionProxyDictionary
        }
        self.session = URLSession(configuration: config)
    }

    deinit {
        session.invalidateAndCancel()
    }

    func request(method: String, url: URL, body: Data?, headers: [String: String]?) async throws -> HTTPResponse {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        if let headers {
            for (key, value) in headers {
                let sanitized = value.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: "")
                request.setValue(sanitized, forHTTPHeaderField: key)
            }
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscordError.network(NSError(domain: "InvalidResponse", code: -1))
        }
        let headerDict = httpResponse.allHeaderFields.reduce(into: [String: String]()) { dict, pair in
            dict["\(pair.key)"] = "\(pair.value)"
        }
        return HTTPResponse(data: data, statusCode: httpResponse.statusCode, headers: headerDict)
    }
}

/// A URLSession-based implementation of WebSocketTransport.
///
/// This is the default WebSocket transport implementation that uses URLSessionWebSocketTask
/// for WebSocket connections. It supports proxy configuration and maintains the existing behavior.
final class URLSessionWebSocketTransport: WebSocketTransport {
    private let task: URLSessionWebSocketTask
    let session: URLSession
    private let closeCodeBox = LockedBox<Int?>(nil)

    var closeCode: Int? { closeCodeBox.read() }

    deinit {
        session.invalidateAndCancel()
    }

    init(url: URL, proxy: ProxyConfiguration? = nil, maxConnectionsPerHost: Int = 8) {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = maxConnectionsPerHost
        if let proxy {
            config.connectionProxyDictionary = proxy.urlSessionProxyDictionary
        }
        self.session = URLSession(configuration: config)
        self.task = session.webSocketTask(with: url)
        self.task.maximumMessageSize = 16 * 1024 * 1024
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
        closeCodeBox.write(Int(task.closeCode.rawValue))
        session.invalidateAndCancel()
    }

    func forceClose() async {
        session.invalidateAndCancel()
    }

    func sendPing() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            task.sendPing { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

/// Thread-safe box for protecting mutable state across Sendable boundaries.
final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value
    init(_ value: Value) { _value = value }
    func read() -> Value { lock.withLock { _value } }
    func write(_ value: Value) { lock.withLock { _value = value } }
}
