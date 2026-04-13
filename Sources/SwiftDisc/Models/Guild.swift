import Foundation

/// A full Discord Guild (server) object.
/// Fields such as `members`, `channels`, and `threads` are only populated
/// in the `GUILD_CREATE` gateway event; REST responses return `nil` for them.
public struct Guild: Codable, Hashable, Sendable {
    // MARK: - Core Identity
    public let id: GuildID
    public let name: String
    public let icon: String?
    public let icon_hash: String?
    public let splash: String?
    public let discovery_splash: String?

    // MARK: - Ownership
    public let owner: Bool?
    public let owner_id: UserID?
    public let permissions: String?

    // MARK: - AFK
    public let afk_channel_id: ChannelID?
    public let afk_timeout: Int?

    // MARK: - Widget
    public let widget_enabled: Bool?
    public let widget_channel_id: ChannelID?

    // MARK: - Moderation
    public let verification_level: Int?
    public let default_message_notifications: Int?
    public let explicit_content_filter: Int?
    public let mfa_level: Int?
    public let nsfw_level: Int?

    // MARK: - Content
    public let roles: [Role]?
    public let emojis: [Emoji]?
    public let features: [String]?
    public let stickers: [Sticker]?

    // MARK: - System Channels
    public let application_id: ApplicationID?
    public let system_channel_id: ChannelID?
    public let system_channel_flags: Int?
    public let rules_channel_id: ChannelID?

    // MARK: - Size
    public let max_presences: Int?
    public let max_members: Int?
    public let member_count: Int?
    public let large: Bool?
    public let unavailable: Bool?

    // MARK: - Branding
    public let vanity_url_code: String?
    public let description: String?
    public let banner: String?

    // MARK: - Nitro / Boost
    public let premium_tier: Int?
    public let premium_subscription_count: Int?
    public let premium_progress_bar_enabled: Bool?

    // MARK: - Locale & Update Channels
    public let preferred_locale: String?
    public let public_updates_channel_id: ChannelID?
    public let safety_alerts_channel_id: ChannelID?

    // MARK: - Capacity
    public let max_video_channel_users: Int?
    public let max_stage_video_channel_users: Int?
    public let approximate_member_count: Int?
    public let approximate_presence_count: Int?

    // MARK: - GUILD_CREATE-only fields
    /// ISO 8601 timestamp for when the bot joined. Present only in GUILD_CREATE payloads.
    public let joined_at: String?
    /// Member list included by the gateway. Not present in standard REST guild responses.
    public let members: [GuildMember]?
    /// Channel list included by the gateway. Not present in standard REST guild responses.
    public let channels: [Channel]?
    /// Active threads included by the gateway. Not present in standard REST guild responses.
    public let threads: [Channel]?

    // MARK: - Initializer for tests and cache seeding
    public init(
        id: GuildID,
        name: String,
        owner_id: UserID? = nil,
        member_count: Int? = nil,
        roles: [Role]? = nil,
        emojis: [Emoji]? = nil,
        channels: [Channel]? = nil,
        members: [GuildMember]? = nil,
        features: [String]? = nil,
        icon: String? = nil,
        description: String? = nil,
        banner: String? = nil,
        preferred_locale: String? = nil,
        premium_tier: Int? = nil,
        nsfw_level: Int? = nil
    ) {
        self.id = id; self.name = name; self.icon = icon; self.icon_hash = nil
        self.splash = nil; self.discovery_splash = nil; self.owner = nil
        self.owner_id = owner_id; self.permissions = nil; self.afk_channel_id = nil
        self.afk_timeout = nil; self.widget_enabled = nil; self.widget_channel_id = nil
        self.verification_level = nil; self.default_message_notifications = nil
        self.explicit_content_filter = nil; self.mfa_level = nil; self.nsfw_level = nsfw_level
        self.roles = roles; self.emojis = emojis; self.features = features; self.stickers = nil
        self.application_id = nil; self.system_channel_id = nil; self.system_channel_flags = nil
        self.rules_channel_id = nil; self.max_presences = nil; self.max_members = nil
        self.member_count = member_count; self.large = nil; self.unavailable = nil
        self.vanity_url_code = nil; self.description = description; self.banner = banner
        self.premium_tier = premium_tier; self.premium_subscription_count = nil
        self.premium_progress_bar_enabled = nil; self.preferred_locale = preferred_locale
        self.public_updates_channel_id = nil; self.safety_alerts_channel_id = nil
        self.max_video_channel_users = nil; self.max_stage_video_channel_users = nil
        self.approximate_member_count = nil; self.approximate_presence_count = nil
        self.joined_at = nil; self.members = members; self.channels = channels; self.threads = nil
    }
}
