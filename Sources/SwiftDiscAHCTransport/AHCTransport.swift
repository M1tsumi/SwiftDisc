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
        throw DiscordError.network(NSError(domain: "NotImplemented", code: -1, userInfo: nil))
    }
}
