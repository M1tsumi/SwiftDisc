import Foundation

/// A Discord event with shard metadata.
///
/// Produced by the `ShardingGatewayManager`, this struct wraps a `DiscordEvent`
/// with information about which shard produced it and the shard's latency.
public struct ShardedEvent: Sendable {
    /// The shard ID that produced this event.
    public let shardId: Int
    
    /// The Discord event.
    public let event: DiscordEvent
    
    /// When this event was received.
    public let receivedAt: Date
    
    /// The shard's heartbeat latency at the time of this event.
    public let shardLatency: TimeInterval?
}

/// Manages Discord gateway sharding for large bots.
///
/// Discord requires bots with many guilds to use sharding to distribute
/// the load across multiple gateway connections. This actor manages shard
/// lifecycle, connection strategies, and provides a unified event stream.
///
/// ## Example
///
/// ```swift
/// let config = ShardingGatewayManager.Configuration(
///     shardCount: .automatic,
///     identifyConcurrency: .respectDiscordLimits
/// )
/// let manager = ShardingGatewayManager(
///     token: token,
///     configuration: config,
///     intents: intents
/// )
/// try await manager.connect()
/// for await event in manager.events {
///     print("Shard \(event.shardId): \(event.event)")
/// }
/// ```
public actor ShardingGatewayManager {
    /// Configuration for the sharding manager.
    public struct Configuration: Sendable {
        /// Strategy for determining the number of shards.
        public enum ShardCountStrategy: Sendable {
            /// Let Discord determine the shard count automatically.
            case automatic
            
            /// Use an exact number of shards.
            case exact(Int)
        }
        
        /// Presence configuration for shards.
        public struct PresenceConfig: Sendable {
            /// Activities to display.
            public let activities: [PresenceUpdatePayload.Activity]
            
            /// Status string (e.g., "online", "idle", "dnd").
            public let status: String
            
            /// Whether the user is AFK.
            public let afk: Bool
            
            /// Unix timestamp for when the user went AFK.
            public let since: Int?
            
            public init(activities: [PresenceUpdatePayload.Activity], status: String, afk: Bool, since: Int? = nil) {
                self.activities = activities
                self.status = status
                self.afk = afk
                self.since = since
            }
        }
        
        /// Connection delay strategy.
        public enum ConnectionDelay: Sendable {
            /// Connect shards in parallel batches respecting rate limits.
            case none
            
            /// Connect shards one at a time with a delay between each.
            case staggered(interval: TimeInterval)
        }
        
        /// The shard count strategy.
        public let shardCount: ShardCountStrategy
        
        /// The identify concurrency strategy.
        public let identifyConcurrency: IdentifyConcurrency
        
        /// Optional function to customize intents per shard.
        public let makeIntents: (@Sendable (Int, Int) -> GatewayIntents)?
        
        /// Optional function to customize presence per shard.
        public let makePresence: (@Sendable (Int, Int) -> PresenceConfig)?
        
        /// Fallback presence for all shards.
        public let fallbackPresence: PresenceConfig?
        
        /// Connection delay strategy.
        public let connectionDelay: ConnectionDelay
        
        public init(
            shardCount: ShardCountStrategy = .automatic,
            identifyConcurrency: IdentifyConcurrency = .respectDiscordLimits,
            makeIntents: (@Sendable (Int, Int) -> GatewayIntents)? = nil,
            makePresence: (@Sendable (Int, Int) -> PresenceConfig)? = nil,
            fallbackPresence: PresenceConfig? = nil,
            connectionDelay: ConnectionDelay = .none
        ) {
            self.shardCount = shardCount
            self.identifyConcurrency = identifyConcurrency
            self.makeIntents = makeIntents
            self.makePresence = makePresence
            self.fallbackPresence = fallbackPresence
            self.connectionDelay = connectionDelay
        }
    }

    /// Identify concurrency strategy.
    public enum IdentifyConcurrency: Sendable { 
        /// Respect Discord's rate limits for identifying shards.
        case respectDiscordLimits 
    }

    /// Snapshot of a shard's current status.
    public struct ShardStatusSnapshot: Sendable {
        /// The shard ID.
        public let shardId: Int
        
        /// The shard's current status string.
        public let status: String
        
        /// Heartbeat latency in milliseconds.
        public let heartbeatLatencyMs: Int?
        
        /// The shard's session ID.
        public let sessionId: String?
        
        /// The last sequence number received.
        public let lastSequence: Int?
        
        /// Total number of resume attempts.
        public let resumeCount: Int
        
        /// Number of successful resumes.
        public let resumeSuccessCount: Int
        
        /// Number of failed resumes.
        public let resumeFailureCount: Int
        
        /// When the last resume attempt occurred.
        public let lastResumeAttemptAt: Date?
        
        /// When the last successful resume occurred.
        public let lastResumeSuccessAt: Date?
    }
    
    /// Overall health status of the sharding system.
    public struct ShardingHealth: Sendable {
        /// Total number of shards.
        public let totalShards: Int
        
        /// Number of ready shards.
        public let readyShards: Int
        
        /// Number of connecting shards.
        public let connectingShards: Int
        
        /// Number of reconnecting shards.
        public let reconnectingShards: Int
        
        /// Average latency across all shards.
        public let averageLatency: TimeInterval?
        
        /// Total guilds across all shards.
        public let totalGuilds: Int
    }

    private let token: RedactedToken
    private let shardingConfiguration: Configuration
    private let httpConfiguration: DiscordConfiguration
    private let fallbackIntents: GatewayIntents

    private struct GatewayBotCache: Sendable {
        var info: GatewayBotInfo
        var gatewayUrl: String
        var fetchedAt: Date
        var urlExpiresAt: Date
        var sessionExpiresAt: Date
    }
    private var cachedGatewayBot: GatewayBotCache?

    private struct GatewayBotInfo: Decodable, Sendable {
        struct SessionStartLimit: Decodable, Sendable {
            let total: Int
            let remaining: Int
            let reset_after: Int
            let max_concurrency: Int
        }
        let url: String
        let shards: Int
        let session_start_limit: SessionStartLimit
    }

    /// Creates a new sharding gateway manager.
    ///
    /// - Parameters:
    ///   - token: The bot token.
    ///   - configuration: The sharding configuration.
    ///   - intents: The gateway intents to use.
    ///   - httpConfiguration: The HTTP configuration.
    public init(token: String, configuration: Configuration = .init(), intents: GatewayIntents, httpConfiguration: DiscordConfiguration = .init()) {
        self.token = RedactedToken(token)
        self.shardingConfiguration = configuration
        self.httpConfiguration = httpConfiguration
        self.fallbackIntents = intents
    }

    // Unified event stream
    private var eventStream: AsyncStream<ShardedEvent>!
    private nonisolated(unsafe) var eventContinuation: AsyncStream<ShardedEvent>.Continuation!
    
    /// The unified event stream for all shards.
    public var events: AsyncStream<ShardedEvent> { eventStream }

    // Logging
    private enum LogLevel: String, Sendable { case info = "INFO", warning = "WARN", error = "ERROR", debug = "DEBUG" }
    private func log(_ level: LogLevel, _ message: @autoclosure () -> String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        print("[SwiftDisc][\(level.rawValue)] \(ts) - \(message())")
    }

    // Per-shard
    
    /// A handle for interacting with a specific shard.
    public struct ShardHandle: Sendable {
        /// The shard ID.
        public let id: Int
        
        fileprivate let client: GatewayClient
        
        /// Returns the shard's current heartbeat latency.
        public func heartbeatLatency() async -> TimeInterval? { await client.heartbeatLatency() }
        
        /// Returns the shard's current status as a string.
        public func status() async -> String {
            switch await client.currentStatus() {
            case .disconnected: return "disconnected"
            case .connecting: return "connecting"
            case .identifying: return "identifying"
            case .ready: return "ready"
            case .resuming: return "resuming"
            case .reconnecting: return "reconnecting"
            }
        }
    }
    
    private var shardHandles: [ShardHandle] = []
    private var maxIdentifyConcurrency: Int = 1
    private var guildsByShard: [Int: Set<String>] = [:]
    private var isShuttingDown: Bool = false

    private func setShuttingDown() {
        isShuttingDown = true
    }

    /// Returns all shard handles.
    public func shards() async -> [ShardHandle] { shardHandles }
    
    /// Returns the shard handle for a specific shard ID.
    public func shard(id: Int) async -> ShardHandle? { shardHandles.first { $0.id == id } }

    /// Returns a status snapshot for a specific shard.
    public func shardHealth(id: Int) async -> ShardStatusSnapshot? {
        guard let handle = await shard(id: id) else { return nil }
        let status = await handle.status()
        let latency = await handle.heartbeatLatency()
        let ms = latency.map { Int($0 * 1000) }
        let sess = await handle.client.currentSessionId()
        let seq = await handle.client.currentSeq()
        let rc = await handle.client.currentResumeCount()
        let rsc = await handle.client.getResumeSuccessCount()
        let rfc = await handle.client.getResumeFailureCount()
        let rla = await handle.client.getLastResumeAttemptAt()
        let rls = await handle.client.getLastResumeSuccessAt()
        return .init(shardId: id, status: status, heartbeatLatencyMs: ms, sessionId: sess, lastSequence: seq, resumeCount: rc, resumeSuccessCount: rsc, resumeFailureCount: rfc, lastResumeAttemptAt: rla, lastResumeSuccessAt: rls)
    }

    /// Returns the overall health status of the sharding system.
    public func healthCheck() async -> ShardingHealth {
        let total = shardHandles.count
        var ready = 0, connecting = 0, reconnecting = 0
        var latencies: [TimeInterval] = []
        let snapshots = await withTaskGroup(of: (String, TimeInterval?).self, returning: [(String, TimeInterval?)].self) { group in
            for h in shardHandles {
                group.addTask {
                    let st = await h.status()
                    let l = await h.heartbeatLatency()
                    return (st, l)
                }
            }
            var result: [(String, TimeInterval?)] = []
            for await s in group { result.append(s) }
            return result
        }
        for (st, l) in snapshots {
            switch st {
            case "ready": ready += 1
            case "connecting", "identifying", "resuming": connecting += 1
            case "reconnecting": reconnecting += 1
            default: break
            }
            if let l { latencies.append(l) }
        }
        let avg = latencies.isEmpty ? nil : (latencies.reduce(0, +) / Double(latencies.count))
        let totalGuilds = guildsByShard.values.reduce(0) { $0 + $1.count }
        return .init(totalShards: total, readyShards: ready, connectingShards: connecting, reconnectingShards: reconnecting, averageLatency: avg, totalGuilds: totalGuilds)
    }

    /// Connects all shards to the Discord gateway.
    ///
    /// This method will connect all shards according to the configured strategy,
    /// wait for them to become ready, and verify guild distribution.
    public func connect() async throws {
        // Prepare unified events
        self.eventStream = AsyncStream<ShardedEvent> { continuation in
            continuation.onTermination = { @Sendable _ in
                // Clean up resources when stream terminates
                Task { await self.setShuttingDown() }
            }
            self.eventContinuation = continuation
        }

        // Determine shard count and identify concurrency
        let (totalShards, maxConcurrency) = try await fetchShardPlan()
        self.maxIdentifyConcurrency = maxConcurrency

        // Validate configuration with available information
        await validateConfiguration(totalShards: totalShards)

        // Build shard clients
        shardHandles = (0..<totalShards).map { idx in
            let client = GatewayClient(token: token.rawValue, configuration: httpConfiguration)
            return ShardHandle(id: idx, client: client)
        }

        // Connection strategy: either parallel batches or staggered per-shard
        switch shardingConfiguration.connectionDelay {
        case .none:
            // Identify in batches respecting maxConcurrency, 5s between batches
            var index = 0
            while index < shardHandles.count {
                let end = min(index + maxConcurrency, shardHandles.count)
                let batch = Array(shardHandles[index..<end])
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for handle in batch {
                        group.addTask { try await self.connectShardWithRetry(handle: handle, totalShards: totalShards) }
                    }
                    try await group.waitForAll()
                }
                index = end
                if index < shardHandles.count { try await Task.sleep(nanoseconds: 5_000_000_000) }
            }
        case .staggered(let interval):
            log(.info, "Using staggered connection mode (interval: \(interval)s per shard)")
            for i in 0..<shardHandles.count {
                let handle = shardHandles[i]
                try await connectShardWithRetry(handle: handle, totalShards: totalShards)
                // apply per-shard delay
                if i + 1 < shardHandles.count {
                    log(.debug, "Staggering connection, waiting \(interval)s before next shard")
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
                // After each maxConcurrency group, wait 5s as well (Discord batch pacing)
                if (i + 1) % maxConcurrency == 0 && (i + 1) < shardHandles.count {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
        }

        // Wait until all shards are READY (with timeout) then verify guild distribution
        await waitUntilAllReady(total: shardHandles.count, timeoutSeconds: 60)
        await verifyGuildDistribution()
    }

    // MARK: - Per-shard event streams
    
    /// Returns an event stream for a specific shard.
    public func events(for shardId: Int) -> AsyncStream<ShardedEvent> {
        let total = shardHandles.count
        guard shardId >= 0 && shardId < total else {
            log(.warning, "events(for:) invalid shardId \(shardId). Valid range: 0..<\(total)")
            return AsyncStream { c in c.finish() }
        }
        return AsyncStream { continuation in
            Task {
                for await ev in self.events {
                    if ev.shardId == shardId { continuation.yield(ev) }
                }
                continuation.finish()
            }
        }
    }

    /// Disconnects all shards gracefully.
    public func disconnect() async {
        if isShuttingDown {
            log(.debug, "disconnect() called but already shutting down")
            return
        }
        isShuttingDown = true
        log(.info, "🛑 Initiating graceful shutdown of \(shardHandles.count) shards…")
        // Prevent reconnects and close shards concurrently
        await withTaskGroup(of: Void.self) { group in
            for h in shardHandles {
                group.addTask {
                    await h.client.setAllowReconnect(false)
                    await h.client.close()
                }
            }
            // Best-effort 5s timeout: sleep while closures proceed
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
        // Clear gateway bot cache
        cachedGatewayBot = nil
        // Finish events
        eventContinuation?.finish()
        log(.info, "✅ All shards disconnected gracefully")
    }

    /// Restarts a specific shard.
    public func restartShard(_ shardId: Int) async throws {
        guard let handle = shardHandles.first(where: { $0.id == shardId }) else { return }
        log(.info, "Restarting shard \(shardId)…")
        await handle.client.close()
        try await Task.sleep(nanoseconds: 5_000_000_000)
        try await connectShardWithRetry(handle: handle, totalShards: shardHandles.count)
    }

    private func intentsForShard(_ shardId: Int, total: Int) async -> GatewayIntents {
        if let maker = self.shardingConfiguration.makeIntents { return maker(shardId, total) }
        return fallbackIntents
    }

    private func fetchShardPlan() async throws -> (Int, Int) {
        switch shardingConfiguration.shardCount {
        case .exact(let n):
            let info = try await gatewayBotInfo()
            return (n, max(1, info.session_start_limit.max_concurrency))
        case .automatic:
            let info = try await gatewayBotInfo()
            return (info.shards, max(1, info.session_start_limit.max_concurrency))
        }
    }

    private func gatewayBotInfo(forceRefresh: Bool = false) async throws -> GatewayBotInfo {
        if !forceRefresh, let cached = cachedGatewayBot {
            // Check both URL cache (24 hours) and session limit cache (reset_after)
            if Date() < cached.urlExpiresAt {
                // Session limits might have expired, refresh them
                if Date() >= cached.sessionExpiresAt {
                    let http = HTTPClient(token: token.rawValue, configuration: httpConfiguration)
                    struct Info: Decodable, Sendable {
                        let url: String
                        let shards: Int
                        let session_start_limit: GatewayBotInfo.SessionStartLimit
                    }
                    let info: Info = try await http.get(path: "/gateway/bot")
                    let converted = GatewayBotInfo(url: cached.gatewayUrl, shards: info.shards, session_start_limit: .init(total: info.session_start_limit.total, remaining: info.session_start_limit.remaining, reset_after: info.session_start_limit.reset_after, max_concurrency: info.session_start_limit.max_concurrency))
                    let sessionExpiresAt = Date().addingTimeInterval(Double(info.session_start_limit.reset_after) / 1000.0 + 5.0)
                    cachedGatewayBot = .init(info: converted, gatewayUrl: cached.gatewayUrl, fetchedAt: Date(), urlExpiresAt: cached.urlExpiresAt, sessionExpiresAt: sessionExpiresAt)
                    return converted
                }
                return cached.info
            }
        }
        let http = HTTPClient(token: token.rawValue, configuration: httpConfiguration)
        struct Info: Decodable, Sendable {
            let url: String
            let shards: Int
            let session_start_limit: GatewayBotInfo.SessionStartLimit
        }
        let info: Info = try await http.get(path: "/gateway/bot")
        let converted = GatewayBotInfo(url: info.url, shards: info.shards, session_start_limit: .init(total: info.session_start_limit.total, remaining: info.session_start_limit.remaining, reset_after: info.session_start_limit.reset_after, max_concurrency: info.session_start_limit.max_concurrency))
        // Cache gateway URL for 24 hours (rarely changes)
        let urlExpiresAt = Date().addingTimeInterval(24 * 3600)
        // Use reset_after to determine session limit cache expiration (with 5 second buffer)
        let sessionExpiresAt = Date().addingTimeInterval(Double(info.session_start_limit.reset_after) / 1000.0 + 5.0)
        cachedGatewayBot = .init(info: converted, gatewayUrl: info.url, fetchedAt: Date(), urlExpiresAt: urlExpiresAt, sessionExpiresAt: sessionExpiresAt)
        return converted
    }

    private func connectShardWithRetry(handle: ShardHandle, totalShards: Int) async throws {
        let shardId = handle.id
        let intents: GatewayIntents = await self.intentsForShard(shardId, total: totalShards)
        var attempt = 0
        let maxAttempts = 5
        var backoff: UInt64 = 5_000_000_000
        while true {
            attempt += 1
            do {
                log(.info, "Shard \(shardId) connecting (attempt \(attempt))")
                try await handle.client.connect(intents: intents, shard: (shardId, totalShards)) { @Sendable event in
                    Task { @Sendable [self] in
                        let latency = await handle.client.heartbeatLatency()
                        if case let .guildCreate(guild) = event {
                            await self.recordGuild(shardId: shardId, guildId: guild.id.rawValue)
                        }
                        await self.emitEvent(ShardedEvent(shardId: shardId, event: event, receivedAt: Date(), shardLatency: latency))
                    }
                }
                log(.info, "Shard \(shardId) connected successfully")
                // Apply per-shard presence if configured
                if let presence = await presenceForShard(shardId, total: totalShards) {
                    await handle.client.setPresence(status: presence.status, activities: presence.activities, afk: presence.afk, since: presence.since)
                    log(.debug, "Applied presence to shard \(shardId)")
                }
                return
            } catch {
                if attempt >= maxAttempts {
                    log(.error, "Shard \(shardId) failed to connect after \(attempt) attempts: \(error)")
                    throw error
                } else {
                    let seconds = Double(backoff) / 1_000_000_000
                    log(.warning, "Shard \(shardId) connect failed (attempt \(attempt)). Backing off for \(seconds)s")
                    try await Task.sleep(nanoseconds: backoff)
                    backoff = min(backoff * 2, 40_000_000_000)
                }
            }
        }
    }

    // MARK: - Presence and validation utilities
    private func presenceForShard(_ shardId: Int, total: Int) async -> Configuration.PresenceConfig? {
        if let make = shardingConfiguration.makePresence { return make(shardId, total) }
        return shardingConfiguration.fallbackPresence
    }

    private func validateConfiguration(totalShards: Int) async {
        // Warn when privileged intents are requested by the configured intent set.
        var privileged: [String] = []
        if fallbackIntents.contains(.messageContent) { privileged.append("messageContent") }
        if fallbackIntents.contains(.guildMembers) { privileged.append("guildMembers") }
        if fallbackIntents.contains(.guildPresences) { privileged.append("guildPresences") }
        if !privileged.isEmpty {
            log(.warning, "Privileged intents in use: \(privileged.joined(separator: ", ")). Ensure they are enabled in the Developer Portal.")
        }
        // Shard count vs recommendation
        switch shardingConfiguration.shardCount {
        case .exact(let n):
            if n < totalShards {
                log(.warning, "Explicit shard count (\(n)) is less than Discord recommendation (\(totalShards)). Consider increasing.")
            }
        case .automatic:
            break
        }
        // Token format sanity check
        if token.rawValue.hasPrefix("Bot ") {
            log(.warning, "Token appears to include 'Bot ' prefix. Pass the raw token; SwiftDisc adds the header automatically.")
        }
        if token.rawValue.contains(" ") {
            log(.warning, "Token contains whitespace. Verify your bot token is correct.")
        }
    }

    // MARK: - READY wait & guild distribution
    private func waitUntilAllReady(total: Int, timeoutSeconds: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let statuses = await withTaskGroup(of: String.self, returning: [String].self) { group in
                for h in shardHandles { group.addTask { await h.status() } }
                var arr: [String] = []
                for await s in group { arr.append(s) }
                return arr
            }
            if statuses.allSatisfy({ $0 == "ready" }) { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        log(.warning, "Timed out waiting for all shards to be READY")
    }

    private func verifyGuildDistribution() async {
        let total = shardHandles.count
        guard total > 0 else { return }
        let totalGuilds = guildsByShard.values.reduce(0) { $0 + $1.count }
        if totalGuilds == 0 {
            log(.debug, "No guilds received yet, skipping distribution verification")
            return
        }
        log(.debug, "Verifying guild distribution across \(total) shards…")
        var mismatches: [(guildId: String, expected: Int, actual: Int)] = []
        for (shardId, guilds) in guildsByShard {
            for gid in guilds {
                if let val = UInt64(gid) {
                    let expected = Int(val % UInt64(total))
                    if expected != shardId { mismatches.append((gid, expected, shardId)) }
                } else {
                    log(.warning, "Failed to parse guild ID: \(gid)")
                }
            }
        }
        if mismatches.isEmpty {
            log(.info, "✅ Guild distribution verified: all \(totalGuilds) guilds on correct shards")
        } else {
            log(.warning, "Guild distribution mismatches detected: \(mismatches.count)/\(totalGuilds) guilds on wrong shard")
            for m in mismatches.prefix(5) {
                log(.debug, "  Guild \(m.guildId) on shard \(m.actual), expected shard \(m.expected)")
            }
            if mismatches.count > 5 {
                log(.debug, "  …and \(mismatches.count - 5) more mismatches")
            }
        }
    }

    // MARK: - Actor-isolated utilities
    private func recordGuild(shardId: Int, guildId: String) {
        var set = guildsByShard[shardId] ?? []
        set.insert(guildId)
        guildsByShard[shardId] = set
    }

    private func emitEvent(_ ev: ShardedEvent) async {
        eventContinuation.yield(ev)
    }
}
