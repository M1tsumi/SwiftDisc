import Foundation
import SwiftDisc

@main
struct ViewExample {
    /// Starts an example bot that registers a persistent component view router.
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)

        let manager = ViewManager()
        await client.useViewManager(manager)

        // Create a view that responds to a button with custom_id "confirm_" prefix
        let view = View(id: "confirm-view", timeout: 60.0, handlers: [:], patterns: [
            ("confirm_", MatchType.prefix, { interaction, client in
                do {
                    try await client.createInteractionResponseWithFiles(applicationId: interaction.application_id, interactionToken: interaction.token, payload: ["type": .number(6)], files: [])
                } catch {
                    print("Failed to acknowledge interaction: \(error)")
                }
            })
        ])

        await manager.register(view, client: client)

        do {
            try await client.loginAndConnect(intents: [.guilds])
            let events = await client.events
            for await _ in events { /* keep alive */ }
        } catch {
            print("Failed to start: \(error)")
        }
    }
}
