import Foundation

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
}
