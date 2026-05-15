import Foundation

/// Represents a Discord channel.
///
/// Channels are the primary way users communicate in Discord. This struct represents all channel types including:
/// - Text channels (type 0)
/// - Direct messages (type 1)
/// - Voice channels (type 2)
/// - Group DMs (type 3)
/// - Categories (type 4)
/// - News channels (type 5)
/// - Store channels (type 6)
/// - News threads (type 10)
/// - Public threads (type 11)
/// - Private threads (type 12)
/// - Stage channels (type 13)
/// - Directory channels (type 14)
/// - Forum channels (type 15)
///
/// ## Example
///
/// ```swift
/// // Access channel from cache or API response
/// if let channel = client.cache.channels[channelId] {
///     print("Channel name: \(channel.name ?? "DM")")
///     print("Channel type: \(channel.type)")
///     if let topic = channel.topic {
///         print("Topic: \(topic)")
///     }
/// }
/// ```
///
/// ## Channel Type Constants
///
/// - `0`: Guild text channel
/// - `1`: DM channel
/// - `2`: Guild voice channel
/// - `3`: Group DM
/// - `4`: Guild category
/// - `5`: Guild news channel
/// - `6`: Guild store channel
/// - `10`: Guild news thread
/// - `11`: Guild public thread
/// - `12`: Guild private thread
/// - `13`: Guild stage channel
/// - `14`: Guild directory
/// - `15`: Guild forum channel
///
/// ## Related Topics
/// - ``DiscordClient/getChannel(id:)``
/// - ``DiscordClient/modifyChannel(id:topic:nsfw:position:parentId:)``
/// - ``ThreadMetadata``
/// - ``ForumTag``
public struct Channel: Codable, Hashable, Sendable {
    /// The unique ID of the channel.
    public let id: ChannelID
    
    /// The type of channel (see Channel Type Constants in the struct documentation).
    public let type: Int
    
    /// The name of the channel (1-100 characters).
    public let name: String?
    
    /// The channel topic (0-1024 characters for text channels).
    public let topic: String?
    
    /// Whether the channel is NSFW (age-restricted).
    public let nsfw: Bool?
    
    /// The sorting position of the channel.
    public let position: Int?
    
    /// The ID of the parent category (for channels in categories).
    public let parent_id: ChannelID?
    
    /// The ID of the last message sent in the channel (may not point to an actual or valid message).
    public let last_message_id: MessageID?
    
    /// The bitrate (in bits) of the voice channel (voice channels only).
    public let bitrate: Int?
    
    /// The user limit of the voice channel (0 for no limit, voice channels only).
    public let user_limit: Int?
    
    /// The amount of seconds a user has to wait before sending another message (0-21600).
    public let rate_limit_per_user: Int?
    
    /// The recipients of the DM (DM channels only).
    public let recipients: [User]?
    
    /// The icon hash of the group DM (group DMs only).
    public let icon: String?
    
    /// The ID of the owner of the group DM (group DMs only).
    public let owner_id: UserID?
    
    /// The application ID of the group DM creator if it is bot-created (group DMs only).
    public let application_id: ApplicationID?
    
    /// Whether the channel is managed by an application via the `gdm.join` OAuth2 scope.
    public let managed: Bool?
    
    /// The region for the voice channel (voice channels only).
    public let rtc_region: String?
    
    /// The camera video quality mode of the voice channel (1: auto, 2: full).
    public let video_quality_mode: Int?
    
    /// The approximate count of messages in a thread (thread channels only).
    public let message_count: Int?
    
    /// The approximate count of members in a thread (thread channels only).
    public let member_count: Int?
    
    /// Thread-specific metadata (thread channels only).
    public let thread_metadata: ThreadMetadata?
    
    /// The thread member object for the current user if they are a member of the thread.
    public let member: ThreadMember?
    
    /// The default auto-archive duration for threads created in this channel (in minutes).
    public let default_auto_archive_duration: Int?
    
    /// Computed permissions for the invoking user in the channel (only for threads).
    public let permissions: String?
    
    /// Channel flags combined as a bitfield.
    public let flags: Int?
    
    /// Number of messages ever sent in a thread (thread channels only).
    public let total_message_sent: Int?
    
    /// The set of tags that can be used in a forum channel (forum channels only).
    public let available_tags: [ForumTag]?
    
    /// The IDs of the tags applied to a thread in a forum channel.
    public let applied_tags: [ForumTagID]?
    
    /// The default reaction emoji for forum channels.
    public let default_reaction_emoji: DefaultReaction?
    
    /// The default rate limit per user for threads in a forum channel (in seconds).
    public let default_thread_rate_limit_per_user: Int?
    
    /// The default sort order type used to order forum threads (0: latest, 1: oldest).
    public let default_sort_order: Int?
    
    /// The default forum layout type used to display forum posts (0: not set, 1: list view, 2: gallery view).
    public let default_forum_layout: Int?
    
    /// The default emoji to use for forum threads.
    public let default_thread_emoji: DefaultReaction?
    
    /// Whether the channel is newly created (for thread creation events).
    public let newly_created: Bool?
    
    /// Permission overwrites for the channel.
    public let permission_overwrites: [PermissionOverwrite]?
    
    /// When the last pinned message was pinned (ISO8601 timestamp).
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

/// Represents a tag in a forum channel.
///
/// Forum tags are used to categorize and organize posts in forum channels.
///
/// ## Example
///
/// ```swift
/// if let channel = client.cache.channels[channelId],
///    let tags = channel.available_tags {
///     for tag in tags {
///         print("Tag: \(tag.name)")
///         if tag.moderated {
///             print("  (moderated)")
///         }
///     }
/// }
/// ```
public struct ForumTag: Codable, Hashable, Sendable {
    /// The ID of the tag.
    public let id: ForumTagID
    
    /// The name of the tag (0-20 characters).
    public let name: String
    
    /// Whether the tag can only be added to or removed from threads by a moderator.
    public let moderated: Bool?
    
    /// The ID of the custom emoji for the tag.
    public let emoji_id: EmojiID?
    
    /// The name of the custom emoji for the tag.
    public let emoji_name: String?
}

/// Represents a default reaction emoji for a forum channel.
///
/// This emoji is automatically added to new forum posts.
///
/// ## Example
///
/// ```swift
/// if let channel = client.cache.channels[channelId],
///    let reaction = channel.default_reaction_emoji {
///     if let emojiId = reaction.emoji_id {
///         print("Default emoji ID: \(emojiId)")
///     } else if let emojiName = reaction.emoji_name {
///         print("Default emoji name: \(emojiName)")
///     }
/// }
/// ```
public struct DefaultReaction: Codable, Hashable, Sendable {
    /// The ID of the custom emoji.
    public let emoji_id: EmojiID?
    
    /// The name of the emoji (for Unicode emoji or custom emoji).
    public let emoji_name: String?
}

/// Represents a permission overwrite for a channel.
///
/// Permission overwrites allow you to customize permissions for specific roles or members in a channel.
///
/// ## Example
///
/// ```swift
/// if let channel = client.cache.channels[channelId],
///    let overwrites = channel.permission_overwrites {
///     for overwrite in overwrites {
///         print("Overwrite ID: \(overwrite.id)")
///         print("Type: \(overwrite.type == 0 ? "role" : "member")")
///         print("Allow: \(overwrite.allow)")
///         print("Deny: \(overwrite.deny)")
///     }
/// }
/// ```
///
/// ## Type Values
/// - `0`: Role overwrite
/// - `1`: Member overwrite
public struct PermissionOverwrite: Codable, Hashable, Sendable {
    /// The ID of the role or member this overwrite applies to.
    public let id: OverwriteID
    
    /// The type of overwrite (0 for role, 1 for member).
    public let type: Int
    
    /// Permission bit set for allowed permissions.
    public let allow: String
    
    /// Permission bit set for denied permissions.
    public let deny: String
}

/// Represents metadata for a thread channel.
///
/// Thread metadata contains information about the thread's archival state and settings.
///
/// ## Example
///
/// ```swift
/// if let channel = client.cache.channels[channelId],
///    let metadata = channel.thread_metadata {
///     print("Archived: \(metadata.archived ?? false)")
///     print("Locked: \(metadata.locked ?? false)")
///     print("Auto-archive duration: \(metadata.auto_archive_duration ?? 0) minutes")
/// }
/// ```
public struct ThreadMetadata: Codable, Hashable, Sendable {
    /// Whether the thread is archived.
    public let archived: Bool?
    
    /// The duration in minutes before the thread is automatically archived (60, 1440, 4320, or 10080).
    public let auto_archive_duration: Int?
    
    /// The timestamp when the thread's archive status was last changed (ISO8601 timestamp).
    public let archive_timestamp: String?
    
    /// Whether the thread is locked.
    ///
    /// When a thread is locked, only users with `MANAGE_THREADS` can unarchive it.
    public let locked: Bool?
    
    /// Whether non-moderators can add other non-moderators to the thread.
    public let invitable: Bool?
    
    /// The timestamp when the thread was created (ISO8601 timestamp).
    public let create_timestamp: String?
}
