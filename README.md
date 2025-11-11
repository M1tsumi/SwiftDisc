<div align="center">

# SwiftDisc

SwiftDisc is a Swift-native, cross-platform library for the Discord API. It takes inspiration from discord.py’s architecture while embracing Swift concurrency and modern patterns suitable for production systems.

## Platforms

- iOS 14+
- macOS 11+
- tvOS 14+
- watchOS 7+
- Windows (Swift 5.9+)

Note: WebSocket support on non-Apple platforms may vary across Swift Foundation ports. SwiftDisc uses conditional compilation and an abstraction boundary to keep Windows support viable. A dedicated WebSocket adapter is planned if Foundation’s WebSocket isn’t available.

## Installation

Add to your Package.swift dependencies:

```swift
.package(url: "https://github.com/M1tsumi/SwiftDisc.git", from: "0.1.0")
```

### Notes on intents

- `.messageContent` is a privileged intent. Enable it in your bot’s settings on the Discord Developer Portal and follow Discord policies.
- Start minimal and add intents as needed. Extra intents increase event volume and complexity.


And add "SwiftDisc" to your target dependencies.

## Quick Start

```swift
import SwiftDisc

@main
struct BotMain {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] ?? "<Bot Token>"
        let client = DiscordClient(token: token)
        do {
            // Connect with common intents (messageContent is privileged; see Notes below)
            try await client.loginAndConnect(intents: [.guilds, .guildMessages, .messageContent])

            // Subscribe to events
            for await event in client.events {
                switch event {
                case .ready(let info):
                    print("Ready as: \(info.user.username)")
                case .messageCreate(let msg):
                    print("#\(msg.channel_id): \(msg.author.username): \(msg.content)")
                }
            }
        } catch {
            print("SwiftDisc error: \(error)")
        }
    }
}
```

## Design Goals

- Strongly-typed models matching Discord payloads
- Async/await and AsyncSequence-centric API for scalable event handling
- Clear separation of concerns: REST, Gateway, Models, Client
- Respect Discord rate limits and connection lifecycles

## Current Status (0.1.0-alpha)

- REST: Basic GET/POST, JSON encode/decode, simple rate limiter, error typing
- Models: Snowflake, User, Channel, Message
- Gateway: Minimal scaffolding; Identify/Heartbeat implementation in progress
- API: `DiscordClient` with `getCurrentUser`, `sendMessage`, `loginAndConnect`, and `events` stream
- Tests: Basic initialization test; mocks in progress

## Roadmap (inspired by discord.py)

- Gateway
  - Identify, Resume, Reconnect
  - Heartbeat/ACK tracking and jitter
  - Intents coverage: start with `.guilds`, `.guildMessages`, `.messageContent` (as permitted)
  - Event coverage (prioritized): READY, MESSAGE_CREATE, GUILD_CREATE, INTERACTION_CREATE
  - Sharding and presence updates

- REST
  - Route buckets and per-route rate limiting with retries
  - Error payload decoding into structured types
  - Key endpoints: Channels, Guilds, Interactions, Webhooks

- High-Level API
  - AsyncSequence as primary; callback adapters for UI frameworks
  - Command helpers (prefix and slash commands)
  - Caching layer for users/guilds/channels/messages

- Cross-Platform
  - WebSocket adapter for Windows if Foundation lacks URLSessionWebSocketTask
  - CI for macOS and Windows

- Testing & Tooling
  - Mock URLProtocol and WebSocket harness
  - Conformance tests vs. recorded Discord sessions

## Reference

- Primary reference implementation: discord.py (BSD-licensed) https://github.com/Rapptz/discord.py
  - We adapt patterns (intents, event dispatch, rate limits) idiomatically for Swift.


[![Discord](https://img.shields.io/discord/1010302596351859718?logo=discord)](https://discord.com/invite/r4rCAXvb8d)

## Support

- Discord: https://discord.com/invite/r4rCAXvb8d
  - Community support, Q&A, and announcements.

## Versioning

- This project follows Semantic Versioning (SemVer). See CHANGELOG.md for release notes.

## Security

- Never commit tokens. Use environment variables or secure storage.
- Be mindful of privileged intents and Discord developer policies.

## License

MIT. See LICENSE.
