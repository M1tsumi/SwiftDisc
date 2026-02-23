import Foundation

/// Represents the user's primary guild (guild tag) information.
/// Added 2025-07-02 per Discord API changelog (Guild Tags).
public struct UserPrimaryGuild: Codable, Hashable {
    /// The ID of the guild the user has set as their primary guild.
    public let guild_id: String?
    /// The badge / tag string displayed next to the user's display name (1–4 characters).
    public let tag: String?
    public let badge: String?
    public let identity_enabled: Bool?
    public let identity_guild_id: String?
}

public struct User: Codable, Hashable {
    public let id: UserID
    public let username: String
    public let discriminator: String?
    public let globalName: String?
    public let avatar: String?
    public let banner: String?
    public let accent_color: Int?
    public let flags: Int?
    public let public_flags: Int?
    /// The user's primary guild tag. Added 2025-07-02.
    public let primary_guild: UserPrimaryGuild?

    enum CodingKeys: String, CodingKey {
        case id, username, discriminator, avatar, banner
        case accent_color, flags, public_flags
        case primary_guild
        case globalName = "global_name"
    }
}
