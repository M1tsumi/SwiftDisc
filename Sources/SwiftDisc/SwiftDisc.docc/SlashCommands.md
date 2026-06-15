# Slash Commands

Register and handle slash commands with typed option accessors.

@Metadata {
  @PageKind(article)
  @PageImage(purpose: card, source: swiftdisc-logo)
}

## Basic Example

```swift
import Foundation
import SwiftDisc

@main
struct SlashBot {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)

        let slash = SlashCommandRouter()
        await slash.register("ping") { ctx in
            try await ctx.client.createInteractionResponse(
                interactionId: ctx.interaction.id,
                token: ctx.interaction.token,
                content: "Pong!"
            )
        }

        await client.useSlashCommands(slash)
        try? await client.loginAndConnect(intents: [.guilds])
        let events = await client.events
        for await _ in events { }
    }
}
```

## Command Options

Add options to commands with fluent builders:

```swift
await slash.register("greet") { ctx in
    let name = try ctx.option("name")
    try await ctx.client.createInteractionResponse(
        interactionId: ctx.interaction.id,
        token: ctx.interaction.token,
        content: "Hello, \(name)!"
    )
}
.options {
    StringOption(name: "name", description: "Who to greet", required: true)
}
```

## Autocomplete

Provide live search suggestions for command options using ``AutocompleteRouter``.
