//
//  FileUploadBot.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation
import SwiftDisc

@main
struct FileUploadBot {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token, configuration: .init(maxUploadBytes: 150 * 1024 * 1024)) // override guardrail if needed

        client.onReady = { ready in
            print("Logged in as: \(ready.user.username)")
        }

        // Example usage: send a file with optional embed
        Task {
            do {
                // Replace with a real channel ID and a real file path in your environment
                let channel: ChannelID = "000000000000000000"
                let fileURL = URL(fileURLWithPath: "./README.md")
                let data = try Data(contentsOf: fileURL)
                let attachment = FileAttachment(
                    filename: fileURL.lastPathComponent,
                    data: data,
                    description: "Sample readme upload",
                    contentType: "text/markdown"
                )
                let embed = Embed(title: "Uploaded README", description: "File attached via SwiftDisc")
                _ = try await client.sendMessageWithFiles(channelId: channel, content: "Here is the file", embeds: [embed], files: [attachment])
            } catch {
                print("Upload failed: \(error)")
            }
        }

        try? await client.loginAndConnect(intents: [.guilds])
        for await _ in client.events { _ = () }
    }
}
