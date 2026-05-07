import Foundation

public struct DiscordConfiguration: Sendable {
    /// SwiftDisc library version for User-Agent header and Discord tracking.
    public static let version = "2.2.0"

    // Default URLs are static constants so startup never depends on force-unwrapped strings.
    public static let defaultApiBaseURL: URL = URL(string: "https://discord.com/api")!

    public static let defaultGatewayBaseURL: URL = URL(string: "wss://gateway.discord.gg")!

    public var apiBaseURL: URL
    public var apiVersion: Int
    public var gatewayBaseURL: URL
    public var maxUploadBytes: Int // Per-file upload limit used before sending multipart requests.
    public typealias RateLimitHandler = @Sendable (RateLimitEvent) -> Void
    /// Enables extra gateway decode logs with opcode/event context.
    /// Turn this on when payloads drift and you need to see what failed to decode.
    public var enableGatewayDecodeDiagnostics: Bool
    /// Called whenever the REST limiter updates bucket state or enters a wait.
    public var onRateLimit: RateLimitHandler?
    /// Gateway transport compression: none, zlib-stream, or zstd-stream
    public enum GatewayCompression: Sendable {
        case none
        case zlibStream
        case zstdStream
    }
    public var gatewayCompression: GatewayCompression
    /// Enable payload compression in Identify payload
    public var gatewayPayloadCompression: Bool
    /// Large threshold for guild member count (default 50)
    public var gatewayLargeThreshold: Int?

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

    var restBase: URL { apiBaseURL.appendingPathComponent("v\(apiVersion)") }
}
