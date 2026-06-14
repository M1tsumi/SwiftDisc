import Foundation
import SwiftDisc

@main
struct ComponentsExample {
    /// Starts an example bot that sends a message with typed component builders.
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)

        // Build an embed
        let embed = EmbedBuilder()
            .title("Components V2 Example")
            .description("This message demonstrates buttons and select menus using the typed builders.")
            .build()

        // Build components
        var components = ComponentsBuilder()
        _ = components.row { row in
            let btn = ButtonBuilder()
                .style(.primary)
                .label("Click me")
                .customId("btn_click_1")
                .build()
            _ = row.add(btn)
        }
        _ = components.row { row in
            let sel = SelectMenuBuilder()
                .customId("menu_1")
                .option(label: "Option A", value: "a")
                .option(label: "Option B", value: "b")
                .build()
            _ = row.add(sel)
        }
        let comps = components.build()

        // Send message (note: this example requires a running bot token and permissions)
        Task {
            do {
                _ = try await client.sendMessage(channelId: "CHANNEL_ID", content: "Hello from ComponentsExample", embeds: [embed], components: comps)
            } catch {
                print("Failed to send message: \(error)")
            }
        }

        // Start client to receive events etc.
        do {
            try await client.loginAndConnect(intents: [.guilds, .guildMessages, .messageContent])
            let events = await client.events
            for await _ in events { /* keep alive */ }
        } catch {
            print("Client failed to start: \(error)")
        }
    }
}
