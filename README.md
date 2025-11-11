<div align="center">

# SwiftDisc

**Native Swift Discord API for iOS & macOS Bot Development**  
Zero dependencies • Full Discord v10 • Async/Await • SwiftPM Ready

![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20Linux-blue)
![SPM](https://img.shields.io/badge/SwiftPM-Compatible-green)
![MIT](https://img.shields.io/badge/License-MIT-lightgrey)

[![Stars](https://img.shields.io/github/stars/M1tsumi/SwiftDisc?style=social)](https://github.com/M1tsumi/SwiftDisc)
[![Discord](https://img.shields.io/discord/1302695959864414319?logo=discord&label=Support&color=5865F2)](https://discord.gg/r4rCAXvb8d))

</div>

---

## Features

- **Full Discord API v10** – REST + Gateway  
- **Async/Await** – Modern Swift concurrency  
- **Zero External Dependencies** – Pure Foundation  
- **Codable Models** – Type-safe JSON handling  
- **Slash Commands & Interactions** – Buttons, modals, selects  
- **Sharding & Intents** – Scale to millions of guilds  
- **Rate Limit Intelligence** – Auto 429 handling  
- **Swift Package Manager** – Drop-in Xcode integration  
- **iOS/macOS/Linux** – Build bots anywhere  

---

## Quick Start

```swift
import SwiftDisc

let client = DiscordClient(token: "YOUR_BOT_TOKEN", intents: [.guilds, .guildMessages])

client.on(.messageCreate) { message in
    if message.content == "!ping" {
        try await message.reply("Pong! from SwiftDisc")
    }
}

try await client.login()
