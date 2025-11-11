<div align="center">

# SwiftDisc

**A Swift-native, cross-platform Discord API library**

[![Discord](https://img.shields.io/discord/1010302596351859718?logo=discord&label=Discord&color=5865F2)](https://discord.com/invite/r4rCAXvb8d)
[![Swift Version](https://img.shields.io/badge/Swift-5.9+-F05138)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[Features](#features) • [Installation](#installation) • [Quick Start](#quick-start) • [Documentation](#documentation) • [Roadmap](#roadmap)

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
    .package(url: "https://github.com/M1tsumi/SwiftDisc.git", from: "0.1.0")
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

## Current Status

**Version:** 0.1.0-alpha

SwiftDisc is in active development. The following components are currently available:

### ✅ Implemented

- **REST API**
  - Basic GET/POST operations
  - JSON encoding/decoding
  - Simple rate limiting
  - Structured error types

- **Models**
  - Snowflake identifiers
  - User, Channel, Message entities

- **Gateway**
  - Connection scaffolding
  - Identify/Heartbeat (in progress)

- **Client API**
  - `getCurrentUser()`
  - `sendMessage()`
  - `loginAndConnect()`
  - `events` AsyncSequence

- **Testing**
  - Basic initialization tests
  - Mock infrastructure in development

## Roadmap

SwiftDisc's development roadmap is inspired by battle-tested libraries like discord.py:

### Phase 1: Gateway Stability
- [ ] Complete Identify, Resume, and Reconnect logic
- [ ] Robust heartbeat/ACK tracking with jitter
- [ ] Comprehensive intent support
- [ ] Priority event coverage: `READY`, `MESSAGE_CREATE`, `GUILD_CREATE`, `INTERACTION_CREATE`
- [ ] Sharding support
- [ ] Presence updates

### Phase 2: REST Maturity
- [ ] Per-route rate limiting with automatic retries
- [ ] Detailed error payload decoding
- [ ] Complete endpoint coverage:
  - Channels
  - Guilds
  - Interactions
  - Webhooks

### Phase 3: High-Level API
- [ ] AsyncSequence as primary pattern with callback adapters
- [ ] Command framework (prefix and slash commands)
- [ ] Intelligent caching layer for users, guilds, channels, and messages
- [ ] Helper utilities for common bot patterns

### Phase 4: Cross-Platform Excellence
- [ ] Custom WebSocket adapter for Windows compatibility
- [ ] Continuous integration for macOS and Windows
- [ ] Platform-specific optimizations

### Phase 5: Production Hardening
- [ ] Comprehensive mock testing infrastructure
- [ ] Conformance testing against recorded Discord sessions
- [ ] Performance benchmarking
- [ ] Production deployment guides

## Design Philosophy

SwiftDisc is built on these core principles:

1. **Type Safety** — Leverage Swift's type system to catch errors at compile time
2. **Modern Concurrency** — Embrace async/await and structured concurrency
3. **Clear Architecture** — Maintain strict boundaries between REST, Gateway, Models, and Client
4. **Respect Limits** — Honor Discord's rate limits and connection lifecycle requirements
5. **Cross-Platform First** — Support all Swift platforms from day one

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