import Foundation

public struct DiscordConfiguration {
    public var apiBaseURL: URL
    public var apiVersion: Int
    public var gatewayBaseURL: URL
    public var maxUploadBytes: Int // per-file guardrail
    public var enableVoiceExperimental: Bool
    
    // Heartbeat configuration
    public var heartbeatJitter: Double // 0.0 to 1.0, jitter factor
    public var maxMissedHeartbeats: Int // Max missed heartbeats before reconnect

    public init(
        apiBaseURL: URL = URL(string: "https://discord.com/api")!, 
        apiVersion: Int = 10, 
        gatewayBaseURL: URL = URL(string: "wss://gateway.discord.gg")!, 
        maxUploadBytes: Int = 100 * 1024 * 1024, 
        enableVoiceExperimental: Bool = false,
        heartbeatJitter: Double = 0.1,
        maxMissedHeartbeats: Int = 3
    ) {
        self.apiBaseURL = apiBaseURL
        self.apiVersion = apiVersion
        self.gatewayBaseURL = gatewayBaseURL
        self.maxUploadBytes = maxUploadBytes
        self.enableVoiceExperimental = enableVoiceExperimental
        self.heartbeatJitter = max(0.0, min(1.0, heartbeatJitter))
        self.maxMissedHeartbeats = max(1, maxMissedHeartbeats)
    }

    var restBase: URL { apiBaseURL.appendingPathComponent("v\(apiVersion)") }
}
