# Gateway & Events

The Discord Gateway is a persistent WebSocket connection that provides real-time events. SwiftDisc handles the complexity of connection management, heartbeats, and reconnections for you.

## Connection Management

### Basic Connection

```swift
import SwiftDisc

let client = DiscordClient(token: token)

// Connect with specific intents
try await client.loginAndConnect(intents: [
    .guilds,           // Guild events
    .guildMessages,    // Message events
    .messageContent    // Message content intent
])
```

### Automatic Reconnection

SwiftDisc automatically handles:
- Connection drops and reconnections
- Session resumption when possible
- Exponential backoff with jitter
- Heartbeat monitoring and recovery

## Intents

Intents subscribe your bot to specific event categories. Some require verification in the Discord Developer Portal.

### Privileged Intents
```swift
[
    .guildPresences,      // User presence updates
    .guildMembers,        // Member join/leave/update
    .messageContent,      // Message content (requires verification)
]
```

### Non-Privileged Intents
```swift
[
    .guilds,              // Guild create/update/delete
    .guildMessages,       // Message events (without content)
    .guildMessageReactions, // Reactions
    .guildMessageTyping,  // Typing indicators
    .directMessages,      // DM events
    .directMessageReactions,
    .directMessageTyping,
]
```

## Event Handling

### Event Stream Pattern

```swift
for await event in client.events {
    switch event {
    case .ready(let info):
        print("Bot ready: \(info.user.username)")
        
    case .messageCreate(let message):
        await handleMessage(message)
        
    case .guildCreate(let guild):
        print("Joined guild: \(guild.name)")
        
    default:
        break
    }
}
```

### Callback Pattern

```swift
client.onReady = { info in
    print("Bot is ready!")
}

client.onMessage = { message in
    print("New message: \(message.content)")
}

client.onGuildCreate = { guild in
    print("Joined new guild: \(guild.name)")
}
```

## Heartbeat Management

SwiftDisc implements robust heartbeat handling:

- **Automatic jitter**: Random delay to prevent thundering herd
- **ACK monitoring**: Tracks heartbeat acknowledgments
- **Zombie detection**: Detects and handles zombie connections
- **Graceful degradation**: Continues operation during heartbeat issues

### Heartbeat Configuration

```swift
let config = DiscordConfiguration(
    heartbeatInterval: 30.0,  // Custom interval (seconds)
    heartbeatJitter: 0.1      // Jitter factor (0.0-1.0)
)
let client = DiscordClient(token: token, configuration: config)
```

## Raw Event Access

For unmodeled or new Discord events:

```swift
for await event in client.events {
    switch event {
    case .raw(let eventName, let data):
        print("Raw event: \(eventName)")
        // Handle custom or unmodeled events
        
    default:
        break
    }
}
```

## Gateway Events Reference

### Guild Events
- `GUILD_CREATE` - Joined a guild
- `GUILD_UPDATE` - Guild updated
- `GUILD_DELETE` - Left/was removed from guild
- `GUILD_MEMBER_ADD` - User joined guild
- `GUILD_MEMBER_UPDATE` - Member updated
- `GUILD_MEMBER_REMOVE` - User left guild

### Message Events
- `MESSAGE_CREATE` - New message
- `MESSAGE_UPDATE` - Message edited
- `MESSAGE_DELETE` - Message deleted
- `MESSAGE_DELETE_BULK` - Multiple messages deleted

### Channel Events
- `CHANNEL_CREATE` - Channel created
- `CHANNEL_UPDATE` - Channel updated
- `CHANNEL_DELETE` - Channel deleted

### Thread Events
- `THREAD_CREATE` - Thread created
- `THREAD_UPDATE` - Thread updated
- `THREAD_DELETE` - Thread deleted
- `THREAD_MEMBER_UPDATE` - Thread member updated
- `THREAD_MEMBERS_UPDATE` - Thread members updated

### Interaction Events
- `INTERACTION_CREATE` - Slash command, button click, etc.

## Connection States

The Gateway client maintains these states:

```swift
enum GatewayStatus {
    case disconnected    // Not connected
    case connecting      // Establishing connection
    case identifying     // Sending identify payload
    case ready          // Fully connected and operational
    case resuming       // Attempting to resume session
    case reconnecting   // Reconnecting after failure
}
```

## Error Handling

Common gateway errors and their handling:

```swift
do {
    try await client.loginAndConnect(intents: intents)
} catch DiscordError.gatewayAuthenticationFailed {
    print("Invalid bot token")
} catch DiscordError.gatewayDisallowedIntents {
    print("Privileged intents not enabled")
} catch let error as DiscordError {
    print("Gateway error: \(error.localizedDescription)")
}
```

## Performance Tips

1. **Use appropriate intents** - Only subscribe to events you need
2. **Process events quickly** - Avoid blocking the event loop
3. **Use caching** - Leverage the built-in cache for frequently accessed data
4. **Consider sharding** - For large bots, use multiple shards

---

**Next:** Learn about [REST API](./rest-api.md) or [Sharding](../advanced/sharding.md).
