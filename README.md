<div align="center">

![SwiftDisc Typing](https://raw.githubusercontent.com/M1tsumi/M1tsumi/main/assets/typing-swiftdisc.svg)

# SwiftDisc

A Swift-native Discord API library for building bots and integrations.

Async/await, strongly typed, cross-platform.

<a href="https://discord.gg/6nS2KqxQtj"><img alt="Discord" src="https://img.shields.io/badge/Discord-Join%20Server-5865F2?style=for-the-badge&logo=discord&logoColor=white"></a>

[![Discord](https://img.shields.io/discord/1439300942167146508?color=5865F2&label=Discord&logo=discord&logoColor=white)](https://discord.gg/6nS2KqxQtj)
[![Swift Version](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![CI](https://github.com/M1tsumi/SwiftDisc/actions/workflows/ci.yml/badge.svg)](https://github.com/M1tsumi/SwiftDisc/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[Documentation](https://github.com/M1tsumi/SwiftDisc/wiki) · [Examples](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples) · [Discord](https://discord.gg/6nS2KqxQtj)

</div>

---

## About

SwiftDisc is a Discord API wrapper written in Swift. It uses async/await and structured concurrency throughout, provides typed models for Discord's data structures, and handles the usual pain points (rate limiting, reconnection, sharding) so you don't have to.

Works on macOS, iOS, tvOS, watchOS, and Windows.

## Installation

Add SwiftDisc to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/M1tsumi/SwiftDisc.git", from: "1.0.0")
]

```swift
targets: [
    .target(name: "YourBot", dependencies: ["SwiftDisc"])
]

### Platform Support

| Platform | Minimum Version |
|----------|----------------|
| iOS | 14.0+ |
| macOS | 11.0+ |
| tvOS | 14.0+ |
| watchOS | 7.0+ |
| Windows | Swift 5.9+ |

## Quick Start
### Command Framework

SwiftDisc includes a small, developer-friendly command framework to get started quickly with prefix and slash-style commands. The framework is intentionally lightweight and designed to be extended by applications or higher-level frameworks.

Example (see `Examples/CommandFrameworkBot.swift`):

```swift
let router = CommandRouter(prefix: "!")
router.register("ping") { ctx in
    try? await ctx.reply("Pong!")
}

client.onMessageCreate { message in
    await router.processMessage(message)
}
```

The `CommandRouter` and `CommandContext` are in `Sources/SwiftDisc/HighLevel/CommandFramework.swift` and are intended as a foundation for a richer command framework (cogs, converters, cooldowns).

### Cogs / Extensions

SwiftDisc provides a minimal `Cog` protocol and an `ExtensionManager` for organizing features into loadable modules. A `Cog` exposes `onLoad(client:)` and `onUnload(client:)` hooks — ideal for registering commands, listeners, or background tasks when the extension is active. See `Sources/SwiftDisc/HighLevel/Cog.swift` and `Examples/CogExample.swift`.

### Converters, Checks & Cooldowns

The command framework now includes lightweight converters and utilities to make command development ergonomic:

- `Converters`: helpers to parse mentions and plain IDs into typed `Snowflake<T>` aliases (e.g. `UserID`, `ChannelID`, `RoleID`). See `Sources/SwiftDisc/HighLevel/Converters.swift`.
- `Check` functions: small async predicates that can be attached to commands to gate execution (permission checks, role checks, owner-only, etc.).
- `CooldownManager`: per-command cooldown support with `user`, `guild`, and `global` scopes to throttle command usage.

Example:

```swift
router.register("echo", checks: [isAdminCheck], cooldown: 5.0) { ctx in
    try? await ctx.reply(ctx.args)
}
```

These features are intentionally small and composable; they are a foundation for richer developer-facing frameworks (decorators, converters, and higher-level command frameworks) and are documented in `CHANGELOG.md` under the v1.0.0 notes.

### Collectors & Paginators

SwiftDisc now includes AsyncStream-based collectors and paginators to make common tasks easy and idiomatic with Swift concurrency. Highlights:

- `createMessageCollector(...)`: attach a filter and stream matching messages from the client's event stream with optional timeout and maximum count.
- `streamGuildMembers(...)`: paginated streaming helper that yields `GuildMember` entries lazily via `listGuildMembers`.
- `streamChannelPins(...)`: existing helper that streams pinned messages using the paginated pins endpoint.

These tools avoid manual paging/looping boilerplate and are designed to compose with higher-level collectors and view state utilities.

### Components V2 (Complete Integration)

Components V2 is now fully integrated and exposes typed models, fluent builders, and examples to make constructing message components ergonomic and type-safe:

- Models: `MessageComponent` includes `ActionRow`, `Button`, `SelectMenu`, and `TextInput` with exact field names matching the API.
- Builders: `ButtonBuilder`, `SelectMenuBuilder`, `TextInputBuilder`, `ActionRowBuilder`, and a top-level `ComponentsBuilder` for composing rows.
- Embeds: `EmbedBuilder` provides a fluent API for constructing rich embeds.
- Examples: see `Examples/ComponentsExample.swift` demonstrating constructing an embed and multiple component rows and sending a message.

These builders produce values directly usable in `DiscordClient.sendMessage(..., components: [MessageComponent])` and interaction response payloads. They are covered by basic serialization and smoke tests in `Tests/SwiftDiscTests`.

### Component Collectors / Persistent Views

`createComponentCollector(customId:timeout:max:)` returns an `AsyncStream<Interaction>` that yields component interactions (buttons/selects) matching an optional `customId`. Use collectors to implement short-lived UIs or wire into a persistent view manager that maps `custom_id`s to handler callbacks and keeps state for the view lifecycle.

Example (collector usage):

```swift
let collector = client.createComponentCollector(customId: "btn_confirm", timeout: 30)
Task {
    for await interaction in collector {
        // handle interaction, e.g. acknowledge or edit message
        try? await client.createInteractionResponseWithFiles(applicationId: interaction.application_id, interactionToken: interaction.token, payload: ["type": .number(6)], files: [])
    }
}
```

Collectors are a building block for a higher-level `View` system (persistent views + automatic timeout/unload). If you'd like, I can implement a `View` manager next that maps component `custom_id`s to callbacks and supports ephemeral state and automatic cleanup.

### View Manager (Persistent Views)

`ViewManager` provides a simple, concurrency-safe way to register persistent UI views that handle component interactions. Features:

- Register a `View` with handlers mapped by `custom_id` (exact or prefix matching).
- Automatic expiration by timeout, and optional one-shot views that unregister after first use.
- Integration with `DiscordClient` via `client.useViewManager(_:)` which starts routing component interactions to registered views.

See `Sources/SwiftDisc/HighLevel/ViewManager.swift` and `Examples/ViewExample.swift` for usage. `Tests/ViewManagerTests.swift` contains smoke tests for registration/unregistration.

Example `Check` implementation:

```swift
let isAdminCheck: CommandRouter.Check = { ctx in
    // Example: allow if author has ADMINISTRATOR permission or is the guild owner.
    if let guildId = ctx.message.guild_id {
        // Note: a real implementation would inspect the cache or fetch member permissions.
        // This example assumes a helper `hasAdminPermissions(member:guildId:)` exists.
        return await hasAdminPermissions(ctx.message.author.id, guildId: guildId)
    }
    return false
}
```

`hasAdminPermissions` is intentionally left as an integration point for application-specific permission checks (cache lookups, REST fallbacks, etc.).

```swift
import SwiftDisc

@main
struct MyBot {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)
        
        do {
            try await client.loginAndConnect(intents: [.guilds, .guildMessages, .messageContent])
            
            for await event in client.events {
                switch event {
                case .ready(let info):
                    print("Logged in as \(info.user.username)")
                    
                case .messageCreate(let message) where message.content == "!hello":
                    try await client.sendMessage(
                        channelId: message.channel_id,
                        content: "Hello, \(message.author.username)!"
                    )
                    
                default:
                    break
                }
            }
        } catch {
            print("Error: \(error)")
        }
    }
}

## Features

### Gateway

- WebSocket connection with automatic heartbeat
- Session resume on disconnect
- Event stream via AsyncSequence
- Presence/status updates
- Thread and scheduled event support
- Raw event fallback for unmodeled dispatches

### REST API

Covers most of the Discord API:

- Channels and threads
- Messages (with embeds, components, attachments)
- Guilds, members, roles
- Slash commands
- Webhooks
- Auto moderation
- Scheduled events
- Forum channels
- Role Connections: Fully supported now, with intuitive tools to manage linked roles and user metadata, helping you create bots that adapt dynamically to user data for better community interactions.
- Permissions: Upgraded to a typed bitset with cache integration, offering efficient and safe permission handling that scales well and reduces the risk of bugs in complex applications.

For endpoints we haven't wrapped yet, use `rawGET`, `rawPOST`, etc.

### Rate Limiting

Per-route and global rate limits are handled automatically. The client backs off and retries when needed.

### Modal File Uploads (v1.0.0)

SwiftDisc provides helpers to send files with interaction responses and follow-ups. These helpers send multipart requests and enforce per-attachment limits configured via `DiscordConfiguration.maxUploadBytes`.

Use `createInteractionResponseWithFiles` for initial interaction responses (the endpoint is the webhook path for an interaction token; the helper uses `wait=true` to return the created message).

Example:

```swift
let file = FileAttachment(filename: "screenshot.png", data: pngData, contentType: "image/png")
let payload: [String: JSONValue] = ["content": .string("Here's the file")]
let message = try await client.createInteractionResponseWithFiles(applicationId: appId, interactionToken: token, payload: payload, files: [file])
```

To create follow-up messages with files, use `createFollowupMessageWithFiles` which returns the created `Message` when `wait=true`.

### Sharding

```swift
let manager = await ShardingGatewayManager(
    token: token,
    configuration: .init(
        shardCount: .automatic,
        connectionDelay: .staggered(interval: 1.5)
    ),
    intents: [.guilds, .guildMessages]
)

try await manager.connect()

let health = await manager.healthCheck()
print("Shards ready: \(health.readyShards)/\(health.totalShards)")
```

## Examples

### Ping Bot

```swift
case .messageCreate(let message) where message.content == "!ping":
    try await client.sendMessage(
        channelId: message.channel_id,
        content: "Pong!"
    )
```

[Full example](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples/PingBot.swift)

### Slash Commands

```swift
let slash = SlashCommandRouter()
slash.register("greet") { interaction in
    try await interaction.reply("Hello from SwiftDisc!")
}
```

[Slash bot example](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples/SlashBot.swift)

More examples in the [Examples folder](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples):

- Command routing with prefixes
- Autocomplete
- File uploads
- Thread and scheduled event listeners

## Additional APIs

### Member Timeouts

```swift
let updated = try await client.setMemberTimeout(
    guildId: guildId,
    userId: userId,
    until: Date().addingTimeInterval(600)
)

let cleared = try await client.clearMemberTimeout(guildId: guildId, userId: userId)
```

### App Emoji

```swift
let emoji = try await client.createAppEmoji(
    applicationId: appId,
    name: "party",
    imageBase64: "data:image/png;base64,...."
)

try await client.deleteAppEmoji(applicationId: appId, emojiId: emoji.id)
```

### Components V2

For newer component layouts, pass a raw payload:

```swift
let payload: [String: JSONValue] = [
    "content": .string("Message with Components V2"),
    "flags": .int(1 << 15),
    "components": .array([
        .object(["type": .int(1), "children": .array([])])
    ])
]
let msg = try await client.postMessage(channelId: channelId, payload: payload)
```

Or use the typed helper:

```swift
let v2 = V2MessagePayload(
    content: "Message with V2",
    flags: 1 << 15,
    components: [.object(["type": .int(1), "children": .array([])])]
)
let msg = try await client.sendComponentsV2Message(channelId: channelId, payload: v2)
```

### Polls

```swift
let poll: [String: JSONValue] = [
    "question": .object(["text": .string("Favorite language?")]),
    "answers": .array([
        .object(["answer_id": .int(1), "poll_media": .object(["text": .string("Swift")])]),
        .object(["answer_id": .int(2), "poll_media": .object(["text": .string("Kotlin")])])
    ]),
    "allow_multiple": .bool(false),
    "duration": .int(600)
]
let msg = try await client.createPollMessage(channelId: channelId, content: "Vote:", poll: poll)
```

### Command Localization

```swift
let updated = try await client.setCommandLocalizations(
    applicationId: appId,
    commandId: cmdId,
    nameLocalizations: ["en-US": "ping", "ja": "ピン"],
    descriptionLocalizations: ["en-US": "Check latency", "ja": "レイテンシーを確認"]
)
```

### Message Forwarding

```swift
let forwarded = try await client.forwardMessageByReference(
    targetChannelId: targetChannelId,
    sourceChannelId: sourceChannelId,
    messageId: messageId
)
```

### Generic Application Resources

```swift
let res = try await client.postApplicationResource(
    applicationId: appId,
    relativePath: "some/feature",
    payload: ["key": .string("value")]
)
```

### Utilities

```swift
Mentions.user(userId)
Mentions.channel(channelId)
Mentions.role(roleId)
Mentions.slashCommand(name: "ping", id: commandId)

EmojiUtils.custom(name: "blob", id: emojiId, animated: false)

DiscordTimestamp.format(date: Date(), style: .relative)

MessageFormat.escapeSpecialCharacters(text)
```

## Voice (Experimental)

Experimental voice support. Connects to Discord voice, handles UDP discovery, negotiates encryption, and can transmit Opus frames (and, on Apple platforms, receive them).

```swift
let config = DiscordConfiguration(enableVoiceExperimental: true)
let client = DiscordClient(token: token, configuration: config)

try await client.joinVoice(guildId: guildId, channelId: channelId)

// Send Opus packets directly
try await client.playVoiceOpus(guildId: guildId, data: opusPacket)

// Or use a source
try await client.play(source: MyOpusSource(), guildId: guildId)

try await client.leaveVoice(guildId: guildId)

## Running Tests

To run the test suite locally you need Swift installed. On macOS with Xcode/toolchain:

```bash
cd /home/pepe/Desktop/Github\ DevWork/Discord\ API\ Libs/SwiftDisc-1
swift test
```

CI is configured in `.github/workflows/ci.yml` to run on macOS and Windows; if you encounter environment issues locally, ensure your Swift toolchain matches the CI configuration (Xcode 16.4 / Swift 6.x where applicable).
```

On Apple platforms, you can observe inbound Opus frames via `onVoiceFrame`:

```swift
client.onVoiceFrame = { frame in
    // frame.opus contains a decrypted Opus packet for the guild
}
```

Input must be Opus-encoded at 48kHz. SwiftDisc doesn't include an encoder—use ffmpeg or similar externally and pipe the output in.

For macOS, you can run ffmpeg separately and feed framed Opus to `PipeOpusSource`:

```swift
let source = PipeOpusSource(handle: FileHandle.standardInput)
try await client.play(source: source, guildId: guildId)
```

Frame format: `[u32 little-endian length][data]` repeated.

On iOS, provide Opus packets from your app or backend over your own transport.

## Building

```bash
swift build
swift test
```

CI runs on macOS (Xcode 16.4 / Swift 5.10.1) and Windows Server 2022 (Swift 5.10.1).

## Documentation

- [Wiki](https://github.com/M1tsumi/SwiftDisc/wiki) — setup guides, concepts, deployment
- [Examples](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples)
- [Discord server](https://discord.gg/6nS2KqxQtj) — questions and discussion

## Roadmap

### Released (v1.0.0) - 2025-12-27
- Stable v1.0.0 released with broad REST and Gateway coverage, full Components V2, modal file uploads, and a focused set of developer-friendly high-level APIs.

Completed highlights:
- Command framework: `CommandRouter`, `CommandContext`, async `Check` predicates, and per-command cooldowns.
- Cogs / Extensions: `Cog` protocol and `ExtensionManager` for modular bots and plugins.
- Collectors & Paginators: AsyncStream collectors (`createMessageCollector`, `createComponentCollector`) and paginators (`streamGuildMembers`, `streamChannelPins`).
- Components V2: typed `MessageComponent` models, fluent builders, and `EmbedBuilder`.
- View Manager: concurrency-safe `ViewManager` with exact/prefix/regex matching, per-view state, automatic expiration, and edit-on-expire helpers.
- Modal file uploads: `createInteractionResponseWithFiles` and `createFollowupMessageWithFiles` helpers.
- Performance & stability: rate-limiter and HTTPClient improvements, sharding health checks, and CI coverage across macOS and Windows.

See `CHANGELOG.md` for full release notes and migration guidance.

## Contributing

Bug reports, feature suggestions, and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).

---

<div align="center">

[Documentation](https://github.com/M1tsumi/SwiftDisc/wiki) · [Discord](https://discord.gg/6nS2KqxQtj) · [Examples](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples)

</div>
