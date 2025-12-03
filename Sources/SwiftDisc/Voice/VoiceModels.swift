import Foundation

public enum VoiceError: Error, CustomStringConvertible {
    case disabled
    case notImplemented(String)

    public var description: String {
        switch self {
        case .disabled: return "Voice is disabled. Enable via DiscordConfiguration.enableVoiceExperimental."
        case .notImplemented(let msg): return "Voice not implemented: \(msg)"
        }
    }
}

public struct VoiceConnectionInfo {
    public let guildId: GuildID
    public let channelId: ChannelID
    public let sessionId: String?
    public let endpoint: String?
    public let token: String?

    public init(guildId: GuildID, channelId: ChannelID, sessionId: String? = nil, endpoint: String? = nil, token: String? = nil) {
        self.guildId = guildId
        self.channelId = channelId
        self.sessionId = sessionId
        self.endpoint = endpoint
        self.token = token
    }
}

public struct VoiceFrame {
    public let guildId: GuildID
    public let ssrc: UInt32
    public let sequence: UInt16
    public let timestamp: UInt32
    public let opus: Data

    public init(guildId: GuildID, ssrc: UInt32, sequence: UInt16, timestamp: UInt32, opus: Data) {
        self.guildId = guildId
        self.ssrc = ssrc
        self.sequence = sequence
        self.timestamp = timestamp
        self.opus = opus
    }
}
