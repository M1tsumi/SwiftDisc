<div align="center">

![SwiftDisc Typing](https://raw.githubusercontent.com/M1tsumi/M1tsumi/main/assets/typing-swiftdisc.svg)

**A Swift-native, cross-platform Discord API library**  
Build Discord bots and integrations natively in Swift — fast, modern, and fully async.

<a href="https://discord.com/invite/r4rCAXvb8d" target="_blank"><img alt="Join our Discord" src="https://img.shields.io/badge/🔥%20JOIN%20OUR%20DISCORD-Click%20to%20Chat-EC4899?style=for-the-badge&logo=discord&logoColor=white"></a>

[![Discord](https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white)](https://discord.com/invite/r4rCAXvb8d)
[![Swift Version](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![CI](https://github.com/M1tsumi/SwiftDisc/actions/workflows/ci.yml/badge.svg)
[![GitHub Stars](https://img.shields.io/github/stars/M1tsumi/SwiftDisc?style=social)](https://github.com/M1tsumi/SwiftDisc/stargazers)
![Platforms](https://img.shields.io/badge/platforms-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS%20|%20Windows-informational)
![SPM](https://img.shields.io/badge/SPM-supported-success)

<div>
  <a href="https://github.com/M1tsumi/SwiftDisc/wiki" target="_blank"><img alt="Docs" src="https://img.shields.io/badge/📖%20Docs-Wiki-blue?style=for-the-badge"></a>
  <a href="#installation"><img alt="Install" src="https://img.shields.io/badge/⚙️%20Install-SPM-orange?style=for-the-badge"></a>
  <a href="https://github.com/M1tsumi/SwiftDisc/tree/main/Examples" target="_blank"><img alt="Examples" src="https://img.shields.io/badge/🧪%20Examples-Repo-green?style=for-the-badge"></a>
  <a href="https://discord.com/invite/r4rCAXvb8d" target="_blank"><img alt="Join Discord" src="https://img.shields.io/badge/💬%20Join%20Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white"></a>
</div>

📚 [Features](#features) • ⚙️ [Installation](#installation) • 🚦 [Quick Start](#quick-start) • 🧾 [Documentation](#documentation) • 🗺️ [Roadmap](#roadmap)

</div>

---

## Overview

SwiftDisc is a modern Discord API library built from the ground up for Swift. Drawing inspiration from discord.py's proven architecture, SwiftDisc embraces Swift concurrency, type safety, and modern patterns to deliver a production-ready solution for building Discord bots and applications.

### Key Features

- **🚀 Swift Concurrency First** — Built on async/await and AsyncSequence for scalable, responsive applications
- **🎯 Strongly Typed** — Comprehensive type-safe models matching Discord's API payloads
- **🌐 Cross-Platform** — Runs on iOS, macOS, tvOS, watchOS, and Windows
- **🏗️ Clean Architecture** — Clear separation between REST, Gateway, Models, and Client layers
- **⚡ Production Ready** — Respects Discord rate limits and connection lifecycles out of the box

## Platform Support

| Platform | Minimum Version |
|----------|----------------|
| iOS | 14.0+ |
| macOS | 11.0+ |
| tvOS | 14.0+ |
| watchOS | 7.0+ |
| Windows | Swift 5.9+ |

> **Note:** WebSocket support on non-Apple platforms may vary across Swift Foundation implementations. SwiftDisc uses conditional compilation and abstraction layers to maintain Windows compatibility. A dedicated WebSocket adapter is planned if Foundation's WebSocket support is unavailable.

## Installation

### Swift Package Manager

Add SwiftDisc to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/M1tsumi/SwiftDisc.git", from: "0.7.0")
]
```

Then add it to your target:

```swift
targets: [
    .target(
        name: "YourBot",
        dependencies: ["SwiftDisc"]
    )
]
```

## Setup & Configuration

### Prerequisites

- Swift 5.9+
- Internet access to Discord Gateway and REST endpoints
- A Discord application with a Bot token

### Windows

- Install Swift toolchain for Windows (from swift.org downloads)
- Ensure `swift` is on PATH
- Foundation's URLSession WebSocket is used; no extra dependencies required

### Environment Variables

- `DISCORD_TOKEN` — your bot token (do not include `Bot ` prefix)

Example run command:

```bash
DISCORD_TOKEN=your_token_here swift run
```

### Intents

- Start with minimal intents: `.guilds`, `.guildMessages`
- Enable privileged intents in the Developer Portal if needed (`.messageContent`, `.guildMembers`, `.guildPresences`)

### Logging

SwiftDisc prints structured logs to stdout by default. To integrate with swift-log:

```swift
import Logging
LoggingSystem.bootstrap { label in
    var h = StreamLogHandler.standardOutput(label: label)
    h.logLevel = .info // .debug for development
    return h
}
```

### Migrating to ShardingGatewayManager

If you currently use `DiscordClient.loginAndConnect`, you can migrate to sharding with minimal changes:

```swift
// Before
let client = DiscordClient(token: token)
try await client.loginAndConnect(intents: [.guilds, .guildMessages])
for await ev in client.events { /* ... */ }

// After
let manager = await ShardingGatewayManager(
    token: token,
    configuration: .init(shardCount: .automatic),
    intents: [.guilds, .guildMessages]
)
try await manager.connect()
for await sharded in manager.events { /* sharded.event, sharded.shardId */ }
```

## Quick Start

Here's a minimal bot that responds to Discord events:

```swift
import SwiftDisc

@main
struct BotMain {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] ?? "YOUR_BOT_TOKEN"
        let client = DiscordClient(token: token)
        
        do {
            // Connect with required intents
            try await client.loginAndConnect(intents: [
                .guilds,
                .guildMessages,
                .messageContent  // Privileged intent - requires approval
            ])
            
            // Process events as they arrive
            for await event in client.events {
                switch event {
                case .ready(let info):
                    print("✅ Connected as: \(info.user.username)")
                    
                case .messageCreate(let message):
                    print("💬 [\(message.channel_id)] \(message.author.username): \(message.content)")
                    
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

### Understanding Intents

Discord uses **Gateway Intents** to control which events your bot receives:

- **Standard Intents** (`.guilds`, `.guildMessages`) — Available to all bots
- **Privileged Intents** (`.messageContent`) — Require explicit approval in the Discord Developer Portal

> ⚠️ **Important:** The `.messageContent` intent is privileged and must be enabled in your bot's settings. Start with minimal intents and add more only as needed to reduce event volume and complexity.

**Enable privileged intents:**
1. Visit the [Discord Developer Portal](https://discord.com/developers/applications)
2. Select your application
3. Navigate to the "Bot" section
4. Enable required privileged intents under "Privileged Gateway Intents"

## Documentation

### Core Components

#### DiscordClient

The main entry point for interacting with Discord:

```swift
let client = DiscordClient(token: "YOUR_BOT_TOKEN")
try await client.loginAndConnect(intents: [.guilds, .guildMessages])
```

#### Event Handling

SwiftDisc uses AsyncSequence for event processing:

```swift
for await event in client.events {
    switch event {
    case .ready(let info):
        // Bot is connected and ready
    case .messageCreate(let message):
        // New message received
    case .guildCreate(let guild):
        // Guild data received
    }
}
```

#### REST API

Make direct API calls when needed:

```swift
let user = try await client.getCurrentUser()
try await client.sendMessage(channelId: "123456789", content: "Hello, Discord!")
```

### Examples

- Ping bot: `Examples/PingBot.swift`
- Prefix commands bot with help: `Examples/CommandsBot.swift`
- Slash commands bot: `Examples/SlashBot.swift`

## Current Status

**Version:** 0.7.0

SwiftDisc is in active development. The following components are currently available:

### ✅ Implemented

- **REST API**
  - GET/POST/PATCH/DELETE operations
  - JSON encoding/decoding with detailed error decoding
  - Per-route rate limiting with automatic retries and 429 handling
  - Structured error types
  - Initial endpoint coverage: Channels, Guilds, Interactions, Webhooks
  - Message sending with embeds (title/desc/color/footer/author/thumbnail/image/timestamp/fields)

- **Models**
  - Snowflake identifiers
  - User, Channel, Message entities

- **Gateway**
  - Connection scaffolding
  - Identify/Heartbeat with ACK tracking, resume/reconnect
  - Presence updates helper

- **Client API**
  - `getCurrentUser()`
  - `sendMessage()`
  - `loginAndConnect()`
  - `events` AsyncSequence
  - Slash command management: create/list/delete/bulk overwrite (global/guild), options support

- **Testing**
  - Basic initialization tests
  - Mock infrastructure in development


## Production Deployment

Deploying SwiftDisc-based bots:

- **Build & Run**
  - Server/CLI: build with SwiftPM; run with environment variable `DISCORD_TOKEN`.
  - Use a process supervisor (systemd, launchd, PM2, or Docker) to keep the bot running.
- **Configuration**
  - Set required intents in the Discord Developer Portal.
  - Configure shard count if you operate at scale; use `ShardManager`.
- **Environment**
  - Enable logging (stdout/stderr) and retain logs.
  - Ensure outbound network access to Discord domains; time sync is recommended.
- **Scaling**
  - Horizontal: multiple processes with shard ranges.
  - Respect REST and gateway limits; avoid per-second spikes.
- **Secrets**
  - Never commit tokens. Use env vars or secret stores (Keychain/KeyVault/Parameter Store).
- **CI/CD**
  - Use GitHub Actions CI provided (build/test/coverage). Add a deploy job to your infrastructure.

### Sharding Configuration

For production bots with many guilds, prefer automatic shard count and staggered connections:

```swift
let manager = await ShardingGatewayManager(
    token: token,
    configuration: .init(
        shardCount: .automatic,
        connectionDelay: .staggered(interval: 1.5),
        makePresence: { shardId, total in
            .init(
                activities: [.init(name: "Shard \(shardId+1)/\(total)", type: 3 /* watching */)],
                status: "online",
                afk: false
            )
        }
    ),
    intents: [.guilds, .guildMessages, .messageContent]
)
```

### Health Monitoring

Expose a simple health probe using the sharding manager's health API:

```swift
struct HealthStatus: Codable {
    let healthy: Bool
    let totalShards: Int
    let readyShards: Int
    let connectingShards: Int
    let reconnectingShards: Int
    let averageLatencyMs: Int?
}

func healthCheck(manager: ShardingGatewayManager) async -> HealthStatus {
    let h = await manager.healthCheck()
    let avgMs = h.averageLatency.map { Int($0 * 1000) }
    let healthy = (h.readyShards == h.totalShards)
    return HealthStatus(
        healthy: healthy,
        totalShards: h.totalShards,
        readyShards: h.readyShards,
        connectingShards: h.connectingShards,
        reconnectingShards: h.reconnectingShards,
        averageLatencyMs: avgMs
    )
}
```

## Sharding

SwiftDisc provides a high-level `ShardingGatewayManager` for production-grade sharding:

```swift
let manager = await ShardingGatewayManager(
    token: token,
    configuration: .init(shardCount: .automatic),
    intents: [.guilds, .guildMessages]
)

try await manager.connect()

for await sharded in manager.events {
    // sharded.shardId identifies which shard received the event
    switch sharded.event {
    case .ready(let info): print("READY on shard \(sharded.shardId): \(info.user.username)")
    default: break
    }
}
```

**Best Practices**

- Start with `.automatic` shard count
- Monitor shard health in production (`healthCheck()` and `shardHealth(id:)`)
- Use `.staggered(interval:)` for very large bots
- Enable guild distribution verification during development
- Use `restartShard(_:)` to recover a problem shard without restarting the bot

**Troubleshooting**

- "Shard X failed to connect after 5 attempts" → check token/network/Discord status
- "Guild distribution mismatches detected" → try restarting the affected shard; ensure `.automatic` shard count
- High latency on specific shards → `restartShard(_:)` that shard

### Per-shard presence and event streams

```swift
let manager = await ShardingGatewayManager(
    token: token,
    configuration: .init(
        shardCount: .automatic,
        connectionDelay: .staggered(interval: 1.5),
        makePresence: { shard, total in
            .init(
                activities: [.init(name: "Shard \(shard+1)/\(total)", type: 3 /* watching */)],
                status: "online",
                afk: false
            )
        }
    ),
    intents: [.guilds, .guildMessages, .messageContent]
)

try await manager.connect()

// Filtered event stream for a subset of shards
for await se in manager.events(for: [0, 1]) {
    print("Shards 0-1 event from shard \(se.shardId)")
}
```

### Graceful shutdown

```swift
// On SIGINT/SIGTERM
Task { await manager.disconnect() }
```

---

## Advanced Features

### Scheduled Events

```swift
// Create a scheduled event (voice/stage/external)
let ev = try await client.createGuildScheduledEvent(
    guildId: guildId,
    channelId: voiceChannelId,
    entityType: .voice,
    name: "Community Meetup",
    scheduledStartTimeISO8601: "2026-01-10T18:00:00Z",
    description: "Monthly chat"
)

// Get interested users
let users = try await client.listGuildScheduledEventUsers(
    guildId: guildId,
    eventId: ev.id,
    withMember: true
)
```

### Stage Instances

```swift
// Start a stage instance
let stage = try await client.createStageInstance(
    channelId: stageChannelId,
    topic: "Q&A with the dev team",
    privacyLevel: 2 // guild-only
)

// Update topic
_ = try await client.modifyStageInstance(channelId: stageChannelId, topic: "Now taking questions!")

// End the stage
try await client.deleteStageInstance(channelId: stageChannelId)
```

### Auto Moderation

```swift
let rule = try await client.createAutoModerationRule(
    guildId: guildId,
    name: "Block Spam Links",
    eventType: 1, // message send
    triggerType: 3, // spam or keyword preset
    actions: [ .init(type: 1, metadata: nil) ]
)
```

### Audit Logs

```swift
let logs = try await client.getGuildAuditLog(guildId: guildId, actionType: 20, limit: 50)
for entry in logs.audit_log_entries { print(entry) }
```

### Stickers

```swift
let stickers = try await client.listGuildStickers(guildId: guildId)
let s = try await client.getSticker(id: someStickerId)
```

### Forum Channels

```swift
let thread = try await client.createForumThread(
    channelId: forumChannelId,
    name: "How do I use SwiftDisc?",
    content: "I'm trying to build a bot...",
    autoArchiveDuration: 1440
)
```

## Design Philosophy

SwiftDisc is built on these core principles:

1. **Type Safety** — Leverage Swift's type system to catch errors at compile time
2. **Modern Concurrency** — Embrace async/await and structured concurrency
3. **Clear Architecture** — Maintain strict boundaries between REST, Gateway, Models, and Client
4. **Respect Limits** — Honor Discord's rate limits and connection lifecycle requirements
5. **Cross-Platform First** — Support all Swift platforms from day one

## Discord API Listing Checklist (minreqs)

Status aligned with percentage.txt. Voice is not required for listing.

- [x] Entire documented API featureset (minus voice)
  - Broad REST coverage: Channels, Guilds, Interactions, Webhooks, Members, Roles, Bans, Permissions, Prune, Widget, Messages (send/edit/components), Lists.
- [x] Advanced gateway features (RESUME)
  - Identify/Resume/Reconnect with exponential backoff; shard preserved on reconnect.
- [x] REST rate limit handling
  - Per-route buckets, global limit handling, Retry-After, resilient retries.
- [x] Usability
  - README, InstallGuide, examples (Ping/Commands/Slash), CHANGELOG, percentage report; docs present.
- [x] Code style & conventions
  - Consistent API surface and naming; CI enabled; Production Deployment guidance added.
- [x] Distinct value vs existing libs (for Swift ecosystem)
  - Swift-native, async/await-first, cross-platform (incl. Windows), high-level routers.
- [x] Feature parity with other Swift libs
  - Embeds, slash commands (full mgmt + typed routing), sharding with manager, webhooks, rich REST surface; voice optional/pending.
- [x] Community conduct
  - Will adhere to Discord API community guidelines.

## Distinct Value vs Existing Swift Discord Libraries

SwiftDisc focuses on practical, production-ready strengths:

- **Swift-native, async/await-first**
  - Embraces structured concurrency throughout (Gateway, REST, high-level routers).
- **Cross-platform, including Windows**
  - Unified URLSession-based WebSocket adapter, tuned HTTP/WebSocket sessions, CI for macOS and Windows.
- **High-level developer ergonomics**
  - Prefix `CommandRouter` and `SlashCommandRouter` with typed accessors, subcommand paths, and error callbacks.
- **Resilience by design**
  - Actor-based `GatewayClient` and serialized `EventDispatcher` prevent race conditions; exponential backoff and session resume.
- **Modern message features**
  - Rich `Embed`, message `components` (buttons, selects), `attachments`, `mentions`, plus convenient send/edit helpers.
- **Pragmatic REST coverage + rate limits**
  - Per-route bucket limiter with global handling and retry-after; growing endpoints to cover the documented API.
- **Examples and docs**
  - Minimal Ping, Prefix Commands, and Slash bots; status tracking via percentage.txt; CHANGELOG-driven releases.

## Community & Support

- **Discord Server:** [Join our community](https://discord.com/invite/r4rCAXvb8d) for support, announcements, and discussions
- **GitHub Issues:** Report bugs and request features
- **GitHub Discussions:** Ask questions and share your projects

## Security

⚠️ **Never commit tokens or sensitive credentials to version control.**

**Best practices:**
- Use environment variables for bot tokens
- Leverage secure storage on device platforms (Keychain, credential managers)
- Follow Discord's [developer policies](https://discord.com/developers/docs/policies-and-agreements/developer-policy)
- Be mindful when requesting privileged intents

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

## Reference Implementation

SwiftDisc adapts proven patterns from [discord.py](https://github.com/Rapptz/discord.py) (BSD-licensed), implementing them idiomatically for Swift. Key adaptations include intents, event dispatch, and rate limiting strategies.

## Versioning

This project follows [Semantic Versioning](https://semver.org/). See [CHANGELOG.md](CHANGELOG.md) for detailed release notes.

## License

SwiftDisc is released under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

**Built with ❤️ for the Swift and Discord communities**

[Documentation](https://github.com/M1tsumi/SwiftDisc/wiki) • [Examples](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples) • [Discord](https://discord.com/invite/r4rCAXvb8d)

</div>
