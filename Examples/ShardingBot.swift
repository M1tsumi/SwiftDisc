import SwiftDisc
import Foundation

@main
struct ShardingBotMain {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? "YOUR_BOT_TOKEN"

        let config = ShardingGatewayManager.Configuration(
            shardCount: .automatic,
            identifyConcurrency: .respectDiscordLimits,
            connectionDelay: .staggered(interval: 5.0)
        )

        let manager = ShardingGatewayManager(
            token: token,
            configuration: config,
            intents: [.guilds, .guildMessages, .messageContent],
            presence: ShardingGatewayManager.Configuration.PresenceConfig(
                activities: [
                    .init(name: "with shards", type: 0)
                ],
                status: "online",
                afk: false
            )
        )

        // Monitor shard health periodically
        Task {
            while true {
                let health = await manager.healthCheck()
                print("Health: \(health.readyShards)/\(health.totalShards) shards ready, \(health.totalGuilds) guilds")
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }

        // Monitor events with shard metadata
        Task {
            for await event in manager.events {
                print("[Shard \(event.shardId)] \(event.event)")
            }
        }

        do {
            try await manager.connect()
            // Keep the process alive
            while true {
                try await Task.sleep(nanoseconds: UInt64.max)
            }
        } catch {
            print("Sharding manager failed: \(error)")
        }
    }
}
