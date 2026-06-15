# Event Handling

SwiftDisc gives you two ways to handle gateway events: callbacks and async streams.

@Metadata {
  @PageKind(article)
  @PageImage(purpose: card, source: swiftdisc-logo)
}

## Callbacks

Set individual callbacks for the events you care about:

```swift
await client.setOnReady { ready in
    print("Bot is ready in \(ready.guilds.count) guilds")
}

await client.setOnMessage { message in
    guard message.content == "ping" else { return }
    try await message.reply(client: client, content: "Pong!")
}

await client.setOnGuildCreate { guild in
    print("Joined \(guild.name), \(guild.member_count ?? 0) members")
}
```

Available callbacks include: ``DiscordClient/onReady``, ``DiscordClient/onMessage``, ``DiscordClient/onMessageUpdate``, ``DiscordClient/onGuildCreate``, ``DiscordClient/onInteractionCreate``, ``DiscordClient/onReactionAdd``, ``DiscordClient/onMemberAdd``, and 30+ more — one for every Discord gateway event.

## Async Stream

When you need to filter, combine, or transform events, use the unified stream:

```swift
for await event in await client.events {
    switch event {
    case .messageCreate(let msg) where msg.content == "ping":
        try await msg.reply(client: client, content: "Pong!")
    case .guildCreate(let guild):
        print("New guild: \(guild.name)")
    case .reactionAdd(let reaction):
        guard reaction.emoji.name == "⭐" else { break }
        print("Starred in channel \(reaction.channel_id)")
    default:
        break
    }
}
```

## Connection State

Monitor the Gateway connection state in real time:

```swift
for await state in await client.connectionState {
    switch state {
    case .ready:         print("Connected and ready")
    case .reconnecting:  print("Reconnecting...")
    case .resuming:      print("Resuming session")
    case .disconnected:  print("Disconnected")
    case .connecting:    print("Connecting...")
    case .identifying:   print("Identifying...")
    }
}
```
