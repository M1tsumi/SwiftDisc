import Foundation

public struct Channel: Codable, Hashable, Sendable {
    public let id: ChannelID
    public let type: Int
    public let name: String?
    public let topic: String?
    public let nsfw: Bool?
    public let position: Int?
    public let parent_id: ChannelID?
    public let last_message_id: MessageID?
    public let bitrate: Int?
    public let user_limit: Int?
    public let rate_limit_per_user: Int?
    public let recipients: [User]?
    public let icon: String?
    public let owner_id: UserID?
    public let application_id: ApplicationID?
    public let managed: Bool?
    public let rtc_region: String?
    public let video_quality_mode: Int?
    public let message_count: Int?
    public let member_count: Int?
    public let thread_metadata: ThreadMetadata?
    public let member: ThreadMember?
    public let default_auto_archive_duration: Int?
    public let permissions: String?
    public let flags: Int?
    public let total_message_sent: Int?
    public let available_tags: [ForumTag]?
    public let applied_tags: [ForumTagID]?
    public let default_reaction_emoji: DefaultReaction?
    public let default_thread_rate_limit_per_user: Int?
    public let default_sort_order: Int?
    public let default_forum_layout: Int?
    public let default_thread_emoji: DefaultReaction?
    public let newly_created: Bool?
    public let permission_overwrites: [PermissionOverwrite]?
    public let last_pin_timestamp: String?

    public init(
        id: ChannelID,
        type: Int,
        name: String? = nil,
        topic: String? = nil,
        nsfw: Bool? = nil,
        position: Int? = nil,
        parent_id: ChannelID? = nil,
        last_message_id: MessageID? = nil,
        bitrate: Int? = nil,
        user_limit: Int? = nil,
        rate_limit_per_user: Int? = nil,
        recipients: [User]? = nil,
        icon: String? = nil,
        owner_id: UserID? = nil,
        application_id: ApplicationID? = nil,
        managed: Bool? = nil,
        rtc_region: String? = nil,
        video_quality_mode: Int? = nil,
        message_count: Int? = nil,
        member_count: Int? = nil,
        thread_metadata: ThreadMetadata? = nil,
        member: ThreadMember? = nil,
        default_auto_archive_duration: Int? = nil,
        permissions: String? = nil,
        flags: Int? = nil,
        total_message_sent: Int? = nil,
        available_tags: [ForumTag]? = nil,
        applied_tags: [ForumTagID]? = nil,
        default_reaction_emoji: DefaultReaction? = nil,
        default_thread_rate_limit_per_user: Int? = nil,
        default_sort_order: Int? = nil,
        default_forum_layout: Int? = nil,
        default_thread_emoji: DefaultReaction? = nil,
        newly_created: Bool? = nil,
        permission_overwrites: [PermissionOverwrite]? = nil,
        last_pin_timestamp: String? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.topic = topic
        self.nsfw = nsfw
        self.position = position
        self.parent_id = parent_id
        self.last_message_id = last_message_id
        self.bitrate = bitrate
        self.user_limit = user_limit
        self.rate_limit_per_user = rate_limit_per_user
        self.recipients = recipients
        self.icon = icon
        self.owner_id = owner_id
        self.application_id = application_id
        self.managed = managed
        self.rtc_region = rtc_region
        self.video_quality_mode = video_quality_mode
        self.message_count = message_count
        self.member_count = member_count
        self.thread_metadata = thread_metadata
        self.member = member
        self.default_auto_archive_duration = default_auto_archive_duration
        self.permissions = permissions
        self.flags = flags
        self.total_message_sent = total_message_sent
        self.available_tags = available_tags
        self.applied_tags = applied_tags
        self.default_reaction_emoji = default_reaction_emoji
        self.default_thread_rate_limit_per_user = default_thread_rate_limit_per_user
        self.default_sort_order = default_sort_order
        self.default_forum_layout = default_forum_layout
        self.default_thread_emoji = default_thread_emoji
        self.newly_created = newly_created
        self.permission_overwrites = permission_overwrites
        self.last_pin_timestamp = last_pin_timestamp
    }
}

public struct ForumTag: Codable, Hashable, Sendable {
    public let id: ForumTagID
    public let name: String
    public let moderated: Bool?
    public let emoji_id: EmojiID?
    public let emoji_name: String?
}

public struct DefaultReaction: Codable, Hashable, Sendable {
    public let emoji_id: EmojiID?
    public let emoji_name: String?
}

public struct PermissionOverwrite: Codable, Hashable, Sendable {
    // type: 0 role, 1 member
    public let id: OverwriteID
    public let type: Int
    public let allow: String
    public let deny: String
}

public struct ThreadMetadata: Codable, Hashable, Sendable {
    public let archived: Bool?
    public let auto_archive_duration: Int?
    public let archive_timestamp: String?
    public let locked: Bool?
    public let invitable: Bool?
    public let create_timestamp: String?
}
