import Foundation

/// Represents a live stage instance in a stage channel.
public struct StageInstance: Codable, Hashable, Sendable {
    public let id: StageInstanceID
    public let guild_id: GuildID
    public let channel_id: ChannelID
    public let topic: String
    public let privacy_level: EventPrivacyLevel
    public let discoverable_disabled: Bool?
    public let guild_scheduled_event_id: GuildScheduledEventID?
}
