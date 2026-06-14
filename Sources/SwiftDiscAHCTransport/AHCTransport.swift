import Foundation
import AsyncHTTPClient
import SwiftDisc

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
