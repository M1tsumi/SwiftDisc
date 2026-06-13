import Foundation
#if canImport(OSLog)
import OSLog
#endif

/// A logger abstraction used throughout SwiftDisc.
///
/// Implement this protocol to route library log messages to your preferred
/// logging backend (e.g. os_log, SwiftyBeaver, custom file output). The
/// default implementation writes to `os_log` on Apple platforms and falls
/// back to `print` elsewhere.
///
/// ## Example
///
/// ```swift
/// struct MyLogger: DiscordLogger {
///     func log(_ level: DiscordLogLevel, _ message: @autoclosure () -> String) {
///         // Forward to your logging system
///         print("[\(level.label)] \(message())")
///     }
/// }
/// let config = DiscordConfiguration(logger: MyLogger())
/// ```
public enum DiscordLogLevel: String, Sendable {
    case debug, info, warning, error

    var label: String {
        switch self {
        case .debug:   "DEBUG"
        case .info:    "INFO"
        case .warning: "WARN"
        case .error:   "ERROR"
        }
    }
}

public protocol DiscordLogger: Sendable {
    /// Log a message at the given severity level.
    /// The `message` closure is `@autoclosure` so it is not evaluated when
    /// the logger discards the message (e.g. below a minimum threshold).
    func log(_ level: DiscordLogLevel, _ message: @autoclosure () -> String)
}

/// Default logger: uses `os_log` on Apple platforms, `print` elsewhere.
public struct DefaultDiscordLogger: DiscordLogger {
    public init() {}
    public func log(_ level: DiscordLogLevel, _ message: @autoclosure () -> String) {
        #if canImport(OSLog)
        let log = OSLog(subsystem: "com.swiftdisc", category: level.label)
        let msg = message()
        switch level {
        case .debug:   os_log(.debug,   log: log, "%{public}@", msg)
        case .info:    os_log(.info,    log: log, "%{public}@", msg)
        case .warning: os_log(.default, log: log, "%{public}@", msg)
        case .error:   os_log(.error,   log: log, "%{public}@", msg)
        }
        #else
        print("[SwiftDisc][\(level.label)] \(message())")
        #endif
    }
}

/// Configuration options for the Discord client.
///
/// Use this struct to customize the behavior of the Discord client,
/// including API endpoints, gateway settings, and rate limiting.
///
/// ## Example
///
/// ```swift
/// let config = DiscordConfiguration(
///     apiBaseURL: URL(string: "https://discord.com/api")!,
///     apiVersion: 10,
///     maxUploadBytes: 50 * 1024 * 1024, // 50MB
///     onRateLimit: { event in
///         print("Rate limited: \(event)")
///     }
/// )
/// let client = DiscordClient(token: token, configuration: config)
/// ```
///
/// ## Related Topics
/// - ``DiscordClient/init(token:configuration:)``
/// - ``RateLimitEvent``
public struct DiscordConfiguration: Sendable {
    /// SwiftDisc library version for User-Agent header and Discord tracking.
    public static let version = "2.4.0"

    // Default URLs are static constants so startup never depends on force-unwrapped strings.
    /// The default Discord API base URL.
    public static let defaultApiBaseURL: URL = URL(string: "https://discord.com/api")!

    /// The default Discord Gateway base URL.
    public static let defaultGatewayBaseURL: URL = URL(string: "wss://gateway.discord.gg")!

    /// The base URL for the Discord REST API.
    public var apiBaseURL: URL
    
    /// The API version to use (default is 10).
    public var apiVersion: Int
    
    /// The base URL for the Discord Gateway.
    public var gatewayBaseURL: URL
    
    /// The maximum file upload size in bytes (default is 100MB).
    public var maxUploadBytes: Int
    
    /// Handler for rate limit events.
    public typealias RateLimitHandler = @Sendable (RateLimitEvent) -> Void
    
    /// Enables extra gateway decode logs with opcode/event context.
    ///
    /// Turn this on when payloads drift and you need to see what failed to decode.
    public var enableGatewayDecodeDiagnostics: Bool
    
    /// Called whenever the REST limiter updates bucket state or enters a wait.
    public var onRateLimit: RateLimitHandler?
    
    /// Gateway transport compression options.
    public enum GatewayCompression: Sendable {
        /// No compression.
        case none
        
        /// Zlib-stream compression (not yet implemented).
        @available(*, unavailable, message: "zlib-stream compression not yet implemented")
        case zlibStream
        
        /// Zstd-stream compression (not yet implemented).
        @available(*, unavailable, message: "zstd-stream compression not yet implemented")
        case zstdStream
    }
    
    /// The gateway compression method to use.
    public var gatewayCompression: GatewayCompression
    
    /// Enable payload compression in Identify payload.
    public var gatewayPayloadCompression: Bool
    
    /// Large threshold for guild member count (default 50).
    public var gatewayLargeThreshold: Int?

    /// Maximum concurrent connections per host for the HTTP client (default 8).
    ///
    /// Increase this for high-volume bots that need to send many concurrent API requests.
    /// Discord's REST API generally recommends staying under ~50 concurrent requests per host.
    public var httpMaxConnectionsPerHost: Int

    /// The logger used by the library for diagnostic and error messages.
    /// Set to `nil` to silence all library logging.
    public var logger: (any DiscordLogger)?

    /// Proxy configuration for all HTTP and WebSocket connections.
    ///
    /// Set this to route all REST API requests and Gateway WebSocket traffic
    /// through a proxy server. Requires the proxy to support the `CONNECT`
    /// method for HTTPS/WSS traffic.
    ///
    /// ## Example
    /// ```swift
    /// config.proxy = ProxyConfiguration(host: "proxy.example.com", port: 8080)
    /// ```
    public var proxy: ProxyConfiguration?

    /// Creates a new Discord configuration.
    ///
    /// - Parameters:
    ///   - apiBaseURL: The base URL for the Discord REST API (default is Discord's production API).
    ///   - apiVersion: The API version to use (default is 10).
    ///   - gatewayBaseURL: The base URL for the Discord Gateway (default is Discord's production gateway).
    ///   - maxUploadBytes: The maximum file upload size in bytes (default is 100MB).
    ///   - enableGatewayDecodeDiagnostics: Whether to enable gateway decode diagnostics (default is false).
    ///   - onRateLimit: A handler for rate limit events.
    ///   - gatewayCompression: The gateway compression method to use (default is none).
    ///   - gatewayPayloadCompression: Whether to enable payload compression in Identify payload (default is false).
    ///   - gatewayLargeThreshold: Large threshold for guild member count (default is nil).
    ///   - httpMaxConnectionsPerHost: Maximum concurrent connections per host for the HTTP client (default is 8).
    ///   - logger: Optional logger instance. Defaults to `DefaultDiscordLogger()` which writes
    ///             to `os_log` on Apple platforms and `print` elsewhere. Pass `nil` to disable logging.
    ///   - proxy: Optional proxy configuration. Routes all HTTP and WebSocket traffic through the given proxy (default is nil).
    public init(apiBaseURL: URL = DiscordConfiguration.defaultApiBaseURL, apiVersion: Int = 10, gatewayBaseURL: URL = DiscordConfiguration.defaultGatewayBaseURL, maxUploadBytes: Int = 100 * 1024 * 1024, enableGatewayDecodeDiagnostics: Bool = false, onRateLimit: RateLimitHandler? = nil, gatewayCompression: GatewayCompression = .none, gatewayPayloadCompression: Bool = false, gatewayLargeThreshold: Int? = nil, httpMaxConnectionsPerHost: Int = 8, logger: (any DiscordLogger)? = DefaultDiscordLogger(), proxy: ProxyConfiguration? = nil) {
        self.apiBaseURL = apiBaseURL
        self.apiVersion = apiVersion
        self.gatewayBaseURL = gatewayBaseURL
        self.maxUploadBytes = maxUploadBytes
        self.enableGatewayDecodeDiagnostics = enableGatewayDecodeDiagnostics
        self.onRateLimit = onRateLimit
        self.gatewayCompression = gatewayCompression
        self.gatewayPayloadCompression = gatewayPayloadCompression
        self.gatewayLargeThreshold = gatewayLargeThreshold
        self.httpMaxConnectionsPerHost = httpMaxConnectionsPerHost
        self.logger = logger
        self.proxy = proxy
    }

    /// The REST API base URL with the version appended.
    var restBase: URL { apiBaseURL.appendingPathComponent("v\(apiVersion)") }
}
