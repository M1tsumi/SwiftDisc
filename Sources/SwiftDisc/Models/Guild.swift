import Foundation

/// A feature enabled on a guild.
public enum GuildFeature: RawRepresentable, Codable, Hashable, Sendable {
    case animatedIcon
    case banner
    case community
    case discoveries
    case featurable
    case inviteSplash
    case memberVerificationGateEnabled
    case monetizationEnabled
    case moreStickers
    case news
    case partnered
    case previewEnabled
    case raidAlertsDisabled
    case roleSubscriptionsEnabled
    case roleSubscriptionsPurchased
    case ticketedEventsEnabled
    case vanityUrl
    case verified
    case vipRegions
    case welcomeScreenEnabled
    case guestsEnabled
    case guildTags
    case enhancedRoleColors
    case applicationCommandPermissionsV2
    case autoModeration
    case guildWebPageVanityUrl
    case creatorMonetizable
    case creatorMonetizableDisclaimer
    case creatorStorePage
    case roleSubscriptionsAvailableForPurchase
    case onboardingEnabled
    case onboarding
    case soundboard
    case memberProfiles
    case roleSubscriptions
    case home
    case channelIconEmojisGenerated
    case [`internal`]
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .animatedIcon: return "ANIMATED_ICON"
        case .banner: return "BANNER"
        case .community: return "COMMUNITY"
        case .discoveries: return "DISCOVERABLE"
        case .featurable: return "FEATURABLE"
        case .inviteSplash: return "INVITE_SPLASH"
        case .memberVerificationGateEnabled: return "MEMBER_VERIFICATION_GATE_ENABLED"
        case .monetizationEnabled: return "MONETIZATION_ENABLED"
        case .moreStickers: return "MORE_STICKERS"
        case .news: return "NEWS"
        case .partnered: return "PARTNERED"
        case .previewEnabled: return "PREVIEW_ENABLED"
        case .raidAlertsDisabled: return "RAID_ALERTS_DISABLED"
        case .roleSubscriptionsEnabled: return "ROLE_SUBSCRIPTIONS_ENABLED"
        case .roleSubscriptionsPurchased: return "ROLE_SUBSCRIPTIONS_PURCHASED"
        case .ticketedEventsEnabled: return "TICKETED_EVENTS_ENABLED"
        case .vanityUrl: return "VANITY_URL"
        case .verified: return "VERIFIED"
        case .vipRegions: return "VIP_REGIONS"
        case .welcomeScreenEnabled: return "WELCOME_SCREEN_ENABLED"
        case .guestsEnabled: return "GUESTS_ENABLED"
        case .guildTags: return "GUILD_TAGS"
        case .enhancedRoleColors: return "ENHANCED_ROLE_COLORS"
        case .applicationCommandPermissionsV2: return "APPLICATION_COMMAND_PERMISSIONS_V2"
        case .autoModeration: return "AUTO_MODERATION"
        case .guildWebPageVanityUrl: return "GUILD_WEB_PAGE_VANITY_URL"
        case .creatorMonetizable: return "CREATOR_MONETIZABLE"
        case .creatorMonetizableDisclaimer: return "CREATOR_MONETIZABLE_DISCLAIMER"
        case .creatorStorePage: return "CREATOR_STORE_PAGE"
        case .roleSubscriptionsAvailableForPurchase: return "ROLE_SUBSCRIPTIONS_AVAILABLE_FOR_PURCHASE"
        case .onboardingEnabled: return "ONBOARDING_ENABLED"
        case .onboarding: return "ONBOARDING"
        case .soundboard: return "SOUNDBOARD"
        case .memberProfiles: return "MEMBER_PROFILES"
        case .roleSubscriptions: return "ROLE_SUBSCRIPTIONS"
        case .home: return "HOME"
        case .channelIconEmojisGenerated: return "CHANNEL_ICON_EMOJIS_GENERATED"
        case .`internal`: return "INTERNAL"
        case .unknown(let value): return value
        }
    }

    public init(rawValue: String) {
        self = Self.allKnown.first { $0.rawValue == rawValue } ?? .unknown(rawValue)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static let allKnown: [GuildFeature] = [
        .animatedIcon, .banner, .community, .discoveries, .featurable,
        .inviteSplash, .memberVerificationGateEnabled, .monetizationEnabled,
        .moreStickers, .news, .partnered, .previewEnabled, .raidAlertsDisabled,
        .roleSubscriptionsEnabled, .roleSubscriptionsPurchased, .ticketedEventsEnabled,
        .vanityUrl, .verified, .vipRegions, .welcomeScreenEnabled, .guestsEnabled,
        .guildTags, .enhancedRoleColors, .applicationCommandPermissionsV2,
        .autoModeration, .guildWebPageVanityUrl, .creatorMonetizable,
        .creatorMonetizableDisclaimer, .creatorStorePage,
        .roleSubscriptionsAvailableForPurchase, .onboardingEnabled, .onboarding,
        .soundboard, .memberProfiles, .roleSubscriptions, .home,
        .channelIconEmojisGenerated, .`internal`
    ]
}

/// Represents a Discord guild (server).
///
/// Guilds are the primary way users organize and communicate in Discord.
///
/// ## Field Availability
///
/// Fields such as `members`, `channels`, and `threads` are only populated
/// in the `GUILD_CREATE` gateway event; REST responses return `nil` for them.
///
/// ## Example
///
/// ```swift
/// await client.setOnReady { ready in
///     for guild in ready.guilds {
///         print("Guild: \(guild.name)")
///         print("Members: \(guild.member_count ?? 0)")
///         print("Boost level: \(guild.premium_tier ?? 0)")
///     }
/// }
/// ```
///
/// ## Related Topics
/// - ``DiscordClient/getCurrentUserGuilds(before:after:limit:)``
/// - ``GuildMember``
/// - ``Role``
public struct Guild: Codable, Hashable, Sendable {
    // MARK: - Core Identity
    /// The unique ID of the guild.
    public let id: GuildID
    
    /// The name of the guild (2-100 characters).
    public let name: String
    
    /// The icon hash of the guild.
    public let icon: String?
    
    /// The icon hash, returned when in the template object.
    public let icon_hash: String?
    
    /// The splash hash of the guild.
    public let splash: String?
    
    /// The discovery splash hash of the guild.
    public let discovery_splash: String?

    // MARK: - Ownership
    /// Whether the user is the owner of the guild.
    public let owner: Bool?
    
    /// The ID of the owner of the guild.
    public let owner_id: UserID?
    
    /// The total permissions for the user in the guild (excludes overwrites).
    public let permissions: String?

    // MARK: - AFK
    /// The ID of the AFK channel.
    public let afk_channel_id: ChannelID?
    
    /// The AFK timeout in seconds.
    public let afk_timeout: Int?

    // MARK: - Widget
    /// Whether the widget is enabled.
    public let widget_enabled: Bool?
    
    /// The channel ID for the widget.
    public let widget_channel_id: ChannelID?

    // MARK: - Moderation
    /// The verification level required for the guild (0-5).
    public let verification_level: Int?
    
    /// The default message notifications level (0-1).
    public let default_message_notifications: Int?
    
    /// The explicit content filter level (0-4).
    public let explicit_content_filter: Int?
    
    /// The MFA level required for the guild (0-1).
    public let mfa_level: Int?
    
    /// The NSFW level of the guild (0-3).
    public let nsfw_level: Int?

    // MARK: - Content
    /// The roles in the guild.
    public let roles: [Role]?
    
    /// The custom emojis in the guild.
    public let emojis: [Emoji]?
    
    /// The enabled guild features.
    public let features: [GuildFeature]?
    
    /// The custom guild stickers.
    public let stickers: [Sticker]?

    // MARK: - System Channels
    /// The ID of the application that created the guild (if applicable).
    public let application_id: ApplicationID?
    
    /// The ID of the channel where guild notices are sent.
    public let system_channel_id: ChannelID?
    
    /// The system channel flags.
    public let system_channel_flags: Int?
    
    /// The ID of the channel where community updates are posted.
    public let rules_channel_id: ChannelID?

    // MARK: - Size
    /// The maximum number of presences for the guild.
    public let max_presences: Int?
    
    /// The maximum number of members for the guild.
    public let max_members: Int?
    
    /// The number of members in the guild (approximate for large guilds).
    public let member_count: Int?
    
    /// Whether the guild is considered large.
    public let large: Bool?
    
    /// Whether the guild is unavailable due to an outage.
    public let unavailable: Bool?

    // MARK: - Branding
    /// The vanity URL code for the guild.
    public let vanity_url_code: String?
    
    /// The description of the guild (0-1000 characters).
    public let description: String?
    
    /// The banner hash of the guild.
    public let banner: String?

    // MARK: - Nitro / Boost
    /// The premium tier of the guild (0-3).
    public let premium_tier: Int?
    
    /// The number of boosts the guild has.
    public let premium_subscription_count: Int?
    
    /// Whether the premium progress bar is enabled.
    public let premium_progress_bar_enabled: Bool?

    // MARK: - Locale & Update Channels
    /// The preferred locale of the guild (ISO 639 code).
    public let preferred_locale: String?
    
    /// The ID of the channel where admins receive notices from Discord.
    public let public_updates_channel_id: ChannelID?
    
    /// The ID of the channel where safety alerts are sent.
    public let safety_alerts_channel_id: ChannelID?

    // MARK: - Capacity
    /// The maximum number of users in a video channel.
    public let max_video_channel_users: Int?
    
    /// The maximum number of users in a stage video channel.
    public let max_stage_video_channel_users: Int?
    
    /// The approximate number of members in the guild (from REST).
    public let approximate_member_count: Int?
    
    /// The approximate number of online members in the guild (from REST).
    public let approximate_presence_count: Int?

    // MARK: - Incidents
    /// Incidents data for the guild (raid alerts, etc.).
    public let incidents_data: IncidentsData?

    // MARK: - Welcome Screen
    /// The welcome screen of a Community guild.
    public let welcome_screen: WelcomeScreen?

    // MARK: - GUILD_CREATE-only fields
    /// ISO 8601 timestamp for when the bot joined (present only in GUILD_CREATE payloads).
    public let joined_at: String?
    
    /// Member list included by the gateway (not present in standard REST guild responses).
    public let members: [GuildMember]?
    
    /// Channel list included by the gateway (not present in standard REST guild responses).
    public let channels: [Channel]?
    
    /// Active threads included by the gateway (not present in standard REST guild responses).
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
        self.incidents_data = nil; self.welcome_screen = nil
    }
}

/// Incidents data for a guild (e.g. raid detection).
public struct IncidentsData: Codable, Hashable, Sendable {
    public let raids_disabled: Bool?
    public let raid_system_enabled: Bool?
    public let invites_disabled_until: String?
}

/// Welcome screen shown to new members of a Community guild.
public struct WelcomeScreen: Codable, Hashable, Sendable {
    public let description: String?
    public let welcome_channels: [WelcomeScreenChannel]?
}

/// A channel in the welcome screen.
public struct WelcomeScreenChannel: Codable, Hashable, Sendable {
    public let channel_id: ChannelID
    public let description: String
    public let emoji_id: EmojiID?
    public let emoji_name: String?
}
