import Foundation

public struct Invite: Codable, Hashable {
    public struct InviteGuild: Codable, Hashable { public let id: GuildID; public let name: String? }
    public struct InviteChannel: Codable, Hashable { public let id: ChannelID; public let name: String?; public let type: Int? }
    /// Partial role returned on community invite objects. Only contains id, name,
    /// position, color, colors, icon, and unicode_emoji per the 2026-02-05 breaking change.
    public struct PartialInviteRole: Codable, Hashable {
        public let id: RoleID
        public let name: String?
        public let position: Int?
        public let color: Int?
        public let colors: RoleColors?
        public let icon: String?
        public let unicode_emoji: String?
    }

    public let code: String
    public let guild: InviteGuild?
    public let channel: InviteChannel?
    public let inviter: User?
    public let uses: Int?
    public let max_uses: Int?
    public let max_age: Int?
    public let temporary: Bool?
    public let created_at: String?
    public let expires_at: String?
    /// Role IDs that will be assigned to users when they accept this community invite.
    /// Added 2026-01-13 per Discord API changelog.
    public let role_ids: [RoleID]?
    /// Partial role objects granted by this invite. As of 2026-02-05 this is a partial,
    /// no longer the full Role object.
    public let roles: [PartialInviteRole]?
    /// Target user type for restricted invites.
    public let target_type: Int?
}
