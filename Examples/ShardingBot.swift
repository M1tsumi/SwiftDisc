import SwiftDisc
import Foundation

@main
struct ShardingBotMain {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? "YOUR_BOT_TOKEN"
        let client = DiscordClient(token: token)

        // Observe connection state across all shards
        await client.setOnReady { info in
            print("Shard ready as: \(info.user.username)")
        }

        // Use the connection state stream to monitor gateway lifecycle
        Task {
            for await state in await client.connectionState {
                switch state {
                case .ready:
                    print("Gateway ready — bot is receiving events")
                case .reconnecting:
                    print("Gateway reconnecting...")
                case .disconnected:
                    print("Gateway disconnected")
                default:
                    break
                }
            }
        }

        // Connect as shard 0 of 2 total shards
        // In production, determine shard count via gateway/bot endpoint
        do {
            try await client.loginAndConnectSharded(
                index: 0,
                total: 2,
                intents: [.guilds, .guildMessages, .messageContent]
            )
            let events = await client.events
            for await _ in events { }
        } catch {
            print("Connection error: \(error)")
        }
    }
}
