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

    // Public: request guild members (OP 8)
    func requestGuildMembers(guildId: GuildID, query: String? = nil, limit: Int? = nil, presences: Bool? = nil, userIds: [UserID]? = nil, nonce: String? = nil) async throws {
        let payload = RequestGuildMembers(d: .init(guild_id: guildId, query: query, limit: limit, presences: presences, user_ids: userIds, nonce: nonce))
        let enc = JSONEncoder()
        let data = try enc.encode(payload)
        try await socket?.send(.string(String(decoding: data, as: UTF8.self)))
    }
    private var status: Status = .disconnected

    private var lastIntents: GatewayIntents = []
    private var lastEventSink: ((DiscordEvent) -> Void)?
    private var lastShard: (index: Int, total: Int)?

    init(token: String, configuration: DiscordConfiguration) {
        self.token = token
        self.configuration = configuration
    }

    // VOICE_STATE_UPDATE (op 4)
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

    func connect(intents: GatewayIntents, shard: (index: Int, total: Int)? = nil, eventSink: @escaping (DiscordEvent) -> Void) async throws {
        guard let url = URL(string: "\(configuration.gatewayBaseURL.absoluteString)?v=\(configuration.apiVersion)&encoding=json") else {
            throw DiscordError.gateway("Invalid gateway URL")
        }

        // Select a WebSocket adapter appropriate for the current platform.
        // URLSessionWebSocketTask is available on Apple platforms and Linux (via FoundationNetworking),
        // and on modern Windows Swift toolchains. Fall back to an
        // UnavailableWebSocketAdapter on unsupported platforms so builds succeed.
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

        // Receive initial HELLO frame from the gateway
        guard case let .string(helloText) = try await socket.receive() else {
            throw DiscordError.gateway("Expected HELLO string frame")
        }
        let helloData = Data(helloText.utf8)
        let hello = try JSONDecoder().decode(GatewayPayload<GatewayHello>.self, from: helloData)
        guard hello.op == .hello, let d = hello.d else { throw DiscordError.gateway("Invalid HELLO payload") }
        heartbeatIntervalMs = d.heartbeat_interval

        // Start heartbeat loop based on negotiated interval
        startHeartbeat()

        // Send Resume when resuming a session, otherwise Identify
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

        // Start read loop for gateway messages
        Task.detached { [weak self] in
            await self?.readLoop(eventSink: eventSink)
        }
        // Wait for READY or RESUMED before returning
        if self.status != .ready {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                self.connectReadyContinuation = cont
            }
        }
    }

    private func readLoop(eventSink: @escaping (DiscordEvent) -> Void) async {
        guard let socket = self.socket else { return }
        let dec = JSONDecoder()
        while true {
            do {
                let msg = try await socket.receive()
                let data: Data
                switch msg {
                case .string(let text): data = Data(text.utf8)
                case .data(let d): data = d
                }
                // capture seq
                if let s = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let seqNum = s["s"] as? Int {
                    self.seq = seqNum
                }
                // Decode opcode first
                if let opBox = try? dec.decode(GatewayOpBox.self, from: data) {
                    switch opBox.op {
                    case .dispatch:
                        guard let t = opBox.t else { continue }
                        if t == "READY" {
                            if let payload = try? dec.decode(GatewayPayload<ReadyEvent>.self, from: data), let ready = payload.d {
                                // capture session id for resume
                                self.sessionId = ready.session_id ?? self.sessionId
                                self.status = .ready
                                eventSink(.ready(ready))
                                if let cont = self.connectReadyContinuation {
                                    self.connectReadyContinuation = nil
                                    cont.resume()
                                }
                            }
                        } else if t == "RESUMED" {
                            // Successful resume
                            self.status = .ready
                            self.resumeSuccessCount += 1
                            self.lastResumeSuccessAt = Date()
                            // No specific event emitted for RESUMED in our public API
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
                        } else {
                            // Fallback: emit raw event for anything not modeled yet
                            eventSink(.raw(t, data))
                        }
                    case .heartbeatAck:
                        awaitingHeartbeatAck = false
                        lastHeartbeatAckAt = Date()
                        break
                    case .invalidSession:
                        // Resume failed; clear session to force new identify next connect
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
                // Non-fatal: skip malformed frame and continue
                _ = error
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
        // Initial jitter before first heartbeat per Discord guidance
        let jitterNs = UInt64.random(in: 0..<UInt64(heartbeatIntervalMs)) * 1_000_000
        try? await Task.sleep(nanoseconds: jitterNs)
        while !Task.isCancelled {
            // If previous heartbeat wasn't ACKed, reconnect
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
            // Wait full interval before next heartbeat and ACK check
            try? await Task.sleep(nanoseconds: intervalNs)
        }
    }

    private func attemptReconnect() async {
        // Basic reconnect: close existing socket and perform a fresh connect
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
        while allowReconnect {
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

    // Presence update
    func setPresence(status: String, activities: [PresenceUpdatePayload.Activity] = [], afk: Bool = false, since: Int? = nil) async {
        guard let socket = self.socket else { return }
        let p = PresenceUpdatePayload(d: .init(since: since, activities: activities, status: status, afk: afk))
        let payload = GatewayPayload(op: .presenceUpdate, d: p, s: nil, t: nil)
        if let data = try? JSONEncoder().encode(payload) {
            try? await socket.send(.string(String(decoding: data, as: UTF8.self)))
        }
    }

    // MARK: - Health accessors
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

// MARK: - Lightweight decoding helpers

private struct GatewayOpBox: Codable {
    let op: GatewayOpcode
    let t: String?
}
