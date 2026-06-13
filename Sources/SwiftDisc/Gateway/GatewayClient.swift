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

    private var socket: WebSocketClient?
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
        try await sendGatewayData(data)
    }

    private var status: GatewayStatus = .disconnected

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
        var queryItems = [
            URLQueryItem(name: "v", value: String(configuration.apiVersion)),
            URLQueryItem(name: "encoding", value: "json")
        ]
        // Add transport compression if configured
        switch configuration.gatewayCompression {
        case .zlibStream:
            queryItems.append(URLQueryItem(name: "compress", value: "zlib-stream"))
        case .zstdStream:
            queryItems.append(URLQueryItem(name: "compress", value: "zstd-stream"))
        case .none:
            break
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw DiscordError.gateway("Failed to construct gateway URL")
        }

        // Pick the best adapter for the current platform.
        // URLSessionWebSocketTask is available on Apple platforms, Linux (FoundationNetworking),
        // and modern Windows toolchains. Unsupported targets use the unavailable adapter so
        // the package still compiles with clear runtime behavior.
        #if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(Windows)
        let socket: WebSocketClient = URLSessionWebSocketAdapter(url: url, maxConnectionsPerHost: configuration.httpMaxConnectionsPerHost)
        #else
        let socket: WebSocketClient = UnavailableWebSocketAdapter()
        #endif
        self.socket = socket
        self.lastIntents = intents
        self.lastEventSink = eventSink
        self.lastShard = shard
        self.status = .connecting; statusContinuation?.yield(.connecting)

        // The first frame must be HELLO because it carries the heartbeat interval.
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
                        } else if t == "MESSAGE_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<Message>.self, from: data), let msg = payload.d {
                                eventSink(.messageCreate(msg))
                            }
                        } else if t == "MESSAGE_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<Message>.self, from: data), let msg = payload.d {
                                eventSink(.messageUpdate(msg))
                            }
                        } else if t == "MESSAGE_DELETE" {
                            if let payload = try? dec.decode(GatewayPayload<MessageDelete>.self, from: data), let del = payload.d {
                                eventSink(.messageDelete(del))
                            }
                        } else if t == "MESSAGE_DELETE_BULK" {
                            if let payload = try? dec.decode(GatewayPayload<MessageDeleteBulk>.self, from: data), let bulk = payload.d {
                                eventSink(.messageDeleteBulk(bulk))
                            }
                        } else if t == "MESSAGE_REACTION_ADD" {
                            if let payload = try? dec.decode(GatewayPayload<MessageReactionAdd>.self, from: data), let ev = payload.d {
                                eventSink(.messageReactionAdd(ev))
                            }
                        } else if t == "MESSAGE_REACTION_REMOVE" {
                            if let payload = try? dec.decode(GatewayPayload<MessageReactionRemove>.self, from: data), let ev = payload.d {
                                eventSink(.messageReactionRemove(ev))
                            }
                        } else if t == "MESSAGE_REACTION_REMOVE_ALL" {
                            if let payload = try? dec.decode(GatewayPayload<MessageReactionRemoveAll>.self, from: data), let ev = payload.d {
                                eventSink(.messageReactionRemoveAll(ev))
                            }
                        } else if t == "MESSAGE_REACTION_REMOVE_EMOJI" {
                            if let payload = try? dec.decode(GatewayPayload<MessageReactionRemoveEmoji>.self, from: data), let ev = payload.d {
                                eventSink(.messageReactionRemoveEmoji(ev))
                            }
                        } else if t == "GUILD_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<Guild>.self, from: data), let guild = payload.d {
                                eventSink(.guildCreate(guild))
                            }
                        } else if t == "GUILD_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<Guild>.self, from: data), let guild = payload.d {
                                eventSink(.guildUpdate(guild))
                            }
                        } else if t == "GUILD_DELETE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildDelete>.self, from: data), let ev = payload.d {
                                eventSink(.guildDelete(ev))
                            }
                        } else if t == "GUILD_MEMBER_ADD" {
                            if let payload = try? dec.decode(GatewayPayload<GuildMemberAdd>.self, from: data), let ev = payload.d {
                                eventSink(.guildMemberAdd(ev))
                            }
                        } else if t == "GUILD_MEMBER_REMOVE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildMemberRemove>.self, from: data), let ev = payload.d {
                                eventSink(.guildMemberRemove(ev))
                            }
                        } else if t == "GUILD_MEMBER_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildMemberUpdate>.self, from: data), let ev = payload.d {
                                eventSink(.guildMemberUpdate(ev))
                            }
                        } else if t == "GUILD_ROLE_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildRoleCreate>.self, from: data), let ev = payload.d {
                                eventSink(.guildRoleCreate(ev))
                            }
                        } else if t == "GUILD_ROLE_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildRoleUpdate>.self, from: data), let ev = payload.d {
                                eventSink(.guildRoleUpdate(ev))
                            }
                        } else if t == "GUILD_ROLE_DELETE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildRoleDelete>.self, from: data), let ev = payload.d {
                                eventSink(.guildRoleDelete(ev))
                            }
                        } else if t == "GUILD_EMOJIS_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildEmojisUpdate>.self, from: data), let ev = payload.d {
                                eventSink(.guildEmojisUpdate(ev))
                            }
                        } else if t == "GUILD_STICKERS_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildStickersUpdate>.self, from: data), let ev = payload.d {
                                eventSink(.guildStickersUpdate(ev))
                            }
                        } else if t == "GUILD_MEMBERS_CHUNK" {
                            if let payload = try? dec.decode(GatewayPayload<GuildMembersChunk>.self, from: data), let ev = payload.d {
                                eventSink(.guildMembersChunk(ev))
                            }
                        } else if t == "CHANNEL_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<Channel>.self, from: data), let channel = payload.d {
                                eventSink(.channelCreate(channel))
                            }
                        } else if t == "CHANNEL_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<Channel>.self, from: data), let channel = payload.d {
                                eventSink(.channelUpdate(channel))
                            }
                        } else if t == "CHANNEL_DELETE" {
                            if let payload = try? dec.decode(GatewayPayload<Channel>.self, from: data), let channel = payload.d {
                                eventSink(.channelDelete(channel))
                            }
                        } else if t == "THREAD_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<Channel>.self, from: data), let ch = payload.d {
                                eventSink(.threadCreate(ch))
                            }
                        } else if t == "THREAD_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<Channel>.self, from: data), let ch = payload.d {
                                eventSink(.threadUpdate(ch))
                            }
                        } else if t == "THREAD_DELETE" {
                            if let payload = try? dec.decode(GatewayPayload<Channel>.self, from: data), let ch = payload.d {
                                eventSink(.threadDelete(ch))
                            }
                        } else if t == "THREAD_MEMBER_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<ThreadMember>.self, from: data), let m = payload.d {
                                eventSink(.threadMemberUpdate(m))
                            }
                        } else if t == "THREAD_MEMBERS_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<ThreadMembersUpdate>.self, from: data), let m = payload.d {
                                eventSink(.threadMembersUpdate(m))
                            }
                        } else if t == "THREAD_LIST_SYNC" {
                            if let payload = try? dec.decode(GatewayPayload<ThreadListSync>.self, from: data), let tls = payload.d {
                                eventSink(.threadListSync(tls))
                            }
                        } else if t == "APPLICATION_COMMAND_PERMISSIONS_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<ApplicationCommandPermissionsUpdate>.self, from: data), let acpu = payload.d {
                                eventSink(.applicationCommandPermissionsUpdate(acpu))
                            }
                        } else if t == "CHANNEL_INFO" {
                            if let payload = try? dec.decode(GatewayPayload<Channel>.self, from: data), let channel = payload.d {
                                eventSink(.channelInfo(channel))
                            }
                        } else if t == "INTERACTION_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<Interaction>.self, from: data), let interaction = payload.d {
                                eventSink(.interactionCreate(interaction))
                            } else {
                                // Preserve visibility when payload shape drifts instead of silently dropping.
                                logDecodeDiagnostic("Failed to decode INTERACTION_CREATE as Interaction (op=\(opBox.op.rawValue), seq=\(String(describing: self.seq)))", data: data)
                                eventSink(.raw(t, data))
                            }
                        } else if t == "GUILD_SCHEDULED_EVENT_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildScheduledEvent>.self, from: data), let ev = payload.d {
                                eventSink(.guildScheduledEventCreate(ev))
                            }
                        } else if t == "GUILD_SCHEDULED_EVENT_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildScheduledEvent>.self, from: data), let ev = payload.d {
                                eventSink(.guildScheduledEventUpdate(ev))
                            }
                        } else if t == "GUILD_SCHEDULED_EVENT_DELETE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildScheduledEvent>.self, from: data), let ev = payload.d {
                                eventSink(.guildScheduledEventDelete(ev))
                            }
                        } else if t == "GUILD_SCHEDULED_EVENT_USER_ADD" {
                            if let payload = try? dec.decode(GatewayPayload<GuildScheduledEventUser>.self, from: data), let ev = payload.d {
                                eventSink(.guildScheduledEventUserAdd(ev))
                            }
                        } else if t == "GUILD_SCHEDULED_EVENT_USER_REMOVE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildScheduledEventUser>.self, from: data), let ev = payload.d {
                                eventSink(.guildScheduledEventUserRemove(ev))
                            }
                        } else if t == "TYPING_START" {
                            if let payload = try? dec.decode(GatewayPayload<TypingStart>.self, from: data), let ev = payload.d {
                                eventSink(.typingStart(ev))
                            }
                        } else if t == "CHANNEL_PINS_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<ChannelPinsUpdate>.self, from: data), let ev = payload.d {
                                eventSink(.channelPinsUpdate(ev))
                            }
                        } else if t == "PRESENCE_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<PresenceUpdate>.self, from: data), let ev = payload.d {
                                eventSink(.presenceUpdate(ev))
                            }
                        } else if t == "GUILD_BAN_ADD" {
                            if let payload = try? dec.decode(GatewayPayload<GuildBanAdd>.self, from: data), let ev = payload.d {
                                eventSink(.guildBanAdd(ev))
                            }
                        } else if t == "GUILD_BAN_REMOVE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildBanRemove>.self, from: data), let ev = payload.d {
                                eventSink(.guildBanRemove(ev))
                            }
                        } else if t == "AUTO_MODERATION_RULE_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<AutoModerationRule>.self, from: data), let ev = payload.d {
                                eventSink(.autoModerationRuleCreate(ev))
                            }
                        } else if t == "AUTO_MODERATION_RULE_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<AutoModerationRule>.self, from: data), let ev = payload.d {
                                eventSink(.autoModerationRuleUpdate(ev))
                            }
                        } else if t == "AUTO_MODERATION_RULE_DELETE" {
                            if let payload = try? dec.decode(GatewayPayload<AutoModerationRule>.self, from: data), let ev = payload.d {
                                eventSink(.autoModerationRuleDelete(ev))
                            }
                        } else if t == "AUTO_MODERATION_ACTION_EXECUTION" {
                            if let payload = try? dec.decode(GatewayPayload<AutoModerationActionExecution>.self, from: data), let ev = payload.d {
                                eventSink(.autoModerationActionExecution(ev))
                            }
                        } else if t == "GUILD_AUDIT_LOG_ENTRY_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<AuditLogEntry>.self, from: data), let ev = payload.d {
                                eventSink(.guildAuditLogEntryCreate(ev))
                            }
                        } else if t == "WEBHOOKS_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<WebhooksUpdate>.self, from: data), let ev = payload.d {
                                eventSink(.webhooksUpdate(ev))
                            }
                        } else if t == "GUILD_INTEGRATIONS_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<GuildIntegrationsUpdate>.self, from: data), let ev = payload.d {
                                eventSink(.guildIntegrationsUpdate(ev))
                            }
                        } else if t == "POLL_VOTE_ADD" {
                            if let payload = try? dec.decode(GatewayPayload<PollVote>.self, from: data), let ev = payload.d {
                                eventSink(.pollVoteAdd(ev))
                            }
                        } else if t == "POLL_VOTE_REMOVE" {
                            if let payload = try? dec.decode(GatewayPayload<PollVote>.self, from: data), let ev = payload.d {
                                eventSink(.pollVoteRemove(ev))
                            }
                        } else if t == "SOUNDBOARD_SOUND_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<SoundboardSound>.self, from: data), let ev = payload.d {
                                eventSink(.soundboardSoundCreate(ev))
                            }
                        } else if t == "SOUNDBOARD_SOUND_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<SoundboardSound>.self, from: data), let ev = payload.d {
                                eventSink(.soundboardSoundUpdate(ev))
                            }
                        } else if t == "SOUNDBOARD_SOUND_DELETE" {
                            if let payload = try? dec.decode(GatewayPayload<SoundboardSound>.self, from: data), let ev = payload.d {
                                eventSink(.soundboardSoundDelete(ev))
                            }
                        } else if t == "ENTITLEMENT_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<Entitlement>.self, from: data), let ev = payload.d {
                                eventSink(.entitlementCreate(ev))
                            }
                        } else if t == "ENTITLEMENT_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<Entitlement>.self, from: data), let ev = payload.d {
                                eventSink(.entitlementUpdate(ev))
                            }
                        } else if t == "ENTITLEMENT_DELETE" {
                            if let payload = try? dec.decode(GatewayPayload<Entitlement>.self, from: data), let ev = payload.d {
                                eventSink(.entitlementDelete(ev))
                            }
                        } else if t == "INVITE_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<InviteCreate>.self, from: data), let ev = payload.d {
                                eventSink(.inviteCreate(ev))
                            }
                        } else if t == "INVITE_DELETE" {
                            if let payload = try? dec.decode(GatewayPayload<InviteDelete>.self, from: data), let ev = payload.d {
                                eventSink(.inviteDelete(ev))
                            }
                        } else {
                            // Unknown events are forwarded as raw payloads so callers still get visibility.
                            eventSink(.raw(t, data))
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
            // Sleep for one interval, then verify the previous heartbeat was acknowledged.
            try? await Task.sleep(nanoseconds: intervalNs)
        }
    }

    private func attemptReconnect() async {
        // Reconnect strategy: drop the current socket without a clean close,
        // then retry with bounded exponential backoff with jitter.
        if !allowReconnect { return }

        // Capture close code before closing so we can detect fatal codes
        let closeCode = await socket?.closeCode
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

    private func fetchGatewayBot() async throws -> GatewayBotResponse {
        let url = configuration.apiBaseURL
            .appendingPathComponent("v\(configuration.apiVersion)")
            .appendingPathComponent("gateway/bot")
        var request = URLRequest(url: url)
        request.setValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
        request.setValue("DiscordBot (https://github.com/M1tsumi/SwiftDisc, \(DiscordConfiguration.version))", forHTTPHeaderField: "User-Agent")

        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DiscordError.gateway("Failed to fetch gateway bot info")
        }
        return try JSONCoders.decoder.decode(GatewayBotResponse.self, from: data)
    }

    func close() async {
        await socket?.close()
        socket = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        status = .disconnected; statusContinuation?.yield(.disconnected)
        statusContinuation?.finish()
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
    func currentSessionId() -> String? { sessionId }
    func currentSeq() -> Int? { seq }
    func incrementResumeCount() { resumeCount += 1 }
    func currentResumeCount() -> Int { resumeCount }
  func getResumeSuccessCount() -> Int { resumeSuccessCount }
  func getResumeFailureCount() -> Int { resumeFailureCount }
  func getLastResumeAttemptAt() -> Date? { lastResumeAttemptAt }
  func getLastResumeSuccessAt() -> Date? { lastResumeSuccessAt }
  func setAllowReconnect(_ allow: Bool) { allowReconnect = allow }

    // MARK: - Gateway send helpers

    private func sendGatewayPayload<T: Encodable & Sendable>(_ payload: GatewayPayload<T>) async throws {
        guard let socket = self.socket else { throw DiscordError.gateway("Socket not connected") }
        let data = try JSONCoders.encoder.encode(payload)
        await rateLimiter.acquire()
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private func sendGatewayData(_ data: Data) async throws {
        guard let socket = self.socket else { throw DiscordError.gateway("Socket not connected") }
        await rateLimiter.acquire()
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
    }
}

// MARK: - Lightweight decode utilities

private struct GatewayOpBox: Codable, Sendable {
    let op: GatewayOpcode
    let t: String?
}

// MARK: - Gateway send rate limiter

/// Enforces Discord's gateway send rate limit: 120 events per 60 seconds.
private actor GatewaySendRateLimiter {
    private var tokens: Double
    private var lastRefill: Date
    private let maxTokens: Double = 120
    private let refillRate: Double = 2.0 // tokens per second (120 per 60s)

    init() {
        self.tokens = maxTokens
        self.lastRefill = Date()
    }

    func acquire() async {
        refill()
        if tokens >= 1 {
            tokens -= 1
            return
        }
        let waitSeconds = (1 - tokens) / refillRate
        try? await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
        refill()
        tokens = max(0, tokens - 1)
    }

    private func refill() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefill)
        tokens = min(maxTokens, tokens + elapsed * refillRate)
        lastRefill = now
    }
}
