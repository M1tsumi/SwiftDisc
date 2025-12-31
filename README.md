<div align="center">

![SwiftDisc Typing](https://raw.githubusercontent.com/M1tsumi/M1tsumi/main/assets/typing-swiftdisc.svg)

# SwiftDisc

[![Discord](https://img.shields.io/discord/1439300942167146508?color=5865F2&label=Discord&logo=discord&logoColor=white)](https://discord.gg/6nS2KqxQtj)
[![Swift Version](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![CI](https://github.com/M1tsumi/SwiftDisc/actions/workflows/ci.yml/badge.svg)](https://github.com/M1tsumi/SwiftDisc/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**A modern Swift library for building Discord bots and integrations.**

Built with async/await, strongly typed, and cross-platform.

[Documentation](https://github.com/M1tsumi/SwiftDisc/wiki) · [Examples](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples) · [Discord Server](https://discord.gg/6nS2KqxQtj)

</div>

---

## About

SwiftDisc is a powerful Swift library for interacting with the Discord API. It embraces modern Swift concurrency with async/await throughout, provides fully typed models for Discord's data structures, and handles common pain points like rate limiting, reconnection, and sharding automatically.

Whether you're building a simple bot or a complex integration, SwiftDisc gives you the tools you need while staying out of your way.

## Installation

Add SwiftDisc to your Swift package dependencies in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/M1tsumi/SwiftDisc.git", from: "1.1.0")
]
```

Then add it to your target:

```swift
targets: [
    .target(name: "YourBot", dependencies: ["SwiftDisc"])
]
```

### Platform Requirements

| Platform | Minimum Version |
|----------|----------------|
| macOS | 11.0+ |
| iOS | 14.0+ |
| tvOS | 14.0+ |
| watchOS | 7.0+ |
| Windows | Swift 5.9+ |

## Quick Start

Here's a simple bot that responds to messages:

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
                    print("✅ Logged in as \(info.user.username)")
                    
                case .messageCreate(let message) where message.content == "!ping":
                    try await client.sendMessage(
                        channelId: message.channel_id,
                        content: "🏓 Pong!"
                    )
                    
                default:
                    break
                }
            }
        } catch {
            print("❌ Error: \(error)")
        }
    }
}
```

## Features

## Features

### Core Capabilities

- **Gateway Connection**: WebSocket with automatic heartbeat, session resume, and event streaming
- **REST API**: Comprehensive coverage of Discord's HTTP endpoints
- **Rate Limiting**: Automatic per-route and global rate limit handling
- **Sharding**: Built-in support for large bots with health monitoring
- **Type Safety**: Strongly typed models throughout with compile-time safety
- **Cross-Platform**: Works on macOS, iOS, tvOS, watchOS, and Windows

### High-Level Features

- **Command Framework**: Built-in router for prefix and slash commands
- **Component Builders**: Fluent API for buttons, select menus, embeds, and modals
- **View Manager**: Persistent UI views with automatic lifecycle management
- **Collectors**: AsyncStream-based message and component collectors
- **Extensions/Cogs**: Modular architecture for organizing bot features
- **Utilities**: Mention formatters, emoji helpers, timestamp formatting, and more

### What's Included

The REST API covers all essential Discord features:

✅ Messages, embeds, reactions, threads  
✅ Channels, permissions, webhooks  
✅ Guilds, members, roles, bans  
✅ Slash commands, autocomplete, modals  
✅ Components (buttons, select menus)  
✅ Scheduled events, stage instances  
✅ Auto-moderation rules  
✅ Application commands and interactions  

For a complete API checklist, see the [REST API Coverage](#rest-api-coverage) section below.

## Examples

### Command Framework

```swift
let router = CommandRouter(prefix: "!")
router.register("ping") { ctx in
    try? await ctx.reply("Pong!")
}

client.onMessageCreate { message in
    await router.processMessage(message)
}
```


### Command Framework

Create command-based bots easily with the built-in router:

```swift
let router = CommandRouter(prefix: "!")
router.register("ping") { ctx in
    try? await ctx.reply("Pong!")
}

client.onMessageCreate { message in
    await router.processMessage(message)
}
```

Add checks and cooldowns to commands:

```swift
router.register("ban", checks: [isAdminCheck], cooldown: 10.0) { ctx in
    // Command logic here
}
```

[See full example →](Examples/CommandFrameworkBot.swift)

### Slash Commands

```swift
let slash = SlashCommandRouter()
slash.register("greet") { interaction in
    try await interaction.reply("Hello from SwiftDisc!")
}
```

[See full example →](Examples/SlashBot.swift)

### Components & Embeds

Use the fluent builders to create rich messages:

```swift
let embed = EmbedBuilder()
    .title("Welcome!")
    .description("Thanks for joining our server")
    .color(0x5865F2)
    .timestamp(Date())
    .build()

let button = ButtonBuilder()
    .style(.primary)
    .label("Click me!")
    .customId("welcome_button")
    .build()

let row = ActionRowBuilder()
    .addButton(button)
    .build()

try await client.sendMessage(
    channelId: channelId,
    embeds: [embed],
    components: [row]
)
```

[See full example →](Examples/ComponentsExample.swift)

### Message Collectors

Collect messages or component interactions using AsyncStreams:

```swift
let collector = client.createMessageCollector(
    filter: { $0.author.id == userId && $0.channel_id == channelId },
    timeout: 60.0,
    max: 1
)

for await message in collector {
    print("Received: \(message.content)")
}
```

### View Manager

Create persistent interactive UIs with automatic lifecycle management:

```swift
let view = BasicView(timeout: 300) { customId, interaction in
    if customId == "confirm_button" {
        try? await interaction.reply("Confirmed!")
        return true // Remove view after use
    }
    return false
}

client.viewManager?.register(view: view, for: messageId)
```

[See full example →](Examples/ViewExample.swift)

### Extensions/Cogs

Organize your bot into modular extensions:

```swift
struct ModerationCog: Cog {
    func onLoad(client: DiscordClient) async {
        print("Moderation module loaded")
        // Register commands, set up listeners
    }
    
    func onUnload(client: DiscordClient) async {
        print("Moderation module unloaded")
    }
}

let extensionManager = ExtensionManager()
await extensionManager.load(cog: ModerationCog(), client: client)
```

[See full example →](Examples/CogExample.swift)

## Advanced Features

### Sharding

For large bots, SwiftDisc handles sharding automatically:

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
print("Shards: \(health.readyShards)/\(health.totalShards) ready")
```

### Voice Support (Experimental)

Connect to voice channels and send audio:

```swift
// Enable voice in config
let config = DiscordConfiguration(enableVoiceExperimental: true)
let client = DiscordClient(token: token, configuration: config)

// Join a voice channel
try await client.joinVoice(guildId: guildId, channelId: voiceChannelId)

// Send Opus audio
try await client.playVoiceOpus(guildId: guildId, data: opusPacket)

// Or use an audio source
try await client.play(source: audioSource, guildId: guildId)
```

### File Uploads

Send files with messages and interactions:

```swift
let file = FileAttachment(
    filename: "image.png",
    data: imageData,
    contentType: "image/png"
)

try await client.sendMessage(
    channelId: channelId,
    content: "Check out this image!",
    files: [file]
)
```

For interaction responses:

```swift
try await client.createInteractionResponseWithFiles(
    applicationId: appId,
    interactionToken: token,
    payload: responsePayload,
    files: [file]
)
```

### Utilities

SwiftDisc includes helpful utilities for common tasks:

```swift
// Mention formatting
Mentions.user(userId)           // <@123456>
Mentions.channel(channelId)     // <#123456>
Mentions.role(roleId)           // <@&123456>

// Custom emoji
EmojiUtils.custom(name: "party", id: emojiId, animated: true)

// Timestamp formatting
DiscordTimestamp.format(date: Date(), style: .relative)

// Escape special characters
MessageFormat.escapeSpecialCharacters(userInput)
```

## REST API Coverage

### Messages
✅ Send, edit, delete messages  
✅ Reactions (add, remove, remove all)  
✅ Embeds, components, attachments  
✅ Pins, bulk delete  
✅ Crosspost, polls  
✅ Forward messages  

### Channels
✅ Create, modify, delete channels  
✅ Permissions, invites  
✅ Webhooks (full CRUD + execute)  
✅ Typing indicators  
✅ Threads (create, archive, members)  

### Guilds
✅ Create, modify, delete guilds  
✅ Channels, roles, emojis  
✅ Members (add, remove, modify, timeout)  
✅ Bans, prune, audit logs  
✅ Widget, preview, vanity URL  
✅ Templates  

### Interactions
✅ Slash commands (global & guild)  
✅ Autocomplete  
✅ Modals and components  
✅ Interaction responses  
✅ Follow-up messages  
✅ Command localization  

### Other Features
✅ Scheduled events  
✅ Stage instances  
✅ Auto-moderation rules  
✅ Application emojis  
✅ Role connections (linked roles)  
✅ Sticker info (read-only)  

### Not Yet Implemented
❌ Guild sticker creation/modification  
❌ Soundboard endpoints  

For unsupported endpoints, use the raw HTTP methods: `rawGET`, `rawPOST`, `rawPATCH`, `rawDELETE`

## More Examples

Check out the [Examples](Examples) directory for complete, runnable examples:

- [PingBot.swift](Examples/PingBot.swift) - Simple message responder
- [CommandFrameworkBot.swift](Examples/CommandFrameworkBot.swift) - Command routing with checks
- [SlashBot.swift](Examples/SlashBot.swift) - Slash command handling
- [AutocompleteBot.swift](Examples/AutocompleteBot.swift) - Autocomplete interactions
- [ComponentsExample.swift](Examples/ComponentsExample.swift) - Buttons, selects, and embeds
- [ViewExample.swift](Examples/ViewExample.swift) - Persistent interactive views
- [CogExample.swift](Examples/CogExample.swift) - Modular bot architecture
- [FileUploadBot.swift](Examples/FileUploadBot.swift) - Sending files
- [ThreadsAndScheduledEventsBot.swift](Examples/ThreadsAndScheduledEventsBot.swift) - Thread and event handling
- [VoiceStdin.swift](Examples/VoiceStdin.swift) - Voice playback (experimental)
- [LinkedRolesBot.swift](Examples/LinkedRolesBot.swift) - Role connections

## Documentation

- **[Wiki](https://github.com/M1tsumi/SwiftDisc/wiki)** - Setup guides, concepts, and deployment tips
- **[Examples](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples)** - Complete working examples
- **[Discord Server](https://discord.gg/6nS2KqxQtj)** - Get help and discuss the library
- **[Changelog](CHANGELOG.md)** - Version history and migration guides

## Building & Testing

```bash
# Build the library
swift build

# Run tests
swift test

# With code coverage (macOS)
swift test --enable-code-coverage
```

CI runs on macOS (Xcode 16.4) and Windows (Swift 6.2).

## Contributing

We welcome contributions! Whether it's bug reports, feature requests, or pull requests, we'd love your help making SwiftDisc better.

Before contributing, please:
- Check existing issues and PRs to avoid duplicates
- Read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines
- Join our [Discord server](https://discord.gg/6nS2KqxQtj) if you have questions

## Roadmap

### Current Version: v1.1.0

Expanded Discord API coverage with new gateway events and REST endpoints. See [CHANGELOG.md](CHANGELOG.md) for details.

### Future Plans

- Enhanced autocomplete and modal builders
- Additional component types as Discord adds them
- Performance optimizations and caching improvements
- Expanded voice support

Have ideas? Open an issue or join the discussion on Discord!

## Help

If you need help or have questions:

- Check the [Wiki](https://github.com/M1tsumi/SwiftDisc/wiki) for guides and documentation
- Browse [Examples](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples) for code samples
- Join our [Discord server](https://discord.gg/6nS2KqxQtj) for live help
- Search [existing issues](https://github.com/M1tsumi/SwiftDisc/issues) for similar questions

## License

SwiftDisc is released under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

**Built with ❤️ using Swift**

[Documentation](https://github.com/M1tsumi/SwiftDisc/wiki) · [Discord Server](https://discord.gg/6nS2KqxQtj) · [Examples](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples)

</div>
