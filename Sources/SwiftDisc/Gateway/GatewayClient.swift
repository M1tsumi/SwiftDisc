import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Gateway connection state.
///
/// Represents the current state of the WebSocket connection to Discord's gateway.
/// This is broadcast through ``DiscordClient/connectionState``.
public enum GatewayStatus: Sendable {
    /// The gateway is not connected.
    case disconnected
    /// The gateway is establishing a connection.
    case connecting
    /// The gateway is sending an Identify payload.
    case identifying
    /// The gateway is ready and receiving events.
    case ready
    /// The gateway is attempting to resume a previous session.
    case resuming
    /// The gateway is reconnecting after a disconnect.
    case reconnecting
}

actor GatewayClient {
    private struct SeqProbe: Decodable { let s: Int? }
    
    private let token: RedactedToken
    private let configuration: DiscordConfiguration

    private var socket: WebSocketTransport?
    private var heartbeatTask: Task<Void, Never>?
    private var heartbeatIntervalMs: Int = 0
    private var seq: Int?
    private var sessionId: String?
    private var resumeGatewayUrl: String?
    private var resumeGatewayUrlReceivedAt: Date?
    private var missedHeartbeatAckCount: Int = 0
    private var lastHeartbeatSentAt: Date?
    private var lastHeartbeatAckAt: Date?
    private var resumeCount: Int = 0
    private var resumeSuccessCount: Int = 0
    private var resumeFailureCount: Int = 0
    private var lastResumeAttemptAt: Date?
    private var lastResumeSuccessAt: Date?
    private var lastIdentifyAt: Date?
    private var cachedGatewayUrl: String?
    private var sessionStartLimit: SessionStartLimit?
    private var recommendedShards: Int?
    private var allowReconnect: Bool = true
    private var connectReadyContinuation: CheckedContinuation<Void, any Error>?
    private var maxReconnectAttempts: Int = 10
    private var maxReconnectDelayNs: UInt64 = 16_000_000_000

    // Gateway OP 8 entry point for member chunk requests.
    func requestGuildMembers(guildId: GuildID, query: String? = nil, limit: Int? = nil, presences: Bool? = nil, userIds: [UserID]? = nil, nonce: String? = nil) async throws {
        let payload = RequestGuildMembers(d: .init(guild_id: guildId, query: query, limit: limit, presences: presences, user_ids: userIds, nonce: nonce))
        let data = try JSONCoders.encoder.encode(payload)
        try await sendGatewayData(data, opcode: 8)
    }

    private var status: GatewayStatus = .disconnected
    private var statusContinuation: AsyncStream<GatewayStatus>.Continuation?
    private var statusStream: AsyncStream<GatewayStatus>?

    private var lastIntents: GatewayIntents = []
    private var lastEventSink: (@Sendable (DiscordEvent) -> Void)?
    private var lastShard: (index: Int, total: Int)?
    private let rateLimiter = GatewaySendRateLimiter()

    init(token: String, configuration: DiscordConfiguration) {
        self.token = RedactedToken(token)
        self.configuration = configuration
        (self.statusStream, self.statusContinuation) = AsyncStream<GatewayStatus>.makeStream()
    }

    private func logDecodeDiagnostic(_ message: String, data: Data? = nil) {
        guard configuration.enableGatewayDecodeDiagnostics else { return }
        let ts = ISO8601DateFormatter().string(from: Date())
        if let data, !data.isEmpty {
            let preview = String(decoding: data.prefix(512), as: UTF8.self)
            print("[SwiftDisc][GW-DECODE][WARN] \(ts) - \(message) | payload-preview=\(preview)")
        } else {
            print("[SwiftDisc][GW-DECODE][WARN] \(ts) - \(message)")
        }
    }

    func connect(intents: GatewayIntents, shard: (index: Int, total: Int)? = nil, eventSink: @escaping @Sendable (DiscordEvent) -> Void) async throws {
        // Validate gateway version
        guard configuration.apiVersion >= 8 && configuration.apiVersion <= 10 else {
            throw DiscordError.gateway("Unsupported gateway version: \(configuration.apiVersion). Supported versions are 8-10.")
        }
        // Fetch gateway URL from REST on first connect
        if cachedGatewayUrl == nil && resumeGatewayUrl == nil {
            do {
                let botInfo = try await fetchGatewayBot()
                cachedGatewayUrl = botInfo.url
                sessionStartLimit = botInfo.session_start_limit
                recommendedShards = botInfo.shards
            } catch {
                // Fall back to configuration default
            }
        }
        // Validate shard count against recommended shards from gateway bot
        if let shard = shard, let recommended = recommendedShards {
            if shard.total > recommended {
                logDecodeDiagnostic("Shard count \(shard.total) exceeds recommended \(recommended) from gateway bot endpoint")
            }
        }
        // Use resume_gateway_url from READY if available, otherwise cached or default
        let baseURL: URL
        // Discord's resume_gateway_url expires after ~7 days; check before using
        let resumeUrlExpired: Bool
        if let receivedAt = resumeGatewayUrlReceivedAt {
            let age = Date().timeIntervalSince(receivedAt)
            resumeUrlExpired = age > 7 * 24 * 60 * 60 // 7 days in seconds
        } else {
            resumeUrlExpired = true
        }
        if resumeUrlExpired, resumeGatewayUrl != nil {
            // Clear expired resume URL and session to force fresh identify
            self.resumeGatewayUrl = nil
            self.resumeGatewayUrlReceivedAt = nil
            self.sessionId = nil
            self.seq = nil
        }
        if let resumeUrl = resumeGatewayUrl, !resumeUrlExpired, let url = URL(string: resumeUrl) {
            baseURL = url
        } else if let cachedUrl = cachedGatewayUrl, let url = URL(string: cachedUrl) {
            baseURL = url
        } else {
            baseURL = configuration.gatewayBaseURL
        }
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw DiscordError.gateway("Invalid gateway URL")
        }
        let queryItems = [
            URLQueryItem(name: "v", value: String(configuration.apiVersion)),
            URLQueryItem(name: "encoding", value: "json")
        ]
        // Transport compression can be added here when implemented
        components.queryItems = queryItems
        guard let url = components.url else {
            throw DiscordError.gateway("Failed to construct gateway URL")
        }

        // Pick the best adapter for the current platform.
        // URLSessionWebSocketTask is available on Apple platforms, Linux (FoundationNetworking),
        // and modern Windows toolchains. Unsupported targets use the unavailable adapter so
        // the package still compiles with clear runtime behavior.
        #if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(Windows)
        if let customWebSocketTransport = configuration.webSocketTransport {
            self.socket = customWebSocketTransport
        } else {
            self.socket = URLSessionWebSocketTransport(url: url, proxy: configuration.proxy, maxConnectionsPerHost: configuration.httpMaxConnectionsPerHost)
        }
        #else
        self.socket = UnavailableWebSocketAdapter()
        #endif
        self.lastIntents = intents
        self.lastEventSink = eventSink
        self.lastShard = shard
        self.status = .connecting; statusContinuation?.yield(.connecting)

        // The first frame must be HELLO because it carries the heartbeat interval.
        guard let socket = self.socket else { throw DiscordError.gateway("Socket not available") }
        guard case let .string(helloText) = try await socket.receive() else {
            throw DiscordError.gateway("Expected HELLO string frame")
        }
        let helloData = Data(helloText.utf8)
        let hello = try JSONCoders.decoder.decode(GatewayPayload<GatewayHello>.self, from: helloData)
        guard hello.op == .hello, let d = hello.d else { throw DiscordError.gateway("Invalid HELLO payload") }
        heartbeatIntervalMs = d.heartbeat_interval

        // Start heartbeats using the interval negotiated by Discord.
        startHeartbeat()

        // Resume when we have a saved session, otherwise perform a fresh identify.
        if let sessionId, let seq {
            self.status = .resuming; statusContinuation?.yield(.resuming)
            self.lastResumeAttemptAt = Date()
            let resume = ResumePayload(token: token.rawValue, session_id: sessionId, seq: seq)
            let payload = GatewayPayload(op: .resume, d: resume, s: nil, t: nil)
            try await sendGatewayPayload(payload)
        } else {
            self.status = .identifying; statusContinuation?.yield(.identifying)
            // Discord enforces 1 identify per 5 seconds per token.
            if let last = lastIdentifyAt {
                let elapsed = Date().timeIntervalSince(last)
                if elapsed < 5 {
                    let delayNs = UInt64((5 - elapsed) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delayNs)
                }
            }
            // Check session start limit to avoid hitting identify rate limits
            if let limit = sessionStartLimit, limit.remaining <= 0 {
                let delayMs = limit.reset_after
                let delayNs = UInt64(delayMs) * 1_000_000
                try? await Task.sleep(nanoseconds: delayNs)
            }
            self.lastIdentifyAt = Date()
            let shardArray: [Int]? = shard.map { [$0.index, $0.total] }
            let compress = configuration.gatewayPayloadCompression ? true : nil
            let identify = IdentifyPayload(token: token.rawValue, intents: intents.rawValue, properties: .default, compress: compress, large_threshold: configuration.gatewayLargeThreshold, shard: shardArray)
            let payload = GatewayPayload(op: .identify, d: identify, s: nil, t: nil)
            try await sendGatewayPayload(payload)
        }

        // Read loop stays detached so connect() can return once READY/RESUMED arrives.
        Task.detached { @Sendable in
            await self.readLoop(eventSink: eventSink)
        }
        // Wait until the socket is actually usable before returning to callers.
        // Use a single atomic check to avoid race condition with readLoop setting status.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            if self.status == .ready {
                cont.resume()
            } else {
                self.connectReadyContinuation = cont
            }
        }
    }

    /// Type-erased handler for a single gateway dispatch event.
    private typealias EventHandler = @Sendable (Data) -> DiscordEvent?

    /// Dictionary-based dispatch table replacing the massive if/else chain.
    private static let dispatchTable: [String: EventHandler] = {
        let dec = JSONCoders.decoder
        var table: [String: EventHandler] = [:]

        func add<T: Codable>(_ eventName: String, _ type: T.Type, _ transform: @escaping @Sendable (T) -> DiscordEvent) {
            table[eventName] = { data in
                guard let payload = try? dec.decode(GatewayPayload<T>.self, from: data), let d = payload.d else { return nil }
                return transform(d)
            }
        }

        add("MESSAGE_CREATE",              Message.self,                        { .messageCreate($0) })
        add("MESSAGE_UPDATE",              Message.self,                        { .messageUpdate($0) })
        add("MESSAGE_DELETE",              MessageDelete.self,                  { .messageDelete($0) })
        add("MESSAGE_DELETE_BULK",         MessageDeleteBulk.self,              { .messageDeleteBulk($0) })
        add("MESSAGE_REACTION_ADD",        MessageReactionAdd.self,             { .messageReactionAdd($0) })
        add("MESSAGE_REACTION_REMOVE",     MessageReactionRemove.self,          { .messageReactionRemove($0) })
        add("MESSAGE_REACTION_REMOVE_ALL", MessageReactionRemoveAll.self,       { .messageReactionRemoveAll($0) })
        add("MESSAGE_REACTION_REMOVE_EMOJI", MessageReactionRemoveEmoji.self,   { .messageReactionRemoveEmoji($0) })
        // GUILD_CREATE is handled as a special case in readLoop for auto-chunk support.
        add("GUILD_UPDATE",                Guild.self,                          { .guildUpdate($0) })
        add("GUILD_DELETE",                GuildDelete.self,                    { .guildDelete($0) })
        add("GUILD_MEMBER_ADD",            GuildMemberAdd.self,                 { .guildMemberAdd($0) })
        add("GUILD_MEMBER_REMOVE",         GuildMemberRemove.self,              { .guildMemberRemove($0) })
        add("GUILD_MEMBER_UPDATE",         GuildMemberUpdate.self,              { .guildMemberUpdate($0) })
        add("GUILD_ROLE_CREATE",           GuildRoleCreate.self,                { .guildRoleCreate($0) })
        add("GUILD_ROLE_UPDATE",           GuildRoleUpdate.self,                { .guildRoleUpdate($0) })
        add("GUILD_ROLE_DELETE",           GuildRoleDelete.self,                { .guildRoleDelete($0) })
        add("GUILD_EMOJIS_UPDATE",         GuildEmojisUpdate.self,              { .guildEmojisUpdate($0) })
        add("GUILD_STICKERS_UPDATE",       GuildStickersUpdate.self,            { .guildStickersUpdate($0) })
        add("GUILD_MEMBERS_CHUNK",         GuildMembersChunk.self,              { .guildMembersChunk($0) })
        add("CHANNEL_CREATE",              Channel.self,                        { .channelCreate($0) })
        add("CHANNEL_UPDATE",              Channel.self,                        { .channelUpdate($0) })
        add("CHANNEL_DELETE",              Channel.self,                        { .channelDelete($0) })
        add("THREAD_CREATE",               Channel.self,                        { .threadCreate($0) })
        add("THREAD_UPDATE",               Channel.self,                        { .threadUpdate($0) })
        add("THREAD_DELETE",               Channel.self,                        { .threadDelete($0) })
        add("THREAD_MEMBER_UPDATE",        ThreadMember.self,                   { .threadMemberUpdate($0) })
        add("THREAD_MEMBERS_UPDATE",       ThreadMembersUpdate.self,            { .threadMembersUpdate($0) })
        add("THREAD_LIST_SYNC",            ThreadListSync.self,                 { .threadListSync($0) })
        add("APPLICATION_COMMAND_PERMISSIONS_UPDATE", ApplicationCommandPermissionsUpdate.self, { .applicationCommandPermissionsUpdate($0) })
        add("CHANNEL_INFO",                Channel.self,                        { .channelInfo($0) })
        add("GUILD_SCHEDULED_EVENT_CREATE", GuildScheduledEvent.self,           { .guildScheduledEventCreate($0) })
        add("GUILD_SCHEDULED_EVENT_UPDATE", GuildScheduledEvent.self,           { .guildScheduledEventUpdate($0) })
        add("GUILD_SCHEDULED_EVENT_DELETE", GuildScheduledEvent.self,           { .guildScheduledEventDelete($0) })
        add("GUILD_SCHEDULED_EVENT_USER_ADD", GuildScheduledEventUser.self,     { .guildScheduledEventUserAdd($0) })
        add("GUILD_SCHEDULED_EVENT_USER_REMOVE", GuildScheduledEventUser.self,  { .guildScheduledEventUserRemove($0) })
        add("TYPING_START",                TypingStart.self,                    { .typingStart($0) })
        add("CHANNEL_PINS_UPDATE",         ChannelPinsUpdate.self,              { .channelPinsUpdate($0) })
        add("PRESENCE_UPDATE",             PresenceUpdate.self,                 { .presenceUpdate($0) })
        add("GUILD_BAN_ADD",               GuildBanAdd.self,                    { .guildBanAdd($0) })
        add("GUILD_BAN_REMOVE",            GuildBanRemove.self,                 { .guildBanRemove($0) })
        add("AUTO_MODERATION_RULE_CREATE", AutoModerationRule.self,             { .autoModerationRuleCreate($0) })
        add("AUTO_MODERATION_RULE_UPDATE", AutoModerationRule.self,             { .autoModerationRuleUpdate($0) })
        add("AUTO_MODERATION_RULE_DELETE", AutoModerationRule.self,             { .autoModerationRuleDelete($0) })
        add("AUTO_MODERATION_ACTION_EXECUTION", AutoModerationActionExecution.self, { .autoModerationActionExecution($0) })
        add("GUILD_AUDIT_LOG_ENTRY_CREATE", AuditLogEntry.self,                 { .guildAuditLogEntryCreate($0) })
        add("WEBHOOKS_UPDATE",             WebhooksUpdate.self,                 { .webhooksUpdate($0) })
        add("GUILD_INTEGRATIONS_UPDATE",   GuildIntegrationsUpdate.self,        { .guildIntegrationsUpdate($0) })
        add("POLL_VOTE_ADD",               PollVote.self,                       { .pollVoteAdd($0) })
        add("POLL_VOTE_REMOVE",            PollVote.self,                       { .pollVoteRemove($0) })
        add("SOUNDBOARD_SOUND_CREATE",     SoundboardSound.self,                { .soundboardSoundCreate($0) })
        add("SOUNDBOARD_SOUND_UPDATE",     SoundboardSound.self,                { .soundboardSoundUpdate($0) })
        add("SOUNDBOARD_SOUND_DELETE",     SoundboardSound.self,                { .soundboardSoundDelete($0) })
        add("USER_UPDATE",                 User.self,                           { .userUpdate($0) })
        add("ENTITLEMENT_CREATE",          Entitlement.self,                    { .entitlementCreate($0) })
        add("ENTITLEMENT_UPDATE",          Entitlement.self,                    { .entitlementUpdate($0) })
        add("ENTITLEMENT_DELETE",          Entitlement.self,                    { .entitlementDelete($0) })
        add("INVITE_CREATE",               InviteCreate.self,                   { .inviteCreate($0) })
        add("INVITE_DELETE",               InviteDelete.self,                   { .inviteDelete($0) })
        // INTERACTION_CREATE is handled separately because it has diagnostic logging on failure

        return table
    }()

    private func readLoop(eventSink: @escaping @Sendable (DiscordEvent) -> Void) async {
        guard let socket = self.socket else { return }
        let dec = JSONCoders.decoder
        var lastFrameData: Data?
        while true {
            do {
                let msg = try await socket.receive()
                let data: Data
                switch msg {
                case .string(let text): data = Data(text.utf8)
                case .data(let d): data = d
                }
                lastFrameData = data
                // Track the latest sequence number for heartbeats and resume.
                if let probe = try? dec.decode(SeqProbe.self, from: data), let s = probe.s {
                    self.seq = s
                }
                // Decode opcode first, then dispatch by event name when needed.
                if let opBox = try? dec.decode(GatewayOpBox.self, from: data) {
                    switch opBox.op {
                    case .dispatch:
                        guard let t = opBox.t else { continue }
                        if t == "READY" {
                            if let payload = try? dec.decode(GatewayPayload<ReadyEvent>.self, from: data), let ready = payload.d {
                                // Save session ID and resume gateway URL for reconnects.
                                self.sessionId = ready.session_id
                                self.resumeGatewayUrl = ready.resume_gateway_url
                                self.resumeGatewayUrlReceivedAt = Date()
                                self.status = .ready; statusContinuation?.yield(.ready)
                                eventSink(.ready(ready))
                                if let cont = self.connectReadyContinuation {
                                    self.connectReadyContinuation = nil
                                    cont.resume()
                                }
                            }
                        } else if t == "RESUMED" {
                            // RESUME accepted; keep the same session.
                            self.status = .ready; statusContinuation?.yield(.ready)
                            self.resumeSuccessCount += 1
                            self.lastResumeSuccessAt = Date()
                            eventSink(.resumed)
                            if let cont = self.connectReadyContinuation {
                                self.connectReadyContinuation = nil
                                cont.resume()
                            }
                        } else if t == "GUILD_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<Guild>.self, from: data), let guild = payload.d {
                                eventSink(.guildCreate(guild))
                                // Auto-request guild members for large guilds when configured.
                                if configuration.autoRequestGuildMembersChunk,
                                   let threshold = configuration.gatewayLargeThreshold,
                                   guild.large == true || (guild.member_count ?? 0) > threshold {
                                    try? await requestGuildMembers(
                                        guildId: guild.id,
                                        limit: configuration.guildMembersChunkLimit
                                    )
                                }
                            } else {
                                eventSink(.raw(t, data))
                            }
                        } else if t == "INTERACTION_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<Interaction>.self, from: data), let interaction = payload.d {
                                eventSink(.interactionCreate(interaction))
                            } else {
                                // Preserve visibility when payload shape drifts instead of silently dropping.
                                logDecodeDiagnostic("Failed to decode INTERACTION_CREATE as Interaction (op=\(opBox.op.rawValue), seq=\(String(describing: self.seq)))", data: data)
                                eventSink(.raw(t, data))
                            }
                        } else {
                            // Use the dictionary-based dispatch table for all other events.
                            if let handler = Self.dispatchTable[t] {
                                if let event = handler(data) {
                                    eventSink(event)
                                }
                            } else {
                                // Unknown events are forwarded as raw payloads so callers still get visibility.
                                eventSink(.raw(t, data))
                            }
                        }
                    case .heartbeat:
                        // Discord requested an immediate heartbeat (op 1)
                        do {
                            let hb: HeartbeatPayload = seq
                            let payload = GatewayPayload(op: .heartbeat, d: hb, s: nil, t: nil)
                            try await sendGatewayPayload(payload)
                            missedHeartbeatAckCount += 1
                            lastHeartbeatSentAt = Date()
                        } catch {
                            await attemptReconnect()
                        }
                        break
                    case .heartbeatAck:
                        missedHeartbeatAckCount = 0
                        lastHeartbeatAckAt = Date()
                        break
                    case .rateLimited:
                        // Gateway is rate limiting our connection
                        logDecodeDiagnostic("Gateway rate limited, waiting before reconnecting")
                        await attemptReconnect()
                        break
                    case .invalidSession:
                        // Decode the resumable flag (d field) to determine if session can be resumed
                        if let payload = try? dec.decode(GatewayPayload<Bool>.self, from: data), let resumable = payload.d {
                            if resumable {
                                // Session is resumable - sleep 1-5s then retry RESUME
                                let delay = UInt64.random(in: 1_000_000_000...5_000_000_000)
                                try? await Task.sleep(nanoseconds: delay)
                                await attemptReconnect()
                            } else {
                                // Session is not resumable - clear state and use IDENTIFY on reconnect
                                self.resumeFailureCount += 1
                                self.sessionId = nil
                                self.seq = nil
                                eventSink(.sessionInvalidated)
                                await attemptReconnect()
                            }
                        } else {
                            // Failed to decode, assume non-resumable
                            self.resumeFailureCount += 1
                            self.sessionId = nil
                            self.seq = nil
                            eventSink(.sessionInvalidated)
                            await attemptReconnect()
                        }
                        break
                    case .reconnect:
                        await attemptReconnect()
                        break
                    default:
                        break
                    }
                }
            } catch let error as DecodingError {
                // Malformed payloads are logged and skipped so one bad frame does not kill the socket.
                logDecodeDiagnostic("Top-level gateway frame decoding error: \(error)", data: lastFrameData)
                continue
            } catch {
                await attemptReconnect()
                break
            }
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { @Sendable in
            await self.runHeartbeatLoop()
        }
    }

    private func runHeartbeatLoop() async {
        let intervalNs = UInt64(heartbeatIntervalMs) * 1_000_000
        // Discord recommends jitter before the first heartbeat to avoid thundering herd reconnects.
        let jitterNs = UInt64.random(in: 0..<UInt64(heartbeatIntervalMs)) * 1_000_000
        try? await Task.sleep(nanoseconds: jitterNs)
        var pingCounter = 0
        while !Task.isCancelled {
            // Discord spec: treat connection as zombied after a single missed ACK
            if missedHeartbeatAckCount >= 1 {
                await attemptReconnect()
                break
            }
            do {
                let hb: HeartbeatPayload = seq
                let payload = GatewayPayload(op: .heartbeat, d: hb, s: nil, t: nil)
                try await sendGatewayPayload(payload)
                missedHeartbeatAckCount += 1
                lastHeartbeatSentAt = Date()
            } catch {
                await attemptReconnect()
                break
            }
            // Periodically send a platform-level ping to detect dead sockets faster
            // than waiting for a missed heartbeat ACK.
            pingCounter += 1
            if pingCounter >= 5, let socket {
                pingCounter = 0
                do {
                    try await socket.sendPing()
                } catch {
                    await attemptReconnect()
                    break
                }
            }
            // Sleep for one interval, then verify the previous heartbeat was acknowledged.
            try? await Task.sleep(nanoseconds: intervalNs)
        }
    }

    private func attemptReconnect() async {
        // Reconnect strategy: drop the current socket without a clean close,
        // then retry with bounded exponential backoff with jitter.
        if !allowReconnect { return }

        // Capture close code before closing so we can detect fatal codes
        let closeCode = socket?.closeCode
        if let code = closeCode, isFatalCloseCode(code) {
            status = .disconnected; statusContinuation?.yield(.disconnected)
            let reason = fatalCloseCodeDescription(code)
            if let cont = connectReadyContinuation {
                connectReadyContinuation = nil
                let error: DiscordError = (code == 4004)
                    ? .authenticationFailed
                    : .gateway("Fatal close code \(code): \(reason)")
                cont.resume(throwing: error)
                return
            }
            guard let sink = lastEventSink else { return }
            sink(.disconnected(reason: "Fatal close code \(code): \(reason)"))
            return
        }

        // Use forceClose to avoid sending 1000/1001, which Discord treats as
        // session-invalidating and would prevent resume.
        await socket?.forceClose()
        socket = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        missedHeartbeatAckCount = 0
        status = .reconnecting; statusContinuation?.yield(.reconnecting)
        let intents = lastIntents
        guard let sink = lastEventSink else { return }
        var delay: UInt64 = 500_000_000
        var attemptCount = 0
        while allowReconnect && attemptCount < maxReconnectAttempts {
            attemptCount += 1
            // Add jitter to delay to avoid thundering herd with multiple shards
            let jitter = UInt64.random(in: 0...(delay / 4))
            try? await Task.sleep(nanoseconds: delay + jitter)
            do {
                try await connect(intents: intents, shard: lastShard, eventSink: sink)
                return
            } catch {
                delay = min(delay * 2, maxReconnectDelayNs)
                continue
            }
        }
        // Max reconnect attempts reached - surface fatal disconnect
        status = .disconnected; statusContinuation?.yield(.disconnected)
        if let cont = connectReadyContinuation {
            connectReadyContinuation = nil
            cont.resume(throwing: DiscordError.gateway("Max reconnect attempts (\(maxReconnectAttempts)) reached"))
        } else {
            sink(.disconnected(reason: "Max reconnect attempts (\(maxReconnectAttempts)) reached"))
        }
    }
    
    private func isFatalCloseCode(_ code: Int) -> Bool {
        // Only explicit fatal codes should block reconnection; other 4000-series codes are recoverable
        return code == 4004 || code == 4010 || code == 4011 || code == 4012 || code == 4013 || code == 4014
    }
    
    private func fatalCloseCodeDescription(_ code: Int) -> String {
        switch code {
        case 4004: return "Authentication failed"
        case 4010: return "Invalid shard"
        case 4011: return "Sharding required"
        case 4012: return "Invalid API version"
        case 4013: return "Invalid intents"
        case 4014: return "Disallowed intents"
        default: return "Unknown error"
        }
    }

    // MARK: - Gateway URL fetch

    /// Validates that privileged intents are used with awareness of their privileged status.
    /// Logs a warning for each privileged intent used. This is a static check and does not
    /// verify the Developer Portal configuration.
    public static func validatePrivilegedIntents(_ intents: GatewayIntents, logger: (any DiscordLogger)? = nil) {
        let privileged: [(GatewayIntents, String)] = [
            (.guildMembers, "GUILD_MEMBERS"),
            (.guildPresences, "GUILD_PRESENCES"),
            (.messageContent, "MESSAGE_CONTENT")
        ]
        let log = logger ?? DefaultDiscordLogger()
        for (intent, name) in privileged {
            if intents.contains(intent) {
                log.log(.warning, "[SwiftDisc] Privileged intent '\(name)' is enabled. Ensure it is toggled on in the Discord Developer Portal (https://discord.com/developers/applications).")
            }
        }
    }

    private func fetchGatewayBot() async throws -> GatewayBotResponse {
        let url = configuration.apiBaseURL
            .appendingPathComponent("v\(configuration.apiVersion)")
            .appendingPathComponent("gateway/bot")
        var request = URLRequest(url: url)
        request.setValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
        request.setValue("DiscordBot (https://github.com/M1tsumi/SwiftDisc, \(DiscordConfiguration.version))", forHTTPHeaderField: "User-Agent")

        let sessionConfig = URLSessionConfiguration.ephemeral
        if let proxy = configuration.proxy {
            sessionConfig.connectionProxyDictionary = proxy.urlSessionProxyDictionary
        }
        let session = URLSession(configuration: sessionConfig)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DiscordError.gateway("Failed to fetch gateway bot info")
        }
        return try JSONCoders.decoder.decode(GatewayBotResponse.self, from: data)
    }

    /// Gracefully disconnects from the gateway, canceling the session.
    /// After calling this, a new `connect()` must be made to resume traffic.
    public func disconnect() async {
        await socket?.close()
        socket = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        status = .disconnected; statusContinuation?.yield(.disconnected)
        statusContinuation?.finish()
    }

    /// Alias for `disconnect()`.
    func close() async {
        await disconnect()
    }

    // Sends a gateway presence update payload for status/activity changes.
    func setPresence(status: String, activities: [PresenceUpdatePayload.Activity] = [], afk: Bool = false, since: Int? = nil) async {
        let p = PresenceUpdatePayload(d: .init(since: since, activities: activities, status: status, afk: afk))
        let payload = GatewayPayload(op: .presenceUpdate, d: p, s: nil, t: nil)
        try? await sendGatewayPayload(payload)
    }

    // MARK: - Health and telemetry accessors
    func heartbeatLatency() -> TimeInterval? {
        guard let sent = lastHeartbeatSentAt, let ack = lastHeartbeatAckAt else { return nil }
        return ack.timeIntervalSince(sent)
    }

    func currentStatus() -> GatewayStatus { status }
    func statusUpdates() -> AsyncStream<GatewayStatus> { statusStream ?? AsyncStream { $0.finish() } }
    func currentSessionId() -> String? { sessionId }
    func currentSeq() -> Int? { seq }
    func setAllowReconnect(_ allow: Bool) { allowReconnect = allow }

    func incrementResumeCount() { resumeCount += 1 }
    func currentResumeCount() -> Int { resumeCount }
    func getResumeSuccessCount() -> Int { resumeSuccessCount }
    func getResumeFailureCount() -> Int { resumeFailureCount }
    func getLastResumeAttemptAt() -> Date? { lastResumeAttemptAt }
    func getLastResumeSuccessAt() -> Date? { lastResumeSuccessAt }

    /// A snapshot of connection health metrics for the single-shard gateway client.
    public func connectionMetrics() -> GatewayConnectionMetrics {
        GatewayConnectionMetrics(
            status: status,
            sessionId: sessionId,
            seq: seq,
            heartbeatLatency: heartbeatLatency(),
            resumeCount: resumeCount,
            resumeSuccessCount: resumeSuccessCount,
            resumeFailureCount: resumeFailureCount,
            lastResumeAttemptAt: lastResumeAttemptAt,
            lastResumeSuccessAt: lastResumeSuccessAt,
            lastIdentifyAt: lastIdentifyAt,
            missedHeartbeatAckCount: missedHeartbeatAckCount
        )
    }

    // MARK: - Gateway send helpers

    private func sendGatewayPayload<T: Encodable & Sendable>(_ payload: GatewayPayload<T>) async throws {
        guard let socket = self.socket else { throw DiscordError.gateway("Socket not connected") }
        let data = try JSONCoders.encoder.encode(payload)
        await rateLimiter.acquire(opcode: payload.op.rawValue)
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private func sendGatewayData(_ data: Data, opcode: Int) async throws {
        guard let socket = self.socket else { throw DiscordError.gateway("Socket not connected") }
        await rateLimiter.acquire(opcode: opcode)
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
    }
}

// MARK: - Connection metrics

/// A snapshot of the gateway connection's health and telemetry.
///
/// Returned by ``GatewayClient/connectionMetrics()`` so single-shard bots
/// can observe reconnect activity, heartbeat latency, and session state
/// without needing the sharding manager.
public struct GatewayConnectionMetrics: Sendable {
    /// The current connection state.
    public let status: GatewayStatus
    /// The active session ID, if any.
    public let sessionId: String?
    /// The latest event sequence number.
    public let seq: Int?
    /// The time interval between the last heartbeat and its acknowledgment.
    public let heartbeatLatency: TimeInterval?
    /// Total reconnection attempts.
    public let resumeCount: Int
    /// Successful session resumes.
    public let resumeSuccessCount: Int
    /// Failed session resumes.
    public let resumeFailureCount: Int
    /// The last time a resume was attempted.
    public let lastResumeAttemptAt: Date?
    /// The last time a resume succeeded.
    public let lastResumeSuccessAt: Date?
    /// The last time an identify was sent.
    public let lastIdentifyAt: Date?
    /// The number of heartbeats that have not received an ACK.
    public let missedHeartbeatAckCount: Int
}

// MARK: - Lightweight decode utilities

private struct GatewayOpBox: Codable, Sendable {
    let op: GatewayOpcode
    let t: String?
}

// MARK: - Gateway send rate limiter

/// Per-opcode rate limit configuration for gateway sends.
///
/// Discord applies different rate limits per opcode. The global limit is
/// 120 commands per 60s, but specific opcodes have stricter limits:
/// - OP 2 (Identify): 1 per 5s (enforced separately in `connect()`)
/// - OP 3 (Presence Update): 5 per 60s
/// - All other ops: 120 per 60s (global bucket)
private struct OpcodeRateLimit: Sendable {
    let maxTokens: Double
    let refillRate: Double // tokens per second
}

/// Enforces Discord's gateway send rate limits with per-opcode awareness.
private actor GatewaySendRateLimiter {
    /// Global rate limit: 120 commands per 60 seconds.
    private static let globalLimit = OpcodeRateLimit(maxTokens: 120, refillRate: 2.0)
    /// Presence update (OP 3) limit: 5 per 60 seconds.
    private static let presenceLimit = OpcodeRateLimit(maxTokens: 5, refillRate: 5.0 / 60.0)

    /// Per-opcode overrides on the global bucket.
    /// Key: opcode raw value; nil means the global limit applies.
    private static let perOpcodeLimits: [Int: OpcodeRateLimit] = [
        3: presenceLimit
    ]

    // Global bucket state
    private var globalTokens: Double
    private var globalLastRefill: Date

    // Per-opcode bucket state
    private var opTokens: [Int: Double] = [:]
    private var opLastRefill: [Int: Date] = [:]

    init() {
        self.globalTokens = Self.globalLimit.maxTokens
        self.globalLastRefill = Date()
    }

    /// Acquire permission to send a gateway payload with the given opcode.
    func acquire(opcode: Int) async {
        // Acquire from the global bucket first.
        await acquireGlobal()
        // Then acquire from the per-opcode bucket if one exists.
        if let limit = Self.perOpcodeLimits[opcode] {
            await acquireOpcode(opcode, limit: limit)
        }
    }

    private func acquireGlobal() async {
        refillGlobal()
        if globalTokens >= 1 {
            globalTokens -= 1
            return
        }
        let waitSeconds = (1 - globalTokens) / Self.globalLimit.refillRate
        try? await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
        refillGlobal()
        globalTokens = max(0, globalTokens - 1)
    }

    private func acquireOpcode(_ opcode: Int, limit: OpcodeRateLimit) async {
        refillOpcode(opcode, limit: limit)
        let tokens = opTokens[opcode] ?? limit.maxTokens
        if tokens >= 1 {
            opTokens[opcode] = tokens - 1
            return
        }
        let waitSeconds = (1 - tokens) / limit.refillRate
        try? await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
        refillOpcode(opcode, limit: limit)
        opTokens[opcode] = max(0, (opTokens[opcode] ?? limit.maxTokens) - 1)
    }

    private func refillGlobal() {
        let now = Date()
        let elapsed = now.timeIntervalSince(globalLastRefill)
        globalTokens = min(Self.globalLimit.maxTokens, globalTokens + elapsed * Self.globalLimit.refillRate)
        globalLastRefill = now
    }

    private func refillOpcode(_ opcode: Int, limit: OpcodeRateLimit) {
        let now = Date()
        let last = opLastRefill[opcode] ?? now
        let elapsed = now.timeIntervalSince(last)
        let current = opTokens[opcode] ?? limit.maxTokens
        opTokens[opcode] = min(limit.maxTokens, current + elapsed * limit.refillRate)
        opLastRefill[opcode] = now
    }
}
