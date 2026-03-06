import Foundation

public struct Webhook: Codable, Hashable, Sendable {
    public let id: WebhookID
    public let type: Int
    public let channel_id: ChannelID?
    public let guild_id: GuildID?
    public let name: String?
    public let token: String?
}
