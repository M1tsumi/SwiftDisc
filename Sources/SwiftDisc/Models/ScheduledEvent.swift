import Foundation

/// The privacy level of a scheduled event.
public enum EventPrivacyLevel: Int, Codable, Sendable {
    case guildOnly = 2
    case unknown = -1

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = EventPrivacyLevel(rawValue: rawValue) ?? .unknown
    }
}

/// Represents a scheduled event in a guild.
public struct GuildScheduledEvent: Codable, Hashable, Sendable {
    /// The type of entity associated with a scheduled event.
    public enum EntityType: Int, Codable, Sendable {
        case stageInstance = 1
        case voice = 2
        case external = 3
        case unknown = 0

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(Int.self)
            self = EntityType(rawValue: rawValue) ?? .unknown
        }
    }

    public enum Status: Int, Codable, Sendable {
        case scheduled = 1
        case active = 2
        case completed = 3
        case canceled = 4
        case unknown = 0

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(Int.self)
            self = Status(rawValue: rawValue) ?? .unknown
        }
    }
    public let id: GuildScheduledEventID
    public let guild_id: GuildID
    public let channel_id: ChannelID?
    public let creator_id: UserID?
    public let name: String
    public let description: String?
    public let scheduled_start_time: String
    public let scheduled_end_time: String?
    public let privacy_level: EventPrivacyLevel
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
