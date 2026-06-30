import Foundation

/// Guild member flags combined as a bitfield.
public struct GuildMemberFlags: OptionSet, Codable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let didRejoin = GuildMemberFlags(rawValue: 1 << 0)
    public static let completedOnboarding = GuildMemberFlags(rawValue: 1 << 1)
    public static let bypassesVerification = GuildMemberFlags(rawValue: 1 << 2)
    public static let startedOnboarding = GuildMemberFlags(rawValue: 1 << 3)
    public static let automodQuarantinedGuildTag = GuildMemberFlags(rawValue: 1 << 4)
}

/// Represents a Discord guild member.
///
/// Guild members represent a user's membership in a specific guild (server),
/// including their nickname, roles, and voice state.
///
/// ## Example
///
/// ```swift
/// if let guild = client.cache.getGuild(id: guildId),
///    let members = guild.members {
///     for member in members {
///         if let user = member.user {
///             print("User: \(user.username)")
///         }
///         if let nick = member.nick {
///             print("Nickname: \(nick)")
///         }
///         print("Roles: \(member.roles)")
///     }
/// }
/// ```
public struct GuildMember: Codable, Hashable, Sendable {
    /// The user this member belongs to.
    public let user: User?
    
    /// The member's nickname.
    public let nick: String?
    
    /// The member's guild avatar hash.
    public let avatar: String?
    
    /// The member's role IDs.
    public let roles: [RoleID]
    
    /// When the member joined the guild (ISO 8601 timestamp).
    public let joined_at: String?
    
    /// Whether the member is deafened in voice channels.
    public let deaf: Bool?
    
    /// Whether the member is muted in voice channels.
    public let mute: Bool?
    
    /// Effective permissions bitfield (decimal string) included by Discord in
    /// interaction payloads and some gateway member events.
    public let permissions: String?
    
    /// The member's guild banner hash.
    public let banner: String?
    
    /// Avatar decoration data for the member's guild avatar.
    public let avatar_decoration_data: AvatarDecorationData?
    
    /// Collectibles data for the member.
    public let collectibles: Collectibles?
    
    /// Guild member flags as a bit set.
    public let flags: GuildMemberFlags?
    
    /// When the member's timeout expires (ISO 8601 timestamp).
    public let communication_disabled_until: String?
    
    /// Whether the member has not yet passed Membership Screening.
    public let pending: Bool?
}
