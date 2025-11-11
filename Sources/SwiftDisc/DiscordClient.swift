import Foundation

public final class DiscordClient {
    public let token: String
    private let http: HTTPClient
    private let gateway: GatewayClient

    private var eventStream: AsyncStream<DiscordEvent>!
    private var eventContinuation: AsyncStream<DiscordEvent>.Continuation!

    public let cache = Cache()

    public var events: AsyncStream<DiscordEvent> { eventStream }

    public init(token: String, configuration: DiscordConfiguration = .init()) {
        self.token = token
        self.http = HTTPClient(token: token, configuration: configuration)
        self.gateway = GatewayClient(token: token, configuration: configuration)

        var localContinuation: AsyncStream<DiscordEvent>.Continuation!
        self.eventStream = AsyncStream<DiscordEvent> { continuation in
            continuation.onTermination = { _ in }
            localContinuation = continuation
        }
        self.eventContinuation = localContinuation
    }

    public func loginAndConnect(intents: GatewayIntents) async throws {
        try await gateway.connect(intents: intents, eventSink: { [weak self] event in
            guard let self = self else { return }
            Task { [weak self] in
                guard let self = self else { return }
                // Minimal cache updates
                switch event {
                case .ready(let info):
                    await self.cache.upsert(user: info.user)
                case .messageCreate(let msg):
                    await self.cache.upsert(user: msg.author)
                    await self.cache.upsert(channel: Channel(id: msg.channel_id, type: 0, name: nil))
                case .guildCreate(let guild):
                    await self.cache.upsert(guild: guild)
                case .channelCreate(let channel), .channelUpdate(let channel):
                    await self.cache.upsert(channel: channel)
                case .channelDelete(let channel):
                    await self.cache.removeChannel(id: channel.id)
                case .interactionCreate(let interaction):
                    if let cid = interaction.channel_id {
                        await self.cache.upsert(channel: Channel(id: cid, type: 0, name: nil))
                    }
                }
                self.eventContinuation?.yield(event)
            }
        })
    }

    public func getCurrentUser() async throws -> User {
        try await http.get(path: "/users/@me")
    }

    public func sendMessage(channelId: Snowflake, content: String) async throws -> Message {
        struct Body: Encodable { let content: String }
        return try await http.post(path: "/channels/\(channelId)/messages", body: Body(content: content))
    }
}
