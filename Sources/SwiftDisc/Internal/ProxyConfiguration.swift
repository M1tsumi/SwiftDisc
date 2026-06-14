import Foundation

/// Configuration for routing HTTP and WebSocket connections through a proxy server.
///
/// Pass an instance to ``DiscordConfiguration/proxy`` to route all Discord API
/// requests and Gateway WebSocket traffic through the proxy. This is commonly
/// needed in corporate environments, when using SSH tunnels, or when geolocation
/// requires routing through a specific region.
///
/// ## Example
///
/// ```swift
/// var config = DiscordConfiguration()
/// config.proxy = ProxyConfiguration(host: "proxy.example.com", port: 8080)
/// let client = DiscordClient(token: token, configuration: config)
/// ```
///
/// The proxy dictionary is applied to `URLSessionConfiguration.connectionProxyDictionary`
/// for both HTTP and WebSocket connections. HTTP proxies must support the `CONNECT`
/// method for HTTPS/WSS traffic.
public struct ProxyConfiguration: Sendable, Hashable {
    /// The proxy hostname or IP address.
    public let host: String
    /// The proxy port number.
    public let port: Int

    /// Creates a proxy configuration for the given host and port.
    ///
    /// - Parameters:
    ///   - host: The proxy hostname or IP address (e.g. `"proxy.example.com"`).
    ///   - port: The proxy port number (e.g. `8080`).
    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    /// The proxy dictionary to apply to `URLSessionConfiguration.connectionProxyDictionary`.
    var urlSessionProxyDictionary: [AnyHashable: Any] {
        [
            "HTTPEnable": 1,
            "HTTPProxy": host,
            "HTTPPort": port,
            "HTTPSEnable": 1,
            "HTTPSProxy": host,
            "HTTPSPort": port,
        ]
    }
}
