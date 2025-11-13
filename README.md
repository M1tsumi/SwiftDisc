<div align="center">

![SwiftDisc Typing](https://raw.githubusercontent.com/M1tsumi/M1tsumi/main/assets/typing-swiftdisc.svg)

# SwiftDisc

**A modern, Swift-native Discord API library for building powerful bots**

Build Discord bots and integrations with the elegance of Swift — fully async, strongly typed, and production-ready.

<a href="https://discord.com/invite/r4rCAXvb8d" target="_blank"><img alt="Join our Discord" src="https://img.shields.io/badge/💬%20JOIN%20OUR%20DISCORD-Get%20Help%20%26%20Share%20Ideas-5865F2?style=for-the-badge&logo=discord&logoColor=white"></a>

[![Discord](https://img.shields.io/discord/YOUR_SERVER_ID?color=5865F2&label=Discord&logo=discord&logoColor=white)](https://discord.com/invite/r4rCAXvb8d)
[![Swift Version](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![CI](https://github.com/M1tsumi/SwiftDisc/actions/workflows/ci.yml/badge.svg)
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
        let token = ProcessInfo.processInfo.environment["DISCORD_TOKEN"] ?? ""
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

### ⚡ Slash Commands Bot
Discover modern Discord interactions with slash commands and autocomplete.

```swift
let slash = SlashCommandRouter()
slash.register("greet") { interaction in
    try await interaction.reply("Hello from SwiftDisc! 👋")
}
```

**[View Full Example →](https://github.com/M1tsumi/SwiftDisc/tree/main/Examples/SlashBot.swift)**

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

### Advanced Features
- ✅ Per-route rate limit handling with automatic retries
- ✅ Global rate limit detection and backoff
- ✅ Sharding support with automatic shard count
- ✅ Health monitoring and shard management
- ✅ Typed command routing (prefix and slash)
- ✅ Rich embed builder
- ✅ Message components (buttons, select menus)

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

### Current Focus (v0.8.x)
- [x] Enhanced slash command builders with option helpers
- [x] Modal interactions support
- [x] Message component builders
- [x] Expanded REST endpoint coverage

### Future Plans
- [ ] Voice support (optional module)
- [ ] Advanced caching strategies
- [ ] Plugin/extension system
- [ ] Performance optimizations

**Want to influence the roadmap?** Join the [Discord server](https://discord.com/invite/r4rCAXvb8d) and share your ideas!



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