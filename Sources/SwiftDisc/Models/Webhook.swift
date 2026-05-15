import Foundation

/// Represents a Discord webhook.
///
/// Webhooks are a way to send messages to Discord channels without using a bot account.
/// They can be used for external services to post messages to Discord.
///
/// ## Example
///
/// ```swift
/// let webhook = try await client.getWebhook(webhookId: webhookId)
/// print("Webhook: \(webhook.name ?? "unknown")")
/// print("Channel: \(webhook.channel_id ?? "unknown")")
/// ```
public struct Webhook: Codable, Hashable, Sendable {
    /// The webhook ID.
    public let id: WebhookID
    
    /// The webhook type.
    public let type: Int
    
    /// The channel ID the webhook is for.
    public let channel_id: ChannelID?
    
    /// The guild ID the webhook is for.
    public let guild_id: GuildID?
    
    /// The webhook name.
    public let name: String?
    
    /// The webhook token.
    public let token: String?
    
    /// The webhook avatar hash.
    public let avatar: String?
    
    /// The application ID for the webhook.
    public let application_id: ApplicationID?
    
    /// The source guild for the webhook (for channel follower webhooks).
    public let source_guild: PartialGuild?
    
    /// The source channel for the webhook (for channel follower webhooks).
    public let source_channel: Invite.InviteChannel?
    
    /// The webhook URL.
    public let url: String?
    
    /// The user who created the webhook.
    public let user: User?
    
    /// The user ID who created the webhook.
    public let creator_id: UserID?
    
    /// The webhook secret.
    public let secret: String?
}
