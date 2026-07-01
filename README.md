<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/swiftdisc-logo.svg">
  <img alt="SwiftDisc" src="assets/swiftdisc-logo.svg" width="400">
</picture>

[![CI](https://github.com/M1tsumi/SwiftDisc/actions/workflows/ci.yml/badge.svg)](https://github.com/M1tsumi/SwiftDisc/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/release-2.5.0-blue.svg)](https://github.com/M1tsumi/SwiftDisc/releases)
[![Swift](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Discord](https://img.shields.io/discord/1439300942167146508?label=discord&logo=discord&logoColor=white)](https://discord.gg/tWyefRKKEH)

## Features

- **Single-actor client.** `DiscordClient` owns the gateway connection, REST client, event dispatcher, and cache in one place.
- **Automatic gateway management.** Reconnection, session resumption, heartbeats, and rate-limit backoff are handled internally.
- **Actor-based concurrency.** Built on Swift 6.2 structured concurrency with `async/await`. The cache, gateway, and REST client avoid locks by design.
- **Typed models.** Every Discord API object is a native Swift struct with `Codable`, `Hashable`, and `Sendable`. The REST client returns concrete types, not `[String: Any]`.
- **Event callbacks + async streams.** Use callback closures or `for await` on the unified event stream — or both at once.
- **Pluggable transports.** Default transports use URLSession. Swap in AsyncHTTPClient for proxy support on Linux, or conform to `HTTPTransport`/`WebSocketTransport` for custom networking.
- **Modular high-level APIs.** Separate routers for slash commands, prefix commands, autocomplete, views, webhooks, collectors, and cooldowns.

## Quick start (ping bot)

Create a new SwiftPM executable, add SwiftDisc as a dependency, and drop this in:

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

Set your token and run:

```bash
export DISCORD_BOT_TOKEN="your_token_here"
swift run
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

## Installation

Add SwiftDisc via Swift Package Manager:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YourBot",
    dependencies: [
        .package(url: "https://github.com/M1tsumi/SwiftDisc.git", from: "2.5.0")
    ],
    targets: [
        .target(
            name: "YourBot",
            dependencies: ["SwiftDisc"]
        )
    ]
)
```

### Platform support

| Platform | Minimum version |
|----------|----------------|
| macOS | 11+ |
| iOS | 14+ |
| tvOS | 14+ |
| watchOS | 7+ |
| Windows | Swift 6.2+ |

## How SwiftDisc works

SwiftDisc is split into these layers:

**`DiscordClient`** -- the main actor. It owns your Gateway connection, the REST client, the event dispatcher, and the cache. You will spend most of your time here.

**Gateway** -- manages the WebSocket connection to Discord's real-time event system. Handles heartbeats, reconnects, resuming sessions, and rate limits so you do not have to. Monitor connection state with `client.connectionState` and react to lifecycle events with `onResumed`, `onDisconnected`, and `onSessionInvalidated`.

**REST client** -- typed HTTP methods for every Discord API endpoint. Methods throw `DiscordError` with descriptive messages, and the built-in rate limiter keeps you under Discord's global and per-route limits.

**High-level modules** in [Sources/SwiftDisc/HighLevel](Sources/SwiftDisc/HighLevel):

| Module | What it does |
|--------|-------------|
| `SlashCommandRouter` | Register and handle slash commands with typed option accessors |
| `AutocompleteRouter` | Provide live search suggestions for command options |
| `CommandRouter` | Classic prefix-based commands (e.g. `!ping`) |
| `ViewManager` | Persistent UI views with `custom_id` matching |
| `WebhookClient` | Standalone token-free webhook execution |
| `MessagePayload` | Fluent builder for complex message payloads |
| `Collectors` | Streams for messages, reactions, and components |
| `CooldownManager` | Per-user or per-guild rate limiting for commands |

**Models** in [Sources/SwiftDisc/Models](Sources/SwiftDisc/Models) -- complete, typed Swift structs for every Discord API object, from Users and Channels to Interactions, Polls, Auto Moderation, Monetization SKUs, and Onboarding prompts.

**Cache** -- actor-safe in-memory store for users, channels, guilds, roles, emojis, and recent messages. Supports TTL expiration and LRU eviction to keep memory bounded. Inspect cache health with `cache.summary`, `cache.userCount`, etc.

### Transport system

The default transport uses URLSession and works everywhere. If you need proxy support on Linux or want to use AsyncHTTPClient, swap in the optional `SwiftDiscAHCTransport` module:

```swift
import SwiftDisc
import SwiftDiscAHCTransport

var config = DiscordConfiguration()
config.httpTransport = AHCTransport(
    proxy: ProxyConfiguration(host: "proxy.corp.com", port: 8080)
)
let client = DiscordClient(token: token, configuration: config)
```

Conform to `HTTPTransport` or `WebSocketTransport` to integrate any networking library.

## Example programs

Run any example from the repo root with `swift run <TargetName>`:

| Example | What it shows | Run with |
|---------|--------------|----------|
| [PingBot](Examples/PingBot.swift) | Minimal message-based bot | `swift run PingBotExample` |
| [SlashBot](Examples/SlashBot.swift) | Slash command registration + response | `swift run SlashBotExample` |
| [CommandsBot](Examples/CommandsBot.swift) | Prefix commands (`!ping` style) | `swift run CommandsBotExample` |
| [AutocompleteBot](Examples/AutocompleteBot.swift) | Slash commands with live search suggestions | `swift run AutocompleteBotExample` |
| [ComponentsExample](Examples/ComponentsExample.swift) | Buttons, select menus, and interaction handling | `swift run ComponentsExample` |
| [ComponentsV2Bot](Examples/ComponentsV2Bot.swift) | The `IS_COMPONENTS_V2` flag, channel select menus, modal with Label+TextInput layout | `swift run ComponentsV2BotExample` |
| [ViewExample](Examples/ViewExample.swift) | Persistent UI views with ViewManager | `swift run ViewExample` |
| [FileUploadBot](Examples/FileUploadBot.swift) | Sending attachments with embeds | `swift run FileUploadBotExample` |
| [WebhookBot](Examples/WebhookBot.swift) | Create, execute, edit, and delete webhooks | `swift run WebhookBotExample` |
| [ShardingBot](Examples/ShardingBot.swift) | Sharded gateway connection with state monitoring | `swift run ShardingBotExample` |

All examples read the bot token from the `DISCORD_BOT_TOKEN` environment variable. Some also use `DISCORD_CHANNEL_ID` -- set them before running:

```bash
export DISCORD_BOT_TOKEN="your_token"
export DISCORD_CHANNEL_ID="your_channel_id"
swift run PingBotExample
```

## Event handling guide

You can handle gateway events with callbacks or an async stream.

### Option 1: Callback closures (simple, self-documenting)

Set individual callbacks for the events you care about:

```swift
await client.setOnReady { ready in
    print("Bot is ready in \(ready.guilds.count) guilds")
}

await client.setOnMessage { message in
    guard message.content == "ping" else { return }
    try await message.reply(client: client, content: "Pong!")
}

await client.setOnGuildCreate { guild in
    print("Joined \(guild.name), \(guild.member_count ?? 0) members")
}
```

Available callbacks: `onReady`, `onMessage`, `onMessageUpdate`, `onGuildCreate`, `onInteractionCreate`, `onReactionAdd`, `onMemberAdd`, and 30+ more -- one for every Discord gateway event.

### Option 2: Event AsyncStream (flexible, pattern-matching)

When you need to filter, combine, or transform events, use the unified stream:

```swift
for await event in await client.events {
    switch event {
    case .messageCreate(let msg) where msg.content == "ping":
        try await msg.reply(client: client, content: "Pong!")
    case .guildCreate(let guild):
        print("New guild: \(guild.name)")
    case .reactionAdd(let reaction):
        guard reaction.emoji.name == "⭐" else { break }
        print("Starred in channel \(reaction.channel_id)")
    default:
        break
    }
}
```

The event stream is an `AsyncStream` -- you can use it with `filter`, `map`, `compactMap`, and other async algorithms. You can also use both callbacks and the stream at the same time.

### Connection state observability

Monitor Gateway connection state in real time:

```swift
for await state in await client.connectionState {
    switch state {
    case .ready:         print("Connected and ready to receive events")
    case .reconnecting:  print("Connection lost, reconnecting...")
    case .resuming:      print("Resuming session with Discord")
    case .disconnected:  print("Fully disconnected")
    case .connecting:    print("Establishing initial connection")
    case .identifying:   print("Sending identify payload")
    }
}
```

Or grab the current state synchronously: `let state = await client.gatewayStatus`.

### Lifecycle callbacks

React to connection lifecycle events:

```swift
await client.onResumed = { print("Session resumed -- missed events replayed") }
await client.onDisconnected = { reason in print("Disconnected: \(reason)") }
await client.onSessionInvalidated = { print("Session invalidated -- will re-identify on next connect") }
```

## Bot setup checklist

If your bot connects but does not receive events, check these in order:

1. **Is your token set?** -- `DISCORD_BOT_TOKEN` must be a valid bot token from the Discord Developer Portal.
2. **Are you requesting the right intents?** -- Pass them to `loginAndConnect(intents:)`. For example, to read message content you need `[.guilds, .guildMessages, .messageContent]`.
3. **Are privileged intents enabled?** -- In the Developer Portal, go to your app's Bot page and toggle `MESSAGE CONTENT INTENT`, `SERVER MEMBERS INTENT`, and `PRESENCE INTENT` as needed. These are required even if you pass them in code.
4. **Was the bot invited with the right scopes?** -- Use the OAuth2 URL generator in the Developer Portal and include the `bot` scope plus the permissions your bot needs.
5. **Is the bot in the guild?** -- The bot must be a member of the guild to receive events from it.
6. **Check for close codes** -- Watch console output for Gateway close codes like `4004` (bad token), `4013` (invalid intents), or `4014` (disallowed privileged intent).

## Reliability and debugging

Reconnection, rate-limit backoff, and session resumption are handled internally. Debugging tools:

**Gateway decode diagnostics** -- Enable `DiscordConfiguration.enableGatewayDecodeDiagnostics` to log payload decoding failures with opcode context and payload previews. Essential when adding support for new Discord features.

**Rate limit observability** -- Set `DiscordConfiguration.onRateLimit` to receive `RateLimitEvent` snapshots for REST bucket updates and waits. Useful for tuning request patterns.

**Structured logging** -- Provide a custom logger via `DiscordConfiguration.logger`. The built-in `DefaultDiscordLogger` uses `os_log` on Apple platforms and `print` on others. Implement the `DiscordLogger` protocol to route to your own backend.

**Pluggable HTTP and WebSocket transports** -- Swap out the default URLSession networking for a custom implementation. Useful when you need proxy support on Linux, want to use AsyncHTTPClient, or need fine-grained control over connection behavior.

**Typed error handling** -- All operations throw `DiscordError` with descriptive messages. Use convenience properties to inspect errors:
```swift
catch let error as DiscordError {
    if error.isRateLimited { /* back off */ }
    if error.isAuthenticationFailure { /* token expired */ }
    if let statusCode = error.httpStatusCode { /* 400, 404, 429 etc */ }
    if let validationErrors = error.validationErrors { /* per-field failures */ }
}
```

**Router error handlers** -- `CommandRouter`, `SlashCommandRouter`, and `ViewManager` support custom error handlers that receive context about the failed operation. Set them during initialization.

**Cache statistics** -- Inspect cache contents any time:
```swift
print(await cache.summary)
// "Cache: 843 users, 127 channels, 5 guilds, 3412 messages in 34 channels, ..."
```

## Documentation map

| Resource | What you will find |
|----------|-------------------|
| [**GitHub Pages**](https://M1tsumi.github.io/SwiftDisc/) | DocC documentation for SwiftDisc -- API reference with search |
| [**CHANGELOG.md**](CHANGELOG.md) | Per-release changelog following Keep a Changelog |
| [**CONTRIBUTING.md**](CONTRIBUTING.md) | How to set up, build, test, and submit PRs |
| [**Examples/README.md**](Examples/README.md) | Quick-start guides for every example bot |
| `SwiftDiscAHCTransport` | Optional AsyncHTTPClient transport. Add `.product(name: "SwiftDiscAHCTransport", package: "SwiftDisc")` to use it. Supports proxies on Linux |
| [**CODE_OF_CONDUCT.md**](CODE_OF_CONDUCT.md) | Community standards and expectations |

You can also build the docs locally:

```bash
# Requires swift-docc-plugin (add it to Package.swift first)
swift package --allow-writing-to-directory generate-documentation --target SwiftDisc --output-path docs --transform-for-static-hosting
```

Then open `docs/index.html` in a browser.

## Community and support

- **Discord server** -- [https://discord.gg/tWyefRKKEH](https://discord.gg/tWyefRKKEH) -- get help, discuss features, show off your bot
- **GitHub Issues** -- [https://github.com/M1tsumi/SwiftDisc/issues](https://github.com/M1tsumi/SwiftDisc/issues) -- report bugs and request features
- **GitHub Discussions** -- available on the repo for longer conversations

## License

MIT. See [LICENSE](LICENSE).
