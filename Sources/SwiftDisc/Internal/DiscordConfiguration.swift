import Foundation

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
    public static let version = "2.3.1"

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
    public init(apiBaseURL: URL = DiscordConfiguration.defaultApiBaseURL, apiVersion: Int = 10, gatewayBaseURL: URL = DiscordConfiguration.defaultGatewayBaseURL, maxUploadBytes: Int = 100 * 1024 * 1024, enableGatewayDecodeDiagnostics: Bool = false, onRateLimit: RateLimitHandler? = nil, gatewayCompression: GatewayCompression = .none, gatewayPayloadCompression: Bool = false, gatewayLargeThreshold: Int? = nil) {
        self.apiBaseURL = apiBaseURL
        self.apiVersion = apiVersion
        self.gatewayBaseURL = gatewayBaseURL
        self.maxUploadBytes = maxUploadBytes
        self.enableGatewayDecodeDiagnostics = enableGatewayDecodeDiagnostics
        self.onRateLimit = onRateLimit
        self.gatewayCompression = gatewayCompression
        self.gatewayPayloadCompression = gatewayPayloadCompression
        self.gatewayLargeThreshold = gatewayLargeThreshold
    }

    /// The REST API base URL with the version appended.
    var restBase: URL { apiBaseURL.appendingPathComponent("v\(apiVersion)") }
}
