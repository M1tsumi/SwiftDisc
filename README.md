<div align="center">

![SwiftDisc Typing](https://raw.githubusercontent.com/M1tsumi/M1tsumi/main/assets/typing-swiftdisc.svg)

# SwiftDisc

**A modern, Swift-native Discord API library for building powerful bots**

Build Discord bots and integrations with the elegance of Swift — fully async, strongly typed, and production-ready.

<a href="https://discord.com/invite/r4rCAXvb8d" target="_blank"><img alt="Join our Discord" src="https://img.shields.io/badge/💬%20JOIN%20OUR%20DISCORD-Get%20Help%20%26%20Share%20Ideas-5865F2?style=for-the-badge&logo=discord&logoColor=white"></a>

[![Discord](https://img.shields.io/discord/YOUR_SERVER_ID?color=5865F2&label=Discord&logo=discord&logoColor=white)](https://discord.com/invite/r4rCAXvb8d)
[![Swift Version](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/M1tsumi/SwiftDisc?style=social)](https://github.com/M1tsumi/SwiftDisc/stargazers)

<div>
  <a href="https://github.com/M1tsumi/SwiftDisc/wiki" target="_blank"><img alt="Documentation" src="https://img.shields.io/badge/📖%20Documentation-Wiki-4A9EFF?style=for-the-badge"></a>
  <a href="#-quick-start"><img alt="Quick Start" src="https://img.shields.io/badge/🚀%20Quick%20Start-Get%20Started-00C853?style=for-the-badge"></a>
  <a href="https://github.com/M1tsumi/SwiftDisc/tree/main/Examples" target="_blank"><img alt="Examples" src="https://img.shields.io/badge/💡%20Examples-Learn%20More-FF6B6B?style=for-the-badge"></a>
</div>

</div>

---

## Why SwiftDisc?

SwiftDisc brings the power of modern Swift to Discord bot development. Whether you're building a simple utility bot or a complex multi-server application, SwiftDisc provides the tools you need with an API that feels natural to Swift developers.

### ✨ What Makes SwiftDisc Special

- **🎯 Swift-First Design** — Built from the ground up for Swift, leveraging async/await, actors, and structured concurrency
- **🔒 Type Safety** — Comprehensive type-safe models that catch errors at compile time
- **🌍 Truly Cross-Platform** — Deploy on iOS, macOS, tvOS, watchOS, and Windows with the same codebase
- **⚡ Production Ready** — Automatic rate limiting, connection resilience, and sharding support out of the box
- **🎨 Developer Friendly** — Intuitive APIs inspired by discord.py, adapted for Swift's strengths

### 🎯 Perfect For

- **First-time bot developers** looking for a modern, well-documented library
- **Swift developers** wanting to leverage their existing skills
- **Cross-platform projects** requiring deployment flexibility
- **Production applications** demanding reliability and performance

---

## 🚀 Quick Start

Get your first bot running in minutes:

```swift
import SwiftDisc

@main
struct MyFirstBot {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)
        
        do {
            try await client.loginAndConnect(intents: [.guilds, .guildMessages, .messageContent])
            
            for await event in client.events {
                switch event {
                case .ready(let info):
                    print("✅ Bot is online as \(info.user.username)!")
                    
                case .messageCreate(let message) where message.content == "!hello":
                    try await client.sendMessage(
                        channelId: message.channel_id,
                        content: "👋 Hello, \(message.author.username)!"
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

#### App Emoji (typed top-level)

```swift
// Create (image should be data URI string, e.g. "data:image/png;base64,<...>")
let created = try await client.createAppEmoji(
  applicationId: appId,
  name: "party",
  imageBase64: "data:image/png;base64,....",
  options: ["roles": .array([])] // optional extras
)

// Update
let updated = try await client.updateAppEmoji(
  applicationId: appId,
  emojiId: "1234567890",
  updates: ["name": .string("party_blob")] 
)

// Delete
try await client.deleteAppEmoji(
  applicationId: appId,
  emojiId: "1234567890"
)
```

#### UserApps (typed wrapper names)

```swift
// Create resource under your application scope
let res = try await client.createUserAppResource(
  applicationId: appId,
  relativePath: "directory/listings",
  payload: ["title": .string("My Awesome App"), "enabled": .bool(true)]
)

// Update resource
let upd = try await client.updateUserAppResource(
  applicationId: appId,
  relativePath: "directory/listings/abc",
  payload: ["enabled": .bool(false)]
)

// Delete resource
try await client.deleteUserAppResource(
  applicationId: appId,
  relativePath: "directory/listings/abc"
)
```

**That's it!** You now have a working Discord bot. 🎉

---

## 📦 Installation

### Swift Package Manager

Add SwiftDisc to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/M1tsumi/SwiftDisc.git", from: "0.8.0")
]
```

Then include it in your target:

```swift
targets: [
    .target(name: "YourBot", dependencies: ["SwiftDisc"])
]
```

### Platform Requirements

| Platform | Minimum Version | Status |
|----------|----------------|--------|
| iOS | 14.0+ | ✅ Fully Supported |
| macOS | 11.0+ | ✅ Fully Supported |
| tvOS | 14.0+ | ✅ Fully Supported |
| watchOS | 7.0+ | ✅ Fully Supported |
| Windows | Swift 5.9+ | ✅ Fully Supported |

---

## 🎓 Learn by Example

We've created comprehensive examples to help you get started:

### 📌 Simple Ping Bot
Perfect for understanding the basics of event handling and message responses.

```swift
// Responds to "!ping" with the bot's latency
case .messageCreate(let message) where message.content == "!ping":
    try await client.sendMessage(
        channelId: message.channel_id,
        content: "🏓 Pong! Latency: 42ms"
    )
```
 
**[View Full Example →](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples/PingBot.swift)**

### 🎮 Command Handler Bot
Learn how to build a command system with prefix routing and help commands.

```swift
let router = CommandRouter(prefix: "!")
router.register("help") { context in
    try await context.reply("Available commands: !help, !userinfo, !serverinfo")
}
```

**[View Full Example →](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples/CommandsBot.swift)**

### ⚡ Slash Commands & Autocomplete
Discover modern Discord interactions with slash commands and autocomplete.

```swift
let slash = SlashCommandRouter()
slash.register("greet") { interaction in
    try await interaction.reply("Hello from SwiftDisc! 👋")
}
```

**[Slash Bot →](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples/SlashBot.swift)**

### 🔎 Autocomplete Provider
Dynamic suggestions for command options using `AutocompleteRouter`.

**[Autocomplete Bot →](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples/AutocompleteBot.swift)**

### 📎 File Uploads with Embeds
Multipart uploads with content-type detection and size guardrails.

**[File Upload Bot →](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples/FileUploadBot.swift)**

### 🧵 Threads & Scheduled Events Listener
Listen to thread lifecycle and guild scheduled events.

**[Threads & Scheduled Events →](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples/ThreadsAndScheduledEventsBot.swift)**

---

## 📚 Comprehensive Documentation

### Getting Started

Our [Wiki](https://github.com/M1tsumi/SwiftDisc/wiki) provides in-depth guides for:

- **🎯 Core Concepts** — Understanding intents, events, and the Discord API
- **🔧 Configuration** — Setting up your bot for development and production
- **🎨 Message Features** — Embeds, components, attachments, and more
- **⚙️ Sharding** — Scaling your bot across multiple servers
- **🚀 Deployment** — Best practices for production environments

### Need Help?

- **💬 [Join our Discord Server](https://discord.com/invite/r4rCAXvb8d)** — Get real-time support from the community
- **📖 [Browse the Wiki](https://github.com/M1tsumi/SwiftDisc/wiki)** — Detailed documentation and tutorials
- **🐛 [Report Issues](https://github.com/M1tsumi/SwiftDisc/issues)** — Found a bug? Let us know!
- **💡 [GitHub Discussions](https://github.com/M1tsumi/SwiftDisc/discussions)** — Share your projects and ideas

---

## 🌟 Features

### Gateway & Events
- ✅ Full WebSocket gateway implementation
- ✅ Automatic heartbeat and session management
- ✅ Resume support for connection recovery
- ✅ Structured event system with AsyncSequence
- ✅ Presence updates and status management
- ✅ Threads and Scheduled Events (create/update/delete, members add/remove)
- ✅ 100% event visibility via `DiscordEvent.raw(String, Data)` fallback for unmodeled dispatches

### REST API Coverage
- ✅ Channels — Create, modify, delete channels and threads
- ✅ Messages — Send, edit, delete with embeds and components
- ✅ Guilds — Full server management capabilities
- ✅ Members & Roles — User and permission management
- ✅ Slash Commands — Create and manage application commands
- ✅ Webhooks — Create and execute webhooks
- ✅ Auto Moderation — Configure moderation rules
- ✅ Scheduled Events — Create and manage server events
- ✅ Forum Channels — Create threads and posts
- ✅ Raw coverage helpers: `rawGET/POST/PATCH/PUT/DELETE` for any unsupported endpoint

#### Member Timeouts

```swift
// Timeout a member until a specific ISO8601 timestamp
let in10Min = Date().addingTimeInterval(10 * 60)
let updated: GuildMember = try await client.setMemberTimeout(guildId: guildId, userId: userId, until: in10Min)

// Clear timeout
let cleared: GuildMember = try await client.clearMemberTimeout(guildId: guildId, userId: userId)
```

### Advanced Features
- ✅ Per-route rate limit handling with automatic retries
- ✅ Global rate limit detection and backoff
- ✅ Sharding support with automatic shard count
- ✅ Health monitoring and shard management
- ✅ Typed command routing (prefix and slash) + Autocomplete router
- ✅ Rich embed builder and message components (buttons, select menus)
- ✅ File uploads: multipart with content-type detection and configurable guardrails (`maxUploadBytes`)
- ✅ Advanced caching: configurable TTLs and per-channel message LRU
- ✅ Extensions/Cogs: simple plugin protocol and `Cog` helper; `DiscordClient.loadExtension(_:)`
- ✅ Permissions utilities: effective permission calculator with channel overwrites

#### Components V2 (generic payload)

Use `postMessage(channelId:payload:)` with `JSONValue` to send Components V2 while keeping SwiftDisc zero-dependency and future-proof. Paste the payload from the Discord docs.

```swift
// Example skeleton – replace with the latest Components V2 JSON from docs
let payload: [String: JSONValue] = [
  "content": .string("Hello with Components V2"),
  "flags": .int(1 << 15), // if docs require enabling V2 via flag
  "components": .array([
    .object(["type": .int(1), "children": .array([ /* ... */ ])])
  ])
]
let msg = try await client.postMessage(channelId: channelId, payload: payload)
```

Typed envelope helper:

```swift
let v2 = V2MessagePayload(
  content: "Hello with V2",
  flags: 1 << 15, // if required by docs
  components: [
    .object(["type": .int(1), "children": .array([ /* ... */ ])])
  ]
)
let msg = try await client.sendComponentsV2Message(channelId: channelId, payload: v2)
```

#### Polls (generic payload)

Use `createPollMessage(channelId:content:poll:flags:components:)` with a `poll` object conforming to the Poll Resource schema.

```swift
// Example skeleton – replace with the Poll Resource JSON from docs
let poll: [String: JSONValue] = [
  "question": .object(["text": .string("Your favorite language?")]),
  "answers": .array([
    .object(["answer_id": .int(1), "poll_media": .object(["text": .string("Swift")])]),
    .object(["answer_id": .int(2), "poll_media": .object(["text": .string("Kotlin")])])
  ]),
  "allow_multiple": .bool(false),
  "duration": .int(600) // seconds
]
let msg = try await client.createPollMessage(channelId: channelId, content: "Vote now!", poll: poll)
```

Typed envelope helper:

```swift
let pollPayload = PollPayload(
  question: "Your favorite language?",
  answers: ["Swift", "Kotlin"],
  durationSeconds: 600,
  allowMultiple: false
)
let msg = try await client.createPollMessage(channelId: channelId, payload: pollPayload, content: "Vote now!")
```

#### Localization (Application Commands)

Update command name/description localizations:

```swift
let updated = try await client.setCommandLocalizations(
  applicationId: appId,
  commandId: cmdId,
  nameLocalizations: [
    "en-US": "ping",
    "ja": "ピン"
  ],
  descriptionLocalizations: [
    "en-US": "Check latency",
    "ja": "レイテンシーを確認"
  ]
)
```

#### Forwarding

Post a message in another channel that references an existing message (portable forward):

```swift
let forwarded = try await client.forwardMessageByReference(
  targetChannelId: targetChannelId,
  sourceChannelId: sourceChannelId,
  messageId: messageId
)
```

#### Generic Application Resources (UserApps/App Emoji)

Use these helpers to call application-scoped endpoints with `JSONValue` payloads. This keeps SwiftDisc current as Discord evolves.

```swift
// POST /applications/{appId}/{relativePath}
let createRes = try await client.postApplicationResource(
  applicationId: appId,
  relativePath: "some/feature",
  payload: ["key": .string("value")]
)

// PATCH /applications/{appId}/{relativePath}
let patchRes = try await client.patchApplicationResource(
  applicationId: appId,
  relativePath: "some/feature/id",
  payload: ["enabled": .bool(true)]
)

// DELETE /applications/{appId}/{relativePath}
try await client.deleteApplicationResource(
  applicationId: appId,
  relativePath: "some/feature/id"
)
```

#### Developer Utilities
- ✅ Mentions: `Mentions.user(_:)`, `Mentions.channel(_:)`, `Mentions.role(_:)`, `Mentions.slashCommand(name:id:)`
- ✅ Emoji helpers: `EmojiUtils.custom(name:id:animated:)`
- ✅ Timestamps: `DiscordTimestamp.format(date:style:)`, `format(unixSeconds:style:)`
- ✅ Escaping: `MessageFormat.escapeSpecialCharacters(_:)`

---

## 🎯 Production Ready

SwiftDisc is built for real-world applications:

### Reliability
- **Automatic Reconnection** — Handles network issues gracefully
- **Rate Limit Compliance** — Respects Discord's limits automatically
- **Session Resume** — Maintains connection state across reconnects

### Scalability
- **Sharding Support** — Built-in multi-shard management
- **Health Monitoring** — Track shard status and latency
- **Graceful Shutdown** — Clean disconnection handling

### Developer Experience
- **Comprehensive Logging** — Detailed logs for debugging
- **Type-Safe APIs** — Catch errors at compile time
- **Clear Error Messages** — Actionable error descriptions

```swift
// Automatic sharding for large bots
let manager = await ShardingGatewayManager(
    token: token,
    configuration: .init(
        shardCount: .automatic,
        connectionDelay: .staggered(interval: 1.5)
    ),
    intents: [.guilds, .guildMessages]
)

try await manager.connect()

// Monitor health across all shards
let health = await manager.healthCheck()
print("Ready shards: \(health.readyShards)/\(health.totalShards)")
```

---

## 💬 Join Our Community

We're building SwiftDisc together with the community! Whether you're a beginner looking to create your first bot or an experienced developer with feature requests, we'd love to have you.

<div align="center">

### [💬 Join Our Discord Server](https://discord.com/invite/r4rCAXvb8d)

Get help, share your projects, and connect with other SwiftDisc developers!

**What you'll find:**
- 🆘 Support channels for troubleshooting
- 💡 Showcase your bots and get feedback
- 📢 Stay updated with the latest releases
- 🤝 Collaborate with other developers

</div>

---

## 🛣️ Roadmap

We're actively developing SwiftDisc with these priorities:

### Current Focus (v0.9.x)
- [x] Autocomplete
- [x] File uploads polish (MIME + guardrails)
- [x] Gateway parity: Threads & Scheduled Events + raw fallback
- [x] Advanced caching & permissions utilities
- [x] Extensions/Cogs

### Future Plans
- [ ] Voice support (optional module)
- [ ] Voice support (send‑only MVP)
- [ ] Performance optimizations

**Want to influence the roadmap?** Join the [Discord server](https://discord.com/invite/r4rCAXvb8d) and share your ideas!



## 🔊 Voice (Experimental)

Initial voice support is available behind a configuration flag. This is a send-only implementation that connects to Discord Voice, performs UDP IP discovery, negotiates `xsalsa20_poly1305`, and can transmit Opus frames (no external dependencies required).

Enable and use:

```swift
let config = DiscordConfiguration(enableVoiceExperimental: true)
let client = DiscordClient(token: token, configuration: config)

try await client.joinVoice(guildId: guildId, channelId: channelId)

// Option A: Push individual Opus packets (20ms @ 48kHz)
try await client.playVoiceOpus(guildId: guildId, data: opusPacket)

// Option B: Stream from a VoiceAudioSource
struct MySource: VoiceAudioSource {
    func nextFrame() async throws -> OpusFrame? { /* return OpusFrame(data:packet,durationMs:20) */ }
}
try await client.play(source: MySource(), guildId: guildId)

try await client.leaveVoice(guildId: guildId)
```

What’s included:

- Voice Gateway handshake (Hello → Identify → Ready → Heartbeat)
- UDP IP discovery (Network.framework on Apple platforms)
- Protocol selection (xsalsa20_poly1305)
- Session Description key handling
- RTP packetization + pure-Swift Secretbox encryption (no SwiftPM deps)
- Speaking flag management

Requirements:

- Input must be Opus-encoded packets at 48kHz (20ms recommended). SwiftDisc does not bundle an Opus encoder or media demuxer to maintain zero dependencies.

macOS streaming with ffmpeg (no Swift dependencies):

Use an external `ffmpeg` (system-installed) to demux/encode your source (YouTube, SoundCloud, etc.) to raw Opus packets and pipe them into SwiftDisc. Implement a small wrapper to length-prefix packets (u32 LE) or use a helper that outputs framed Opus.

Example framing expected by `PipeOpusSource`:

- Frame format: `[u32 little-endian length][<length> bytes]` repeated.

Use `PipeOpusSource`:

```swift
import Foundation

let source = PipeOpusSource(handle: FileHandle.standardInput)
try await client.play(source: source, guildId: guildId)
```

Then run your bot and feed framed Opus via stdin. For example, you can create a small CLI that transforms `ffmpeg` output to the framed format and pipe to the bot. This keeps SwiftDisc zero-dependency.

iOS guidance:

- iOS cannot spawn `ffmpeg`. Provide Opus packets from your app/backend over your own transport (e.g., HTTPS/WebSocket) and feed them to a `VoiceAudioSource`.

Security and correctness:

- SwiftDisc vendors a pure-Swift Secretbox (XSalsa20-Poly1305) implementation with Poly1305 MAC and Salsa20 core. Nonce derivation follows the Discord RTP header convention. We recommend validating with your own test vectors as part of your CI.



## 🤝 Contributing

Contributions make SwiftDisc better for everyone! Here's how you can help:

- **🐛 Report Bugs** — Found an issue? [Open an issue](https://github.com/M1tsumi/SwiftDisc/issues)
- **💡 Suggest Features** — Have an idea? Start a [discussion](https://github.com/M1tsumi/SwiftDisc/discussions)
- **📝 Improve Docs** — Documentation improvements are always welcome
- **🔧 Submit PRs** — Code contributions are appreciated!

Check our [Contributing Guidelines](CONTRIBUTING.md) for more details.



## 📄 License

SwiftDisc is released under the **MIT License**. See [LICENSE](LICENSE) for details.

**In short:** You're free to use SwiftDisc for personal and commercial projects, with attribution.





<div align="center">

**Ready to build your Discord bot?**

[📖 Read the Docs](https://github.com/M1tsumi/SwiftDisc/wiki) • [💬 Join Discord](https://discord.com/invite/r4rCAXvb8d) • [🚀 View Examples](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples)



⭐ Star us on GitHub if you find SwiftDisc helpful!

</div>
