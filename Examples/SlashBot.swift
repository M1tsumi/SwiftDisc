//
//  SlashBot.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import SwiftDisc
import Foundation

@main
struct SlashBotMain {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] ?? "YOUR_BOT_TOKEN"
        let client = DiscordClient(token: token)

        // Register slash commands on startup (global example)
        Task {
            _ = try? await client.createGlobalCommand(name: "ping", description: "Replies with Pong!")
            let echoOption = DiscordClient.ApplicationCommandOption(type: .string, name: "text", description: "Text to echo", required: false)
            _ = try? await client.createGlobalCommand(name: "echo", description: "Echo back text", options: [echoOption])
        }

        // Wire slash router
        let slash = SlashCommandRouter()
        slash.register("ping") { ctx in
            try await ctx.client.createInteractionResponse(interactionId: ctx.interaction.id, token: ctx.interaction.token, content: "Pong!")
        }
        slash.register("echo") { ctx in
            let text = ctx.option("text") ?? "(no text)"
            try await ctx.client.createInteractionResponse(interactionId: ctx.interaction.id, token: ctx.interaction.token, content: text)
        }
        client.useSlashCommands(slash)

        client.onReady = { info in
            print("✅ Connected as: \(info.user.username)")
        }

        do {
            try await client.loginAndConnect(intents: [.guilds])
            for await _ in client.events { /* keep alive */ }
        } catch {
            print("❌ Error: \(error)")
        }
    }
}
