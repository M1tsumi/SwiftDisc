import Foundation
import SwiftDisc

@main
struct ViewExample {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)

        let manager = ViewManager()
        client.useViewManager(manager)

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

        manager.register(view, client: client)

        do {
            try await client.loginAndConnect(intents: [.guilds])
            for await _ in client.events { /* keep alive */ }
        } catch {
            print("Failed to start: \(error)")
        }
    }
}
