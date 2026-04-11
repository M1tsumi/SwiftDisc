import Foundation
import SwiftDisc

/// Example demonstrating a simple Cog that registers a message handler.
struct HelloCog: Cog {
    let name = "HelloCog"

    func onLoad(client: DiscordClient) async throws {
        await client.setOnMessage { message in
            if message.content?.lowercased() == "!hello" {
                do {
                    try await client.sendMessage(channelId: message.channel_id, content: "Hello, \(message.author.username)!")
                } catch {
                    print("Failed to send message: \(error)")
                }
            }
        }
    }

    func onUnload(client: DiscordClient) async throws {
        // Unregistering handlers is left to implementations; this example is illustrative.
    }
}

@main
struct CogExampleBot {
    /// Starts a bot that demonstrates loading a simple Cog extension.
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)

        let manager = ExtensionManager()
        let cog = HelloCog()

        do {
            try await manager.load(cog, client: client)
            try await client.loginAndConnect(intents: [.guilds, .guildMessages, .messageContent])
        } catch {
            print("Failed to start: \(error)")
        }
    }
}
