import Foundation

public struct Webhook: Codable, Hashable, Sendable {
    public let id: WebhookID
    public let type: Int
    public let channel_id: ChannelID?
    public let guild_id: GuildID?
    public let name: String?
    public let token: String?
    public let avatar: String?
    public let application_id: ApplicationID?
    public let source_guild: PartialGuild?
    public let source_channel: Invite.InviteChannel?
    public let url: String?
    public let user: User?
    public let creator_id: UserID?
    public let secret: String?
}
