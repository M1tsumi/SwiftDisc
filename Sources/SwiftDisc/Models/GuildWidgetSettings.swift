import Foundation

/// Settings for a guild's widget (public invite embed).
public struct GuildWidgetSettings: Codable, Hashable, Sendable {
    public let enabled: Bool
    public let channel_id: ChannelID?
}
