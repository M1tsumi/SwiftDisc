import Foundation

/// Represents the user's primary guild (guild tag) information.
///
/// Guild tags allow users to display a badge next to their name.
/// Added 2025-07-02 per Discord API changelog (Guild Tags).
///
/// ## Example
///
/// ```swift
/// if let primaryGuild = user.primary_guild {
///     print("Primary guild ID: \(primaryGuild.guild_id ?? "")")
///     print("Tag: \(primaryGuild.tag ?? "")")
/// }
/// ```
public struct UserPrimaryGuild: Codable, Hashable, Sendable {
    /// The ID of the guild the user has set as their primary guild.
    public let guild_id: String?
    
    /// The badge/tag string displayed next to the user's display name (1-4 characters).
    public let tag: String?
    
    /// The badge string.
    public let badge: String?
    
    /// Whether the identity is enabled.
    public let identity_enabled: Bool?
    
    /// The ID of the identity guild.
    public let identity_guild_id: String?
}

/// Represents a Discord user.
///
/// Users are the fundamental entities in Discord, representing both human users and bots.
///
/// ## Example
///
/// ```swift
/// await client.setOnMessage { message in
///     let user = message.author
///     print("Username: \(user.username)")
///     if let globalName = user.globalName {
    ///         print("Global name: \(globalName)")
///     }
///     if user.bot {
///         print("This is a bot")
///     }
/// }
/// ```
///
/// ## Related Topics
/// - ``DiscordClient/getUser(userId:)``
/// - ``DiscordClient/getCurrentUser()``
/// - ``GuildMember``
public struct User: Codable, Hashable, Sendable {
    /// The unique ID of the user.
    public let id: UserID
    
    /// The username of the user (2-32 characters).
    public let username: String
    
    /// The user's discriminator (deprecated, now usually "0000").
    public let discriminator: String?
    
    /// The user's global display name (may be null).
    public let globalName: String?
    
    /// The avatar hash of the user.
    public let avatar: String?
    
    /// The banner hash of the user.
    public let banner: String?
    
    /// The user's banner color as an integer (hex color code).
    public let accent_color: Int?
    
    /// The user's flags as a bitfield.
    public let flags: Int?
    
    /// The user's public flags as a bitfield.
    public let public_flags: Int?
    
    /// The user's primary guild tag (added 2025-07-02).
    public let primary_guild: UserPrimaryGuild?
    
    /// The user's premium type (Nitro subscription level).
    public let premium_type: Int?
    
    /// Avatar decoration data.
    public let avatar_decoration_data: AvatarDecorationData?
    
    /// Collectibles data.
    public let collectibles: Collectibles?
    
    /// The user's chosen language locale (ISO 639 code).
    public let locale: String?
    
    /// The user's email (only available for the current user).
    public let email: String?
    
    /// Whether the user's email is verified.
    public let verified: Bool?
    
    /// Whether the user has MFA (multi-factor authentication) enabled.
    public let mfa_enabled: Bool?
    
    /// Whether the user is a bot.
    public let bot: Bool?
    
    /// Whether the user is an official Discord system user (e.g., Clyde).

    public let system: Bool?

    public init(
        id: UserID,
        username: String,
        discriminator: String? = nil,
        globalName: String? = nil,
        avatar: String? = nil,
        banner: String? = nil,
        accent_color: Int? = nil,
        flags: Int? = nil,
        public_flags: Int? = nil,
        premium_type: Int? = nil,
        avatar_decoration_data: AvatarDecorationData? = nil,
        collectibles: Collectibles? = nil,
        locale: String? = nil,
        email: String? = nil,
        verified: Bool? = nil,
        mfa_enabled: Bool? = nil,
        bot: Bool? = nil,
        system: Bool? = nil,
        primary_guild: UserPrimaryGuild? = nil
    ) {
        self.id = id
        self.username = username
        self.discriminator = discriminator
        self.globalName = globalName
        self.avatar = avatar
        self.banner = banner
        self.accent_color = accent_color
        self.flags = flags
        self.public_flags = public_flags
        self.premium_type = premium_type
        self.avatar_decoration_data = avatar_decoration_data
        self.collectibles = collectibles
        self.locale = locale
        self.email = email
        self.verified = verified
        self.mfa_enabled = mfa_enabled
        self.bot = bot
        self.system = system
        self.primary_guild = primary_guild
    }

    enum CodingKeys: String, CodingKey {
        case id, username, discriminator, avatar, banner
        case accent_color, flags, public_flags
        case premium_type, avatar_decoration_data, collectibles
        case primary_guild, locale, email, verified
        case mfa_enabled, bot, system
        case globalName = "global_name"
    }
}

/// Avatar decoration data for a user or member.
public struct AvatarDecorationData: Codable, Hashable, Sendable {
    public let asset: String
    public let sku_id: Snowflake<SKU>?
}

/// Collectibles data for a user or member.
public struct Collectibles: Codable, Hashable, Sendable {
    public let collectibles: [Collectible]?
}

/// A single collectible item.
public struct Collectible: Codable, Hashable, Sendable {
    public let id: String
    public let sku_id: SKUID
    public let name: String
    public let type: Int
}
