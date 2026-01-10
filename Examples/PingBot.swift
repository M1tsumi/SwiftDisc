//
//  PingBot.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import SwiftDisc
import Foundation

@main
struct PingBotMain {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] ?? "YOUR_BOT_TOKEN"
        let client = DiscordClient(token: token)

        client.onReady = { info in
            print("✅ Connected as: \(info.user.username)")
        }

        client.onMessage = { msg in
            if msg.content.lowercased() == "ping" {
                _ = try? await client.sendMessage(channelId: msg.channel_id, content: "Pong!")
            }
        }

        do {
            try await client.loginAndConnect(intents: [.guilds, .guildMessages, .messageContent])
            for await _ in client.events { /* keep alive */ }
        } catch {
            print("❌ Error: \(error)")
        }
    }
}
