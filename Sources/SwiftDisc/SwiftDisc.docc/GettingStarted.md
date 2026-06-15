# Getting Started

Create a bot, connect to Discord, and send your first message.

@Metadata {
  @PageKind(article)
  @PageImage(purpose: card, source: swiftdisc-logo)
}

## 1. Create a SwiftPM project

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MyBot",
    platforms: [.macOS(.v11)],
    dependencies: [
        .package(url: "https://github.com/M1tsumi/SwiftDisc.git", from: "2.4.0")
    ],
    targets: [
        .executableTarget(
            name: "MyBot",
            dependencies: ["SwiftDisc"]
        )
    ]
)
```

## 2. Write your bot

Create a `main.swift` file:

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
            try await message.reply(client: client, content: "Pong!")
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

## 3. Run

```bash
export DISCORD_BOT_TOKEN="your_token_here"
swift run
```

## Next steps

- Learn about <doc:EventHandling>
- Add <doc:SlashCommands>
- Explore ``DiscordClient`` for the full API
