import Foundation

/// Gateway intents that control which events the bot receives from Discord.
///
/// Intents are a way to subscribe to specific events from Discord's gateway.
/// This helps reduce the amount of data your bot needs to process.
///
/// ## Privileged Intents
///
/// Some intents are "privileged" and must be enabled in the Discord Developer Portal:
/// - `guildMembers`
/// - `guildPresences`
/// - `messageContent`
///
/// ## Example
///
/// ```swift
/// // Basic bot with guild messages
/// try await client.loginAndConnect(intents: [
///     .guilds,
///     .guildMessages
/// ])
///
/// // Bot with message content (requires privileged intent)
/// try await client.loginAndConnect(intents: [
///     .guilds,
///     .guildMessages,
///     .messageContent
/// ])
///
/// // Bot with presence tracking (requires privileged intent)
/// try await client.loginAndConnect(intents: [
///     .guilds,
///     .guildPresences
/// ])
/// ```
///
/// ## Related Topics
/// - ``DiscordClient/loginAndConnect(intents:)``
/// - ``DiscordClient/loginAndConnectSharded(index:total:intents:)``
public struct GatewayIntents: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }

    /// Enables guild create/update/delete events.
    ///
    /// Required for your bot to know which guilds it's in.
    public static let guilds = GatewayIntents(rawValue: 1 << 0)
    
    /// Enables guild member update events (privileged).
    ///
    /// - **Privileged**: Must be enabled in the Discord Developer Portal.
    /// - Required for tracking member joins, leaves, and updates.
    public static let guildMembers = GatewayIntents(rawValue: 1 << 1)
    
    /// Enables guild moderation events.
    ///
    /// Includes ban, unban, and moderation events.
    public static let guildModeration = GatewayIntents(rawValue: 1 << 2)
    
    /// Enables guild emoji and sticker events.
    ///
    /// Required for tracking emoji and sticker updates.
    public static let guildEmojisAndStickers = GatewayIntents(rawValue: 1 << 3)
    
    /// Enables guild integration events.
    ///
    /// Required for tracking integration updates.
    public static let guildIntegrations = GatewayIntents(rawValue: 1 << 4)
    
    /// Enables guild webhook events.
    ///
    /// Required for tracking webhook updates.
    public static let guildWebhooks = GatewayIntents(rawValue: 1 << 5)
    
    /// Enables guild invite events.
    ///
    /// Required for tracking invite creates and deletes.
    public static let guildInvites = GatewayIntents(rawValue: 1 << 6)
    
    /// Enables guild presence events (privileged).
    ///
    /// - **Privileged**: Must be enabled in the Discord Developer Portal.
    /// - Required for tracking user status (online, idle, dnd, offline) and activities.
    public static let guildPresences = GatewayIntents(rawValue: 1 << 8)
    
    /// Enables guild message events.
    ///
    /// Required for receiving messages in guild channels.
    /// - **Note**: Without `messageContent`, you won't receive message content.
    public static let guildMessages = GatewayIntents(rawValue: 1 << 9)
    
    /// Enables guild message reaction events.
    ///
    /// Required for tracking reactions on guild messages.
    public static let guildMessageReactions = GatewayIntents(rawValue: 1 << 10)
    
    /// Enables guild message typing events.
    ///
    /// Required for tracking when users are typing in guild channels.
    public static let guildMessageTyping = GatewayIntents(rawValue: 1 << 11)
    
    /// Enables direct message events.
    ///
    /// Required for receiving DMs sent to the bot.
    public static let directMessages = GatewayIntents(rawValue: 1 << 12)
    
    /// Enables direct message reaction events.
    ///
    /// Required for tracking reactions on DMs.
    public static let directMessageReactions = GatewayIntents(rawValue: 1 << 13)
    
    /// Enables direct message typing events.
    ///
    /// Required for tracking when users are typing in DMs.
    public static let directMessageTyping = GatewayIntents(rawValue: 1 << 14)
    
    /// Enables message content intent (privileged).
    ///
    /// - **Privileged**: Must be enabled in the Discord Developer Portal.
    /// - Required for receiving the actual content of messages.
    /// - Without this, message content will be empty for most events.
    /// - **Important**: Bots with 100+ servers must justify this intent.
    public static let messageContent = GatewayIntents(rawValue: 1 << 15)
    
    /// Enables guild scheduled event events.
    ///
    /// Required for tracking scheduled events.
    public static let guildScheduledEvents = GatewayIntents(rawValue: 1 << 16)
    
    /// Enables auto moderation configuration events.
    ///
    /// Required for tracking auto moderation rule updates.
    public static let autoModerationConfiguration = GatewayIntents(rawValue: 1 << 20)
    
    /// Enables auto moderation execution events.
    ///
    /// Required for tracking when auto moderation actions are executed.
    public static let autoModerationExecution = GatewayIntents(rawValue: 1 << 21)
}
