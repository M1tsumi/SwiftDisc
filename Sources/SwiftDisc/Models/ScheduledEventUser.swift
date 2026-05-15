import Foundation

/// A user subscribed to a guild scheduled event.
public struct GuildScheduledEventUser: Codable, Hashable, Sendable {
    public let guild_scheduled_event_id: GuildScheduledEventID
    public let user: User
    public let member: GuildMember?
}
