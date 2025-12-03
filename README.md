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
    .package(url: "https://github.com/M1tsumi/SwiftDisc.git", from: "0.11.0")
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

For endpoints we haven't wrapped yet, use `rawGET`, `rawPOST`, etc.

### Rate Limiting

Per-route and global rate limits are handled automatically. The client backs off and retries when needed.

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

### Current Focus (v0.11.x)
- [x] Autocomplete
- [x] File uploads polish (MIME + guardrails)
- [x] Gateway parity: Threads & Scheduled Events + raw fallback
- [x] Experimental voice receive support (Apple platforms)
- [x] Performance work for large, multi-shard bots
- Caching and permissions utilities
- Extensions/cogs system

## Contributing

Bug reports, feature suggestions, and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).

---

<div align="center">

[Documentation](https://github.com/M1tsumi/SwiftDisc/wiki) · [Discord](https://discord.gg/6nS2KqxQtj) · [Examples](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples)

</div>
