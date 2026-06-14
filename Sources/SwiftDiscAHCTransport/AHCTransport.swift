import Foundation
import AsyncHTTPClient
import SwiftDisc

public final class AHCTransport: HTTPTransport, @unchecked Sendable {
    public init(proxy: ProxyConfiguration? = nil) {
    }

    public func request(method: String, url: URL, body: Data?, headers: [String: String]?) async throws -> HTTPResponse {
        throw DiscordError.network(NSError(domain: "NotImplemented", code: -1, userInfo: nil))
    }
}
