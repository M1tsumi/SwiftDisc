//
//  AutoModeration.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct AutoModerationRule: Codable, Hashable {
    public struct TriggerMetadata: Codable, Hashable {
        public let keyword_filter: [String]?
        public let presets: [Int]?
        public let allow_list: [String]?
        public let mention_total_limit: Int?
        public let mention_raid_protection_enabled: Bool?
    }
    public struct Action: Codable, Hashable {
        public struct Metadata: Codable, Hashable {
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
