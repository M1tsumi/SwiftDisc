import Foundation

public struct ShardedEvent {
    public let shardId: Int
    public let event: DiscordEvent
    public let receivedAt: Date
    public let shardLatency: TimeInterval?
}

public actor ShardingGatewayManager {
    public struct Configuration {
        public enum ShardCountStrategy {
            case automatic
            case exact(Int)
        }
        public struct PresenceConfig {
            public let activities: [PresenceUpdatePayload.Activity]
            public let status: String
            public let afk: Bool
            public let since: Int?
            public init(activities: [PresenceUpdatePayload.Activity], status: String, afk: Bool, since: Int? = nil) {
                self.activities = activities
                self.status = status
                self.afk = afk
                self.since = since
            }
        }
        public enum ConnectionDelay {
            case none
            case staggered(interval: TimeInterval)
        }
        public let shardCount: ShardCountStrategy
        public let identifyConcurrency: IdentifyConcurrency
        public let makeIntents: ((Int, Int) -> GatewayIntents)?
        public let makePresence: ((Int, Int) -> PresenceConfig)?
        public let fallbackPresence: PresenceConfig?
        public let connectionDelay: ConnectionDelay
        public init(
            shardCount: ShardCountStrategy = .automatic,
            identifyConcurrency: IdentifyConcurrency = .respectDiscordLimits,
            makeIntents: ((Int, Int) -> GatewayIntents)? = nil,
            makePresence: ((Int, Int) -> PresenceConfig)? = nil,
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

    public enum IdentifyConcurrency { case respectDiscordLimits }

    public struct ShardStatusSnapshot {
        public let shardId: Int
        public let status: String
        public let heartbeatLatencyMs: Int?
        public let sessionId: String?
        public let lastSequence: Int?
        public let resumeCount: Int
        public let resumeSuccessCount: Int
        public let resumeFailureCount: Int
        public let lastResumeAttemptAt: Date?
        public let lastResumeSuccessAt: Date?
    }
    public struct ShardingHealth {
        public let totalShards: Int
        public let readyShards: Int
        public let connectingShards: Int
        public let reconnectingShards: Int
        public let averageLatency: TimeInterval?
        public let totalGuilds: Int
    }

    private let token: String
    private let shardingConfiguration: Configuration
    private let httpConfiguration: DiscordConfiguration
    private let fallbackIntents: GatewayIntents

    private struct GatewayBotCache {
        var info: GatewayBotInfo
        var fetchedAt: Date
    }
    private var cachedGatewayBot: GatewayBotCache?

    private struct GatewayBotInfo: Decodable {
        struct SessionStartLimit: Decodable { let total: Int; let remaining: Int; let reset_after: Int; let max_concurrency: Int }
        let url: String
        let shards: Int
        let session_start_limit: SessionStartLimit
    }

    public init(token: String, configuration: Configuration = .init(), intents: GatewayIntents, httpConfiguration: DiscordConfiguration = .init()) {
        self.token = token
        self.shardingConfiguration = configuration
        self.httpConfiguration = httpConfiguration
        self.fallbackIntents = intents
    }

    // Unified event stream
    private var eventStream: AsyncStream<ShardedEvent>!
    private var eventContinuation: AsyncStream<ShardedEvent>.Continuation!
    public var events: AsyncStream<ShardedEvent> { eventStream }

    // Logging
    private enum LogLevel: String { case info = "INFO", warning = "WARN", error = "ERROR", debug = "DEBUG" }
    private static let logDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()
    private func log(_ level: LogLevel, _ message: @autoclosure () -> String) {
        let ts = ShardingGatewayManager.logDateFormatter.string(from: Date())
        print("[SwiftDisc][\(level.rawValue)] \(ts) - \(message())")
    }

    // Per-shard
    public struct ShardHandle {
        public let id: Int
        fileprivate let client: GatewayClient
        public func heartbeatLatency() async -> TimeInterval? { await client.heartbeatLatency() }
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

    public func shards() async -> [ShardHandle] { shardHandles }
    public func shard(id: Int) async -> ShardHandle? { shardHandles.first { $0.id == id } }

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

    public func connect() async throws {
        // Prepare unified events
        var localCont: AsyncStream<ShardedEvent>.Continuation!
        self.eventStream = AsyncStream<ShardedEvent> { continuation in
            continuation.onTermination = { _ in }
            localCont = continuation
        }
        self.eventContinuation = localCont

        // Determine shard count and identify concurrency
        let (totalShards, maxConcurrency) = try await fetchShardPlan()
        self.maxIdentifyConcurrency = maxConcurrency

        // Validate configuration with available information
        await validateConfiguration(totalShards: totalShards)

        // Build shard clients
        shardHandles = (0..<totalShards).map { idx in
            let client = GatewayClient(token: token, configuration: httpConfiguration)
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
    public func events(for shardId: Int) -> AsyncStream<ShardedEvent> {
        let total = shardHandles.count
        guard shardId >= 0 && shardId < total else {
            log(.warning, "events(for:) invalid shardId \(shardId). Valid range: 0..<\(total)")
            return AsyncStream { $0.finish() }
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

    public func events(for shardIds: [Int]) -> AsyncStream<ShardedEvent> {
        guard !shardIds.isEmpty else {
            log(.debug, "events(for:) called with empty shardIds, returning empty stream")
            return AsyncStream { $0.finish() }
        }
        let set = Set(shardIds)
        return AsyncStream { continuation in
            Task {
                for await ev in self.events {
                    if set.contains(ev.shardId) { continuation.yield(ev) }
                }
                continuation.finish()
            }
        }
    }

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
            if Date().timeIntervalSince(cached.fetchedAt) < 24 * 3600 { return cached.info }
        }
        let http = HTTPClient(token: token, configuration: httpConfiguration)
        struct Info: Decodable { let url: String; let shards: Int; let session_start_limit: GatewayBotInfo.SessionStartLimit }
        let info: Info = try await http.get(path: "/gateway/bot")
        let converted = GatewayBotInfo(url: info.url, shards: info.shards, session_start_limit: .init(total: info.session_start_limit.total, remaining: info.session_start_limit.remaining, reset_after: info.session_start_limit.reset_after, max_concurrency: info.session_start_limit.max_concurrency))
        cachedGatewayBot = .init(info: converted, fetchedAt: Date())
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
                try await handle.client.connect(intents: intents, shard: (shardId, totalShards)) { [weak self] event in
                    guard let self else { return }
                    Task {
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

    // MARK: - Presence & Validation Helpers
    private func presenceForShard(_ shardId: Int, total: Int) async -> Configuration.PresenceConfig? {
        if let make = shardingConfiguration.makePresence { return make(shardId, total) }
        return shardingConfiguration.fallbackPresence
    }

    private func validateConfiguration(totalShards: Int) async {
        // Privileged intents warnings (based on fallback intents)
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
        if token.hasPrefix("Bot ") {
            log(.warning, "Token appears to include 'Bot ' prefix. Pass the raw token; SwiftDisc adds the header automatically.")
        }
        if token.contains(" ") {
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

    // MARK: - Actor-isolated helpers
    private func recordGuild(shardId: Int, guildId: String) {
        var set = guildsByShard[shardId] ?? []
        set.insert(guildId)
        guildsByShard[shardId] = set
    }

    private func emitEvent(_ ev: ShardedEvent) async {
        eventContinuation.yield(ev)
    }
}
