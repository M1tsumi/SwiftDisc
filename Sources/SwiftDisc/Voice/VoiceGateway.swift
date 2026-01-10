//
//  VoiceGateway.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

final class VoiceGateway {
    struct Hello: Codable { let heartbeat_interval: Int }
    struct Ready: Codable { let ssrc: UInt32; let port: UInt16; let modes: [String] }
    struct SessionDescription: Codable { let mode: String; let secret_key: [UInt8] }

    enum Op: Int, Codable { case identify = 0, selectProtocol = 1, ready = 2, heartbeat = 3, sessionDescription = 4, speaking = 5, heartbeatAck = 6, resume = 7, hello = 8, resumed = 9, clientDisconnect = 13 }

    struct Payload<D: Codable>: Codable { let op: Op; let d: D }

    private var ws: WebSocketClient?
    private var hbTask: Task<Void, Never>?

    private(set) var ssrc: UInt32 = 0
    private(set) var udpPort: UInt16 = 0
    private(set) var modes: [String] = []
    private(set) var secretKey: [UInt8]?

    func connect(endpoint: String, guildId: GuildID, userId: UserID, sessionId: String, token: String) async throws {
        // Endpoint may not include protocol; ensure wss:// prefix
        let urlString = endpoint.starts(with: "wss://") ? endpoint : "wss://\(endpoint)"
        guard let url = URL(string: urlString + "?v=4") else { throw DiscordError.gateway("Invalid voice endpoint URL") }
        let sock = URLSessionWebSocketAdapter(url: url)
        self.ws = sock

        // Receive initial HELLO frame from the voice gateway
        guard case let .string(helloText) = try await sock.receive() else { throw DiscordError.gateway("Expected voice HELLO") }
        let hello = try JSONDecoder().decode(Payload<Hello>.self, from: Data(helloText.utf8))
        guard hello.op == .hello else { throw DiscordError.gateway("Invalid voice HELLO op") }
        startHeartbeat(intervalMs: hello.d.heartbeat_interval)

        // Send Identify payload with guild, user, and session information
        struct Identify: Codable { let server_id: GuildID; let user_id: UserID; let session_id: String; let token: String }
        let identify = Payload(op: .identify, d: Identify(server_id: guildId, user_id: userId, session_id: sessionId, token: token))
        let enc = JSONEncoder()
        try await sock.send(.string(String(decoding: try enc.encode(identify), as: UTF8.self)))

        // Wait for READY and capture voice connection parameters
        guard case let .string(readyText) = try await sock.receive() else { throw DiscordError.gateway("Expected voice READY") }
        let ready = try JSONDecoder().decode(Payload<Ready>.self, from: Data(readyText.utf8))
        guard ready.op == .ready else { throw DiscordError.gateway("Invalid voice READY op") }
        self.ssrc = ready.d.ssrc
        self.udpPort = ready.d.port
        self.modes = ready.d.modes
    }

    func selectProtocol(ip: String, port: UInt16, mode: String = "xsalsa20_poly1305") async throws {
        guard let ws else { throw DiscordError.gateway("Voice socket not connected") }
        struct SelectData: Codable { let address: String; let port: UInt16; let mode: String }
        struct Select: Codable { let protocol_: String; let data: SelectData; enum CodingKeys: String, CodingKey { case protocol_ = "protocol"; case data } }
        let payload = Payload(op: .selectProtocol, d: Select(protocol_: "udp", data: SelectData(address: ip, port: port, mode: mode)))
        try await ws.send(.string(String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)))

        // Await SessionDescription to obtain the voice encryption key
        guard case let .string(sdText) = try await ws.receive() else { throw DiscordError.gateway("Expected SESSION_DESCRIPTION") }
        let sd = try JSONDecoder().decode(Payload<SessionDescription>.self, from: Data(sdText.utf8))
        guard sd.op == .sessionDescription else { throw DiscordError.gateway("Invalid SESSION_DESCRIPTION op") }
        self.secretKey = sd.d.secret_key
    }

    func setSpeaking(speaking: Bool, delay: Int = 0) async {
        guard let ws else { return }
        struct SpeakingData: Codable { let speaking: Int; let delay: Int; let ssrc: UInt32 }
        let data = SpeakingData(speaking: speaking ? 1 : 0, delay: delay, ssrc: ssrc)
        let payload = Payload(op: .speaking, d: data)
        if let bytes = try? JSONEncoder().encode(payload) {
            try? await ws.send(.string(String(decoding: bytes, as: UTF8.self)))
        }
    }

    private func startHeartbeat(intervalMs: Int) {
        hbTask?.cancel()
        hbTask = Task.detached { [weak self] in
            guard let self else { return }
            let intervalNs = UInt64(intervalMs) * 1_000_000
            while !Task.isCancelled {
                struct HB: Codable { let nonce: Int }
                let payload = Payload(op: .heartbeat, d: HB(nonce: Int(Date().timeIntervalSince1970)))
                if let data = try? JSONEncoder().encode(payload) {
                    try? await self.ws?.send(.string(String(decoding: data, as: UTF8.self)))
                }
                try? await Task.sleep(nanoseconds: intervalNs)
            }
        }
    }

    deinit { hbTask?.cancel() }
}
