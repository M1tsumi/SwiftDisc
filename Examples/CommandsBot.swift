//
//  CommandsBot.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import SwiftDisc
import Foundation

@main
struct CommandsBotMain {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] ?? "YOUR_BOT_TOKEN"
        let client = DiscordClient(token: token)

        // Set up command router with a 'ping' and 'help' command
        let router = CommandRouter(prefix: "!")
        router.register("ping", description: "Replies with Pong!") { ctx in
            _ = try await ctx.client.sendMessage(channelId: ctx.message.channel_id, content: "Pong!")
        }
        router.register("echo", description: "Echoes back your text") { ctx in
            let text = ctx.args.joined(separator: " ")
            _ = try await ctx.client.sendMessage(channelId: ctx.message.channel_id, content: text.isEmpty ? "(no text)" : text)
        }
        router.register("help", description: "Shows this help text") { ctx in
            let help = router.helpText()
            for chunk in BotUtils.chunkMessage(help) {
                _ = try await ctx.client.sendMessage(channelId: ctx.message.channel_id, content: chunk)
            }
        }
        client.useCommands(router)

        client.onReady = { info in
            print("✅ Connected as: \(info.user.username)")
        }

        do {
            try await client.loginAndConnect(intents: [.guilds, .guildMessages, .messageContent])
            for await _ in client.events { /* keep alive */ }
        } catch {
            print("❌ Error: \(error)")
        }
    }
}
