//
//  ShardManager.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public final class ShardManager {
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
                    for await _ in client.events { /* keep alive per shard */ }
                }
            }
            try await group.waitForAll()
        }
    }
}
