import Foundation

public struct GuildWidgetSettings: Codable, Hashable, Sendable {
    public let enabled: Bool
    public let channel_id: ChannelID?
}
