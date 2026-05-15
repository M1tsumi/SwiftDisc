import Foundation

/// Represents a scheduled event in a guild.
public struct GuildScheduledEvent: Codable, Hashable, Sendable {
    /// The type of entity associated with a scheduled event.
    public enum EntityType: Int, Codable, Sendable { case stageInstance = 1, voice = 2, external = 3 }
    /// The status of a scheduled event.
    public enum Status: Int, Codable, Sendable { case scheduled = 1, active = 2, completed = 3, canceled = 4 }
    public let id: GuildScheduledEventID
    public let guild_id: GuildID
    public let channel_id: ChannelID?
    public let creator_id: UserID?
    public let name: String
    public let description: String?
    public let scheduled_start_time: String
    public let scheduled_end_time: String?
    public let privacy_level: Int
    public let status: Status
    public let entity_type: EntityType
    public let entity_id: ChannelID?
    public let entity_metadata: EntityMetadata?
    public let user_count: Int?

    /// Metadata for an external scheduled event.
    public struct EntityMetadata: Codable, Hashable, Sendable {
        public let location: String?
    }
}
