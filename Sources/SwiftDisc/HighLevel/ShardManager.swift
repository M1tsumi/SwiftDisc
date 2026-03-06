import Foundation

/// A lightweight manager that owns N `DiscordClient` instances, one per shard.
/// Declared as an `actor` so the `clients` array is safely accessible from
/// concurrent contexts.
public actor ShardManager {
    public let token: String
    public let totalShards: Int
    public let configuration: DiscordConfiguration

    public private(set) var clients: [DiscordClient] = []

    public init(token: String, totalShards: Int, configuration: DiscordConfiguration = .init()) {
        self.token = token
        self.totalShards = totalShards
        self.configuration = configuration
        self.clients = (0..<totalShards).map { _ in DiscordClient(token: token, configuration: configuration) }
    }

    public func start(intents: GatewayIntents) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (idx, client) in clients.enumerated() {
                group.addTask {
                    try await client.loginAndConnectSharded(index: idx, total: self.totalShards, intents: intents)
                    let eventStream = await client.events
                    for await _ in eventStream { /* keep shard task alive */ }
                }
            }
            try await group.waitForAll()
        }
    }
}
