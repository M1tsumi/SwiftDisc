import SwiftDisc
import Foundation

@main
struct PingBotMain {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? "YOUR_BOT_TOKEN"
        let client = DiscordClient(token: token)

        await client.onReady = { info in
            print("✅ Connected as: \(info.user.username)")
        }

        await client.onMessage = { msg in
            if msg.content?.lowercased() == "ping" {
                do {
                    try await client.sendMessage(channelId: msg.channel_id, content: "Pong!")
                } catch {
                    print("Failed to send Pong: \(error)")
                }
            }
        }

        do {
            try await client.loginAndConnect(intents: [.guilds, .guildMessages, .messageContent])
            let events = await client.events
            for await _ in events { /* keep alive */ }
        } catch {
            print("❌ Error: \(error)")
        }
    }
}
