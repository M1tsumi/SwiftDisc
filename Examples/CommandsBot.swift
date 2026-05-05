import SwiftDisc
import Foundation

@main
struct CommandsBotMain {
    /// Starts a command-based bot with ping, echo, and help handlers.
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? "YOUR_BOT_TOKEN"
        let client = DiscordClient(token: token)

        // Set up command router with a 'ping' and 'help' command
        let router = CommandRouter(prefix: "!")
        await router.register(name: "ping", description: "Replies with Pong!") { ctx in
            do {
                _ = try await ctx.client.sendMessage(channelId: ctx.message.channel_id, content: "Pong!")
            } catch {
                print("Command 'ping' failed: \(error)")
            }
        }
        await router.register(name: "echo", description: "Echoes back your text") { ctx in
            let text = ctx.args.joined(separator: " ")
            do {
                _ = try await ctx.client.sendMessage(channelId: ctx.message.channel_id, content: text.isEmpty ? "(no text)" : text)
            } catch {
                print("Command 'echo' failed: \(error)")
            }
        }
        await router.register(name: "help", description: "Shows this help text") { ctx in
            let help = await router.helpText()
            for chunk in BotUtils.chunkMessage(help) {
                do {
                    _ = try await ctx.client.sendMessage(channelId: ctx.message.channel_id, content: chunk)
                } catch {
                    print("Command 'help' chunk send failed: \(error)")
                }
            }
        }
        await client.useCommands(router)

        await client.setOnReady { info in
            print("✅ Connected as: \(info.user.username)")
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
