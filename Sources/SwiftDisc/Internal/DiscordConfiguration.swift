import Foundation

public struct DiscordConfiguration: Sendable {
    public var apiBaseURL: URL
    public var apiVersion: Int
    public var gatewayBaseURL: URL
    public var maxUploadBytes: Int // per-file guardrail
    public var enableVoiceExperimental: Bool
    /// When enabled, gateway decode mismatches emit diagnostic logs with event/op metadata.
    public var enableGatewayDecodeDiagnostics: Bool

    public init(apiBaseURL: URL = URL(string: "https://discord.com/api")!, apiVersion: Int = 10, gatewayBaseURL: URL = URL(string: "wss://gateway.discord.gg")!, maxUploadBytes: Int = 100 * 1024 * 1024, enableVoiceExperimental: Bool = false, enableGatewayDecodeDiagnostics: Bool = false) {
        self.apiBaseURL = apiBaseURL
        self.apiVersion = apiVersion
        self.gatewayBaseURL = gatewayBaseURL
        self.maxUploadBytes = maxUploadBytes
        self.enableVoiceExperimental = enableVoiceExperimental
        self.enableGatewayDecodeDiagnostics = enableGatewayDecodeDiagnostics
    }

    var restBase: URL { apiBaseURL.appendingPathComponent("v\(apiVersion)") }
}
