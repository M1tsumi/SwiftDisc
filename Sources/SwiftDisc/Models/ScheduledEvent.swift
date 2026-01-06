//
//  ScheduledEvent.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct GuildScheduledEvent: Codable, Hashable {
    public enum EntityType: Int, Codable { case stageInstance = 1, voice = 2, external = 3 }
    public enum Status: Int, Codable { case scheduled = 1, active = 2, completed = 3, canceled = 4 }
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

    public struct EntityMetadata: Codable, Hashable {
        public let location: String?
    }
}
