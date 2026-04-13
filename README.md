<div align="center">

![SwiftDisc Typing](https://raw.githubusercontent.com/M1tsumi/M1tsumi/main/assets/typing-swiftdisc.svg)

</div>

# SwiftDisc

[![CI](https://github.com/M1tsumi/SwiftDisc/actions/workflows/ci.yml/badge.svg)](https://github.com/M1tsumi/SwiftDisc/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Discord](https://img.shields.io/discord/1439300942167146508?label=discord&logo=discord&logoColor=white)](https://discord.gg/6nS2KqxQtj)

SwiftDisc is a Swift-first Discord API wrapper for building bots and integrations with async/await, typed models, and practical high-level tools.

This README covers install, first bot run, intents, and example entry points.

## At a glance

- Swift 6.2 concurrency model and actor-safe APIs.
- Gateway and REST support in one library.
- Built-in rate-limit handling and reconnect logic.
- High-level routers for commands, slash commands, autocomplete, components, and views.
- Guild sticker write operations are supported (`createGuildSticker`, `modifyGuildSticker`, `deleteGuildSticker`).
- Runnable examples in [Examples](Examples).

## Installation

Add SwiftDisc with Swift Package Manager:

```swift
// Package.swift
.dependencies([
    .package(url: "https://github.com/M1tsumi/SwiftDisc.git", from: "2.1.0")
]),
.targets([
    .target(
        name: "YourBot",
        dependencies: ["SwiftDisc"]
    )
])
```

### Platform support

- macOS 11+
- iOS 14+
- tvOS 14+
- watchOS 7+
- Windows with Swift 6.2+

## Quick start (message bot)

```swift
import Foundation
import SwiftDisc

@main
struct MyBot {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)

        await client.setOnReady { ready in
            print("Logged in as \(ready.user.username)")
        }

        await client.setOnMessage { message in
            guard message.content?.lowercased() == "ping" else { return }
            do {
                try await message.reply(client: client, content: "Pong!")
            } catch {
                print("Reply failed: \(error)")
            }
        }

        do {
            try await client.loginAndConnect(intents: [.guilds, .guildMessages, .messageContent])
            let events = await client.events
            for await _ in events { }
        } catch {
            print("Client failed: \(error)")
        }
    }
}
```

## Quick start (slash command)

```swift
import Foundation
import SwiftDisc

@main
struct SlashBot {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)

        let slash = SlashCommandRouter()
        slash.register("ping") { ctx in
            try await ctx.client.createInteractionResponse(
                interactionId: ctx.interaction.id,
                token: ctx.interaction.token,
                content: "Pong!"
            )
        }

        client.useSlashCommands(slash)

        do {
            try await client.loginAndConnect(intents: [.guilds])
            let events = await client.events
            for await _ in events { }
        } catch {
            print("Failed to login and connect: \(error)")
            exit(1)
        }
    }
}
```

## Bot setup checklist

If your bot appears to connect but receives no data, one of these is usually the reason:

1. `DISCORD_BOT_TOKEN` is missing or invalid.
2. Required intents are not passed to `loginAndConnect`.
3. Privileged intents (especially `messageContent`) are not enabled in the Discord Developer Portal.
4. Bot was invited without the scopes/permissions you expect.

## How SwiftDisc is organized

- `DiscordClient`: main actor and lifecycle entrypoint.
- Gateway: real-time events and dispatch.
- REST client: typed HTTP request/response operations.
- High-level modules in [Sources/SwiftDisc/HighLevel](Sources/SwiftDisc/HighLevel):
  - `CommandRouter`
  - `SlashCommandRouter`
  - `AutocompleteRouter`
  - `ViewManager`
  - collectors/builders/utilities
- Typed models in [Sources/SwiftDisc/Models](Sources/SwiftDisc/Models).

## Example programs

These examples are included and useful for real onboarding:

- [Examples/PingBot.swift](Examples/PingBot.swift)
- [Examples/CommandsBot.swift](Examples/CommandsBot.swift)
- [Examples/SlashBot.swift](Examples/SlashBot.swift)
- [Examples/AutocompleteBot.swift](Examples/AutocompleteBot.swift)
- [Examples/ComponentsExample.swift](Examples/ComponentsExample.swift)
- [Examples/ViewExample.swift](Examples/ViewExample.swift)
- [Examples/FileUploadBot.swift](Examples/FileUploadBot.swift)

Packaged executable targets can be run with:

```bash
swift run PingBotExample
swift run CommandsBotExample
swift run SlashBotExample
swift run AutocompleteBotExample
swift run ComponentsExample
swift run ViewExample
swift run FileUploadBotExample
```

## Reliability and DX notes

SwiftDisc v2.1.0 includes practical reliability and onboarding improvements:

- Actor-safe example patterns for Swift 6 strict concurrency.
- Reusable test fixtures for faster test authoring.
- Cleaner callback setup with explicit setter methods.
- Updated docs aimed at first-run success.

## Troubleshooting

- Build/toolchain mismatch:
  - Use Swift 6.2+.
- Connected but no command responses:
  - Verify intents and Developer Portal privileged intent settings.
- 429/rate-limit issues:
  - Avoid tight retry loops and bursty duplicate requests.
- CI failures:
  - Start by checking runner logs in [Errors](Errors).

## Documentation map

- Main API and usage reference: [SwiftDiscDocs.txt](SwiftDiscDocs.txt)
- Project changes per release: [CHANGELOG.md](CHANGELOG.md)
- Contributing workflow: [CONTRIBUTING.md](CONTRIBUTING.md)
- Repository standards and behavior: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)

## Community and support

- Discord support server: https://discord.gg/6nS2KqxQtj
- Issues and feature requests: https://github.com/M1tsumi/SwiftDisc/issues

## License

MIT. See [LICENSE](LICENSE).
