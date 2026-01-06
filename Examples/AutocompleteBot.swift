//
//  AutocompleteBot.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation
import SwiftDisc

@main
struct AutocompleteBot {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)

        let slash = SlashCommandRouter()
        client.useSlashCommands(slash)

        let ac = AutocompleteRouter()
        client.useAutocomplete(ac)

        ac.register(path: "search", option: "query") { ctx in
            let q = (ctx.focusedValue ?? "").lowercased()
            let base = ["Swift", "Discord", "NIO", "Opus", "Sodium", "Uploads", "Autocomplete", "Gateway"]
            let filtered = base.filter { q.isEmpty || $0.lowercased().contains(q) }.prefix(5)
            return filtered.map { .init(name: $0, value: $0) }
        }

        slash.register("search") { ctx in
            let q = ctx.string("query") ?? ""
            try await ctx.client.createInteractionResponse(
                interactionId: ctx.interaction.id,
                token: ctx.interaction.token,
                type: .channelMessageWithSource,
                content: "You searched for: \(q)",
                embeds: nil
            )
        }

        try? await client.loginAndConnect(intents: [.guilds, .guildMessages])
        for await _ in client.events { _ = () }
    }
}
