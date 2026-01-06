//
//  Cache.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public actor Cache {
    public struct Configuration {
        public var userTTL: TimeInterval?
        public var channelTTL: TimeInterval?
        public var guildTTL: TimeInterval?
        public var maxMessagesPerChannel: Int
        public init(userTTL: TimeInterval? = nil, channelTTL: TimeInterval? = nil, guildTTL: TimeInterval? = nil, maxMessagesPerChannel: Int = 50) {
            self.userTTL = userTTL; self.channelTTL = channelTTL; self.guildTTL = guildTTL; self.maxMessagesPerChannel = maxMessagesPerChannel
        }
    }

    public var configuration: Configuration

    private struct TimedValue<V> { let value: V; let storedAt: Date }

    private var usersTimed: [UserID: TimedValue<User>] = [:]
    private var channelsTimed: [ChannelID: TimedValue<Channel>] = [:]
    private var guildsTimed: [GuildID: TimedValue<Guild>] = [:]
    public private(set) var recentMessagesByChannel: [ChannelID: [Message]] = [:]

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    public func upsert(user: User) {
        usersTimed[user.id] = TimedValue(value: user, storedAt: Date())
    }

    public func upsert(channel: Channel) {
        channelsTimed[channel.id] = TimedValue(value: channel, storedAt: Date())
    }

    public func removeChannel(id: ChannelID) {
        channelsTimed.removeValue(forKey: id)
    }

    public func upsert(guild: Guild) {
        guildsTimed[guild.id] = TimedValue(value: guild, storedAt: Date())
    }

    public func add(message: Message) {
        var arr = recentMessagesByChannel[message.channel_id] ?? []
        arr.append(message)
        let cap = configuration.maxMessagesPerChannel
        if arr.count > cap { arr.removeFirst(arr.count - cap) }
        recentMessagesByChannel[message.channel_id] = arr
    }

    public func removeMessage(id: MessageID) {
        for (cid, arr) in recentMessagesByChannel {
            if let idx = arr.firstIndex(where: { $0.id == id }) {
                var newArr = arr
                newArr.remove(at: idx)
                recentMessagesByChannel[cid] = newArr
                break
            }
        }
    }

    public func getUser(id: UserID) -> User? { pruneIfNeeded(); return usersTimed[id]?.value }
    public func getChannel(id: ChannelID) -> Channel? { pruneIfNeeded(); return channelsTimed[id]?.value }
    public func getGuild(id: GuildID) -> Guild? { pruneIfNeeded(); return guildsTimed[id]?.value }

    public func pruneIfNeeded(now: Date = Date()) {
        if let ttl = configuration.userTTL {
            usersTimed = usersTimed.filter { now.timeIntervalSince($0.value.storedAt) < ttl }
        }
        if let ttl = configuration.channelTTL {
            channelsTimed = channelsTimed.filter { now.timeIntervalSince($0.value.storedAt) < ttl }
        }
        if let ttl = configuration.guildTTL {
            guildsTimed = guildsTimed.filter { now.timeIntervalSince($0.value.storedAt) < ttl }
        }
    }
}
