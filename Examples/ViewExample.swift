import Foundation
import SwiftDisc

@main
struct ViewExample {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] ?? ""
        let client = DiscordClient(token: token)

        let manager = ViewManager()
        client.useViewManager(manager)

        // Create a view that responds to a button with custom_id "confirm_" prefix
        let handlers: [String: ViewHandler] = [
            "confirm_": { interaction, client in
                // Acknowledge the interaction quickly (type 6 = deferred update message)
                try? await client.createInteractionResponseWithFiles(applicationId: interaction.application_id, interactionToken: interaction.token, payload: ["type": .number(6)], files: [])
                // Perform action: e.g., edit the message or send a confirmation
            }
        ]

        let view = View(id: "confirm-view", timeout: 60.0, handlers: handlers, prefixMatch: true, oneShot: false)
        await manager.register(view, client: client)

        try? await client.start()
    }
}
