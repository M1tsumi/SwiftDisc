import Foundation

actor GatewayClient {
    private let token: String
    private let configuration: DiscordConfiguration

    private var socket: WebSocketClient?
    private var heartbeatTask: Task<Void, Never>?
    private var heartbeatIntervalMs: Int = 0
    private var seq: Int?
    private var sessionId: String?
    private var awaitingHeartbeatAck = false
    private var lastHeartbeatSentAt: Date?
    private var lastHeartbeatAckAt: Date?
    private var resumeCount: Int = 0
    private var resumeSuccessCount: Int = 0
    private var resumeFailureCount: Int = 0
    private var lastResumeAttemptAt: Date?
    private var lastResumeSuccessAt: Date?
    private var allowReconnect: Bool = true
    private var connectReadyContinuation: CheckedContinuation<Void, Never>?

    enum Status {
        case disconnected
        case connecting
        case identifying
        case ready
        case resuming
        case reconnecting
    }

    // Gateway OP 8 entry point for member chunk requests.
    func requestGuildMembers(guildId: GuildID, query: String? = nil, limit: Int? = nil, presences: Bool? = nil, userIds: [UserID]? = nil, nonce: String? = nil) async throws {
        let payload = RequestGuildMembers(d: .init(guild_id: guildId, query: query, limit: limit, presences: presences, user_ids: userIds, nonce: nonce))
        let enc = JSONEncoder()
        let data = try enc.encode(payload)
        try await socket?.send(.string(String(decoding: data, as: UTF8.self)))
    }
    private var status: Status = .disconnected

    private var lastIntents: GatewayIntents = []
    private var lastEventSink: (@Sendable (DiscordEvent) -> Void)?
    private var lastShard: (index: Int, total: Int)?

    init(token: String, configuration: DiscordConfiguration) {
        self.token = token
        self.configuration = configuration
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

    // Sends VOICE_STATE_UPDATE (OP 4) to join, move, or leave voice channels.
    func updateVoiceState(guildId: GuildID, channelId: ChannelID?, selfMute: Bool, selfDeaf: Bool) async {
        struct VoiceStateUpdateData: Codable {
            let guild_id: GuildID
            let channel_id: ChannelID?
            let self_mute: Bool
            let self_deaf: Bool
        }
        let payload = GatewayPayload(op: .voiceStateUpdate, d: VoiceStateUpdateData(guild_id: guildId, channel_id: channelId, self_mute: selfMute, self_deaf: selfDeaf), s: nil, t: nil)
        if let data = try? JSONEncoder().encode(payload) {
            try? await socket?.send(.string(String(decoding: data, as: UTF8.self)))
        }
    }

    func connect(intents: GatewayIntents, shard: (index: Int, total: Int)? = nil, eventSink: @escaping @Sendable (DiscordEvent) -> Void) async throws {
        guard var components = URLComponents(url: configuration.gatewayBaseURL, resolvingAgainstBaseURL: false) else {
            throw DiscordError.gateway("Invalid gateway URL")
        }
        components.queryItems = [
            URLQueryItem(name: "v", value: String(configuration.apiVersion)),
            URLQueryItem(name: "encoding", value: "json")
        ]
        guard let url = components.url else {
            throw DiscordError.gateway("Failed to construct gateway URL")
        }

        // Pick the best adapter for the current platform.
        // URLSessionWebSocketTask is available on Apple platforms, Linux (FoundationNetworking),
        // and modern Windows toolchains. Unsupported targets use the unavailable adapter so
        // the package still compiles with clear runtime behavior.
        #if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(Windows)
        let socket: WebSocketClient = URLSessionWebSocketAdapter(url: url)
        #else
        let socket: WebSocketClient = UnavailableWebSocketAdapter()
        #endif
        self.socket = socket
        self.lastIntents = intents
        self.lastEventSink = eventSink
        self.lastShard = shard
        self.status = .connecting

        // The first frame must be HELLO because it carries the heartbeat interval.
        guard case let .string(helloText) = try await socket.receive() else {
            throw DiscordError.gateway("Expected HELLO string frame")
        }
        let helloData = Data(helloText.utf8)
        let hello = try JSONDecoder().decode(GatewayPayload<GatewayHello>.self, from: helloData)
        guard hello.op == .hello, let d = hello.d else { throw DiscordError.gateway("Invalid HELLO payload") }
        heartbeatIntervalMs = d.heartbeat_interval

        // Start heartbeats using the interval negotiated by Discord.
        startHeartbeat()

        // Resume when we have a saved session, otherwise perform a fresh identify.
        let enc = JSONEncoder()
        if let sessionId, let seq {
            self.status = .resuming
            self.lastResumeAttemptAt = Date()
            let resume = ResumePayload(token: token, session_id: sessionId, seq: seq)
            let payload = GatewayPayload(op: .resume, d: resume, s: nil, t: nil)
            let data = try enc.encode(payload)
            try await socket.send(.string(String(decoding: data, as: UTF8.self)))
        } else {
            self.status = .identifying
            let shardArray: [Int]? = shard.map { [$0.index, $0.total] }
            let identify = IdentifyPayload(token: token, intents: intents.rawValue, properties: .default, compress: nil, large_threshold: nil, shard: shardArray)
            let payload = GatewayPayload(op: .identify, d: identify, s: nil, t: nil)
            let data = try enc.encode(payload)
            try await socket.send(.string(String(decoding: data, as: UTF8.self)))
        }

        // Read loop stays detached so connect() can return once READY/RESUMED arrives.
        Task.detached { [weak self] in
            await self?.readLoop(eventSink: eventSink)
        }
        // Wait until the socket is actually usable before returning to callers.
        if self.status != .ready {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30 second timeout
                    throw DiscordError.gateway("Connection timeout")
                }
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    await self.withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                        self.connectReadyContinuation = cont
                    }
                }
                try await group.next()
                group.cancelAll()
            }
        }
    }

    private func readLoop(eventSink: @escaping @Sendable (DiscordEvent) -> Void) async {
        guard let socket = self.socket else { return }
        let dec = JSONDecoder()
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
                if let seqBox = try? dec.decode([String: Int].self, from: data), let seqNum = seqBox["s"] {
                    self.seq = seqNum
                }
                // Decode opcode first, then dispatch by event name when needed.
                if let opBox = try? dec.decode(GatewayOpBox.self, from: data) {
                    switch opBox.op {
                    case .dispatch:
                        guard let t = opBox.t else { continue }
                        if t == "READY" {
                            if let payload = try? dec.decode(GatewayPayload<ReadyEvent>.self, from: data), let ready = payload.d {
                                // Save session ID so reconnects can try RESUME.
                                self.sessionId = ready.session_id ?? self.sessionId
                                self.status = .ready
                                eventSink(.ready(ready))
                                if let cont = self.connectReadyContinuation {
                                    self.connectReadyContinuation = nil
                                    cont.resume()
                                }
                            }
                        } else if t == "RESUMED" {
                            // RESUME accepted; keep the same session.
                            self.status = .ready
                            self.resumeSuccessCount += 1
                            self.lastResumeSuccessAt = Date()
                            // We do not expose a dedicated RESUMED event in the public API.
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
                        } else if t == "INTERACTION_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<Interaction>.self, from: data), let interaction = payload.d {
                                eventSink(.interactionCreate(interaction))
                            } else {
                                // Preserve visibility when payload shape drifts instead of silently dropping.
                                logDecodeDiagnostic("Failed to decode INTERACTION_CREATE as Interaction (op=\(opBox.op.rawValue), seq=\(String(describing: self.seq)))", data: data)
                                eventSink(.raw(t, data))
                            }
                        } else if t == "VOICE_STATE_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<VoiceState>.self, from: data), let state = payload.d {
                                eventSink(.voiceStateUpdate(state))
                            }
                        } else if t == "VOICE_SERVER_UPDATE" {
                            if let payload = try? dec.decode(GatewayPayload<VoiceServerUpdate>.self, from: data), let vsu = payload.d {
                                eventSink(.voiceServerUpdate(vsu))
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
                    case .heartbeatAck:
                        awaitingHeartbeatAck = false
                        lastHeartbeatAckAt = Date()
                        break
                    case .invalidSession:
                        // Resume was rejected. Clear session state so next connect uses IDENTIFY.
                        self.resumeFailureCount += 1
                        self.sessionId = nil
                        self.seq = nil
                        await attemptReconnect()
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
        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            await self.runHeartbeatLoop()
        }
    }

    private func runHeartbeatLoop() async {
        let intervalNs = UInt64(heartbeatIntervalMs) * 1_000_000
        // Discord recommends jitter before the first heartbeat to avoid thundering herd reconnects.
        let jitterNs = UInt64.random(in: 0..<UInt64(heartbeatIntervalMs)) * 1_000_000
        try? await Task.sleep(nanoseconds: jitterNs)
        while !Task.isCancelled {
            // Missing ACK usually means a stale socket; reconnect early.
            if awaitingHeartbeatAck {
                await attemptReconnect()
                break
            }
            do {
                let hb: HeartbeatPayload = seq
                let payload = GatewayPayload(op: .heartbeat, d: hb, s: nil, t: nil)
                let data = try JSONEncoder().encode(payload)
                try await socket?.send(.string(String(decoding: data, as: UTF8.self)))
                awaitingHeartbeatAck = true
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
        // Reconnect strategy: close current socket, then retry with bounded exponential backoff.
        if !allowReconnect { return }
        await socket?.close()
        socket = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        awaitingHeartbeatAck = false
        status = .reconnecting
        let intents = lastIntents
        guard let sink = lastEventSink else { return }
        var delay: UInt64 = 500_000_000
        var attemptCount = 0
        let maxAttempts = 10
        while allowReconnect && attemptCount < maxAttempts {
            attemptCount += 1
            try? await Task.sleep(nanoseconds: delay)
            do {
                try await connect(intents: intents, shard: lastShard, eventSink: sink)
                return
            } catch {
                delay = min(delay * 2, 16_000_000_000)
                continue
            }
        }
    }

    func close() async {
        await socket?.close()
        socket = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        status = .disconnected
    }

    // Sends a gateway presence update payload for status/activity changes.
    func setPresence(status: String, activities: [PresenceUpdatePayload.Activity] = [], afk: Bool = false, since: Int? = nil) async {
        guard let socket = self.socket else { return }
        let p = PresenceUpdatePayload(d: .init(since: since, activities: activities, status: status, afk: afk))
        let payload = GatewayPayload(op: .presenceUpdate, d: p, s: nil, t: nil)
        if let data = try? JSONEncoder().encode(payload) {
            try? await socket.send(.string(String(decoding: data, as: UTF8.self)))
        }
    }

    // MARK: - Health and telemetry accessors
    func heartbeatLatency() -> TimeInterval? {
        guard let sent = lastHeartbeatSentAt, let ack = lastHeartbeatAckAt else { return nil }
        return ack.timeIntervalSince(sent)
    }

    func currentStatus() -> Status { status }
    func currentSessionId() -> String? { sessionId }
    func currentSeq() -> Int? { seq }
    func incrementResumeCount() { resumeCount += 1 }
    func currentResumeCount() -> Int { resumeCount }
  func getResumeSuccessCount() -> Int { resumeSuccessCount }
  func getResumeFailureCount() -> Int { resumeFailureCount }
  func getLastResumeAttemptAt() -> Date? { lastResumeAttemptAt }
  func getLastResumeSuccessAt() -> Date? { lastResumeSuccessAt }
  func setAllowReconnect(_ allow: Bool) { allowReconnect = allow }
}

// MARK: - Lightweight decode utilities

private struct GatewayOpBox: Codable {
    let op: GatewayOpcode
    let t: String?
}
