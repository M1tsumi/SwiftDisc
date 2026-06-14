import Foundation
import SwiftDisc

#if canImport(AsyncHTTPClient)
import AsyncHTTPClient

/// AsyncHTTPClient-based HTTP transport for SwiftDisc.
///
/// Provides proxy support and connection pooling on Linux and Windows where
/// `URLSession` proxy support is unavailable.
///
/// Requires `async-http-client` as an additional dependency in your project:
/// ```swift
/// .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0")
/// ```
public final class AHCTransport: HTTPTransport, @unchecked Sendable {
    private let client: HTTPClient

    public init(proxy: ProxyConfiguration? = nil) {
        var config = HTTPClient.Configuration()
        if let proxy {
            config.proxy = .server(host: proxy.host, port: proxy.port)
        }
        self.client = HTTPClient(eventLoopGroupProvider: .createNew, configuration: config)
    }

    deinit {
        try? client.syncShutdown()
    }

    public func request(method: String, url: URL, body: Data?, headers: [String: String]?) async throws -> HTTPResponse {
        var req = HTTPClientRequest(url: url.absoluteString)
        req.method = .init(rawValue: method)
        if let body {
            req.body = .bytes(body)
        }
        if let headers {
            for (key, value) in headers {
                req.headers.add(name: key, value: value)
            }
        }
        let response = try await client.execute(req)
        let data: Data
        if let bodyBytes = response.body {
            data = bodyBytes.withUnsafeReadableBytes { Data($0) }
        } else {
            data = Data()
        }
        var respHeaders = [String: String]()
        for (key, value) in response.headers {
            respHeaders[key] = value
        }
        return HTTPResponse(data: data, statusCode: Int(response.status.code), headers: respHeaders)
    }
}
#else
/// Fallback AHC transport when `AsyncHTTPClient` module is not available.
///
/// To use the real AHC transport, add `async-http-client` as a dependency
/// in your project's `Package.swift`.
public final class AHCTransport: HTTPTransport, @unchecked Sendable {
    public init(proxy: ProxyConfiguration? = nil) {
    }

    public func request(method: String, url: URL, body: Data?, headers: [String: String]?) async throws -> HTTPResponse {
        throw DiscordError.network(NSError(domain: "SwiftDiscAHCTransport", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "AsyncHTTPClient module not available. Add async-http-client as a dependency to use AHCTransport."
        ]))
    }
}
#endif
