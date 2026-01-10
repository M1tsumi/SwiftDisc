//
//  VoiceStdin.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation
import SwiftDisc

@main
struct VoiceStdinExample {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let guildId = GuildID("YOUR_GUILD_ID")
        let channelId = ChannelID("YOUR_VOICE_CHANNEL_ID")

        let config = DiscordConfiguration(enableVoiceExperimental: true)
        let client = DiscordClient(token: token, configuration: config)

        do {
            try await client.loginAndConnect(intents: [.guilds])
            try await client.joinVoice(guildId: guildId, channelId: channelId)

            // Read framed Opus from stdin and stream
            let source = PipeOpusSource(handle: FileHandle.standardInput)
            try await client.play(source: source, guildId: guildId)

            try await client.leaveVoice(guildId: guildId)
        } catch {
            print("Voice example error:", error)
        }
    }
}
