import Foundation

final class GatewayClient {
    private let token: String
    private let configuration: DiscordConfiguration

    private var socket: WebSocketClient?
    private var heartbeatTask: Task<Void, Never>?
    private var heartbeatIntervalMs: Int = 0
    private var seq: Int?
    private var sessionId: String?
    private var awaitingHeartbeatAck = false

    private var lastIntents: GatewayIntents = []
    private var lastEventSink: ((DiscordEvent) -> Void)?

    init(token: String, configuration: DiscordConfiguration) {
        self.token = token
        self.configuration = configuration
    }

    func connect(intents: GatewayIntents, eventSink: @escaping (DiscordEvent) -> Void) async throws {
        let url = URL(string: "\(configuration.gatewayBaseURL.absoluteString)?v=\(configuration.apiVersion)&encoding=json")!

        #if os(Windows)
        let socket: WebSocketClient = UnavailableWebSocketAdapter()
        #else
        let socket: WebSocketClient = URLSessionWebSocketAdapter(url: url)
        #endif
        self.socket = socket
        self.lastIntents = intents
        self.lastEventSink = eventSink

        // 1) Receive HELLO
        guard case let .string(helloText) = try await socket.receive() else {
            throw DiscordError.gateway("Expected HELLO string frame")
        }
        let helloData = Data(helloText.utf8)
        let hello = try JSONDecoder().decode(GatewayPayload<GatewayHello>.self, from: helloData)
        guard hello.op == .hello, let d = hello.d else { throw DiscordError.gateway("Invalid HELLO payload") }
        heartbeatIntervalMs = d.heartbeat_interval

        // 2) Start heartbeat loop
        startHeartbeat()

        // 3) Send Identify
        let identify = IdentifyPayload(token: token, intents: intents.rawValue)
        let identifyPayload = GatewayPayload(op: .identify, d: identify, s: nil, t: nil)
        let enc = JSONEncoder()
        let idData = try enc.encode(identifyPayload)
        try await socket.send(.string(String(decoding: idData, as: UTF8.self)))

        // 4) Start read loop
        Task.detached { [weak self] in
            await self?.readLoop(eventSink: eventSink)
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
                                eventSink(.ready(ready))
                            }
                        } else if t == "MESSAGE_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<Message>.self, from: data), let msg = payload.d {
                                eventSink(.messageCreate(msg))
                            }
                        } else if t == "GUILD_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<Guild>.self, from: data), let guild = payload.d {
                                eventSink(.guildCreate(guild))
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
                        } else if t == "INTERACTION_CREATE" {
                            if let payload = try? dec.decode(GatewayPayload<Interaction>.self, from: data), let interaction = payload.d {
                                eventSink(.interactionCreate(interaction))
                            }
                        }
                    case .heartbeatAck:
                        awaitingHeartbeatAck = false
                        break
                    case .reconnect:
                        // TODO: implement reconnect
                        break
                    default:
                        break
                    }
                }
            } catch {
                // TODO: backoff and reconnect
                await attemptReconnect()
                break
            }
        }
    }

    private func startHeartbeat() {
        let intervalNs = UInt64(heartbeatIntervalMs) * 1_000_000
        heartbeatTask?.cancel()
        heartbeatTask = Task.detached { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let hb = HeartbeatPayload(heartbeat: self.seq)
                    let payload = GatewayPayload(op: .heartbeat, d: hb, s: nil, t: nil)
                    let data = try JSONEncoder().encode(payload)
                    try await self.socket?.send(.string(String(decoding: data, as: UTF8.self)))
                    // mark awaiting ACK; if next tick comes and still awaiting, trigger reconnect
                    self.awaitingHeartbeatAck = true
                } catch {
                    // swallow for now; read loop will handle disconnects
                }
                try? await Task.sleep(nanoseconds: intervalNs)
                if self.awaitingHeartbeatAck {
                    await self.attemptReconnect()
                    break
                }
            }
        }
    }

    private func attemptReconnect() async {
        // Basic reconnect: close existing socket and perform a fresh connect
        await socket?.close()
        socket = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        awaitingHeartbeatAck = false
        let intents = lastIntents
        guard let sink = lastEventSink else { return }
        // naive backoff
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        do {
            try await connect(intents: intents, eventSink: sink)
        } catch {
            // give up for now; future: retry with increasing backoff
        }
    }
}

// MARK: - Lightweight decoding helpers

private struct GatewayOpBox: Codable {
    let op: GatewayOpcode
    let t: String?
}
