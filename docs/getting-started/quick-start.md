# Quick Start Guide

Get your first SwiftDisc bot running in minutes with this step-by-step guide.

## Prerequisites

- Swift 5.9+ 
- A Discord application and bot token
- Basic knowledge of Swift and async/await

## Step 1: Create a Discord Bot

1. Go to the [Discord Developer Portal](https://discord.com/developers/applications)
2. Create a new application
3. Go to the "Bot" section and click "Add Bot"
4. Copy your bot token (keep this secret!)
5. Enable the necessary intents for your bot

## Step 2: Set Up Your Project

Create a new Swift package or add SwiftDisc to your existing project:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/M1tsumi/SwiftDisc.git", from: "0.13.0")
]
```

## Step 3: Your First Bot

Create a simple echo bot:

```swift
import SwiftDisc

@main
struct MyBot {
    static func main() async {
        // Load your bot token from environment variables
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)
        
        do {
            // Connect to Discord with required intents
            try await client.loginAndConnect(intents: [
                .guilds,
                .guildMessages,
                .messageContent
            ])
            
            print("Bot connected successfully!")
            
            // Listen for events
            for await event in client.events {
                switch event {
                case .ready(let info):
                    print("Logged in as \(info.user.username)")
                    
                case .messageCreate(let message):
                    // Don't respond to ourselves
                    if message.author.id != info.user.id {
                        try await client.sendMessage(
                            channelId: message.channel_id,
                            content: "You said: \(message.content)"
                        )
                    }
                    
                default:
                    break
                }
            }
        } catch {
            print("Error: \(error)")
        }
    }
}
```

## Step 4: Run Your Bot

1. Set your bot token as an environment variable:
   ```bash
   export DISCORD_BOT_TOKEN="your_bot_token_here"
   ```

2. Run your bot:
   ```bash
   swift run
   ```

3. Invite your bot to a server using the OAuth2 URL generator in the Discord Developer Portal

## What's Next?

- Explore [Slash Commands](../guides/slash-commands.md)
- Learn about [Message Components](../guides/message-components.md)
- Understand [Sharding](../advanced/sharding.md) for larger bots
- Check out more [Examples](../../Examples/)

## Environment Variables

SwiftDisc commonly uses these environment variables:

```bash
DISCORD_BOT_TOKEN=your_bot_token
DISCORD_CLIENT_ID=your_client_id
DISCORD_CLIENT_SECRET=your_client_secret
```

## Troubleshooting

**Bot won't connect:**
- Check your token is correct
- Verify you have the correct intents enabled
- Ensure your bot has proper permissions

**No messages received:**
- Enable the `messageContent` intent in the Developer Portal
- Make sure your bot has read message permissions
- Check that the bot is actually in the server

**Permission errors:**
- Verify bot has required permissions in the server/channel
- Check role hierarchy and channel overwrites

---

**Need more help?** Join our [Discord server](https://discord.gg/6nS2KqxQtj) for support.
