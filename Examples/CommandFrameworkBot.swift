import Foundation
import SwiftDisc

// Example: a minimal bot showing the CommandRouter usage.
@main
struct CommandFrameworkBot {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? "YOUR_TOKEN_HERE"
        let client = DiscordClient(token: token)

        let router = CommandRouter(prefix: "!")

        router.register("ping") { ctx in
            do {
                try await ctx.message.reply(client: ctx.client, content: "Pong!")
            } catch {
                print("Command 'ping' failed: \(error)")
            }
        }

        // Attach simple message handler to the client's event system.
        client.onMessage = { message in
            await router.handleIfCommand(message: message, client: client)
        }

        do {
            try await client.loginAndConnect(intents: [.guilds, .guildMessages, .messageContent])
            for await _ in client.events { /* keep alive */ }
        } catch {
            print("Client failed to start: \(error)")
        }
    }
}
