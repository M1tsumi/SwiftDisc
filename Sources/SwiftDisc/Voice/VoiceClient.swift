import Foundation
#if canImport(Network)
import Network
#endif

final class VoiceClient {
    private let token: String
    private let configuration: DiscordConfiguration
    private let sendVoiceStateUpdate: (GuildID, ChannelID?, Bool, Bool) async -> Void

    private struct Session {
        var guildId: GuildID
        var channelId: ChannelID?
        var sessionId: String?
        var endpoint: String?
        var token: String?
        var voiceGateway: VoiceGateway?
        var udpPort: UInt16?
        var ssrc: UInt32?
        var secretKey: [UInt8]?
        var discoveredIP: String?
        var sender: RTPVoiceSender?
        var receiver: RTPVoiceReceiver?
    }

    private var sessions: [GuildID: Session] = [:]
    private var botUserId: UserID?
    private var onFrame: ((VoiceFrame) -> Void)?

    init(token: String, configuration: DiscordConfiguration, sendVoiceStateUpdate: @escaping (GuildID, ChannelID?, Bool, Bool) async -> Void) {
        self.token = token
        self.configuration = configuration
        self.sendVoiceStateUpdate = sendVoiceStateUpdate
    }

    func setOnFrame(_ handler: @escaping (VoiceFrame) -> Void) {
        self.onFrame = handler
    }

    func joinVoiceChannel(guildId: GuildID, channelId: ChannelID, selfMute: Bool = false, selfDeaf: Bool = false) async throws {
        // Send VOICE_STATE_UPDATE; events will arrive and handled by onVoiceStateUpdate/onVoiceServerUpdate
        await sendVoiceStateUpdate(guildId, channelId, selfMute, selfDeaf)
        // Initialize session bucket
        if sessions[guildId] == nil {
            sessions[guildId] = Session(guildId: guildId, channelId: channelId, sessionId: nil, endpoint: nil, token: nil, voiceGateway: nil, udpPort: nil, ssrc: nil, secretKey: nil, discoveredIP: nil, sender: nil, receiver: nil)
        } else {
            sessions[guildId]?.channelId = channelId
        }
    }

    func leaveVoiceChannel(guildId: GuildID) async throws {
        await sendVoiceStateUpdate(guildId, nil, false, false)
        if var sess = sessions[guildId] {
            sess.receiver?.stop()
            sess.receiver = nil
            sess.voiceGateway = nil
            sessions[guildId] = sess
        }
    }

    func playOpusFrames(guildId: GuildID, pcmOrOpusData: Data) async throws {
        guard var sess = sessions[guildId], let ssrc = sess.ssrc, let key = sess.secretKey, let host = sess.discoveredIP, let port = sess.udpPort else {
            throw VoiceError.notImplemented("Voice session not ready (no key/ssrc/ip/port)")
        }
        if sess.sender == nil {
            let encryptor = Secretbox()
            sess.sender = RTPVoiceSender(ssrc: ssrc, key: key, host: host, port: port, encryptor: encryptor)
            sessions[guildId] = sess
        }
        await sess.sender?.sendOpusFrame(pcmOrOpusData)
    }

    // Stream from a source producing Opus frames
    func play(source: VoiceAudioSource, guildId: GuildID) async throws {
        while let frame = try await source.nextFrame() {
            try await playOpusFrames(guildId: guildId, pcmOrOpusData: frame.data)
            // Pace according to frame duration
            try? await Task.sleep(nanoseconds: UInt64(frame.durationMs) * 1_000_000)
        }
    }

    // MARK: - Event handlers from main gateway
    func onVoiceStateUpdate(_ state: VoiceState) async {
        guard let gid = state.guild_id, var sess = sessions[gid] else { return }
        // Only care about our own bot's voice state
        if let my = botUserId, state.user_id != my { return }
        // Capture session_id for the bot user
        let sid = state.session_id
        sess.sessionId = sid
        sessions[gid] = sess
        await tryBeginVoiceHandshakeIfReady(guildId: sess.guildId)
    }

    func onVoiceServerUpdate(_ vsu: VoiceServerUpdate, botUserId: UserID) async {
        self.botUserId = botUserId
        var sess = sessions[vsu.guild_id] ?? Session(guildId: vsu.guild_id, channelId: nil, sessionId: nil, endpoint: nil, token: nil, voiceGateway: nil, udpPort: nil, ssrc: nil, secretKey: nil, discoveredIP: nil, sender: nil, receiver: nil)
        sess.endpoint = vsu.endpoint
        sess.token = vsu.token
        sessions[vsu.guild_id] = sess
        await tryBeginVoiceHandshakeIfReady(guildId: vsu.guild_id, botUserId: botUserId)
    }

    // MARK: - Handshake orchestration
    private func tryBeginVoiceHandshakeIfReady(guildId: GuildID, botUserId: UserID? = nil) async {
        guard var sess = sessions[guildId] else { return }
        guard let endpoint = sess.endpoint, let token = sess.token, let sessionId = sess.sessionId, let userId = botUserId else { return }

        let vg = VoiceGateway()
        do {
            try await vg.connect(endpoint: endpoint, guildId: guildId, userId: userId, sessionId: sessionId, token: token)
            sess.voiceGateway = vg
            sess.udpPort = vg.udpPort
            sess.ssrc = vg.ssrc
            sessions[guildId] = sess

            // Perform UDP IP discovery using Network.framework (Apple platforms)
            if let discovered = try await udpIPDiscovery(host: endpoint, port: vg.udpPort, ssrc: vg.ssrc) {
                try await vg.selectProtocol(ip: discovered.ip, port: discovered.port)
                // Waited session description inside selectProtocol; store key
                sess.secretKey = vg.secretKey
                sess.discoveredIP = discovered.ip
                // Prepare RTP sender on demand in playOpusFrames
                sessions[guildId] = sess
                await vg.setSpeaking(speaking: true)
                startReceiverIfPossible(guildId: guildId)
            }
        } catch {
            // For now, swallow; TODO: surface via logging callback
        }
    }

    private func startReceiverIfPossible(guildId: GuildID) {
        guard var sess = sessions[guildId] else { return }
        guard let key = sess.secretKey, let host = sess.discoveredIP, let port = sess.udpPort, let ssrc = sess.ssrc else { return }
        sess.receiver?.stop()
        let receiver = RTPVoiceReceiver(ssrc: ssrc, key: key, host: host, port: port) { [weak self] sequence, timestamp, opus in
            guard let self, let handler = self.onFrame else { return }
            let frame = VoiceFrame(guildId: guildId, ssrc: ssrc, sequence: sequence, timestamp: timestamp, opus: opus)
            handler(frame)
        }
        sess.receiver = receiver
        sessions[guildId] = sess
        receiver.start()
    }

    private func udpIPDiscovery(host: String, port: UInt16, ssrc: UInt32) async throws -> (ip: String, port: UInt16)? {
        #if canImport(Network)
        // Resolve host without protocol
        let cleanHost = host.replacingOccurrences(of: ":\\d+", with: "", options: .regularExpression)
        let params = NWParameters.udp
        let endpoint = NWEndpoint.hostPort(host: .name(cleanHost, nil), port: NWEndpoint.Port(rawValue: port)!)
        let conn = NWConnection(to: endpoint, using: params)

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(ip: String, port: UInt16)?, Error>) in
                conn.stateUpdateHandler = { state in
                    if case .ready = state {
                        // Build 70-byte packet: first 4 bytes ssrc (big endian), rest zeros
                        var pkt = Data(count: 70)
                        var beSSRC = ssrc.bigEndian
                        withUnsafeBytes(of: &beSSRC) { pkt.replaceSubrange(0..<4, with: $0) }
                        conn.send(content: pkt, completion: .contentProcessed { _ in
                            conn.receive(minimumIncompleteLength: 70, maximumLength: 70) { data, _, _, _ in
                                guard let data, data.count >= 70 else {
                                    cont.resume(returning: nil); return
                                }
                                // Bytes 4..68 contain null-terminated string ip
                                let ipData = data.subdata(in: 4..<68)
                                let ip = ipData.withUnsafeBytes { raw -> String in
                                    let ptr = raw.bindMemory(to: UInt8.self).baseAddress!
                                    return String(cString: ptr)
                                }
                                // Last 2 bytes little-endian port
                                let pLo = UInt16(data[68])
                                let pHi = UInt16(data[69])
                                let portLE = pLo | (pHi << 8)
                                cont.resume(returning: (ip: ip, port: portLE))
                            }
                        })
                    }
                }
                conn.start(queue: .global())
            }
        }, onCancel: {
            conn.cancel()
        })
        #else
        return nil
        #endif
    }
}
