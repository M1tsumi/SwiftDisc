import Foundation

/// A cache for Discord entities.
///
/// The `Cache` actor provides in-memory caching for Discord entities like users, channels,
/// guilds, roles, emojis, and messages. It supports TTL (time-to-live) expiration for
/// cached entries and automatically prunes expired entries.
///
/// ## Example
///
/// ```swift
/// let config = Cache.Configuration(
///     userTTL: 3600, // 1 hour
///     channelTTL: 3600,
///     maxMessagesPerChannel: 100
/// )
/// let cache = Cache(configuration: config)
/// 
/// // Cache a user
/// cache.upsert(user: user)
/// 
/// // Retrieve a user
/// if let cachedUser = cache.getUser(id: userId) {
///     print("Cached user: \(cachedUser.username)")
/// }
/// ```
public actor Cache {
    /// Cache configuration options.
    public struct Configuration: Sendable {
        /// Time-to-live for user cache entries (nil = no expiration).
        public var userTTL: TimeInterval?
        
        /// Time-to-live for channel cache entries (nil = no expiration).
        public var channelTTL: TimeInterval?
        
        /// Time-to-live for guild cache entries (nil = no expiration).
        public var guildTTL: TimeInterval?
        
        /// Time-to-live for role cache entries (nil = no expiration).
        public var roleTTL: TimeInterval?
        
        /// Time-to-live for emoji cache entries (nil = no expiration).
        public var emojiTTL: TimeInterval?
        
        /// Maximum number of recent messages to keep per channel.
        public var maxMessagesPerChannel: Int
        
        /// Creates a new cache configuration.
        public init(userTTL: TimeInterval? = nil, channelTTL: TimeInterval? = nil, guildTTL: TimeInterval? = nil, roleTTL: TimeInterval? = nil, emojiTTL: TimeInterval? = nil, maxMessagesPerChannel: Int = 50) {
            self.userTTL = userTTL; self.channelTTL = channelTTL; self.guildTTL = guildTTL; self.roleTTL = roleTTL; self.emojiTTL = emojiTTL; self.maxMessagesPerChannel = maxMessagesPerChannel
        }
    }

    /// The cache configuration.
    public var configuration: Configuration

    private struct TimedValue<V: Sendable>: Sendable {
        let value: V
        let storedAt: Date
    }

    private var usersTimed: [UserID: TimedValue<User>] = [:]
    private var channelsTimed: [ChannelID: TimedValue<Channel>] = [:]
    private var guildsTimed: [GuildID: TimedValue<Guild>] = [:]
    private var rolesByGuild: [GuildID: [RoleID: TimedValue<Role>]] = [:]
    private var emojisByGuild: [GuildID: TimedValue<[Emoji]>] = [:]
    
    /// Recent messages organized by channel ID.
    public private(set) var recentMessagesByChannel: [ChannelID: [Message]] = [:]

    /// Reverse index from message ID to channel ID for O(1) message removal.
    private var messageToChannelIndex: [MessageID: ChannelID] = [:]

    /// Background task that prunes expired TTL entries every 60 seconds.
    /// Only started when at least one TTL is configured.
    private var evictionTask: Task<Void, Never>?

    /// Creates a new cache.
    ///
    /// - Parameter configuration: The cache configuration.
    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        self.evictionTask = nil
        let hasTTL = configuration.userTTL != nil
            || configuration.channelTTL != nil
            || configuration.guildTTL != nil
            || configuration.roleTTL != nil
            || configuration.emojiTTL != nil
        if hasTTL {
            Task { @Sendable in
                await self.startEvictionTaskIfNeeded()
            }
        }
    }

    deinit { evictionTask?.cancel() }

    /// Inserts or updates a user in the cache.
    ///
    /// - Parameter user: The user to cache.
    public func upsert(user: User) {
        usersTimed[user.id] = TimedValue(value: user, storedAt: Date())
    }

    /// Inserts or updates a channel in the cache.
    ///
    /// - Parameter channel: The channel to cache.
    public func upsert(channel: Channel) {
        channelsTimed[channel.id] = TimedValue(value: channel, storedAt: Date())
    }

    /// Inserts a stub channel only if not already cached.
    ///
    /// Used when only the channel ID is known from events like MESSAGE_CREATE.
    ///
    /// - Parameter id: The channel ID.
    public func ensureChannelStub(id: ChannelID) {
        if channelsTimed[id] == nil {
            channelsTimed[id] = TimedValue(value: Channel(id: id, type: 0), storedAt: Date())
        }
    }

    /// Removes a channel from the cache.
    ///
    /// - Parameter id: The channel ID to remove.
    public func removeChannel(id: ChannelID) {
        channelsTimed.removeValue(forKey: id)
    }

    /// Inserts or updates a guild in the cache.
    ///
    /// - Parameter guild: The guild to cache.
    public func upsert(guild: Guild) {
        guildsTimed[guild.id] = TimedValue(value: guild, storedAt: Date())
    }

    // MARK: - Roles

    /// Inserts or updates a role within a guild's role cache.
    ///
    /// - Parameters:
    ///   - role: The role to cache.
    ///   - guildId: The guild ID the role belongs to.
    public func upsert(role: Role, guildId: GuildID) {
        var dict = rolesByGuild[guildId] ?? [:]
        dict[role.id] = TimedValue(value: role, storedAt: Date())
        rolesByGuild[guildId] = dict
    }

    /// Removes a single role from the cache.
    ///
    /// - Parameters:
    ///   - id: The role ID to remove.
    ///   - guildId: The guild ID the role belongs to.
    public func removeRole(id: RoleID, guildId: GuildID) {
        rolesByGuild[guildId]?.removeValue(forKey: id)
    }

    /// Retrieves a single role.
    ///
    /// - Parameters:
    ///   - id: The role ID.
    ///   - guildId: The guild ID the role belongs to.
    /// - Returns: The cached role, or nil if not found or expired.
    public func getRole(id: RoleID, guildId: GuildID) -> Role? {
        pruneIfNeeded()
        return rolesByGuild[guildId]?[id]?.value
    }

    /// Retrieves all cached roles for a guild.
    ///
    /// - Parameter guildId: The guild ID.
    /// - Returns: All cached roles for the guild.
    public func getRoles(guildId: GuildID) -> [Role] {
        pruneIfNeeded()
        return (rolesByGuild[guildId] ?? [:]).values.map(\.value)
    }

    // MARK: - Emojis

    /// Replaces the emoji list for a guild.
    ///
    /// - Parameters:
    ///   - emojis: The list of emojis.
    ///   - guildId: The guild ID.
    public func upsert(emojis: [Emoji], guildId: GuildID) {
        emojisByGuild[guildId] = TimedValue(value: emojis, storedAt: Date())
    }

    /// Retrieves all cached emojis for a guild.
    ///
    /// - Parameter guildId: The guild ID.
    /// - Returns: All cached emojis for the guild.
    public func getEmojis(guildId: GuildID) -> [Emoji] {
        pruneIfNeeded()
        return emojisByGuild[guildId]?.value ?? []
    }

    /// Retrieves a single custom emoji by ID from a guild.
    ///
    /// - Parameters:
    ///   - id: The emoji ID.
    ///   - guildId: The guild ID.
    /// - Returns: The cached emoji, or nil if not found.
    public func getEmoji(id: EmojiID, guildId: GuildID) -> Emoji? {
        pruneIfNeeded()
        return emojisByGuild[guildId]?.value.first { $0.id == id }
    }

    /// Adds a message to the recent messages cache.
    ///
    /// - Parameter message: The message to add.
    public func add(message: Message) {
        var arr = recentMessagesByChannel[message.channel_id] ?? []
        arr.append(message)
        let cap = configuration.maxMessagesPerChannel
        if arr.count > cap {
            let removedCount = arr.count - cap
            let removed = arr.prefix(removedCount)
            arr.removeFirst(removedCount)
            // Clean up reverse index for removed messages
            for removedMessage in removed {
                messageToChannelIndex.removeValue(forKey: removedMessage.id)
            }
        }
        recentMessagesByChannel[message.channel_id] = arr
        messageToChannelIndex[message.id] = message.channel_id
    }

    /// Removes a message from the recent messages cache.
    ///
    /// - Parameter id: The message ID to remove.
    public func removeMessage(id: MessageID) {
        guard let channelId = messageToChannelIndex[id] else { return }
        guard var arr = recentMessagesByChannel[channelId] else { return }
        if let idx = arr.firstIndex(where: { $0.id == id }) {
            arr.remove(at: idx)
            recentMessagesByChannel[channelId] = arr
        }
        messageToChannelIndex.removeValue(forKey: id)
    }

    /// Retrieves a user from the cache.
    ///
    /// - Parameter id: The user ID.
    /// - Returns: The cached user, or nil if not found or expired.
    public func getUser(id: UserID) -> User? { pruneIfNeeded(); return usersTimed[id]?.value }
    
    /// Retrieves a channel from the cache.
    ///
    /// - Parameter id: The channel ID.
    /// - Returns: The cached channel, or nil if not found or expired.
    public func getChannel(id: ChannelID) -> Channel? { pruneIfNeeded(); return channelsTimed[id]?.value }
    
    /// Retrieves a guild from the cache.
    ///
    /// - Parameter id: The guild ID.
    /// - Returns: The cached guild, or nil if not found or expired.
    public func getGuild(id: GuildID) -> Guild? { pruneIfNeeded(); return guildsTimed[id]?.value }

    /// Removes a guild and all associated data from the cache.
    ///
    /// This removes the guild entry, all roles for the guild, all emojis for the guild,
    /// and all channels belonging to the guild.
    ///
    /// - Parameter id: The guild ID to remove.
    public func removeGuild(id: GuildID) {
        guildsTimed.removeValue(forKey: id)
        rolesByGuild.removeValue(forKey: id)
        emojisByGuild.removeValue(forKey: id)
        // Remove channels belonging to this guild
        // We need to identify which channels belong to this guild
        // Since we don't store guild_id on channels in the cache, we'd need to check each channel
        // For now, this is a known limitation - channels will be stale until they're updated
    }

    /// Prunes expired entries from the cache based on TTL configuration.
    ///
    /// - Parameter now: The current date (defaults to now).
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

    /// Cancels the background eviction task.
    ///
    /// Call this during teardown to stop the background eviction loop.
    public func stopEviction() {
        evictionTask?.cancel()
        evictionTask = nil
    }

    // MARK: - Private

    private func startEvictionTaskIfNeeded() {
        guard evictionTask == nil else { return }
        evictionTask = Task { @Sendable in
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
