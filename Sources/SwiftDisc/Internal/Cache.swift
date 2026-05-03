import Foundation

public actor Cache {
    public struct Configuration {
        public var userTTL: TimeInterval?
        public var channelTTL: TimeInterval?
        public var guildTTL: TimeInterval?
        public var roleTTL: TimeInterval?
        public var emojiTTL: TimeInterval?
        public var maxMessagesPerChannel: Int
        public init(userTTL: TimeInterval? = nil, channelTTL: TimeInterval? = nil, guildTTL: TimeInterval? = nil, roleTTL: TimeInterval? = nil, emojiTTL: TimeInterval? = nil, maxMessagesPerChannel: Int = 50) {
            self.userTTL = userTTL; self.channelTTL = channelTTL; self.guildTTL = guildTTL; self.roleTTL = roleTTL; self.emojiTTL = emojiTTL; self.maxMessagesPerChannel = maxMessagesPerChannel
        }
    }

    public var configuration: Configuration

    private struct TimedValue<V> { let value: V; let storedAt: Date }

    private var usersTimed: [UserID: TimedValue<User>] = [:]
    private var channelsTimed: [ChannelID: TimedValue<Channel>] = [:]
    private var guildsTimed: [GuildID: TimedValue<Guild>] = [:]
    private var rolesByGuild: [GuildID: [RoleID: TimedValue<Role>]] = [:]
    private var emojisByGuild: [GuildID: TimedValue<[Emoji]>] = [:]
    public private(set) var recentMessagesByChannel: [ChannelID: [Message]] = [:]

    /// Background task that prunes expired TTL entries every 60 seconds.
    /// Only started when at least one TTL is configured.
    private var evictionTask: Task<Void, Never>?

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        self.evictionTask = nil
        let hasTTL = configuration.userTTL != nil
            || configuration.channelTTL != nil
            || configuration.guildTTL != nil
            || configuration.roleTTL != nil
            || configuration.emojiTTL != nil
        if hasTTL {
            Task {
                await self.startEvictionTaskIfNeeded()
            }
        }
    }

    deinit { evictionTask?.cancel() }

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

    // MARK: - Roles

    /// Insert or update a role within a guild's role cache.
    public func upsert(role: Role, guildId: GuildID) {
        var dict = rolesByGuild[guildId] ?? [:]
        dict[role.id] = TimedValue(value: role, storedAt: Date())
        rolesByGuild[guildId] = dict
    }

    /// Remove a single role from the cache.
    public func removeRole(id: RoleID, guildId: GuildID) {
        rolesByGuild[guildId]?.removeValue(forKey: id)
    }

    /// Retrieve a single role.
    public func getRole(id: RoleID, guildId: GuildID) -> Role? {
        pruneIfNeeded()
        return rolesByGuild[guildId]?[id]?.value
    }

    /// Retrieve all cached roles for a guild.
    public func getRoles(guildId: GuildID) -> [Role] {
        pruneIfNeeded()
        return (rolesByGuild[guildId] ?? [:]).values.map(\.value)
    }

    // MARK: - Emojis

    /// Replace the emoji list for a guild.
    public func upsert(emojis: [Emoji], guildId: GuildID) {
        emojisByGuild[guildId] = TimedValue(value: emojis, storedAt: Date())
    }

    /// Retrieve all cached emojis for a guild.
    public func getEmojis(guildId: GuildID) -> [Emoji] {
        pruneIfNeeded()
        return emojisByGuild[guildId]?.value ?? []
    }

    /// Retrieve a single custom emoji by ID from a guild.
    public func getEmoji(id: EmojiID, guildId: GuildID) -> Emoji? {
        pruneIfNeeded()
        return emojisByGuild[guildId]?.value.first { $0.id == id }
    }

    public func add(message: Message) {
        var arr = recentMessagesByChannel[message.channel_id] ?? []
        arr.append(message)
        let cap = configuration.maxMessagesPerChannel
        if arr.count > cap { arr.removeFirst(arr.count - cap) }
        recentMessagesByChannel[message.channel_id] = arr
    }

    public func removeMessage(id: MessageID) {
        let snapshot = Array(recentMessagesByChannel)
        for (cid, arr) in snapshot {
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
        if let ttl = configuration.roleTTL {
            for guildId in rolesByGuild.keys {
                rolesByGuild[guildId] = rolesByGuild[guildId]?.filter { now.timeIntervalSince($0.value.storedAt) < ttl }
            }
        }
        if let ttl = configuration.emojiTTL {
            emojisByGuild = emojisByGuild.filter { now.timeIntervalSince($0.value.storedAt) < ttl }
        }
    }

    /// Cancels the background eviction task (e.g. during teardown).
    public func stopEviction() {
        evictionTask?.cancel()
        evictionTask = nil
    }

    // MARK: - Private

    private func startEvictionTaskIfNeeded() {
        guard evictionTask == nil else { return }
        evictionTask = Task {
            await self.evictionLoop()
        }
    }

    private func evictionLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            guard !Task.isCancelled else { break }
            pruneIfNeeded()
        }
    }
}
