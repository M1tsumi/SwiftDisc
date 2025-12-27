import Foundation
import SwiftDisc

@main
struct ComponentsExample {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] ?? ""
        let client = DiscordClient(token: token)

        // Build an embed
        var eb = EmbedBuilder()
        eb.title("Components V2 Example")
        eb.description("This message demonstrates buttons and select menus using the typed builders.")
        let embed = eb.build()

        // Build components
        var components = ComponentsBuilder()
        components.row { row in
            var btn = ButtonBuilder()
            btn.style(.primary).label("Click me").customId("btn_click_1")
            row.add(btn.build())
        }

        components.row { row in
            var sel = SelectMenuBuilder()
            sel.customId("menu_1").option(label: "Option A", value: "a").option(label: "Option B", value: "b")
            row.add(sel.build())
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
        try? await client.start()
    }
}
