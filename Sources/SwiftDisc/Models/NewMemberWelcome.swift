import Foundation

/// The new member welcome configuration for a guild.
public struct NewMemberWelcome: Codable, Hashable, Sendable {
    public let enabled: Bool
    public let welcome_message: String?
    public let welcome_channel_id: ChannelID?
}
