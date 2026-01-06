//
//  Channel.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct Channel: Codable, Hashable {
    public let id: ChannelID
    public let type: Int
    public let name: String?
    public let topic: String?
    public let nsfw: Bool?
    public let position: Int?
    public let parent_id: ChannelID?
    // Forum-specific (type 15)
    public let available_tags: [ForumTag]?
    public let default_reaction_emoji: DefaultReaction?
    public let default_sort_order: Int?
    public let default_forum_layout: Int?
    public let default_auto_archive_duration: Int?
    public let rate_limit_per_user: Int?
    public let permission_overwrites: [PermissionOverwrite]?
}

public struct ForumTag: Codable, Hashable {
    public let id: ForumTagID
    public let name: String
    public let moderated: Bool?
    public let emoji_id: EmojiID?
    public let emoji_name: String?
}

public struct DefaultReaction: Codable, Hashable {
    public let emoji_id: EmojiID?
    public let emoji_name: String?
}

public struct PermissionOverwrite: Codable, Hashable {
    // type: 0 role, 1 member
    public let id: OverwriteID
    public let type: Int
    public let allow: String
    public let deny: String
}
