import SwiftDisc
import Foundation

@main
struct SlashBotMain {
    /// Starts a slash-command bot with sample ping and echo commands.
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? "YOUR_BOT_TOKEN"
        let client = DiscordClient(token: token)

        // Register slash commands on startup (global example)
        Task {
            do {
                try await client.createGlobalCommand(name: "ping", description: "Replies with Pong!")
                let echoOption = DiscordClient.ApplicationCommandOption(type: .string, name: "text", description: "Text to echo", required: false)
                try await client.createGlobalCommand(name: "echo", description: "Echo back text", options: [echoOption])
            } catch {
                print("Failed to create global commands: \(error)")
            }
        }

        // Wire slash router
        let slash = SlashCommandRouter()
        await slash.register("ping") { ctx in
            do {
                try await ctx.client.createInteractionResponse(interactionId: ctx.interaction.id, token: ctx.interaction.token, content: "Pong!")
            } catch {
                print("Slash command 'ping' handler failed: \(error)")
            }
        }
        await slash.register("echo") { ctx in
            let text = ctx.option("text") ?? "(no text)"
            do {
                try await ctx.client.createInteractionResponse(interactionId: ctx.interaction.id, token: ctx.interaction.token, content: text)
            } catch {
                print("Slash command 'echo' handler failed: \(error)")
            }
        }
        await client.useSlashCommands(slash)

        await client.setOnReady { info in
            print("✅ Connected as: \(info.user.username)")
        }

        do {
            try await client.loginAndConnect(intents: [.guilds])
            let events = await client.events
            for await _ in events { /* keep alive */ }
        } catch {
            print("❌ Error: \(error)")
        }
    }
}
