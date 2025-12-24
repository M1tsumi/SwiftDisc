import Foundation

// MARK: - Voice State
public struct VoiceState: Codable, Hashable {
    public let guild_id: GuildID?
    public let channel_id: ChannelID?
    public let user_id: UserID
    public let member: GuildMember?
    public let session_id: String
    public let deaf: Bool
    public let mute: Bool
    public let self_deaf: Bool
    public let self_mute: Bool
    public let self_stream: Bool?
    public let self_video: Bool
    public let suppress: Bool
    public let request_to_speak_timestamp: String?
}

// MARK: - Voice Region
public struct VoiceRegion: Codable, Hashable {
    public let id: String
    public let name: String
    public let optimal: Bool
    public let deprecated: Bool
    public let custom: Bool
}

// MARK: - Voice State Update
public struct VoiceStateUpdate: Codable, Hashable {
    public let guild_id: GuildID?
    public let channel_id: ChannelID?
    public let self_mute: Bool
    public let self_deaf: Bool
    
    public init(guild_id: GuildID? = nil, channel_id: ChannelID? = nil, self_mute: Bool, self_deaf: Bool) {
        self.guild_id = guild_id
        self.channel_id = channel_id
        self.self_mute = self_mute
        self.self_deaf = self_deaf
    }
}
