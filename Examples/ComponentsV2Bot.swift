import SwiftDisc
import Foundation

@main
struct ComponentsV2BotMain {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? "YOUR_BOT_TOKEN"
        let channelId = ChannelID(ProcessInfo.processInfo.environment["DISCORD_CHANNEL_ID"] ?? "0")
        let client = DiscordClient(token: token)

        await client.setOnReady { _ in
            print("Bot connected. Sending Components v2 message...")

            let select = MessageComponent.ChannelSelectMenu(
                custom_id: "channel_picker",
                placeholder: "Pick a channel"
            )
            let row = MessageComponent.ActionRow(components: [.channelSelect(select)])

            Task {
                try? await client.sendMessage(
                    channelId: channelId,
                    content: "Welcome! Use the menu below:",
                    components: [.actionRow(row)],
                    flags: 1 << 15
                )
                print("Components v2 message sent (flags: \(1 << 15))")
            }
        }

        await client.setOnInteractionCreate { interaction in
            guard let data = interaction.data else { return }

            if interaction.type == 3, let customId = data.custom_id {
                if customId == "channel_picker" {
                    let input = MessageComponent.TextInput(
                        custom_id: "feedback_text",
                        style: 2,
                        label: "Your thoughts?",
                        required: true,
                        placeholder: "Tell us what you think..."
                    )
                    let label = MessageComponent.Label(
                        label: "Feedback",
                        description: "Share your experience",
                        components: [.textInput(input)]
                    )
                    Task {
                        try? await client.createInteractionModal(
                            interactionId: interaction.id,
                            token: interaction.token,
                            title: "Component Feedback",
                            customId: "feedback_modal",
                            components: [.label(label)]
                        )
                    }
                }
            } else if interaction.type == 5, data.custom_id == "feedback_modal" {
                print("Modal submitted!")
                Task {
                    try? await client.createInteractionResponse(
                        interactionId: interaction.id,
                        token: interaction.token,
                        type: .channelMessageWithSource,
                        content: "Thanks for your feedback!"
                    )
                }
            }
        }

        do {
            try await client.loginAndConnect(intents: [.guilds])
            let events = await client.events
            for await _ in events { }
        } catch {
            print("Connection error: \(error)")
        }
    }
}
