import Foundation

public actor Cache {
    public private(set) var users: [Snowflake: User] = [:]
    public private(set) var channels: [Snowflake: Channel] = [:]
    public private(set) var guilds: [Snowflake: Guild] = [:]

    public init() {}

    public func upsert(user: User) {
        users[user.id] = user
    }

    public func upsert(channel: Channel) {
        channels[channel.id] = channel
    }

    public func removeChannel(id: Snowflake) {
        channels.removeValue(forKey: id)
    }

    public func upsert(guild: Guild) {
        guilds[guild.id] = guild
    }
}
