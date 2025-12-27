import Foundation
import SwiftDisc

// Example: a minimal bot showing the CommandRouter usage.
@main
struct CommandFrameworkBot {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] ?? "YOUR_TOKEN_HERE"
        let client = DiscordClient(token: token)

        let router = CommandRouter(prefix: "!")

        router.register("ping") { ctx in
            try? await ctx.reply("Pong!")
        }

        // Attach simple message handler to the client's event system.
        client.onMessageCreate { message in
            await router.processMessage(message)
        }

        do {
            try await client.start()
        } catch {
            print("Client failed to start: \(error)")
        }
    }
}
