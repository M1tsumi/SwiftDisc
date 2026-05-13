import Foundation

/// Represents a Discord invite.
///
/// Invites are used to invite users to join a guild or group DM.
///
/// ## Example
///
/// ```swift
/// let invite = try await client.getInvite(code: inviteCode)
/// print("Guild: \(invite.guild?.name ?? "unknown")")
/// print("Channel: \(invite.channel?.name ?? "unknown")")
/// ```
public struct Invite: Codable, Hashable, Sendable {
    /// Partial guild information in an invite.
    public struct InviteGuild: Codable, Hashable, Sendable {
        /// The guild ID.
        public let id: GuildID
        
        /// The guild name.
        public let name: String?
    }
    
    /// Partial channel information in an invite.
    public struct InviteChannel: Codable, Hashable, Sendable {
        /// The channel ID.
        public let id: ChannelID
        
        /// The channel name.
        public let name: String?
        
        /// The channel type.
        public let type: Int?
    }
    
    /// Partial role returned on community invite objects.
    ///
    /// Only contains id, name, position, color, colors, icon, and unicode_emoji
    /// per the 2026-02-05 breaking change.
    public struct PartialInviteRole: Codable, Hashable, Sendable {
        /// The role ID.
        public let id: RoleID
        
        /// The role name.
        public let name: String?
        
        /// The role position.
        public let position: Int?
        
        /// The role color.
        public let color: Int?
        
        /// The role gradient colors.
        public let colors: RoleColors?
        
        /// The role icon hash.
        public let icon: String?
        
        /// The role unicode emoji.
        public let unicode_emoji: String?
    }

    /// The invite code.
    public let code: String
    
    /// The guild this invite is for.
    public let guild: InviteGuild?
    
    /// The channel this invite is for.
    public let channel: InviteChannel?
    
    /// The user who created the invite.
    public let inviter: User?
    
    /// The number of times this invite has been used.
    public let uses: Int?
    
    /// The maximum number of times this invite can be used.
    public let max_uses: Int?
    
    /// The maximum age of the invite in seconds.
    public let max_age: Int?
    
    /// Whether this invite grants temporary membership.
    public let temporary: Bool?
    
    /// When the invite was created (ISO 8601 timestamp).
    public let created_at: String?
    
    /// When the invite expires (ISO 8601 timestamp).
    public let expires_at: String?
    
    /// Role IDs that will be assigned to users when they accept this community invite.
    /// Added 2026-01-13 per Discord API changelog.
    public let role_ids: [RoleID]?
    
    /// Partial role objects granted by this invite.
    ///
    /// As of 2026-02-05 this is a partial, no longer the full Role object.
    public let roles: [PartialInviteRole]?
    
    /// Target user type for restricted invites.
    public let target_type: Int?
}
