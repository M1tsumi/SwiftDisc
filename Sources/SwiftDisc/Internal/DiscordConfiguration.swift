import Foundation

public struct DiscordConfiguration: Sendable {
    // Default URLs are static constants so startup never depends on force-unwrapped strings.
    public static let defaultApiBaseURL: URL = URL(string: "https://discord.com/api")!

    public static let defaultGatewayBaseURL: URL = URL(string: "wss://gateway.discord.gg")!

    public var apiBaseURL: URL
    public var apiVersion: Int
    public var gatewayBaseURL: URL
    public var maxUploadBytes: Int // Per-file upload limit used before sending multipart requests.
    public typealias RateLimitHandler = @Sendable (RateLimitEvent) -> Void
    /// Enables voice features. Keep this off unless your bot joins voice channels.
    public var enableVoiceExperimental: Bool
    /// Enables extra gateway decode logs with opcode/event context.
    /// Turn this on when payloads drift and you need to see what failed to decode.
    public var enableGatewayDecodeDiagnostics: Bool
    /// Called whenever the REST limiter updates bucket state or enters a wait.
    public var onRateLimit: RateLimitHandler?

    public init(apiBaseURL: URL = DiscordConfiguration.defaultApiBaseURL, apiVersion: Int = 10, gatewayBaseURL: URL = DiscordConfiguration.defaultGatewayBaseURL, maxUploadBytes: Int = 100 * 1024 * 1024, enableVoiceExperimental: Bool = false, enableGatewayDecodeDiagnostics: Bool = false, onRateLimit: RateLimitHandler? = nil) {
        self.apiBaseURL = apiBaseURL
        self.apiVersion = apiVersion
        self.gatewayBaseURL = gatewayBaseURL
        self.maxUploadBytes = maxUploadBytes
        self.enableVoiceExperimental = enableVoiceExperimental
        self.enableGatewayDecodeDiagnostics = enableGatewayDecodeDiagnostics
        self.onRateLimit = onRateLimit
    }

    var restBase: URL { apiBaseURL.appendingPathComponent("v\(apiVersion)") }
}
