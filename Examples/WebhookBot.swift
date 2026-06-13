import SwiftDisc
import Foundation

@main
struct WebhookBotMain {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? "YOUR_BOT_TOKEN"
        let channelId = ChannelID(ProcessInfo.processInfo.environment["DISCORD_CHANNEL_ID"] ?? "0") ?? 0
        let client = DiscordClient(token: token)

        await client.setOnReady { info in
            print("Connected as: \(info.user.username)")

            // Create a webhook for the channel
            do {
                let webhook = try await client.createWebhook(channelId: ChannelID(channelId), name: "MyWebhook")
                print("Webhook created: \(webhook.id)")

                // Execute the webhook (asynchronous, no message returned)
                try await client.executeWebhook(webhookId: webhook.id, token: webhook.token ?? "", content: "Hello from webhook!")

                // Execute with wait=true to get the message back
                if let msg = try await client.executeWebhook(
                    webhookId: webhook.id,
                    token: webhook.token ?? "",
                    content: "Webhook with embed",
                    embeds: [Embed(title: "Webhook Embed", description: "Sent via webhook")],
                    wait: true
                ) {
                    print("Webhook message sent: \(msg.id)")
                }

                // Edit a webhook's name
                let updated = try await client.modifyWebhook(webhookId: webhook.id, name: "RenamedWebhook")
                print("Webhook renamed to: \(updated.name ?? "''")")

                // Delete the webhook
                try await client.deleteWebhook(webhookId: webhook.id)
                print("Webhook deleted")
            } catch {
                print("Webhook operation failed: \(error)")
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
