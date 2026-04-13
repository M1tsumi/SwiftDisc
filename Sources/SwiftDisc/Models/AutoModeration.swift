import Foundation

public struct AutoModerationRule: Codable, Hashable, Sendable {
    /// Auto Moderation trigger types for rule configuration.
    public enum TriggerType: Int, Sendable {
        case keyword = 1
        case spam = 3
        case keywordPreset = 4
        case mentionSpam = 5
        /// Member profile trigger type. Checks if a member's profile contains disallowed keywords.
        /// Introduced for member profile moderation.
        case memberProfile = 6
    }

    /// Auto Moderation action types for rule responses.
    public enum ActionType: Int, Sendable {
        case blockMessage = 1
        case sendAlert = 2
        case timeout = 3
        case blockMemberInteraction = 4
    }

    public struct TriggerMetadata: Codable, Hashable, Sendable {
        public let keyword_filter: [String]?
        public let presets: [Int]?
        public let allow_list: [String]?
        public let mention_total_limit: Int?
        public let mention_raid_protection_enabled: Bool?
    }
    public struct Action: Codable, Hashable, Sendable {
        public struct Metadata: Codable, Hashable, Sendable {
            public let channel_id: ChannelID?
            public let duration_seconds: Int?
            public let custom_message: String?
        }
        public let type: Int
        public let metadata: Metadata?
    }
    public let id: AutoModerationRuleID
    public let guild_id: GuildID
    public let name: String
    public let creator_id: UserID
    public let event_type: Int
    public let trigger_type: Int
    public let trigger_metadata: TriggerMetadata?
    public let actions: [Action]
    public let enabled: Bool
    public let exempt_roles: [RoleID]?
    public let exempt_channels: [ChannelID]?
}
