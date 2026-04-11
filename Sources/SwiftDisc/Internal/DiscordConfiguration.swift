import Foundation

public struct DiscordConfiguration: Sendable {
    // Safe defaults for base URLs to avoid force-unwrapping string initializers.
    public static let defaultApiBaseURL: URL = {
        guard let url = URL(string: "https://discord.com/api") else {
            fatalError("Invalid default API base URL")
        }
        return url
    }()

    public static let defaultGatewayBaseURL: URL = {
        guard let url = URL(string: "wss://gateway.discord.gg") else {
            fatalError("Invalid default gateway base URL")
        }
        return url
    }()

    public var apiBaseURL: URL
    public var apiVersion: Int
    public var gatewayBaseURL: URL
    public var maxUploadBytes: Int // per-file guardrail
    public typealias RateLimitHandler = @Sendable (RateLimitEvent) -> Void
    /// Enables the voice stack. Keep disabled unless you need voice-specific APIs.
    public var enableVoiceExperimental: Bool
    /// When enabled, gateway decode mismatches emit diagnostic logs with event/op metadata.
    /// Useful when Discord payload shape drifts or a model needs to be updated.
    public var enableGatewayDecodeDiagnostics: Bool
    /// Called when SwiftDisc observes a REST rate limit bucket update or wait.
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
