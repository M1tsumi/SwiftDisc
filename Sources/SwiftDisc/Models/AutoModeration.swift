import Foundation

/// Represents an auto moderation rule in a guild.
public struct AutoModerationRule: Codable, Hashable, Sendable {
    /// Auto Moderation trigger types for rule configuration.
    public enum TriggerType: Int, Codable, Sendable {
        case keyword = 1
        case spam = 3
        case keywordPreset = 4
        case mentionSpam = 5
        case memberProfile = 6
        case unknown = -1

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(Int.self)
            self = TriggerType(rawValue: rawValue) ?? .unknown
        }
    }

    /// Auto Moderation action types for rule responses.
    public enum ActionType: Int, Codable, Sendable {
        case blockMessage = 1
        case sendAlert = 2
        case timeout = 3
        case blockMemberInteraction = 4
        case unknown = -1

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(Int.self)
            self = ActionType(rawValue: rawValue) ?? .unknown
        }
    }

    /// The event type for an auto moderation rule (1 = MESSAGE_SEND, 2 = MEMBER_UPDATE).
    public enum EventType: Int, Codable, Sendable {
        case messageSend = 1
        case memberUpdate = 2
        case unknown = -1

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(Int.self)
            self = EventType(rawValue: rawValue) ?? .unknown
        }
    }

    /// Metadata for an auto moderation trigger.
    public struct TriggerMetadata: Codable, Hashable, Sendable {
        public let keyword_filter: [String]?
        public let presets: [Int]?
        public let allow_list: [String]?
        public let mention_total_limit: Int?
        public let mention_raid_protection_enabled: Bool?
    }
    /// An action taken when an auto moderation rule is triggered.
    public struct Action: Codable, Hashable, Sendable {
        /// Metadata for an auto moderation action.
        public struct Metadata: Codable, Hashable, Sendable {
            public let channel_id: ChannelID?
            public let duration_seconds: Int?
            public let custom_message: String?
        }
        public let type: ActionType
        public let metadata: Metadata?
    }
    public let id: AutoModerationRuleID
    public let guild_id: GuildID
    public let name: String
    public let creator_id: UserID
    public let event_type: EventType
    public let trigger_type: TriggerType
    public let trigger_metadata: TriggerMetadata?
    public let actions: [Action]
    public let enabled: Bool
    public let exempt_roles: [RoleID]?
    public let exempt_channels: [ChannelID]?
}
