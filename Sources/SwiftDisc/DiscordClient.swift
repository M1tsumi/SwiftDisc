import Foundation

# Documentation

The primary client for interacting with the Discord API.

`DiscordClient` is an `actor`, providing automatic data-race safety for all methods and stored properties. `let` stored properties (e.g., `token`, `cache`) are accessible from any context without `await`, while mutable operations require async/await.

## Overview

SwiftDisc is a Swift-first Discord API wrapper that provides:
- **Gateway connectivity** for real-time event handling
- **REST API** for HTTP-based operations
- **High-level routers** for commands, slash commands, autocomplete, and components
- **Typed models** for Discord entities (channels, guilds, messages, etc.)
- **Automatic rate-limiting** and reconnect logic
- **Actor-safe concurrency** with Swift 6.2

## Quick Start

```swift
import Foundation
import SwiftDisc

let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
let client = DiscordClient(token: token)

await client.setOnReady { ready in
    print("Logged in as \(ready.user.username)")
}

await client.setOnMessage { message in
    guard message.content?.lowercased() == "ping" else { return }
    try await message.reply(client: client, content: "Pong!")
}

try await client.loginAndConnect(intents: [.guilds, .guildMessages, .messageContent])
for await event in await client.events {
    // Handle events
}
```

## Gateway Intents

Discord requires you to specify which events you want to receive. Use `GatewayIntents` to configure this:

```swift
try await client.loginAndConnect(intents: [
    .guilds,              // Guild events (create, update, delete)
    .guildMessages,       // Message events in guilds
    .messageContent,      // Message content (privileged intent)
    .guildMembers,        // Member join/leave/update
    .guildPresences       // User presence updates
])
```

> **Note:** Some intents like `messageContent` and `guildPresences` are privileged and must be enabled in the Discord Developer Portal.

## Event Handling

You can handle events in two ways:

1. **Using callback properties** (simple for basic bots):
```swift
await client.setOnMessage { message in
    print("Received: \(message.content ?? "")")
}
```

2. **Using the event stream** (for advanced event processing):
```swift
for await event in await client.events {
    switch event {
    case .messageCreate(let message):
        print("Message: \(message.content ?? "")")
    case .ready(let ready):
        print("Ready as \(ready.user.username)")
    default:
        break
    }
}
```

## High-Level Routers

SwiftDisc provides high-level routers for common bot patterns:

### Command Router (Prefix-based commands)
```swift
let commands = CommandRouter()
await commands.register("!ping") { ctx in
    try await ctx.message.reply(client: client, content: "Pong!")
}
await client.useCommands(commands)
```

### Slash Command Router
```swift
let slash = SlashCommandRouter()
await slash.register("ping") { ctx in
    try await ctx.client.createInteractionResponse(
        interactionId: ctx.interaction.id,
        token: ctx.interaction.token,
        content: "Pong!"
    )
}
await client.useSlashCommands(slash)
```

### Autocomplete Router
```swift
let autocomplete = AutocompleteRouter()
await autocomplete.register("search") { ctx in
    let choices = ctx.focusedValue.map { value in
        AutocompleteChoice(name: value, value: value)
    }
    try await ctx.respond(choices: choices)
}
await client.useAutocomplete(autocomplete)
```

### View Manager (Persistent Components)
```swift
let viewManager = ViewManager()
await viewManager.register("my_view") { ctx in
    try await ctx.respond(content: "View clicked!")
}
await client.useViewManager(viewManager)
```

## REST API

All Discord REST endpoints are available as methods on `DiscordClient`:

```swift
// Send a message
try await client.sendMessage(
    channelId: channelId,
    content: "Hello, world!"
)

// Edit a message
try await client.editMessage(
    channelId: channelId,
    messageId: messageId,
    content: "Updated message"
)

// Delete a message
try await client.deleteMessage(
    channelId: channelId,
    messageId: messageId
)
```

## Cache

The client includes a built-in cache that stores Discord entities:

```swift
let cache = await client.cache

// Access cached data
if let guild = cache.guilds[guildId] {
    print("Guild: \(guild.name)")
}
```

## Error Handling

All operations can throw `DiscordError`:

```swift
do {
    try await client.sendMessage(channelId: channelId, content: "Hello")
} catch let error as DiscordError {
    print("Discord error: \(error)")
    if let context = error.debugContext {
        print("Debug context: \(context)")
    }
}
```

## Configuration

Customize client behavior with `DiscordConfiguration`:

```swift
let config = DiscordConfiguration(
    apiBaseURL: URL(string: "https://discord.com/api")!,
    apiVersion: 10,
    gatewayBaseURL: URL(string: "wss://gateway.discord.gg")!
)
let client = DiscordClient(token: token, configuration: config)
```

## Sharding

For large bots, use sharding to distribute load:

```swift
// Connect as shard 0 of 5 total shards
try await client.loginAndConnectSharded(
    index: 0,
    total: 5,
    intents: [.guilds, .guildMessages]
)
```

## Thread Safety

As an `actor`, `DiscordClient` provides automatic thread safety:
- All methods are serialized and safe to call from any context
- `let` properties can be accessed without `await`
- Mutable operations require `await`
- No data races possible

## See Also
- `DiscordConfiguration` for client configuration options
- `GatewayIntents` for gateway event subscription
- `CommandRouter` for prefix-based commands
- `SlashCommandRouter` for slash commands
- `AutocompleteRouter` for autocomplete handling
- `ViewManager` for persistent component state
- `Cache` for entity caching
- `DiscordError` for error handling

public actor DiscordClient {
    /// The bot token used for authentication with Discord.
    ///
    /// This is a non-isolated `let` property, so it can be accessed from any context without `await`.
    /// The token should be kept secure and never committed to version control.
    ///
    /// - Note: Obtain your bot token from the Discord Developer Portal.
    public nonisolated let token: String
    let http: HTTPClient
    private let gateway: GatewayClient
    private let configuration: DiscordConfiguration
    private let dispatcher = EventDispatcher()
    private var currentUserId: UserID?

    private lazy var eventStream: AsyncStream<DiscordEvent> = {
        AsyncStream { continuation in
            continuation.onTermination = { @Sendable _ in }
            self.eventContinuation = continuation
        }
    }()
    private nonisolated(unsafe) var eventContinuation: AsyncStream<DiscordEvent>.Continuation?

    /// The cache that stores Discord entities (guilds, channels, members, etc.).
    ///
    /// The cache is automatically populated as events are received from the gateway.
    /// This is a non-isolated `let` property, so it can be accessed from any context without `await`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let cache = await client.cache
    /// if let guild = cache.guilds[guildId] {
    ///     print("Guild name: \(guild.name)")
    /// }
    /// ```
    public let cache = Cache()

    // Loaded extensions are tracked so they can be unloaded cleanly.
    private var loadedExtensions: [SwiftDiscExtension] = []

    /// A stream of all Discord gateway events.
    ///
    /// Use this to handle events in a unified way, or use the individual callback properties like `onMessage`, `onReady`, etc.
    ///
    /// ## Example
    ///
    /// ```swift
    /// for await event in await client.events {
    ///     switch event {
    ///     case .messageCreate(let message):
    ///         print("Message: \(message.content ?? "")")
    ///     case .ready(let ready):
    ///         print("Ready as \(ready.user.username)")
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    ///
    /// - Note: The stream is infinite and will continue until the client disconnects.
    public var events: AsyncStream<DiscordEvent> { eventStream }

    // MARK: - Event Callbacks
    // Assign any of these to be notified of specific gateway events.
    // All callbacks are @Sendable so they can be used safely across actor / task boundaries.

    // -- Ready --
    public var onReady: (@Sendable (ReadyEvent) async -> Void)?

    // -- Messages --
    public var onMessage: (@Sendable (Message) async -> Void)?
    public var onMessageUpdate: (@Sendable (Message) async -> Void)?
    public var onMessageDelete: (@Sendable (MessageDelete) async -> Void)?
    public var onMessageDeleteBulk: (@Sendable (MessageDeleteBulk) async -> Void)?

    // -- Reactions --
    public var onReactionAdd: (@Sendable (MessageReactionAdd) async -> Void)?
    public var onReactionRemove: (@Sendable (MessageReactionRemove) async -> Void)?
    public var onReactionRemoveAll: (@Sendable (MessageReactionRemoveAll) async -> Void)?
    public var onReactionRemoveEmoji: (@Sendable (MessageReactionRemoveEmoji) async -> Void)?

    // -- Guilds --
    public var onGuildCreate: (@Sendable (Guild) async -> Void)?
    public var onGuildUpdate: (@Sendable (Guild) async -> Void)?
    public var onGuildDelete: (@Sendable (GuildDelete) async -> Void)?

    // -- Members --
    public var onGuildMemberAdd: (@Sendable (GuildMemberAdd) async -> Void)?
    public var onGuildMemberRemove: (@Sendable (GuildMemberRemove) async -> Void)?
    public var onGuildMemberUpdate: (@Sendable (GuildMemberUpdate) async -> Void)?

    // -- Channels --
    public var onChannelCreate: (@Sendable (Channel) async -> Void)?
    public var onChannelUpdate: (@Sendable (Channel) async -> Void)?
    public var onChannelDelete: (@Sendable (Channel) async -> Void)?

    // -- Threads --
    public var onThreadCreate: (@Sendable (Channel) async -> Void)?
    public var onThreadUpdate: (@Sendable (Channel) async -> Void)?
    public var onThreadDelete: (@Sendable (Channel) async -> Void)?
    public var onThreadMembersUpdate: (@Sendable (ThreadMembersUpdate) async -> Void)?

    // -- Roles --
    public var onGuildRoleCreate: (@Sendable (GuildRoleCreate) async -> Void)?
    public var onGuildRoleUpdate: (@Sendable (GuildRoleUpdate) async -> Void)?
    public var onGuildRoleDelete: (@Sendable (GuildRoleDelete) async -> Void)?

    // -- Moderation --
    public var onGuildBanAdd: (@Sendable (GuildBanAdd) async -> Void)?
    public var onGuildBanRemove: (@Sendable (GuildBanRemove) async -> Void)?
    public var onAutoModerationActionExecution: (@Sendable (AutoModerationActionExecution) async -> Void)?

    // -- Interactions --
    public var onInteractionCreate: (@Sendable (Interaction) async -> Void)?
    public var onApplicationCommandPermissionsUpdate: (@Sendable (ApplicationCommandPermissionsUpdate) async -> Void)?

    // -- Presence & Typing --
    public var onTypingStart: (@Sendable (TypingStart) async -> Void)?
    public var onPresenceUpdate: (@Sendable (PresenceUpdate) async -> Void)?

    // -- Scheduled Events --
    public var onGuildScheduledEventCreate: (@Sendable (GuildScheduledEvent) async -> Void)?
    public var onGuildScheduledEventUpdate: (@Sendable (GuildScheduledEvent) async -> Void)?
    public var onGuildScheduledEventDelete: (@Sendable (GuildScheduledEvent) async -> Void)?

    // -- Polls --
    public var onPollVoteAdd: (@Sendable (PollVote) async -> Void)?
    public var onPollVoteRemove: (@Sendable (PollVote) async -> Void)?

    // -- Entitlements / Monetization --
    public var onEntitlementCreate: (@Sendable (Entitlement) async -> Void)?
    public var onEntitlementUpdate: (@Sendable (Entitlement) async -> Void)?
    public var onEntitlementDelete: (@Sendable (Entitlement) async -> Void)?

    // -- Soundboard --
    public var onSoundboardSoundCreate: (@Sendable (SoundboardSound) async -> Void)?
    public var onSoundboardSoundUpdate: (@Sendable (SoundboardSound) async -> Void)?
    public var onSoundboardSoundDelete: (@Sendable (SoundboardSound) async -> Void)?

    /// The command router for prefix-based commands.
    ///
    /// Set this to enable prefix-based command handling. Use `useCommands(_:)` to assign a router.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let commands = CommandRouter()
    /// await commands.register("!ping") { ctx in
    ///     try await ctx.message.reply(client: client, content: "Pong!")
    /// }
    /// await client.useCommands(commands)
    /// ```
    ///
    /// - See Also: `CommandRouter`
    public var commands: CommandRouter?
    
    /// Sets the command router for prefix-based commands.
    ///
    /// - Parameter router: The `CommandRouter` instance to use for command handling.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let commands = CommandRouter()
    /// await commands.register("!ping") { ctx in
    ///     try await ctx.message.reply(client: client, content: "Pong!")
    /// }
    /// await client.useCommands(commands)
    /// ```
    ///
    /// - See Also: `CommandRouter`
    public func useCommands(_ router: CommandRouter) { self.commands = router }

    /// The view manager for persistent component state.
    ///
    /// Set this to enable persistent component state handling for message components.
    /// Use `useViewManager(_:)` to assign a manager.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let viewManager = ViewManager()
    /// await viewManager.register("my_view") { ctx in
    ///     try await ctx.respond(content: "View clicked!")
    /// }
    /// await client.useViewManager(viewManager)
    /// ```
    ///
    /// - See Also: `ViewManager`
    public var viewManager: ViewManager?
    
    /// Sets the view manager for persistent component state.
    ///
    /// - Parameter manager: The `ViewManager` instance to use for component state handling.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let viewManager = ViewManager()
    /// await viewManager.register("my_view") { ctx in
    ///     try await ctx.respond(content: "View clicked!")
    /// }
    /// await client.useViewManager(viewManager)
    /// ```
    ///
    /// - See Also: `ViewManager`
    public func useViewManager(_ manager: ViewManager) {
        self.viewManager = manager
        manager.start(client: self)
    }

    /// The slash command router for Discord slash commands.
    ///
    /// Set this to enable slash command handling. Use `useSlashCommands(_:)` to assign a router.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let slash = SlashCommandRouter()
    /// await slash.register("ping") { ctx in
    ///     try await ctx.client.createInteractionResponse(
    ///         interactionId: ctx.interaction.id,
    ///         token: ctx.interaction.token,
    ///         content: "Pong!"
    ///     )
    /// }
    /// await client.useSlashCommands(slash)
    /// ```
    ///
    /// - See Also: `SlashCommandRouter`
    public var slashCommands: SlashCommandRouter?
    
    /// Sets the slash command router for Discord slash commands.
    ///
    /// - Parameter router: The `SlashCommandRouter` instance to use for slash command handling.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let slash = SlashCommandRouter()
    /// await slash.register("ping") { ctx in
    ///     try await ctx.client.createInteractionResponse(
    ///         interactionId: ctx.interaction.id,
    ///         token: ctx.interaction.token,
    ///         content: "Pong!"
    ///     )
    /// }
    /// await client.useSlashCommands(slash)
    /// ```
    ///
    /// - See Also: `SlashCommandRouter`
    public func useSlashCommands(_ router: SlashCommandRouter) { self.slashCommands = router }

    /// The autocomplete router for slash command option suggestions.
    ///
    /// Set this to enable autocomplete handling for slash command options.
    /// Use `useAutocomplete(_:)` to assign a router.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let autocomplete = AutocompleteRouter()
    /// await autocomplete.register("search") { ctx in
    ///     let choices = ctx.focusedValue.map { value in
    ///         AutocompleteChoice(name: value, value: value)
    ///     }
    ///     try await ctx.respond(choices: choices)
    /// }
    /// await client.useAutocomplete(autocomplete)
    /// ```
    ///
    /// - See Also: `AutocompleteRouter`
    public var autocomplete: AutocompleteRouter?
    
    /// Sets the autocomplete router for slash command option suggestions.
    ///
    /// - Parameter router: The `AutocompleteRouter` instance to use for autocomplete handling.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let autocomplete = AutocompleteRouter()
    /// await autocomplete.register("search") { ctx in
    ///     let choices = ctx.focusedValue.map { value in
    ///         AutocompleteChoice(name: value, value: value)
    ///     }
    ///     try await ctx.respond(choices: choices)
    /// }
    /// await client.useAutocomplete(autocomplete)
    /// ```
    ///
    /// - See Also: `AutocompleteRouter`
    public func useAutocomplete(_ router: AutocompleteRouter) { self.autocomplete = router }


    /// Creates a new Discord client with the specified bot token.
    ///
    /// - Parameters:
    ///   - token: The bot token obtained from the Discord Developer Portal.
    ///   - configuration: The client configuration. Defaults to a standard configuration.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
    /// let client = DiscordClient(token: token)
    /// ```
    ///
    /// ## Custom Configuration
    ///
    /// ```swift
    /// let config = DiscordConfiguration(
    ///     apiBaseURL: URL(string: "https://discord.com/api")!,
    ///     apiVersion: 10,
    ///     gatewayBaseURL: URL(string: "wss://gateway.discord.gg")!
    /// )
    /// let client = DiscordClient(token: token, configuration: config)
    /// ```
    ///
    /// - Important: Keep your bot token secure and never commit it to version control.
    /// - See Also: `DiscordConfiguration`
    public init(token: String, configuration: DiscordConfiguration = .init()) {
        self.token = token
        self.http = HTTPClient(token: token, configuration: configuration)
        self.gateway = GatewayClient(token: token, configuration: configuration)
        self.configuration = configuration
    }

    /// Loads an extension (cog) into the client.
    ///
    /// Extensions are reusable modules that can add commands, event handlers, and other functionality to your bot.
    ///
    /// - Parameter ext: The extension to load.
    ///
    /// ## Example
    ///
    /// ```swift
    /// class MyExtension: SwiftDiscExtension {
    ///     func onRegister(client: DiscordClient) async {
    ///         print("Extension registered!")
    ///     }
    ///     
    ///     func onUnload(client: DiscordClient) async {
    ///         print("Extension unloaded!")
    ///     }
    /// }
    ///
    /// let ext = MyExtension()
    /// await client.loadExtension(ext)
    /// ```
    ///
    /// - See Also: `SwiftDiscExtension`, `unloadExtensions()`
    public func loadExtension(_ ext: SwiftDiscExtension) async {
        loadedExtensions.append(ext)
        await ext.onRegister(client: self)
    }

    /// Unloads all loaded extensions.
    ///
    /// This calls `onUnload(client:)` on each extension before removing it.
    ///
    /// ## Example
    ///
    /// ```swift
    /// await client.unloadExtensions()
    /// ```
    ///
    /// - See Also: `SwiftDiscExtension`, `loadExtension(_:)`
    public func unloadExtensions() async {
        let exts = loadedExtensions
        loadedExtensions.removeAll()
        for ext in exts { await ext.onUnload(client: self) }
    }
    // MARK: - REST: Bulk Messages and Crosspost

    /// Sets the callback invoked when the READY event is received.
    ///
    /// The READY event is sent when the client successfully connects to the gateway.
    ///
    /// - Parameter handler: The async callback to invoke when the READY event is received.
    ///
    /// ## Example
    ///
    /// ```swift
    /// await client.setOnReady { ready in
    ///     print("Logged in as \(ready.user.username)")
    ///     print("Guilds: \(ready.guilds.count)")
    /// }
    /// ```
    ///
    /// - See Also: `ReadyEvent`, `onReady`
    public func setOnReady(_ handler: (@Sendable (ReadyEvent) async -> Void)?) {
        self.onReady = handler
    }

    /// Sets the callback invoked for MESSAGE_CREATE events.
    ///
    /// This callback is invoked for every new message in guilds where the bot has access.
    ///
    /// - Parameter handler: The async callback to invoke when a message is created.
    ///
    /// ## Example
    ///
    /// ```swift
    /// await client.setOnMessage { message in
    ///     guard message.content?.lowercased() == "ping" else { return }
    ///     try await message.reply(client: client, content: "Pong!")
    /// }
    /// ```
    ///
    /// - Note: Requires the `guildMessages` and `messageContent` intents.
    /// - See Also: `Message`, `onMessage`
    public func setOnMessage(_ handler: (@Sendable (Message) async -> Void)?) {
        self.onMessage = handler
    }

    /// Bulk deletes multiple messages from a channel.
    ///
    /// This method deletes 2-100 messages in a single API call. All messages must be newer than 14 days old.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel to delete messages from.
    ///   - messageIds: An array of message IDs to delete (2-100 messages).
    ///
    /// - Throws: `DiscordError` if the request fails, if fewer than 2 or more than 100 messages are provided,
    ///            or if any message is older than 14 days.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.bulkDeleteMessages(
    ///     channelId: channelId,
    ///     messageIds: [msgId1, msgId2, msgId3]
    /// )
    /// ```
    ///
    /// - Important: Messages older than 14 days cannot be bulk deleted and must be deleted individually.
    /// - Note: This endpoint has a rate limit of 1 request per channel per second.
    public func bulkDeleteMessages(channelId: ChannelID, messageIds: [MessageID]) async throws {
        struct Body: Encodable, Sendable {
            let messages: [MessageID]
        }
        struct Ack: Decodable, Sendable {
        }
        let body = Body(messages: messageIds)
        let _: Ack = try await http.post(path: "/channels/\(channelId)/messages/bulk-delete", body: body)
    }

    /// Crossposts a message from a news channel to its follower channels.
    ///
    /// This method publishes a message in a news channel to all channels that follow it.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the news channel containing the message.
    ///   - messageId: The ID of the message to crosspost.
    ///
    /// - Returns: The crossposted message.
    /// - Throws: `DiscordError` if the request fails or if the channel is not a news channel.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let message = try await client.crosspostMessage(
    ///     channelId: newsChannelId,
    ///     messageId: messageId
    /// )
    /// ```
    ///
    /// - Note: Only messages in news channels can be crossposted.
    public func crosspostMessage(channelId: ChannelID, messageId: MessageID) async throws -> Message {
        struct Empty: Encodable, Sendable {
        }
        return try await http.post(path: "/channels/\(channelId)/messages/\(messageId)/crosspost", body: Empty())
    }

    /// Retrieves all pinned messages from a channel.
    ///
    /// - Parameter channelId: The ID of the channel to get pinned messages from.
    ///
    /// - Returns: An array of pinned messages.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pinnedMessages = try await client.getPinnedMessages(channelId: channelId)
    /// for message in pinnedMessages {
    ///     print("Pinned: \(message.content ?? "")")
    /// }
    /// ```
    ///
    /// - See Also: `pinMessage(channelId:messageId:)`, `unpinMessage(channelId:messageId:)`
    public func getPinnedMessages(channelId: ChannelID) async throws -> [Message] {
        try await http.get(path: "/channels/\(channelId)/pins")
    }

    /// Pins a message to a channel.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel to pin the message in.
    ///   - messageId: The ID of the message to pin.
    ///
    /// - Throws: `DiscordError` if the request fails or if the channel has reached the pin limit (50 pins).
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.pinMessage(channelId: channelId, messageId: messageId)
    /// ```
    ///
    /// - Note: Channels are limited to 50 pinned messages.
    /// - See Also: `unpinMessage(channelId:messageId:)`, `getPinnedMessages(channelId:)`
    public func pinMessage(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.put(path: "/channels/\(channelId)/pins/\(messageId)")
    }

    /// Unpins a message from a channel.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel to unpin the message from.
    ///   - messageId: The ID of the message to unpin.
    ///
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.unpinMessage(channelId: channelId, messageId: messageId)
    /// ```
    ///
    /// - See Also: `pinMessage(channelId:messageId:)`, `getPinnedMessages(channelId:)`
    public func unpinMessage(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.delete(path: "/channels/\(channelId)/pins/\(messageId)")
    }

    /// Retrieves pinned messages from a channel using the paginated pins endpoint.
    ///
    /// This method uses the newer paginated endpoint `GET /channels/{channel.id}/messages/pins`
    /// which supports pagination for channels with many pinned messages.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel to get pinned messages from.
    ///   - limit: The maximum number of messages to return (1-100). Defaults to Discord's default.
    ///   - after: Get pinned messages after this message ID for pagination.
    ///
    /// - Returns: An array of pinned messages.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Get first 50 pinned messages
    /// let pins = try await client.getChannelPinsPaginated(channelId: channelId, limit: 50)
    ///
    /// // Get pinned messages after a specific message
    /// let morePins = try await client.getChannelPinsPaginated(
    ///     channelId: channelId,
    ///     limit: 50,
    ///     after: lastMessageId
    /// )
    /// ```
    ///
    /// - See Also: `streamChannelPins(channelId:pageLimit:)`
    public func getChannelPinsPaginated(channelId: ChannelID, limit: Int? = nil, after: MessageID? = nil) async throws -> [Message] {
        var query = ""
        if let limit { query += (query.isEmpty ? "?" : "&") + "limit=\(limit)" }
        if let after { query += (query.isEmpty ? "?" : "&") + "after=\(after)" }
        return try await http.get(path: "/channels/\(channelId)/messages/pins\(query)")
    }

    /// Pins a message using the newer V2 endpoint.
    ///
    /// This is a typed wrapper for the newer pin endpoint `PUT /channels/{channel.id}/messages/pins/{message.id}`.
    /// It's kept alongside the legacy route for compatibility.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel to pin the message in.
    ///   - messageId: The ID of the message to pin.
    ///
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.pinMessageV2(channelId: channelId, messageId: messageId)
    /// ```
    ///
    /// - See Also: `pinMessage(channelId:messageId:)`
    public func pinMessageV2(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.put(path: "/channels/\(channelId)/messages/pins/\(messageId)")
    }

    /// Unpins a message using the newer V2 endpoint.
    ///
    /// This is a typed wrapper for the newer unpin endpoint `DELETE /channels/{channel.id}/messages/pins/{message.id}`.
    /// It's kept alongside the legacy route for compatibility.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel to unpin the message from.
    ///   - messageId: The ID of the message to unpin.
    ///
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.unpinMessageV2(channelId: channelId, messageId: messageId)
    /// ```
    ///
    /// - See Also: `unpinMessage(channelId:messageId:)`
    public func unpinMessageV2(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/pins/\(messageId)")
    }

    // MARK: - REST: Messages with Files
    public func sendMessageWithFiles(
        channelId: ChannelID,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        allowedMentions: AllowedMentions? = nil,
        messageReference: MessageReference? = nil,
        tts: Bool? = nil,
        flags: Int? = nil,
        stickerIds: [StickerID]? = nil,
        attachments: [PartialAttachment]? = nil,
        poll: Poll? = nil,
        files: [FileAttachment]
    ) async throws -> Message {
        struct Payload: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
            let allowed_mentions: AllowedMentions?
            let message_reference: MessageReference?
            let tts: Bool?
            let flags: Int?
            let sticker_ids: [StickerID]?
            let attachments: [PartialAttachment]?
            let poll: Poll?
        }
        let body = Payload(
            content: content,
            embeds: embeds,
            components: components,
            allowed_mentions: allowedMentions,
            message_reference: messageReference,
            tts: tts,
            flags: flags,
            sticker_ids: stickerIds,
            attachments: attachments,
            poll: poll
        )
        return try await http.postMultipart(path: "/channels/\(channelId)/messages", jsonBody: body, files: files)
    }

    public func editMessageWithFiles(
        channelId: ChannelID,
        messageId: MessageID,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        files: [FileAttachment]? = nil,
        attachments: [PartialAttachment]? = nil
    ) async throws -> Message {
        struct Payload: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
            let attachments: [PartialAttachment]?
        }
        let body = Payload(content: content, embeds: embeds, components: components, attachments: attachments)
        return try await http.patchMultipart(path: "/channels/\(channelId)/messages/\(messageId)", jsonBody: body, files: files)
    }

    // MARK: - REST: Interaction Follow-ups
    public func getOriginalInteractionResponse(applicationId: ApplicationID, interactionToken: String) async throws -> Message {
        try await http.get(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/@original")
    }

    public func editOriginalInteractionResponse(applicationId: ApplicationID, interactionToken: String, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
        }
        return try await http.patch(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/@original", body: Body(content: content, embeds: embeds, components: components))
    }

    public func deleteOriginalInteractionResponse(applicationId: ApplicationID, interactionToken: String) async throws {
        try await http.delete(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/@original")
    }

    public func createFollowupMessage(applicationId: ApplicationID, interactionToken: String, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil, ephemeral: Bool = false) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
            let flags: Int?
        }
        let flags = ephemeral ? 64 : nil
        return try await http.post(path: "/webhooks/\(applicationId)/\(interactionToken)", body: Body(content: content, embeds: embeds, components: components, flags: flags))
    }

    /// Create a follow-up message with file attachments (multipart). Returns the created `Message` when `wait=true` is used.
    public func createFollowupMessageWithFiles(applicationId: ApplicationID, interactionToken: String, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil, files: [FileAttachment]) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
        }
        // `wait=true` makes the webhook endpoint return the created message payload.
        return try await http.postMultipart(path: "/webhooks/\(applicationId)/\(interactionToken)?wait=true", jsonBody: Body(content: content, embeds: embeds, components: components), files: files)
    }

    /// Respond to an interaction (initial response) with files via webhook. This posts to the webhook URL and returns the created message when `wait=true` is used.
    public func createInteractionResponseWithFiles(applicationId: ApplicationID, interactionToken: String, payload: [String: JSONValue], files: [FileAttachment]) async throws -> Message {
        return try await http.postMultipart(path: "/webhooks/\(applicationId)/\(interactionToken)?wait=true", jsonBody: payload, files: files)
    }

    public func getFollowupMessage(applicationId: ApplicationID, interactionToken: String, messageId: MessageID) async throws -> Message {
        try await http.get(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/\(messageId)")
    }

    public func editFollowupMessage(applicationId: ApplicationID, interactionToken: String, messageId: MessageID, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
        }
        return try await http.patch(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/\(messageId)", body: Body(content: content, embeds: embeds, components: components))
    }

    public func deleteFollowupMessage(applicationId: ApplicationID, interactionToken: String, messageId: MessageID) async throws {
        try await http.delete(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/\(messageId)")
    }

    // MARK: - Application command localization endpoints
    public func setCommandLocalizations(applicationId: ApplicationID, commandId: ApplicationCommandID, nameLocalizations: [String: String]?, descriptionLocalizations: [String: String]?) async throws -> ApplicationCommand {
        struct Body: Encodable, Sendable {
            let name_localizations: [String: String]?
            let description_localizations: [String: String]?
        }
        return try await http.patch(path: "/applications/\(applicationId)/commands/\(commandId)", body: Body(name_localizations: nameLocalizations, description_localizations: descriptionLocalizations))
    }

    // MARK: - Forward message by reference
    public func forwardMessageByReference(targetChannelId: ChannelID, sourceChannelId: ChannelID, messageId: MessageID) async throws -> Message {
        // Send a message in targetChannelId that references the source message.
        let payload: [String: JSONValue] = [
            "message_reference": .object([
                "channel_id": .string(String(describing: sourceChannelId)),
                "message_id": .string(String(describing: messageId))
            ])
        ]
        return try await http.post(path: "/channels/\(targetChannelId)/messages", body: payload)
    }

    // MARK: - Components V2 and poll endpoints
    // Low-level send entry point for JSONValue payloads such as Components V2 bodies.
    public func postMessage(channelId: ChannelID, payload: [String: JSONValue]) async throws -> Message {
        try await http.post(path: "/channels/\(channelId)/messages", body: payload)
    }

    // Merges optional message fields with a raw `poll` payload.
    public func createPollMessage(channelId: ChannelID, content: String? = nil, poll: [String: JSONValue], flags: Int? = nil, components: [JSONValue]? = nil) async throws -> Message {
        var body: [String: JSONValue] = [
            "poll": .object(poll)
        ]
        if let content { body["content"] = .string(content) }
        if let flags { body["flags"] = .int(flags) }
        if let components { body["components"] = .array(components) }
        return try await http.post(path: "/channels/\(channelId)/messages", body: body)
    }

    // MARK: - Components V2 typed payload
    public func sendComponentsV2Message(channelId: ChannelID, payload: V2MessagePayload) async throws -> Message {
        try await http.post(path: "/channels/\(channelId)/messages", body: payload.asJSON())
    }

    // MARK: - Poll typed payload
    public func createPollMessage(channelId: ChannelID, payload: PollPayload, content: String? = nil, flags: Int? = nil, components: [JSONValue]? = nil) async throws -> Message {
        var body: [String: JSONValue] = [
            "poll": .object(payload.pollJSON())
        ]
        if let content { body["content"] = .string(content) }
        if let flags { body["flags"] = .int(flags) }
        if let components { body["components"] = .array(components) }
        return try await http.post(path: "/channels/\(channelId)/messages", body: body)
    }

    // MARK: - Application emoji endpoints
    /// List all emojis for the application (bot-owned emojis usable in any guild)
    public func listApplicationEmojis(applicationId: ApplicationID) async throws -> [Emoji] {
        try await http.get(path: "/applications/\(applicationId)/emojis")
    }

    /// Create a new application emoji
    public func createApplicationEmoji(applicationId: ApplicationID, name: String, imageBase64: String, options: [String: JSONValue]? = nil) async throws -> Emoji {
        var payload: [String: JSONValue] = [
            "name": .string(name),
            "image": .string(imageBase64)
        ]
        if let options { for (k, v) in options { payload[k] = v } }
        return try await http.post(path: "/applications/\(applicationId)/emojis", body: payload)
    }

    /// Update an existing application emoji
    public func updateApplicationEmoji(applicationId: ApplicationID, emojiId: EmojiID, name: String? = nil, roles: [RoleID]? = nil) async throws -> Emoji {
        struct Body: Encodable, Sendable {
            let name: String?
            let roles: [RoleID]?
        }
        return try await http.patch(path: "/applications/\(applicationId)/emojis/\(emojiId)", body: Body(name: name, roles: roles))
    }

    /// Delete an application emoji
    public func deleteApplicationEmoji(applicationId: ApplicationID, emojiId: EmojiID) async throws {
        try await http.delete(path: "/applications/\(applicationId)/emojis/\(emojiId)")
    }

    // MARK: - User app resource endpoints
    public func createUserAppResource(applicationId: ApplicationID, relativePath: String, payload: [String: JSONValue]) async throws -> JSONValue {
        try await postApplicationResource(applicationId: applicationId, relativePath: relativePath, payload: payload)
    }

    public func updateUserAppResource(applicationId: ApplicationID, relativePath: String, payload: [String: JSONValue]) async throws -> JSONValue {
        try await patchApplicationResource(applicationId: applicationId, relativePath: relativePath, payload: payload)
    }

    public func deleteUserAppResource(applicationId: ApplicationID, relativePath: String) async throws {
        try await deleteApplicationResource(applicationId: applicationId, relativePath: relativePath)
    }

    // Guild widget settings endpoints.
    public func getGuildWidgetSettings(guildId: GuildID) async throws -> GuildWidgetSettings {
        try await http.get(path: "/guilds/\(guildId)/widget")
    }

    public func modifyGuildWidgetSettings(guildId: GuildID, enabled: Bool, channelId: ChannelID?) async throws -> GuildWidgetSettings {
        struct Body: Encodable, Sendable {
            let enabled: Bool
            let channel_id: ChannelID?
        }
        return try await http.patch(path: "/guilds/\(guildId)/widget", body: Body(enabled: enabled, channel_id: channelId))
    }

    /// Lists all emojis in a guild.
    ///
    /// - Parameter guildId: The guild ID to list emojis from.
    ///
    /// - Returns: An array of emoji objects.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let emojis = try await client.listGuildEmojis(guildId: guildId)
    /// for emoji in emojis {
    ///     print("Emoji: \(emoji.name)")
    /// }
    /// ```
    public func listGuildEmojis(guildId: GuildID) async throws -> [Emoji] {
        try await http.get(path: "/guilds/\(guildId)/emojis")
    }

    /// Retrieves a specific emoji from a guild.
    ///
    /// - Parameters:
    ///   - guildId: The guild ID containing the emoji.
    ///   - emojiId: The emoji ID to retrieve.
    ///
    /// - Returns: The emoji object.
    /// - Throws: `DiscordError` if the request fails or if the emoji doesn't exist.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let emoji = try await client.getGuildEmoji(guildId: guildId, emojiId: emojiId)
    /// print("Emoji name: \(emoji.name)")
    /// ```
    public func getGuildEmoji(guildId: GuildID, emojiId: EmojiID) async throws -> Emoji {
        try await http.get(path: "/guilds/\(guildId)/emojis/\(emojiId)")
    }

    /// Creates a new emoji in a guild.
    ///
    /// - Parameters:
    ///   - guildId: The guild ID to create the emoji in.
    ///   - name: The emoji name (2-32 characters).
    ///   - image: The emoji image as a base64 data URI.
    ///   - roles: An array of role IDs that can use this emoji (optional).
    ///
    /// - Returns: The created emoji object.
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let emoji = try await client.createGuildEmoji(
    ///     guildId: guildId,
    ///     name: "pepega",
    ///     image: "data:image/png;base64,...",
    ///     roles: [roleId]
    /// )
    /// ```
    ///
    /// - Note: Requires the `MANAGE_EMOJIS_AND_STICKERS` permission.
    /// - See Also: `modifyGuildEmoji(guildId:emojiId:name:roles:)`
    public func createGuildEmoji(guildId: GuildID, name: String, image: String, roles: [RoleID]? = nil) async throws -> Emoji {
        struct Body: Encodable, Sendable {
            let name: String
            let image: String
            let roles: [RoleID]?
        }
        return try await http.post(path: "/guilds/\(guildId)/emojis", body: Body(name: name, image: image, roles: roles))
    }

    /// Modifies an existing emoji in a guild.
    ///
    /// - Parameters:
    ///   - guildId: The guild ID containing the emoji.
    ///   - emojiId: The emoji ID to modify.
    ///   - name: The new emoji name (optional).
    ///   - roles: The new array of role IDs that can use this emoji (optional).
    ///
    /// - Returns: The modified emoji object.
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let updated = try await client.modifyGuildEmoji(
    ///     guildId: guildId,
    ///     emojiId: emojiId,
    ///     name: "newname"
    /// )
    /// ```
    ///
    /// - Note: Requires the `MANAGE_EMOJIS_AND_STICKERS` permission.
    public func modifyGuildEmoji(guildId: GuildID, emojiId: EmojiID, name: String? = nil, roles: [RoleID]? = nil) async throws -> Emoji {
        struct Body: Encodable, Sendable {
            let name: String?
            let roles: [RoleID]?
        }
        return try await http.patch(path: "/guilds/\(guildId)/emojis/\(emojiId)", body: Body(name: name, roles: roles))
    }

    /// Deletes an emoji from a guild.
    ///
    /// - Parameters:
    ///   - guildId: The guild ID containing the emoji.
    ///   - emojiId: The emoji ID to delete.
    ///
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.deleteGuildEmoji(guildId: guildId, emojiId: emojiId)
    /// ```
    ///
    /// - Note: Requires the `MANAGE_EMOJIS_AND_STICKERS` permission.
    public func deleteGuildEmoji(guildId: GuildID, emojiId: EmojiID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/emojis/\(emojiId)")
    }

    /// Adds a user to a guild using an OAuth2 access token.
    ///
    /// This method is used for adding users to a guild via OAuth2 authorization flow.
    ///
    /// - Parameters:
    ///   - guildId: The guild ID to add the user to.
    ///   - userId: The user ID to add to the guild.
    ///   - accessToken: The OAuth2 access token for the user.
    ///   - nick: The nickname to assign to the user (optional).
    ///   - roles: An array of role IDs to assign to the user (optional).
    ///   - mute: Whether to mute the user in voice channels (optional).
    ///   - deaf: Whether to deafen the user in voice channels (optional).
    ///
    /// - Returns: The guild member object.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// - Note: This method requires a valid OAuth2 access token with the `guilds.join` scope.
    public func addGuildMember(guildId: GuildID, userId: UserID, accessToken: String, nick: String? = nil, roles: [RoleID]? = nil, mute: Bool? = nil, deaf: Bool? = nil) async throws -> GuildMember {
        struct Body: Encodable, Sendable {
            let access_token: String
            let nick: String?
            let roles: [RoleID]?
            let mute: Bool?
            let deaf: Bool?
        }
        return try await http.put(path: "/guilds/\(guildId)/members/\(userId)", body: Body(access_token: accessToken, nick: nick, roles: roles, mute: mute, deaf: deaf))
    }

    /// Removes (kicks) a member from a guild.
    ///
    /// - Parameters:
    ///   - guildId: The guild ID to remove the member from.
    ///   - userId: The user ID to remove.
    ///
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.removeGuildMember(guildId: guildId, userId: userId)
    /// ```
    ///
    /// - Note: Requires the `KICK_MEMBERS` permission.
    public func removeGuildMember(guildId: GuildID, userId: UserID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/members/\(userId)")
    }

    /// Updates the current bot member's profile in a guild.
    ///
    /// Supports nickname, avatar, banner, and bio fields.
    ///
    /// - Parameters:
    ///   - guildId: The guild ID to update the member profile in.
    ///   - nick: The new nickname (optional, 1-32 characters).
    ///   - avatar: The new avatar as a base64 data URI (optional, e.g., `data:image/png;base64,...`).
    ///   - banner: The new banner as a base64 data URI (optional).
    ///   - bio: The new bio (optional, up to 190 characters).
    ///
    /// - Returns: The updated guild member object.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let updated = try await client.modifyCurrentMember(
    ///     guildId: guildId,
    ///     nick: "NewNickname"
    /// )
    /// ```
    ///
    /// - Note: Avatar, banner, and bio fields were added in 2025-09-10.
    public func modifyCurrentMember(
        guildId: GuildID,
        nick: String? = nil,
        avatar: String? = nil,
        banner: String? = nil,
        bio: String? = nil
    ) async throws -> GuildMember {
        struct Body: Encodable, Sendable {
            let nick: String?
            let avatar: String?
            let banner: String?
            let bio: String?
        }
        return try await http.patch(path: "/guilds/\(guildId)/members/@me", body: Body(nick: nick, avatar: avatar, banner: banner, bio: bio))
    }

    /// Updates the current bot member's nickname in a guild (legacy endpoint).
    ///
    /// This is a legacy endpoint kept for compatibility. Use `modifyCurrentMember(guildId:nick:avatar:banner:bio:)` for newer features.
    ///
    /// - Parameters:
    ///   - guildId: The guild ID to update the nickname in.
    ///   - nick: The new nickname (optional).
    ///
    /// - Returns: The updated nickname.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let newNick = try await client.modifyCurrentUserNick(guildId: guildId, nick: "NewNick")
    /// ```
    ///
    /// - See Also: `modifyCurrentMember(guildId:nick:avatar:banner:bio:)`
    public func modifyCurrentUserNick(guildId: GuildID, nick: String?) async throws -> String {
        struct Body: Encodable, Sendable {
            let nick: String?
        }
        struct Resp: Decodable, Sendable {
            let nick: String
        }
        let resp: Resp = try await http.patch(path: "/guilds/\(guildId)/members/@me/nick", body: Body(nick: nick))
        return resp.nick
    }

    /// Adds a role to a guild member.
    ///
    /// - Parameters:
    ///   - guildId: The guild ID.
    ///   - userId: The user ID to add the role to.
    ///   - roleId: The role ID to add.
    ///
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.addGuildMemberRole(guildId: guildId, userId: userId, roleId: roleId)
    /// ```
    ///
    /// - Note: Requires the `MANAGE_ROLES` permission. The bot must be able to assign this role (role hierarchy).
    /// - See Also: `removeGuildMemberRole(guildId:userId:roleId:)`
    public func addGuildMemberRole(guildId: GuildID, userId: UserID, roleId: RoleID) async throws {
        try await http.put(path: "/guilds/\(guildId)/members/\(userId)/roles/\(roleId)")
    }

    /// Removes a role from a guild member.
    ///
    /// - Parameters:
    ///   - guildId: The guild ID.
    ///   - userId: The user ID to remove the role from.
    ///   - roleId: The role ID to remove.
    ///
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.removeGuildMemberRole(guildId: guildId, userId: userId, roleId: roleId)
    /// ```
    ///
    /// - Note: Requires the `MANAGE_ROLES` permission.
    /// - See Also: `addGuildMemberRole(guildId:userId:roleId:)`
    public func removeGuildMemberRole(guildId: GuildID, userId: UserID, roleId: RoleID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/members/\(userId)/roles/\(roleId)")
    }

    /// Searches for guild members by username/nickname prefix.
    ///
    /// This uses the newer POST endpoint for member search (2024+).
    ///
    /// - Parameters:
    ///   - guildId: The guild ID to search in.
    ///   - query: The search query (matches username or nickname prefix).
    ///   - limit: Maximum number of results to return (default 1).
    ///
    /// - Returns: An array of matching guild members.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let members = try await client.searchGuildMembers(
    ///     guildId: guildId,
    ///     query: "john",
    ///     limit: 10
    /// )
    /// ```
    public func searchGuildMembers(guildId: GuildID, query: String, limit: Int = 1) async throws -> [GuildMember] {
        struct Body: Encodable, Sendable {
            let query: String
            let limit: Int
        }
        return try await http.post(path: "/guilds/\(guildId)/members/search", body: Body(query: query, limit: limit))
    }

    /// Fetches a user by their ID.
    ///
    /// - Parameter userId: The user ID to fetch.
    ///
    /// - Returns: The user object.
    /// - Throws: `DiscordError` if the request fails or if the user doesn't exist.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let user = try await client.getUser(userId: userId)
    /// print("Username: \(user.username)")
    /// ```
    ///
    /// - See Also: `getCurrentUser()`
    public func getUser(userId: UserID) async throws -> User {
        try await http.get(path: "/users/\(userId)")
    }

    /// Updates the current bot user's username and/or avatar.
    ///
    /// - Parameters:
    ///   - username: The new username (2-32 characters, optional).
    ///   - avatar: The new avatar as a base64 data URI (optional).
    ///
    /// - Returns: The updated user object.
    /// - Throws: `DiscordError` if the request fails or if the values are invalid.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Update username only
    /// let updated = try await client.modifyCurrentUser(username: "NewBotName")
    ///
    /// // Update avatar only (base64 data URI)
    /// let avatarDataURI = "data:image/png;base64,iVBORw0KGgo..."
    /// let withAvatar = try await client.modifyCurrentUser(avatar: avatarDataURI)
    /// ```
    ///
    /// - Note: Username changes are rate-limited (2 changes per hour).
    /// - See Also: `getCurrentUser()`
    public func modifyCurrentUser(username: String? = nil, avatar: String? = nil) async throws -> User {
        struct Body: Encodable, Sendable {
            let username: String?
            let avatar: String?
        }
        return try await http.patch(path: "/users/@me", body: Body(username: username, avatar: avatar))
    }

    /// Lists guilds visible to the current bot user.
    ///
    /// - Parameters:
    ///   - before: Get guilds before this guild ID for pagination.
    ///   - after: Get guilds after this guild ID for pagination.
    ///   - limit: Maximum number of guilds to return (1-200, default 200).
    ///
    /// - Returns: An array of partial guild objects.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let guilds = try await client.getCurrentUserGuilds(limit: 100)
    /// for guild in guilds {
    ///     print("Guild: \(guild.name)")
    /// }
    /// ```
    ///
    /// - Note: Returns partial guild objects with limited information.
    public func getCurrentUserGuilds(before: GuildID? = nil, after: GuildID? = nil, limit: Int = 200) async throws -> [PartialGuild] {
        var parts: [String] = ["limit=\(limit)"]
        if let before { parts.append("before=\(before)") }
        if let after { parts.append("after=\(after)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/users/@me/guilds\(q)")
    }

    /// Makes the bot leave a guild.
    ///
    /// - Parameter guildId: The ID of the guild to leave.
    ///
    /// - Throws: `DiscordError` if the request fails or if the bot is not in the guild.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.leaveGuild(guildId: guildId)
    /// ```
    ///
    /// - Note: The bot cannot be the owner of the guild.
    public func leaveGuild(guildId: GuildID) async throws {
        try await http.delete(path: "/users/@me/guilds/\(guildId)")
    }

    /// Opens a direct message channel with a user.
    ///
    /// - Parameter recipientId: The ID of the user to open a DM with.
    ///
    /// - Returns: The DM channel object.
    /// - Throws: `DiscordError` if the request fails or if the bot cannot DM the user.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let dm = try await client.createDM(recipientId: userId)
    /// try await client.sendMessage(channelId: dm.id, content: "Hello!")
    /// ```
    ///
    /// - Note: The bot must share a guild with the user or the user must have DMs enabled for the bot.
    /// - See Also: `sendDM(userId:content:embeds:components:)`
    public func createDM(recipientId: UserID) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let recipient_id: UserID
        }
        return try await http.post(path: "/users/@me/channels", body: Body(recipient_id: recipientId))
    }

    /// Opens a DM channel with a user and sends a message in one call.
    ///
    /// This is a convenience method that combines `createDM(recipientId:)` and `sendMessage(...)`.
    ///
    /// - Parameters:
    ///   - userId: The ID of the user to DM.
    ///   - content: The message content (optional, up to 2000 characters).
    ///   - embeds: An array of embed objects (optional, up to 10 embeds).
    ///   - components: An array of message components (optional).
    ///
    /// - Returns: The sent message object.
    /// - Throws: `DiscordError` if the request fails or if the bot cannot DM the user.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let message = try await client.sendDM(
    ///     userId: userId,
    ///     content: "Hello from the bot!"
    /// )
    /// ```
    ///
    /// - Note: The bot must share a guild with the user or the user must have DMs enabled for the bot.
    /// - See Also: `createDM(recipientId:)`
    @discardableResult
    public func sendDM(
        userId: UserID,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil
    ) async throws -> Message {
        let dm = try await createDM(recipientId: userId)
        return try await sendMessage(
            channelId: dm.id,
            content: content,
            embeds: embeds,
            components: components
        )
    }

    /// Creates a group DM using OAuth2 access tokens.
    ///
    /// This method is for user OAuth2 applications, not bot applications.
    ///
    /// - Parameters:
    ///   - accessTokens: An array of OAuth2 access tokens for the users to add.
    ///   - nicks: A dictionary mapping user IDs to their nicknames in the group DM.
    ///
    /// - Returns: The group DM channel object.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// - Note: This method is only available for user OAuth2 applications, not bot applications.
    public func createGroupDM(accessTokens: [String], nicks: [UserID: String]) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let access_tokens: [String]
            let nicks: [UserID: String]
        }
        return try await http.post(path: "/users/@me/channels", body: Body(access_tokens: accessTokens, nicks: nicks))
    }

    // Typed request/response payloads for guild prune operations.
    public struct PrunePayload: Codable, Sendable {
        public let days: Int
        public let compute_prune_count: Bool?
        public let include_roles: [RoleID]?

        public init(days: Int, compute_prune_count: Bool? = nil, include_roles: [RoleID]? = nil) {
            self.days = days
            self.compute_prune_count = compute_prune_count
            self.include_roles = include_roles
        }
    }

    public struct PruneResponse: Codable, Sendable {
        public let pruned: Int

        public init(pruned: Int) {
            self.pruned = pruned
        }
    }

    public func getGuildPruneCount(guildId: GuildID, days: Int = 7) async throws -> Int {
        let resp: PruneResponse = try await http.get(path: "/guilds/\(guildId)/prune?days=\(days)")
        return resp.pruned
    }

    public func beginGuildPrune(guildId: GuildID, days: Int = 7, computePruneCount: Bool = true) async throws -> Int {
        let resp: PruneResponse = try await http.post(path: "/guilds/\(guildId)/prune", body: PrunePayload(days: days, compute_prune_count: computePruneCount, include_roles: nil))
        return resp.pruned
    }

    public func pruneGuild(guildId: GuildID, payload: PrunePayload) async throws -> PruneResponse {
        try await http.post(path: "/guilds/\(guildId)/prune", body: payload)
    }

    public func bulkModifyRolePositions(guildId: GuildID, positions: [(id: RoleID, position: Int)]) async throws -> [Role] {
        struct Entry: Encodable, Sendable {
            let id: RoleID
            let position: Int
        }
        let body = positions.map { Entry(id: $0.id, position: $0.position) }
        return try await http.patch(path: "/guilds/\(guildId)/roles", body: body)
    }
    

    /// Connects the client to the Discord gateway with the specified intents.
    ///
    /// This method establishes a WebSocket connection to Discord's gateway and begins receiving events.
    /// You must specify which events you want to receive using `GatewayIntents`.
    ///
    /// - Parameter intents: The gateway intents specifying which events to receive.
    ///
    /// - Throws: `DiscordError` if the connection fails or if the token is invalid.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.loginAndConnect(intents: [
    ///     .guilds,              // Guild events
    ///     .guildMessages,       // Message events in guilds
    ///     .messageContent       // Message content (privileged)
    /// ])
    ///
    /// // Listen for events
    /// for await event in await client.events {
    ///     switch event {
    ///     case .ready(let ready):
    ///         print("Connected as \(ready.user.username)")
    ///     case .messageCreate(let message):
    ///         print("Message: \(message.content ?? "")")
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    ///
    /// - Important: Some intents like `messageContent` and `guildPresences` are privileged and must be enabled in the Discord Developer Portal.
    /// - Note: After calling this method, you should iterate over `client.events` to handle incoming events.
    /// - See Also: `loginAndConnectSharded(index:total:intents:)`, `GatewayIntents`
    public func loginAndConnect(intents: GatewayIntents) async throws {
        try await gateway.connect(intents: intents, shard: nil, eventSink: { @Sendable event in
            Task { [self] in await self.dispatcher.process(event: event, client: self) }
        })
    }

    /// Connects the client to the Discord gateway as a specific shard.
    ///
    /// Sharding is used to distribute bot load across multiple WebSocket connections for large bots.
    /// Each shard handles a subset of guilds.
    ///
    /// - Parameters:
    ///   - index: The shard index (0-based).
    ///   - total: The total number of shards.
    ///   - intents: The gateway intents specifying which events to receive.
    ///
    /// - Throws: `DiscordError` if the connection fails or if the token is invalid.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Connect as shard 0 of 5 total shards
    /// try await client.loginAndConnectSharded(
    ///     index: 0,
    ///     total: 5,
    ///     intents: [.guilds, .guildMessages]
    /// )
    /// ```
    ///
    /// - Note: Discord recommends sharding for bots in 2,500+ guilds.
    /// - See Also: `loginAndConnect(intents:)`
    public func loginAndConnectSharded(index: Int, total: Int, intents: GatewayIntents) async throws {
        try await gateway.connect(intents: intents, shard: (index, total), eventSink: { @Sendable event in
            Task { [self] in await self.dispatcher.process(event: event, client: self) }
        })
    }

    /// Retrieves the current bot user information.
    ///
    /// - Returns: The bot user object.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let user = try await client.getCurrentUser()
    /// print("Bot username: \(user.username)")
    /// print("Bot ID: \(user.id)")
    /// ```
    ///
    /// - See Also: `getUser(userId:)`
    public func getCurrentUser() async throws -> User {
        try await http.get(path: "/users/@me")
    }

    /// Sends a simple text message to a channel.
    ///
    /// This is a convenience method for sending a message with only text content.
    /// For more control over message formatting, use the overloads that accept embeds, components, etc.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel to send the message to.
    ///   - content: The message content (up to 2000 characters).
    ///
    /// - Returns: The created message object.
    /// - Throws: `DiscordError` if the request fails, if the channel doesn't exist, or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let message = try await client.sendMessage(
    ///     channelId: channelId,
    ///     content: "Hello, world!"
    /// )
    /// print("Sent message with ID: \(message.id)")
    /// ```
    ///
    /// - Note: Messages are limited to 2000 characters. For longer content, consider using embeds or splitting into multiple messages.
    /// - See Also: `sendMessage(channelId:content:embeds:components:allowedMentions:messageReference:tts:flags:stickerIds:attachments:poll:)`
    public func sendMessage(channelId: ChannelID, content: String) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String
        }
        return try await http.post(path: "/channels/\(channelId)/messages", body: Body(content: content))
    }

    /// Sends a message with content and embeds to a channel.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel to send the message to.
    ///   - content: The message content (optional, up to 2000 characters).
    ///   - embeds: An array of embed objects (up to 10 embeds).
    ///
    /// - Returns: The created message object.
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let embed = Embed(
    ///     title: "Hello",
    ///     description: "This is an embedded message"
    /// )
    /// let message = try await client.sendMessage(
    ///     channelId: channelId,
    ///     content: "Check this out:",
    ///     embeds: [embed]
    /// )
    /// ```
    ///
    /// - See Also: `Embed`, `sendMessage(channelId:content:embeds:components:allowedMentions:messageReference:tts:flags:stickerIds:attachments:poll:)`
    public func sendMessage(channelId: ChannelID, content: String? = nil, embeds: [Embed]) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]
        }
        return try await http.post(path: "/channels/\(channelId)/messages", body: Body(content: content, embeds: embeds))
    }

    /// Sends a message with full control over all Discord message fields.
    ///
    /// This is the most comprehensive message sending method, allowing you to specify all available message options.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel to send the message to.
    ///   - content: The message content (optional, up to 2000 characters).
    ///   - embeds: An array of embed objects (optional, up to 10 embeds).
    ///   - components: An array of message components (buttons, select menus, etc.).
    ///   - allowedMentions: Controls which user and role mentions are allowed to trigger notifications.
    ///   - messageReference: A reference to another message to reply to or forward.
    ///   - tts: Whether this message should be sent as text-to-speech.
    ///   - flags: Message flags (e.g., 64 for ephemeral messages).
    ///   - stickerIds: An array of sticker IDs to include in the message.
    ///   - attachments: An array of attachment objects for file attachments.
    ///   - poll: A poll object to include in the message.
    ///
    /// - Returns: The created message object.
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let embed = Embed(
    ///     title: "Poll",
    ///     description: "Vote below!"
    /// )
    /// let button = MessageComponent.button(
    ///     style: .primary,
    ///     label: "Click me",
    ///     customId: "my_button"
    /// )
    ///
    /// let message = try await client.sendMessage(
    ///     channelId: channelId,
    ///     content: "Here's a poll:",
    ///     embeds: [embed],
    ///     components: [button]
    /// )
    /// ```
    ///
    /// - Note: For file attachments, use `sendMessageWithFiles(channelId:content:embeds:components:allowedMentions:messageReference:tts:flags:stickerIds:attachments:poll:files:)`.
    /// - See Also: `MessageComponent`, `Embed`, `Poll`, `sendMessageWithFiles(channelId:content:embeds:components:allowedMentions:messageReference:tts:flags:stickerIds:attachments:poll:files:)`
    public func sendMessage(
        channelId: ChannelID,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        allowedMentions: AllowedMentions? = nil,
        messageReference: MessageReference? = nil,
        tts: Bool? = nil,
        flags: Int? = nil,
        stickerIds: [StickerID]? = nil,
        attachments: [PartialAttachment]? = nil,
        poll: Poll? = nil
    ) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
            let allowed_mentions: AllowedMentions?
            let message_reference: MessageReference?
            let tts: Bool?
            let flags: Int?
            let sticker_ids: [StickerID]?
            let attachments: [PartialAttachment]?
            let poll: Poll?

            public init(
                content: String? = nil,
                embeds: [Embed]? = nil,
                components: [MessageComponent]? = nil,
                allowedMentions: AllowedMentions? = nil,
                messageReference: MessageReference? = nil,
                tts: Bool? = nil,
                flags: Int? = nil,
                stickerIds: [StickerID]? = nil,
                attachments: [PartialAttachment]? = nil,
                poll: Poll? = nil
            ) {
                self.content = content
                self.embeds = embeds
                self.components = components
                self.allowed_mentions = allowedMentions
                self.message_reference = messageReference
                self.tts = tts
                self.flags = flags
                self.sticker_ids = stickerIds
                self.attachments = attachments
                self.poll = poll
            }
        }
        let body = Body(
            content: content,
            embeds: embeds,
            components: components,
            allowedMentions: allowedMentions,
            messageReference: messageReference,
            tts: tts,
            flags: flags,
            stickerIds: stickerIds,
            attachments: attachments,
            poll: poll
        )
        return try await http.post(path: "/channels/\(channelId)/messages", body: body)
    }

    /// Ends a poll attached to a message, closing voting.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel containing the poll.
    ///   - messageId: The ID of the message containing the poll.
    ///   - pollId: The ID of the poll to end.
    ///
    /// - Returns: The updated poll object.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let poll = try await client.endPoll(
    ///     channelId: channelId,
    ///     messageId: messageId,
    ///     pollId: pollId
    /// )
    /// print("Poll ended with \(poll.results?.count ?? 0) answers")
    /// ```
    ///
    /// - Note: Only the poll creator or users with the `MANAGE_MESSAGES` permission can end polls.
    public func endPoll(channelId: ChannelID, messageId: MessageID, pollId: String) async throws -> Poll {
        struct Empty: Encodable, Sendable {}
        return try await http.post(path: "/channels/\(channelId)/messages/\(messageId)/polls/\(pollId)/expire", body: Empty())
    }

    /// Retrieves a paginated list of users who voted for a specific poll answer.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel containing the poll message.
    ///   - messageId: The ID of the message containing the poll.
    ///   - answerId: The ID of the poll answer to get voters for.
    ///   - after: Get users after this user ID for pagination.
    ///   - limit: Maximum number of users to return (1-100, default 25).
    ///
    /// - Returns: A paginated list of users who voted for the specified answer.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let voters = try await client.getPollAnswerVoters(
    ///     channelId: channelId,
    ///     messageId: messageId,
    ///     answerId: 1,
    ///     limit: 50
    /// )
    /// print("\(voters.users.count) users voted for this answer")
    /// ```
    public func getPollAnswerVoters(channelId: ChannelID, messageId: MessageID, answerId: Int, after: UserID? = nil, limit: Int = 25) async throws -> PollAnswerUsers {
        var query: [String: String] = ["limit": String(limit)]
        if let after { query["after"] = after.rawValue }
        return try await http.get(path: "/channels/\(channelId)/polls/\(messageId)/answers/\(answerId)", query: query)
    }

    /// Updates the bot's presence status and activities.
    ///
    /// - Parameters:
    ///   - status: The status to set (e.g., "online", "idle", "dnd", "invisible").
    ///   - activities: An array of activity objects to display.
    ///   - afk: Whether the bot is AFK (away from keyboard).
    ///   - since: Unix timestamp (in milliseconds) of when the bot went AFK.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Set status to "Do Not Disturb" with an activity
    /// let activity = PresenceUpdatePayload.Activity(
    ///     name: "Playing Swift",
    ///     type: 0  // Playing
    /// )
    /// await client.setPresence(
    ///     status: "dnd",
    ///     activities: [activity]
    /// )
    /// ```
    ///
    /// - Note: This requires the `guildPresences` intent for status updates to be visible.
    /// - See Also: `setStatus(_:)`, `setActivity(name:type:state:details:buttons:)`
    public func setPresence(status: String, activities: [PresenceUpdatePayload.Activity] = [], afk: Bool = false, since: Int? = nil) async {
        await gateway.setPresence(status: status, activities: activities, afk: afk, since: since)
    }

    /// Sets the bot's status without changing activities.
    ///
    /// - Parameter status: The status to set (e.g., "online", "idle", "dnd", "invisible").
    ///
    /// ## Example
    ///
    /// ```swift
    /// await client.setStatus("online")
    /// ```
    ///
    /// - See Also: `setPresence(status:activities:afk:since:)`
    public func setStatus(_ status: String) async {
        await gateway.setPresence(status: status, activities: [], afk: false, since: nil)
    }

    /// Sets a single activity for the bot with the specified type.
    ///
    /// - Parameters:
    ///   - name: The activity name (e.g., "Playing Minecraft", "Listening to Spotify").
    ///   - type: The activity type (0=Playing, 1=Streaming, 2=Listening, 3=Watching, 5=Competing).
    ///   - state: The activity's state or additional info.
    ///   - details: Additional details about the activity.
    ///   - buttons: An array of button labels for rich presence.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Set "Playing" activity
    /// await client.setActivity(name: "Playing Swift", type: 0)
    ///
    /// // Set "Listening to" activity with state
    /// await client.setActivity(
    ///     name: "Music",
    ///     type: 2,
    ///     state: "Lo-fi beats"
    /// )
    /// ```
    ///
    /// - Note: This automatically sets the status to "online".
    /// - See Also: `setPresence(status:activities:afk:since:)`
    public func setActivity(name: String, type: Int = 0, state: String? = nil, details: String? = nil, buttons: [String]? = nil) async {
        let act = PresenceUpdatePayload.Activity(
            name: name,
            type: type,
            state: state,
            details: details,
            timestamps: nil,
            assets: nil,
            party: nil,
            secrets: nil
        )
        await gateway.setPresence(status: "online", activities: [act], afk: false, since: nil)
    }


    // MARK: - Internal voice wiring used by EventDispatcher
    func _internalSetCurrentUserId(_ id: UserID) async {
        self.currentUserId = id
    }


    // MARK: - Internal event emission used by EventDispatcher
    func _internalEmitEvent(_ event: DiscordEvent) {
        eventContinuation?.yield(event)
    }

    /// Performs a raw GET request to the Discord API.
    ///
    /// This is a low-level method for accessing Discord API endpoints that haven't been wrapped yet.
    /// Use typed methods when available.
    ///
    /// - Parameter path: The API path (e.g., "/channels/123").
    /// - Returns: The decoded response of type `T`.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let channel: Channel = try await client.rawGET("/channels/\(channelId)")
    /// ```
    ///
    /// - Warning: Use typed methods when available for better type safety and documentation.
    public func rawGET<T: Decodable>(_ path: String) async throws -> T { try await http.get(path: path) }

    /// Performs a raw POST request to the Discord API.
    ///
    /// This is a low-level method for accessing Discord API endpoints that haven't been wrapped yet.
    /// Use typed methods when available.
    ///
    /// - Parameters:
    ///   - path: The API path.
    ///   - body: The request body to send.
    /// - Returns: The decoded response of type `T`.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// - Warning: Use typed methods when available for better type safety and documentation.
    public func rawPOST<B: Encodable & Sendable, T: Decodable>(_ path: String, body: B) async throws -> T { try await http.post(path: path, body: body) }

    /// Performs a raw PATCH request to the Discord API.
    ///
    /// This is a low-level method for accessing Discord API endpoints that haven't been wrapped yet.
    /// Use typed methods when available.
    ///
    /// - Parameters:
    ///   - path: The API path.
    ///   - body: The request body to send.
    /// - Returns: The decoded response of type `T`.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// - Warning: Use typed methods when available for better type safety and documentation.
    public func rawPATCH<B: Encodable & Sendable, T: Decodable>(_ path: String, body: B) async throws -> T { try await http.patch(path: path, body: body) }

    /// Performs a raw PUT request to the Discord API.
    ///
    /// This is a low-level method for accessing Discord API endpoints that haven't been wrapped yet.
    /// Use typed methods when available.
    ///
    /// - Parameters:
    ///   - path: The API path.
    ///   - body: The request body to send.
    /// - Returns: The decoded response of type `T`.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// - Warning: Use typed methods when available for better type safety and documentation.
    public func rawPUT<B: Encodable & Sendable, T: Decodable>(_ path: String, body: B) async throws -> T { try await http.put(path: path, body: body) }

    /// Performs a raw DELETE request to the Discord API.
    ///
    /// This is a low-level method for accessing Discord API endpoints that haven't been wrapped yet.
    /// Use typed methods when available.
    ///
    /// - Parameter path: The API path.
    /// - Returns: The decoded response of type `T`.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// - Warning: Use typed methods when available for better type safety and documentation.
    public func rawDELETE<T: Decodable>(_ path: String) async throws -> T { try await http.delete(path: path) }

    /// Performs a POST request to an application-scoped resource endpoint.
    ///
    /// This is a generic method for accessing application-specific endpoints that follow the pattern
    /// `/applications/{application.id}/{relativePath}`.
    ///
    /// - Parameters:
    ///   - applicationId: The application ID.
    ///   - relativePath: The relative path after the application ID (e.g., "role-connections/metadata").
    ///   - payload: The JSON payload to send.
    ///
    /// - Returns: The response as a `JSONValue`.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let payload: [String: JSONValue] = [
    ///     "platform_name": .string("My App"),
    ///     "platform_username": .string("user123")
    /// ]
    /// let response = try await client.postApplicationResource(
    ///     applicationId: appId,
    ///     relativePath: "role-connections/123",
    ///     payload: payload
    /// )
    /// ```
    public func postApplicationResource(applicationId: ApplicationID, relativePath: String, payload: [String: JSONValue]) async throws -> JSONValue {
        try await http.post(path: "/applications/\(applicationId)/\(relativePath)", body: payload)
    }

    /// Performs a PATCH request to an application-scoped resource endpoint.
    ///
    /// - Parameters:
    ///   - applicationId: The application ID.
    ///   - relativePath: The relative path after the application ID.
    ///   - payload: The JSON payload to send.
    ///
    /// - Returns: The response as a `JSONValue`.
    /// - Throws: `DiscordError` if the request fails.
    public func patchApplicationResource(applicationId: ApplicationID, relativePath: String, payload: [String: JSONValue]) async throws -> JSONValue {
        try await http.patch(path: "/applications/\(applicationId)/\(relativePath)", body: payload)
    }

    /// Performs a DELETE request to an application-scoped resource endpoint.
    ///
    /// - Parameters:
    ///   - applicationId: The application ID.
    ///   - relativePath: The relative path after the application ID.
    ///
    /// - Throws: `DiscordError` if the request fails.
    public func deleteApplicationResource(applicationId: ApplicationID, relativePath: String) async throws {
        try await http.delete(path: "/applications/\(applicationId)/\(relativePath)")
    }

    /// Retrieves a channel by its ID.
    ///
    /// - Parameter id: The channel ID.
    ///
    /// - Returns: The channel object.
    /// - Throws: `DiscordError` if the request fails or if the channel doesn't exist.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let channel = try await client.getChannel(id: channelId)
    /// print("Channel name: \(channel.name ?? "DM")")
    /// ```
    ///
    /// - See Also: `modifyChannel(id:topic:nsfw:position:parentId:)`
    public func getChannel(id: ChannelID) async throws -> Channel {
        try await http.get(path: "/channels/\(id)")
    }

    /// Retrieves member counts for all roles in a guild.
    ///
    /// This uses the newer role member counts endpoint `GET /guilds/{guild.id}/roles/member-counts`.
    ///
    /// - Parameter guildId: The guild ID.
    ///
    /// - Returns: An array of `RoleMemberCount` objects containing role IDs and member counts.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let counts = try await client.getGuildRoleMemberCounts(guildId: guildId)
    /// for count in counts {
    ///     print("Role \(count.role_id): \(count.count) members")
    /// }
    /// ```
    ///
    /// - See Also: `getGuildRoleMemberCount(guildId:roleId:)`
    public func getGuildRoleMemberCounts(guildId: GuildID) async throws -> [RoleMemberCount] {
        try await http.get(path: "/guilds/\(guildId)/roles/member-counts")
    }

    /// Retrieves the member count for a specific role in a guild.
    ///
    /// - Parameters:
    ///   - guildId: The guild ID.
    ///   - roleId: The role ID.
    ///
    /// - Returns: The member count for the role, or `0` if the role is not found or has no members.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let count = try await client.getGuildRoleMemberCount(
    ///     guildId: guildId,
    ///     roleId: roleId
    /// )
    /// print("Role has \(count) members")
    /// ```
    ///
    /// - See Also: `getGuildRoleMemberCounts(guildId:)`
    public func getGuildRoleMemberCount(guildId: GuildID, roleId: RoleID) async throws -> Int {
        let counts = try await getGuildRoleMemberCounts(guildId: guildId)
        return counts.first(where: { $0.role_id == roleId })?.count ?? 0
    }

    /// Creates an async stream that yields all pinned messages in a channel.
    ///
    /// This method automatically handles pagination, fetching pinned messages in batches.
    /// It uses the paginated pins endpoint internally.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel to stream pinned messages from.
    ///   - pageLimit: The number of messages to fetch per page (default 50).
    ///
    /// - Returns: An `AsyncStream<Message>` that yields pinned messages.
    ///
    /// ## Example
    ///
    /// ```swift
    /// for await pinnedMessage in client.streamChannelPins(channelId: channelId) {
    ///     print("Pinned: \(pinnedMessage.content ?? "")")
    /// }
    /// ```
    ///
    /// - Note: The stream will automatically terminate when all pinned messages have been yielded.
    /// - See Also: `getChannelPinsPaginated(channelId:limit:after:)`
    public func streamChannelPins(channelId: ChannelID, pageLimit: Int = 50) -> AsyncStream<Message> {
        AsyncStream(Message.self) { @Sendable continuation in
            Task { @Sendable in
                var after: MessageID? = nil
                var lastSeen: String? = nil
                while true {
                    do {
                        let page = try await getChannelPinsPaginated(channelId: channelId, limit: pageLimit, after: after)
                        if page.isEmpty { break }
                        for msg in page {
                            continuation.yield(msg)
                        }
                        // Guard against accidental loops if pagination stops advancing.
                        if let last = page.last?.id.description {
                            if last == lastSeen { break }
                            lastSeen = last
                            after = page.last?.id
                        } else {
                            break
                        }
                    } catch {
                        continuation.finish()
                        return
                    }
                }
                continuation.finish()
            }
        }
    }

    /// Modifies a channel's name.
    ///
    /// - Parameters:
    ///   - id: The channel ID.
    ///   - name: The new channel name (1-100 characters).
    ///
    /// - Returns: The updated channel object.
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let updated = try await client.modifyChannelName(
    ///     id: channelId,
    ///     name: "new-name"
    /// )
    /// ```
    ///
    /// - Note: Requires the `MANAGE_CHANNELS` permission.
    /// - See Also: `modifyChannel(id:topic:nsfw:position:parentId:)`
    public func modifyChannelName(id: ChannelID, name: String) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let name: String
        }
        return try await http.patch(path: "/channels/\(id)", body: Body(name: name))
    }

    /// Modifies common mutable fields of a channel.
    ///
    /// - Parameters:
    ///   - id: The channel ID.
    ///   - topic: The new channel topic (0-1024 characters, for text channels only).
    ///   - nsfw: Whether the channel is NSFW (age-restricted).
    ///   - position: The sorting position of the channel.
    ///   - parentId: The parent category ID (for moving channels between categories).
    ///
    /// - Returns: The updated channel object.
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let updated = try await client.modifyChannel(
    ///     id: channelId,
    ///     topic: "New topic",
    ///     nsfw: false
    /// )
    /// ```
    ///
    /// - Note: Requires the `MANAGE_CHANNELS` permission.
    /// - See Also: `modifyChannelName(id:name:)`, `getChannel(id:)`
    public func modifyChannel(id: ChannelID, topic: String? = nil, nsfw: Bool? = nil, position: Int? = nil, parentId: ChannelID? = nil) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let topic: String?
            let nsfw: Bool?
            let position: Int?
            let parent_id: ChannelID?
        }
        return try await http.patch(path: "/channels/\(id)", body: Body(topic: topic, nsfw: nsfw, position: position, parent_id: parentId))
    }

    /// Deletes a message from a channel.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel containing the message.
    ///   - messageId: The ID of the message to delete.
    ///
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.deleteMessage(
    ///     channelId: channelId,
    ///     messageId: messageId
    /// )
    /// ```
    ///
    /// - Note: Requires the `MANAGE_MESSAGES` permission to delete messages from other users.
    ///       Bots can delete their own messages without this permission.
    /// - Important: Messages older than 14 days cannot be deleted individually by bots.
    /// - See Also: `bulkDeleteMessages(channelId:messageIds:)`
    public func deleteMessage(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)")
    }

    /// Retrieves a single message by its ID.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel containing the message.
    ///   - messageId: The ID of the message to retrieve.
    ///
    /// - Returns: The message object.
    /// - Throws: `DiscordError` if the request fails or if the message doesn't exist.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let message = try await client.getMessage(
    ///     channelId: channelId,
    ///     messageId: messageId
    /// )
    /// print("Message content: \(message.content ?? "")")
    /// ```
    ///
    /// - Note: Requires the `READ_MESSAGE_HISTORY` permission.
    /// - See Also: `listChannelMessages(channelId:limit:)`
    public func getMessage(channelId: ChannelID, messageId: MessageID) async throws -> Message {
        try await http.get(path: "/channels/\(channelId)/messages/\(messageId)")
    }

    /// Edits a message's content, embeds, and/or components.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel containing the message.
    ///   - messageId: The ID of the message to edit.
    ///   - content: The new message content (optional, up to 2000 characters).
    ///   - embeds: The new embeds (optional, up to 10 embeds).
    ///   - components: The new message components (optional).
    ///
    /// - Returns: The edited message object.
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let updated = try await client.editMessage(
    ///     channelId: channelId,
    ///     messageId: messageId,
    ///     content: "Updated content"
    /// )
    /// ```
    ///
    /// - Note: Requires the `MANAGE_MESSAGES` permission to edit messages from other users.
    ///       Bots can edit their own messages without this permission.
    /// - Important: All fields are optional; only provided fields will be updated.
    /// - See Also: `sendMessage(channelId:content:)`
    public func editMessage(channelId: ChannelID, messageId: MessageID, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
        }
        return try await http.patch(path: "/channels/\(channelId)/messages/\(messageId)", body: Body(content: content, embeds: embeds, components: components))
    }

    /// Lists recent messages from a channel.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel to list messages from.
    ///   - limit: The maximum number of messages to return (1-100, default 50).
    ///
    /// - Returns: An array of message objects, ordered from newest to oldest.
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let messages = try await client.listChannelMessages(
    ///     channelId: channelId,
    ///     limit: 25
    /// )
    /// for message in messages {
    ///     print("\(message.author.username): \(message.content ?? "")")
    /// }
    /// ```
    ///
    /// - Note: Requires the `READ_MESSAGE_HISTORY` permission.
    /// - See Also: `getMessage(channelId:messageId:)`
    public func listChannelMessages(channelId: ChannelID, limit: Int = 50) async throws -> [Message] {
        try await http.get(path: "/channels/\(channelId)/messages?limit=\(limit)")
    }

    /// Searches for messages within a guild.
    ///
    /// This method requires the `READ_MESSAGE_HISTORY` and `MESSAGE_CONTENT` intents.
    ///
    /// - Parameters:
    ///   - guildId: The guild ID to search in.
    ///   - query: The search query string.
    ///   - authorId: Filter by message author ID.
    ///   - minId: Only return messages after this message ID.
    ///   - maxId: Only return messages before this message ID.
    ///   - has: Filter by message attributes (e.g., "link", "embed", "file", "video", "image", "sound").
    ///   - limit: Maximum number of results to return.
    ///   - offset: Offset for pagination.
    ///
    /// - Returns: An array of matching messages.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Search for messages containing "hello"
    /// let results = try await client.searchGuildMessages(
    ///     guildId: guildId,
    ///     query: "hello",
    ///     limit: 25
    /// )
    ///
    /// // Search for messages with attachments
    /// let withFiles = try await client.searchGuildMessages(
    ///     guildId: guildId,
    ///     has: "file"
    /// )
    /// ```
    ///
    /// - Note: Message search has rate limits and may not return all results for large searches.
    public func searchGuildMessages(guildId: GuildID, query: String? = nil, authorId: UserID? = nil, minId: MessageID? = nil, maxId: MessageID? = nil, has: String? = nil, limit: Int? = nil, offset: Int? = nil) async throws -> [Message] {
        var queryParams: [String] = []
        if let q = query { queryParams.append("content=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)") }
        if let aid = authorId { queryParams.append("author_id=\(aid)") }
        if let mid = minId { queryParams.append("min_id=\(mid)") }
        if let mid = maxId { queryParams.append("max_id=\(mid)") }
        if let h = has { queryParams.append("has=\(h)") }
        if let l = limit { queryParams.append("limit=\(l)") }
        if let o = offset { queryParams.append("offset=\(o)") }
        let queryString = queryParams.isEmpty ? "" : "?" + queryParams.joined(separator: "&")
        return try await http.get(path: "/guilds/\(guildId)/messages/search\(queryString)")
    }

    /// A typed reference to an emoji for reaction methods.
    ///
    /// Use `.unicode("👍")` for standard Unicode emoji and `.custom(name:id:)` for guild custom emoji.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Unicode emoji
    /// try await client.addReaction(channelId: cid, messageId: mid, emoji: .unicode("🔥"))
    ///
    /// // Custom guild emoji
    /// try await client.addReaction(channelId: cid, messageId: mid, emoji: .custom(name: "pepega", id: emojiId))
    /// ```
    public enum EmojiRef: Sendable {
        /// A standard Unicode emoji, e.g., "👍" or "🔥".
        case unicode(String)
        
        /// A custom guild emoji.
        ///
        /// - Parameters:
        ///   - name: The emoji name (e.g., "pepega").
        ///   - id: The emoji's snowflake ID.
        case custom(name: String, id: EmojiID)

        /// The percent-encoded string Discord expects in reaction URL paths.
        ///
        /// This property automatically handles URL encoding for both Unicode and custom emoji.
        public var encoded: String {
            switch self {
            case .unicode(let char):
                return char.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? char
            case .custom(let name, let id):
                let raw = "\(name):\(id)"
                return raw.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? raw
            }
        }
    }

    private func encodeEmoji(_ emoji: String) -> String {
        emoji.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? emoji
    }

    /// Adds the bot's reaction to a message.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel containing the message.
    ///   - messageId: The ID of the message to react to.
    ///   - emoji: The emoji to react with (either Unicode string or custom emoji format "name:id").
    ///
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Unicode emoji
    /// try await client.addReaction(channelId: channelId, messageId: messageId, emoji: "👍")
    ///
    /// // Custom emoji (use the encoded format)
    /// try await client.addReaction(channelId: channelId, messageId: messageId, emoji: "pepega:123456789")
    /// ```
    ///
    /// - Note: Requires the `READ_MESSAGE_HISTORY` and `ADD_REACTIONS` permissions.
    /// - See Also: `removeOwnReaction(channelId:messageId:emoji:)`, `removeUserReaction(channelId:messageId:emoji:userId:)`
    public func addReaction(channelId: ChannelID, messageId: MessageID, emoji: String) async throws {
        let e = encodeEmoji(emoji)
        try await http.put(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)/@me")
    }

    /// Removes the bot's own reaction from a message.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel containing the message.
    ///   - messageId: The ID of the message to remove the reaction from.
    ///   - emoji: The emoji to remove (either Unicode string or custom emoji format "name:id").
    ///
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.removeOwnReaction(channelId: channelId, messageId: messageId, emoji: "👍")
    /// ```
    ///
    /// - See Also: `addReaction(channelId:messageId:emoji:)`, `removeUserReaction(channelId:messageId:emoji:userId:)`
    public func removeOwnReaction(channelId: ChannelID, messageId: MessageID, emoji: String) async throws {
        let e = encodeEmoji(emoji)
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)/@me")
    }

    /// Removes another user's reaction from a message.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel containing the message.
    ///   - messageId: The ID of the message to remove the reaction from.
    ///   - emoji: The emoji to remove (either Unicode string or custom emoji format "name:id").
    ///   - userId: The ID of the user whose reaction to remove.
    ///
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.removeUserReaction(
    ///     channelId: channelId,
    ///     messageId: messageId,
    ///     emoji: "👍",
    ///     userId: userId
    /// )
    /// ```
    ///
    /// - Note: Requires the `MANAGE_MESSAGES` permission to remove other users' reactions.
    /// - See Also: `addReaction(channelId:messageId:emoji:)`, `removeOwnReaction(channelId:messageId:emoji:)`
    public func removeUserReaction(channelId: ChannelID, messageId: MessageID, emoji: String, userId: UserID) async throws {
        let e = encodeEmoji(emoji)
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)/\(userId)")
    }

    /// Retrieves users who reacted with a specific emoji.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel containing the message.
    ///   - messageId: The ID of the message to get reactions from.
    ///   - emoji: The emoji to get users for (either Unicode string or custom emoji format "name:id").
    ///   - limit: The maximum number of users to return (1-100, default 25).
    ///
    /// - Returns: An array of users who reacted with the specified emoji.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let reactors = try await client.getReactions(
    ///     channelId: channelId,
    ///     messageId: messageId,
    ///     emoji: "👍",
    ///     limit: 50
    /// )
    /// for user in reactors {
    ///     print("\(user.username) reacted with 👍")
    /// }
    /// ```
    ///
    /// - Note: Requires the `READ_MESSAGE_HISTORY` permission.
    /// - See Also: `addReaction(channelId:messageId:emoji:)`
    public func getReactions(channelId: ChannelID, messageId: MessageID, emoji: String, limit: Int? = 25) async throws -> [User] {
        let e = encodeEmoji(emoji)
        let q = limit != nil ? "?limit=\(limit!)" : ""
        return try await http.get(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)\(q)")
    }

    /// Removes all reactions from a message.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel containing the message.
    ///   - messageId: The ID of the message to remove all reactions from.
    ///
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.removeAllReactions(channelId: channelId, messageId: messageId)
    /// ```
    ///
    /// - Note: Requires the `MANAGE_MESSAGES` permission.
    /// - See Also: `removeAllReactionsForEmoji(channelId:messageId:emoji:)`
    public func removeAllReactions(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions")
    }

    /// Removes all reactions for a specific emoji from a message.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel containing the message.
    ///   - messageId: The ID of the message to remove reactions from.
    ///   - emoji: The emoji to remove all reactions for (either Unicode string or custom emoji format "name:id").
    ///
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await client.removeAllReactionsForEmoji(
    ///     channelId: channelId,
    ///     messageId: messageId,
    ///     emoji: "👍"
    /// )
    /// ```
    ///
    /// - Note: Requires the `MANAGE_MESSAGES` permission.
    /// - See Also: `removeAllReactions(channelId:messageId:)`
    public func removeAllReactionsForEmoji(channelId: ChannelID, messageId: MessageID, emoji: String) async throws {
        let e = encodeEmoji(emoji)
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)")
    }

    // MARK: Typed EmojiRef reaction overloads

    /// Adds a reaction using a typed `EmojiRef`.
    ///
    /// - Parameters:
    ///   - channelId: The ID of the channel containing the message.
    ///   - messageId: The ID of the message to react to.
    ///   - emoji: The typed emoji reference (`.unicode()` or `.custom()`).
    ///
    /// - Throws: `DiscordError` if the request fails or if the bot lacks permissions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Unicode emoji
    /// try await client.addReaction(
    ///     channelId: channelId,
    ///     messageId: messageId,
    ///     emoji: .unicode("🔥")
    /// )
    ///
    /// // Custom emoji
    /// try await client.addReaction(
    ///     channelId: channelId,
    ///     messageId: messageId,
    ///     emoji: .custom(name: "pepega", id: emojiId)
    /// )
    /// ```
    ///
    /// - Note: Requires the `READ_MESSAGE_HISTORY` and `ADD_REACTIONS` permissions.
    /// - See Also: `EmojiRef`
    public func addReaction(channelId: ChannelID, messageId: MessageID, emoji: EmojiRef) async throws {
        try await http.put(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(emoji.encoded)/@me")
    }

    /// Remove the bot's own reaction using a typed ``EmojiRef``.
    public func removeOwnReaction(channelId: ChannelID, messageId: MessageID, emoji: EmojiRef) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(emoji.encoded)/@me")
    }

    /// Remove another user's reaction using a typed ``EmojiRef``.
    public func removeUserReaction(channelId: ChannelID, messageId: MessageID, emoji: EmojiRef, userId: UserID) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(emoji.encoded)/\(userId)")
    }

    /// Fetch all users who reacted with a typed ``EmojiRef``.
    public func getReactions(channelId: ChannelID, messageId: MessageID, emoji: EmojiRef, limit: Int? = 25) async throws -> [User] {
        let q = limit != nil ? "?limit=\(limit!)" : ""
        return try await http.get(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(emoji.encoded)\(q)")
    }

    /// Remove all reactions for a typed ``EmojiRef``.
    public func removeAllReactionsForEmoji(channelId: ChannelID, messageId: MessageID, emoji: EmojiRef) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(emoji.encoded)")
    }

    // MARK: - REST: Guilds
    public func getGuild(id: GuildID) async throws -> Guild {
        try await http.get(path: "/guilds/\(id)")
    }

    public func getGuildChannels(guildId: GuildID) async throws -> [Channel] {
        try await http.get(path: "/guilds/\(guildId)/channels")
    }

    public func getGuildMember(guildId: GuildID, userId: UserID) async throws -> GuildMember {
        try await http.get(path: "/guilds/\(guildId)/members/\(userId)")
    }

    public func listGuildMembers(guildId: GuildID, limit: Int = 1000, after: UserID? = nil) async throws -> [GuildMember] {
        var path = "/guilds/\(guildId)/members?limit=\(limit)"
        if let after { path += "&after=\(after)" }
        return try await http.get(path: path)
    }

    // Create and delete guild channels.
    public func createGuildChannel(guildId: GuildID, name: String, type: Int? = nil, topic: String? = nil, nsfw: Bool? = nil, parentId: ChannelID? = nil, position: Int? = nil) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let name: String
            let type: Int?
            let topic: String?
            let nsfw: Bool?
            let parent_id: ChannelID?
            let position: Int?
        }
        return try await http.post(path: "/guilds/\(guildId)/channels", body: Body(name: name, type: type, topic: topic, nsfw: nsfw, parent_id: parentId, position: position))
    }

    public func deleteChannel(channelId: ChannelID) async throws {
        try await http.delete(path: "/channels/\(channelId)")
    }

    // Bulk update channel positions within a guild.
    public func bulkModifyGuildChannelPositions(guildId: GuildID, positions: [(id: ChannelID, position: Int)]) async throws -> [Channel] {
        struct Entry: Encodable, Sendable {
            let id: ChannelID
            let position: Int
        }
        let body = positions.map { Entry(id: $0.id, position: $0.position) }
        return try await http.patch(path: "/guilds/\(guildId)/channels", body: body)
    }

    // Upserts a channel permission overwrite.
    // `type` values: 0 = role overwrite, 1 = member overwrite.
    public func editChannelPermission(channelId: ChannelID, overwriteId: OverwriteID, type: Int, allow: String? = nil, deny: String? = nil) async throws {
        struct Body: Encodable, Sendable {
            let allow: String?
            let deny: String?
            let type: Int
        }
        struct EmptyDecodable: Decodable, Sendable {
        }
        let _: EmptyDecodable = try await http.put(path: "/channels/\(channelId)/permissions/\(overwriteId)", body: Body(allow: allow, deny: deny, type: type))
    }

    public func deleteChannelPermission(channelId: ChannelID, overwriteId: OverwriteID) async throws {
        try await http.delete(path: "/channels/\(channelId)/permissions/\(overwriteId)")
    }

    // Triggers the typing indicator in a channel.
    public func triggerTypingIndicator(channelId: ChannelID) async throws {
        struct Empty: Encodable, Sendable {
        }
        struct EmptyDecodable: Decodable, Sendable {
        }
        let _: EmptyDecodable = try await http.post(path: "/channels/\(channelId)/typing", body: Empty())
    }

    // Role endpoints.
    public func listGuildRoles(guildId: GuildID) async throws -> [Role] {
        try await http.get(path: "/guilds/\(guildId)/roles")
    }

    /// Fetch a single role by ID.
    /// `GET /guilds/{guild.id}/roles/{role.id}` - Added 2025-08-12.
    public func getGuildRole(guildId: GuildID, roleId: RoleID) async throws -> Role {
        try await http.get(path: "/guilds/\(guildId)/roles/\(roleId)")
    }

    public struct RoleCreate: Codable, Sendable {
        public let name: String
        public let permissions: String?
        public let color: Int?
        public let hoist: Bool?
        public let icon: String?
        public let unicode_emoji: String?
        public let mentionable: Bool?

        public init(
            name: String,
            permissions: String? = nil,
            color: Int? = nil,
            hoist: Bool? = nil,
            icon: String? = nil,
            unicode_emoji: String? = nil,
            mentionable: Bool? = nil
        ) {
            self.name = name
            self.permissions = permissions
            self.color = color
            self.hoist = hoist
            self.icon = icon
            self.unicode_emoji = unicode_emoji
            self.mentionable = mentionable
        }
    }

    public struct RoleUpdate: Codable, Sendable {
        public let name: String?
        public let permissions: String?
        public let color: Int?
        public let hoist: Bool?
        public let icon: String?
        public let unicode_emoji: String?
        public let mentionable: Bool?

        public init(
            name: String? = nil,
            permissions: String? = nil,
            color: Int? = nil,
            hoist: Bool? = nil,
            icon: String? = nil,
            unicode_emoji: String? = nil,
            mentionable: Bool? = nil
        ) {
            self.name = name
            self.permissions = permissions
            self.color = color
            self.hoist = hoist
            self.icon = icon
            self.unicode_emoji = unicode_emoji
            self.mentionable = mentionable
        }
    }

    public func modifyRole(guildId: GuildID, roleId: RoleID, payload: RoleUpdate) async throws -> Role {
        try await http.patch(path: "/guilds/\(guildId)/roles/\(roleId)", body: payload)
    }

    public func createRole(guildId: GuildID, payload: RoleCreate) async throws -> Role {
        try await http.post(path: "/guilds/\(guildId)/roles", body: payload)
    }

    public func deleteRole(guildId: GuildID, roleId: RoleID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/roles/\(roleId)")
    }

    // Sets default member permissions for an application command.
    public func setApplicationCommandDefaultPermissions(applicationId: ApplicationID, commandId: ApplicationCommandID, defaultMemberPermissions: String?) async throws -> ApplicationCommand {
        struct Body: Encodable, Sendable {
            let default_member_permissions: String?
        }
        return try await http.patch(path: "/applications/\(applicationId)/commands/\(commandId)", body: Body(default_member_permissions: defaultMemberPermissions))
    }

    // Ban endpoints.
    public func listGuildBans(guildId: GuildID) async throws -> [GuildBan] {
        try await http.get(path: "/guilds/\(guildId)/bans")
    }

    public func getBan(guildId: GuildID, userId: UserID) async throws -> GuildBan {
        try await http.get(path: "/guilds/\(guildId)/bans/\(userId)")
    }

    public func getBans(guildId: GuildID, limit: Int? = nil, before: UserID? = nil, after: UserID? = nil) async throws -> [GuildBan] {
        var parts: [String] = []
        if let limit { parts.append("limit=\(limit)") }
        if let before { parts.append("before=\(before)") }
        if let after { parts.append("after=\(after)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/guilds/\(guildId)/bans\(q)")
    }

    public func banMember(guildId: GuildID, userId: UserID, deleteMessageDays: Int? = nil, reason: String? = nil) async throws {
        struct Body: Encodable, Sendable {
            let delete_message_days: Int?
        }
        var path = "/guilds/\(guildId)/bans/\(userId)"
        if let reason, let encoded = reason.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "?reason=\(encoded)"
        }
        struct EmptyResponse: Decodable, Sendable {
        }
        let _: EmptyResponse = try await http.put(path: path, body: Body(delete_message_days: deleteMessageDays))
    }

    /// Bulk ban up to 200 users from a guild in a single API call
    /// - Parameters:
    ///   - guildId: The guild to ban users from
    ///   - userIds: Array of user IDs to ban (max 200)
    ///   - deleteMessageSeconds: Number of seconds to delete messages for (0-604800)
    ///   - reason: Audit log reason for the ban
    /// - Returns: Object containing list of successfully banned user IDs
    public func bulkBanMembers(guildId: GuildID, userIds: [UserID], deleteMessageSeconds: Int? = nil, reason: String? = nil) async throws -> BulkBanResponse {
        struct Body: Encodable, Sendable {
            let user_ids: [UserID]
            let delete_message_seconds: Int?
        }
        guard userIds.count <= 200 else {
            throw DiscordError.validation("Cannot ban more than 200 users in a single bulk ban")
        }
        let response: BulkBanResponse = try await http.post(
            path: "/guilds/\(guildId)/bulk-ban",
            body: Body(user_ids: userIds, delete_message_seconds: deleteMessageSeconds),
            reason: reason
        )
        return response
    }

    public func unbanMember(guildId: GuildID, userId: UserID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/bans/\(userId)")
    }

    public func createGuildBan(guildId: GuildID, userId: UserID, deleteMessageSeconds: Int? = nil) async throws {
        struct Empty: Encodable, Sendable {
        }
        var path = "/guilds/\(guildId)/bans/\(userId)"
        if let s = deleteMessageSeconds { path += "?delete_message_seconds=\(s)" }
        let _: ApplicationCommand = try await http.put(path: path, body: Empty())
    }

    public func deleteGuildBan(guildId: GuildID, userId: UserID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/bans/\(userId)")
    }

    
    public func modifyGuildMember(guildId: GuildID, userId: UserID, nick: String? = nil, roles: [RoleID]? = nil, flags: Int? = nil) async throws -> GuildMember {
        struct Body: Encodable, Sendable {
            let nick: String?
            let roles: [RoleID]?
            let flags: Int?
        }
        return try await http.patch(path: "/guilds/\(guildId)/members/\(userId)", body: Body(nick: nick, roles: roles, flags: flags))
    }

    // Sets `communication_disabled_until` for timeout moderation.
    public func setMemberTimeout(guildId: GuildID, userId: UserID, until date: Date) async throws -> GuildMember {
        struct Body: Encodable, Sendable {
            let communication_disabled_until: String
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let body = Body(communication_disabled_until: iso.string(from: date))
        return try await http.patch(path: "/guilds/\(guildId)/members/\(userId)", body: body)
    }

    public func clearMemberTimeout(guildId: GuildID, userId: UserID) async throws -> GuildMember {
        struct Body: Encodable, Sendable {
            let communication_disabled_until: String?
        }
        return try await http.patch(path: "/guilds/\(guildId)/members/\(userId)", body: Body(communication_disabled_until: nil))
    }

    // Updates core guild-level settings.
    public func modifyGuild(guildId: GuildID, name: String? = nil, verificationLevel: Int? = nil, defaultMessageNotifications: Int? = nil, systemChannelId: ChannelID? = nil, explicitContentFilter: Int? = nil) async throws -> Guild {
        struct Body: Encodable, Sendable {
            let name: String?
            let verification_level: Int?
            let default_message_notifications: Int?
            let system_channel_id: ChannelID?
            let explicit_content_filter: Int?
        }
        let body = Body(name: name, verification_level: verificationLevel, default_message_notifications: defaultMessageNotifications, system_channel_id: systemChannelId, explicit_content_filter: explicitContentFilter)
        return try await http.patch(path: "/guilds/\(guildId)", body: body)
    }

    public func deleteGuild(guildId: GuildID) async throws {
        try await http.delete(path: "/guilds/\(guildId)")
    }

    public func getGuildVanityURL(guildId: GuildID) async throws -> VanityURL {
        try await http.get(path: "/guilds/\(guildId)/vanity-url")
    }

    public func getGuildPreview(guildId: GuildID) async throws -> GuildPreview {
        try await http.get(path: "/guilds/\(guildId)/preview")
    }

    // MARK: - REST: Threads
    // Starts a thread from an existing message.
    public func startThreadFromMessage(
        channelId: ChannelID,
        messageId: MessageID,
        name: String,
        autoArchiveDuration: Int? = nil,
        rateLimitPerUser: Int? = nil
    ) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let name: String
            let auto_archive_duration: Int?
            let rate_limit_per_user: Int?
        }
        let body = Body(name: name, auto_archive_duration: autoArchiveDuration, rate_limit_per_user: rateLimitPerUser)
        return try await http.post(path: "/channels/\(channelId)/messages/\(messageId)/threads", body: body)
    }

    // Starts a standalone thread in a channel.
    public func startThreadWithoutMessage(
        channelId: ChannelID,
        name: String,
        autoArchiveDuration: Int? = nil,
        type: Int? = nil,
        invitable: Bool? = nil,
        rateLimitPerUser: Int? = nil
    ) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let name: String
            let auto_archive_duration: Int?
            let type: Int?
            let invitable: Bool?
            let rate_limit_per_user: Int?
        }
        let body = Body(name: name, auto_archive_duration: autoArchiveDuration, type: type, invitable: invitable, rate_limit_per_user: rateLimitPerUser)
        return try await http.post(path: "/channels/\(channelId)/threads", body: body)
    }

    // Joins the current user to a thread.
    public func joinThread(channelId: ChannelID) async throws {
        try await http.put(path: "/channels/\(channelId)/thread-members/@me")
    }

    // Leaves a thread.
    public func leaveThread(channelId: ChannelID) async throws {
        try await http.delete(path: "/channels/\(channelId)/thread-members/@me")
    }

    // Adds a specific member to a thread.
    public func addThreadMember(channelId: ChannelID, userId: UserID) async throws {
        try await http.put(path: "/channels/\(channelId)/thread-members/\(userId)")
    }

    // Removes a specific member from a thread.
    public func removeThreadMember(channelId: ChannelID, userId: UserID) async throws {
        try await http.delete(path: "/channels/\(channelId)/thread-members/\(userId)")
    }

    /// Archive (and optionally lock) a thread channel.
    ///
    /// - Parameters:
    ///   - channelId: The thread channel ID to archive.
    ///   - locked: When `true`, only members with `MANAGE_THREADS` can unarchive the thread.
    ///             Defaults to `false`.
    /// - Returns: The updated ``Channel`` object.
    @discardableResult
    public func archiveThread(channelId: ChannelID, locked: Bool = false) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let archived: Bool = true
            let locked: Bool
        }
        return try await http.patch(path: "/channels/\(channelId)", body: Body(locked: locked))
    }

    // Fetches one thread member.
    public func getThreadMember(channelId: ChannelID, userId: UserID, withMember: Bool = false) async throws -> ThreadMember {
        let q = withMember ? "?with_member=true" : ""
        return try await http.get(path: "/channels/\(channelId)/thread-members/\(userId)\(q)")
    }

    // Lists thread members with optional pagination.
    public func listThreadMembers(channelId: ChannelID, withMember: Bool = false, after: UserID? = nil, limit: Int? = 100) async throws -> [ThreadMember] {
        var parts: [String] = []
        if withMember { parts.append("with_member=true") }
        if let after { parts.append("after=\(after)") }
        if let limit { parts.append("limit=\(limit)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/channels/\(channelId)/thread-members\(q)")
    }

    // Lists active threads in a guild.
    public func listActiveThreads(guildId: GuildID) async throws -> ThreadListResponse {
        try await http.get(path: "/guilds/\(guildId)/threads/active")
    }

    // Lists public archived threads for a channel.
    public func listPublicArchivedThreads(channelId: ChannelID, before: String? = nil, limit: Int? = 50) async throws -> ThreadListResponse {
        var parts: [String] = []
        if let before { parts.append("before=\(before)") }
        if let limit { parts.append("limit=\(limit)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/channels/\(channelId)/threads/archived/public\(q)")
    }

    // Lists private archived threads for a channel.
    public func listPrivateArchivedThreads(channelId: ChannelID, before: String? = nil, limit: Int? = 50) async throws -> ThreadListResponse {
        var parts: [String] = []
        if let before { parts.append("before=\(before)") }
        if let limit { parts.append("limit=\(limit)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/channels/\(channelId)/threads/archived/private\(q)")
    }

    // Lists joined private archived threads for the current user.
    public func listJoinedPrivateArchivedThreads(channelId: ChannelID, before: MessageID? = nil, limit: Int? = 50) async throws -> ThreadListResponse {
        var parts: [String] = []
        if let before { parts.append("before=\(before)") }
        if let limit { parts.append("limit=\(limit)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/channels/\(channelId)/users/@me/threads/archived/private\(q)")
    }

    // MARK: - REST: Interactions
    // Sends a basic interaction callback (type 4: ChannelMessageWithSource).
    public func createInteractionResponse(interactionId: InteractionID, token: String, content: String) async throws {
        struct DataObj: Encodable, Sendable {
            let content: String
        }
        struct Body: Encodable, Sendable {
            let type: Int = 4
            let data: DataObj
        }
        struct Ack: Decodable, Sendable {
        }
        let body = Body(data: DataObj(content: content))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    // Interaction callback overload with optional content + embeds.
    public func createInteractionResponse(interactionId: InteractionID, token: String, content: String? = nil, embeds: [Embed]) async throws {
        struct DataObj: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]
        }
        struct Body: Encodable, Sendable {
            let type: Int = 4
            let data: DataObj
        }
        struct Ack: Decodable, Sendable {
        }
        let body = Body(data: DataObj(content: content, embeds: embeds))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    public enum InteractionResponseType: Int, Codable, Sendable {
        case pong = 1
        case channelMessageWithSource = 4
        case deferredChannelMessageWithSource = 5
        case deferredUpdateMessage = 6
        case updateMessage = 7
        case autocompleteResult = 8
        case modal = 9
        /// Launch a linked Activity. Added 2024-08-26.
        case launchActivity = 12
    }

    public func createInteractionResponse(interactionId: InteractionID, token: String, type: InteractionResponseType, content: String? = nil, embeds: [Embed]? = nil) async throws {
        struct DataObj: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
        }
        struct Body: Encodable, Sendable {
            let type: Int
            let data: DataObj?
        }
        struct Ack: Decodable, Sendable {
        }
        let data = (content == nil && embeds == nil) ? nil : DataObj(content: content, embeds: embeds)
        let body = Body(type: type.rawValue, data: data)
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    // Type 8 autocomplete response payload.
    public struct AutocompleteChoice: Codable, Sendable {
        public let name: String
        public let value: String
        public init(name: String, value: String) { self.name = name; self.value = value }
    }

    public func createAutocompleteResponse(interactionId: InteractionID, token: String, choices: [AutocompleteChoice]) async throws {
        struct DataObj: Encodable, Sendable {
            let choices: [AutocompleteChoice]
        }
        struct Body: Encodable, Sendable {
            let type: Int
            let data: DataObj
        }
        struct Ack: Decodable, Sendable {
        }
        let body = Body(type: InteractionResponseType.autocompleteResult.rawValue, data: DataObj(choices: choices))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    // Type 9 modal callback endpoint.
    public func createInteractionModal(
        interactionId: InteractionID,
        token: String,
        title: String,
        customId: String,
        components: [MessageComponent]
    ) async throws {
        struct DataObj: Encodable, Sendable {
            let custom_id: String
            let title: String
            let components: [MessageComponent]
        }
        struct Body: Encodable, Sendable {
            let type: Int
            let data: DataObj
        }
        struct Ack: Decodable, Sendable {
        }
        let body = Body(type: InteractionResponseType.modal.rawValue, data: DataObj(custom_id: customId, title: title, components: components))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    public func shutdown() async {
        await gateway.close()
        eventContinuation?.finish()
    }

    // MARK: - Slash command REST endpoints
    public struct ApplicationCommand: Codable, Sendable {
        public let id: ApplicationCommandID
        public let application_id: ApplicationID
        public let name: String
        public let description: String
    }

    public struct ApplicationCommandOption: Codable, Sendable {
        public enum ApplicationCommandOptionType: Int, Codable, Sendable {
            case subCommand = 1
            case subCommandGroup = 2
            case string = 3
            case integer = 4
            case boolean = 5
            case user = 6
            case channel = 7
            case role = 8
            case mentionable = 9
            case number = 10
            case attachment = 11
        }
        public let type: ApplicationCommandOptionType
        public let name: String
        public let name_localizations: [String: String]?
        public let description: String
        public let description_localizations: [String: String]?
        public let required: Bool?
        public struct Choice: Codable, Sendable {
            public let name: String
            public let name_localizations: [String: String]?
            public let value: JSONValue
        }
        public let choices: [Choice]?
        public init(type: ApplicationCommandOptionType, name: String, description: String, required: Bool? = nil, choices: [Choice]? = nil, nameLocalizations: [String: String]? = nil, descriptionLocalizations: [String: String]? = nil) {
            self.type = type
            self.name = name
            self.name_localizations = nameLocalizations
            self.description = description
            self.description_localizations = descriptionLocalizations
            self.required = required
            self.choices = choices
        }
    }

    public struct ApplicationCommandCreate: Encodable, Sendable {
        public let name: String
        public let name_localizations: [String: String]?
        public let description: String
        public let description_localizations: [String: String]?
        public let options: [ApplicationCommandOption]?
        public let default_member_permissions: String?
        public let dm_permission: Bool?
        public init(name: String, description: String, options: [ApplicationCommandOption]? = nil, default_member_permissions: String? = nil, dm_permission: Bool? = nil, nameLocalizations: [String: String]? = nil, descriptionLocalizations: [String: String]? = nil) {
            self.name = name
            self.name_localizations = nameLocalizations
            self.description = description
            self.description_localizations = descriptionLocalizations
            self.options = options
            self.default_member_permissions = default_member_permissions
            self.dm_permission = dm_permission
        }
    }

    public func createGlobalCommand(name: String, description: String) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable, Sendable {
            let name: String
            let description: String
        }
        return try await http.post(path: "/applications/\(appId)/commands", body: Body(name: name, description: description))
    }

    public func createGuildCommand(guildId: GuildID, name: String, description: String) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable, Sendable {
            let name: String
            let description: String
        }
        return try await http.post(path: "/applications/\(appId)/guilds/\(guildId)/commands", body: Body(name: name, description: description))
    }

    public func createGlobalCommand(name: String, description: String, options: [ApplicationCommandOption]) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable, Sendable {
            let name: String
            let description: String
            let options: [ApplicationCommandOption]
        }
        return try await http.post(path: "/applications/\(appId)/commands", body: Body(name: name, description: description, options: options))
    }

    public func createGuildCommand(guildId: GuildID, name: String, description: String, options: [ApplicationCommandOption]) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable, Sendable {
            let name: String
            let description: String
            let options: [ApplicationCommandOption]
        }
        return try await http.post(path: "/applications/\(appId)/guilds/\(guildId)/commands", body: Body(name: name, description: description, options: options))
    }

    public func createGlobalCommand(_ command: ApplicationCommandCreate) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        return try await http.post(path: "/applications/\(appId)/commands", body: command)
    }

    public func createGuildCommand(guildId: GuildID, _ command: ApplicationCommandCreate) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        return try await http.post(path: "/applications/\(appId)/guilds/\(guildId)/commands", body: command)
    }

    public func listGlobalCommands() async throws -> [ApplicationCommand] {
        let appId = try await getCurrentUser().id
        return try await http.get(path: "/applications/\(appId)/commands")
    }

    public func listGuildCommands(guildId: GuildID) async throws -> [ApplicationCommand] {
        let appId = try await getCurrentUser().id
        return try await http.get(path: "/applications/\(appId)/guilds/\(guildId)/commands")
    }

    public func deleteGlobalCommand(commandId: ApplicationCommandID) async throws {
        let appId = try await getCurrentUser().id
        try await http.delete(path: "/applications/\(appId)/commands/\(commandId)")
    }

    public func deleteGuildCommand(guildId: GuildID, commandId: ApplicationCommandID) async throws {
        let appId = try await getCurrentUser().id
        try await http.delete(path: "/applications/\(appId)/guilds/\(guildId)/commands/\(commandId)")
    }

    public func bulkOverwriteGlobalCommands(_ commands: [ApplicationCommandCreate]) async throws -> [ApplicationCommand] {
        let appId = try await getCurrentUser().id
        return try await http.put(path: "/applications/\(appId)/commands", body: commands)
    }

    public func bulkOverwriteGuildCommands(guildId: GuildID, _ commands: [ApplicationCommandCreate]) async throws -> [ApplicationCommand] {
        let appId = try await getCurrentUser().id
        return try await http.put(path: "/applications/\(appId)/guilds/\(guildId)/commands", body: commands)
    }

    /// Sync the desired application commands with Discord.
    ///
    /// Fetches the currently registered commands, compares name sets, and only
    /// calls `bulkOverwrite` when there is a difference (new commands, deleted
    /// commands, or a name change). This avoids unnecessary API writes during
    /// repeated bot restarts.
    ///
    /// - Parameters:
    ///   - desired: The full list of commands you want registered.
    ///   - guildId: Target guild for guild-scoped commands, or `nil` for global commands.
    /// - Returns: The commands now registered with Discord.
    @discardableResult
    public func syncCommands(
        _ desired: [ApplicationCommandCreate],
        guildId: GuildID? = nil
    ) async throws -> [ApplicationCommand] {
        let existing: [ApplicationCommand]
        if let guildId {
            existing = try await listGuildCommands(guildId: guildId)
        } else {
            existing = try await listGlobalCommands()
        }

        let existingNames = Set(existing.map(\.name).sorted())
        let desiredNames  = Set(desired.map(\.name).sorted())

        guard existingNames != desiredNames else {
            // Nothing changed at the command-name level, so keep the existing registration.
            return existing
        }

        if let guildId {
            return try await bulkOverwriteGuildCommands(guildId: guildId, desired)
        } else {
            return try await bulkOverwriteGlobalCommands(desired)
        }
    }

    // MARK: - REST: Webhooks
    public func createWebhook(channelId: ChannelID, name: String) async throws -> Webhook {
        struct Body: Encodable, Sendable {
            let name: String
        }
        return try await http.post(path: "/channels/\(channelId)/webhooks", body: Body(name: name))
    }

    public func createWebhook(channelId: ChannelID, name: String, avatar: String?) async throws -> Webhook {
        struct Body: Encodable, Sendable {
            let name: String
            let avatar: String?
        }
        return try await http.post(path: "/channels/\(channelId)/webhooks", body: Body(name: name, avatar: avatar))
    }

    public func getChannelWebhooks(channelId: ChannelID) async throws -> [Webhook] {
        try await http.get(path: "/channels/\(channelId)/webhooks")
    }

    public func getGuildWebhooks(guildId: GuildID) async throws -> [Webhook] {
        try await http.get(path: "/guilds/\(guildId)/webhooks")
    }

    public func getWebhook(webhookId: WebhookID) async throws -> Webhook {
        try await http.get(path: "/webhooks/\(webhookId)")
    }

    public func modifyWebhook(webhookId: WebhookID, name: String? = nil, avatar: String? = nil, channelId: ChannelID? = nil) async throws -> Webhook {
        struct Body: Encodable, Sendable {
            let name: String?
            let avatar: String?
            let channel_id: ChannelID?
        }
        return try await http.patch(path: "/webhooks/\(webhookId)", body: Body(name: name, avatar: avatar, channel_id: channelId))
    }

    public func deleteWebhook(webhookId: WebhookID) async throws {
        try await http.delete(path: "/webhooks/\(webhookId)")
    }

    public func executeWebhook(webhookId: WebhookID, token: String, content: String) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String
        }
        return try await http.post(path: "/webhooks/\(webhookId)/\(token)", body: Body(content: content))
    }

    public func executeWebhook(webhookId: WebhookID, token: String, content: String? = nil, username: String? = nil, avatarUrl: String? = nil, embeds: [Embed]? = nil, wait: Bool = false) async throws -> Message? {
        struct Body: Encodable, Sendable {
            let content: String?
            let username: String?
            let avatar_url: String?
            let embeds: [Embed]?
        }
        let body = Body(content: content, username: username, avatar_url: avatarUrl, embeds: embeds)
        let waitParam = wait ? "?wait=true" : ""
        if wait {
            return try await http.post(path: "/webhooks/\(webhookId)/\(token)\(waitParam)", body: body)
        } else {
            struct EmptyResponse: Decodable, Sendable {
            }
            let _: EmptyResponse = try await http.post(path: "/webhooks/\(webhookId)/\(token)", body: body)
            return nil
        }
    }

    /// Create an invite for a channel.
    /// `role_ids` assigns roles when accepted. `targetUsersFile` is a CSV `FileAttachment`
    /// (`user_id` column) restricting who can accept. Both added 2026-01-13.
    public func createChannelInvite(
        channelId: ChannelID,
        maxAge: Int? = nil,
        maxUses: Int? = nil,
        temporary: Bool? = nil,
        unique: Bool? = nil,
        roleIds: [RoleID]? = nil,
        targetUsersFile: FileAttachment? = nil
    ) async throws -> Invite {
        struct Body: Encodable, Sendable {
            let max_age: Int?
            let max_uses: Int?
            let temporary: Bool?
            let unique: Bool?
            let role_ids: [RoleID]?
        }
        let body = Body(max_age: maxAge, max_uses: maxUses, temporary: temporary, unique: unique, role_ids: roleIds)
        if let file = targetUsersFile {
            return try await http.postMultipart(path: "/channels/\(channelId)/invites", jsonBody: body, files: [file])
        }
        return try await http.post(path: "/channels/\(channelId)/invites", body: body)
    }

    public func listChannelInvites(channelId: ChannelID) async throws -> [Invite] {
        try await http.get(path: "/channels/\(channelId)/invites")
    }

    public func listGuildInvites(guildId: GuildID) async throws -> [Invite] {
        try await http.get(path: "/guilds/\(guildId)/invites")
    }

    public func getInvite(code: String, withCounts: Bool = false, withExpiration: Bool = false) async throws -> Invite {
        let path = "/invites/\(code)?with_counts=\(withCounts)&with_expiration=\(withExpiration)"
        return try await http.get(path: path)
    }

    public func deleteInvite(code: String) async throws {
        try await http.delete(path: "/invites/\(code)")
    }

    // MARK: - REST: Community Invite Target Users (Added 2026-01-13)

    /// Response from the Get Target Users Job Status endpoint.
    public struct InviteTargetUsersJobStatus: Codable, Sendable {
        public let job_id: String
        public let status: String  // e.g. "pending", "complete", "failed"
        public let invite_code: String
    }

    /// Get the raw CSV of user IDs allowed to accept a restricted invite.
    /// The response is CSV bytes with a `user_id` header column (not JSON).
    /// Decode with `String(data: result, encoding: .utf8)` to get the CSV text.
    /// `GET /invites/{code}/users` — Added 2026-01-13, updated 2026-02-05 (header always `user_id`).
    public func getInviteTargetUsers(code: String) async throws -> Data {
        try await http.getRaw(path: "/invites/\(code)/users")
    }

    /// Replace the list of users allowed to accept a restricted invite by uploading a CSV file.
    /// The CSV must have a `user_id` column. Returns the async job status.
    /// `PATCH /invites/{code}/users` — Added 2026-01-13.
    public func updateInviteTargetUsers(code: String, file: FileAttachment) async throws -> InviteTargetUsersJobStatus {
        struct Empty: Encodable, Sendable {
        }
        return try await http.patchMultipart(path: "/invites/\(code)/users", jsonBody: Empty(), files: [file])
    }

    /// Check the status of the background job that processes a target-users CSV upload.
    /// `GET /invites/{code}/users/jobs/{job_id}` — Added 2026-01-13.
    public func getInviteTargetUsersJobStatus(code: String, jobId: String) async throws -> InviteTargetUsersJobStatus {
        try await http.get(path: "/invites/\(code)/users/jobs/\(jobId)")
    }

    public func getTemplate(code: String) async throws -> Template {
        try await http.get(path: "/guilds/templates/\(code)")
    }

    public func listGuildTemplates(guildId: GuildID) async throws -> [Template] {
        try await http.get(path: "/guilds/\(guildId)/templates")
    }

    public func createGuildTemplate(guildId: GuildID, name: String, description: String? = nil) async throws -> Template {
        struct Body: Encodable, Sendable {
            let name: String
            let description: String?
        }
        return try await http.post(path: "/guilds/\(guildId)/templates", body: Body(name: name, description: description))
    }

    public func modifyGuildTemplate(guildId: GuildID, code: String, name: String? = nil, description: String? = nil) async throws -> Template {
        struct Body: Encodable, Sendable {
            let name: String?
            let description: String?
        }
        return try await http.patch(path: "/guilds/\(guildId)/templates/\(code)", body: Body(name: name, description: description))
    }

    public func syncGuildTemplate(guildId: GuildID, code: String) async throws -> Template {
        struct Empty: Encodable, Sendable {
        }
        return try await http.put(path: "/guilds/\(guildId)/templates/\(code)", body: Empty())
    }

    public func deleteGuildTemplate(guildId: GuildID, code: String) async throws {
        try await http.delete(path: "/guilds/\(guildId)/templates/\(code)")
    }

    // MARK: - REST: Stickers
    public func getSticker(id: StickerID) async throws -> Sticker {
        try await http.get(path: "/stickers/\(id)")
    }

    public func listStickerPacks() async throws -> [StickerPack] {
        struct Packs: Decodable, Sendable {
            let sticker_packs: [StickerPack]
        }
        let resp: Packs = try await http.get(path: "/sticker-packs")
        return resp.sticker_packs
    }

    public func listGuildStickers(guildId: GuildID) async throws -> [Sticker] {
        try await http.get(path: "/guilds/\(guildId)/stickers")
    }

    public func getGuildSticker(guildId: GuildID, stickerId: StickerID) async throws -> Sticker {
        try await http.get(path: "/guilds/\(guildId)/stickers/\(stickerId)")
    }

    public func createGuildSticker(guildId: GuildID, name: String, description: String? = nil, tags: String, file: FileAttachment, reason: String? = nil) async throws -> Sticker {
        return try await http.postStickerMultipart(path: "/guilds/\(guildId)/stickers", name: name, description: description, tags: tags, file: file, reason: reason)
    }

    public func modifyGuildSticker(guildId: GuildID, stickerId: StickerID, name: String? = nil, description: String? = nil, tags: String? = nil) async throws -> Sticker {
        struct Payload: Encodable, Sendable {
            let name: String?
            let description: String?
            let tags: String?
        }
        return try await http.patch(path: "/guilds/\(guildId)/stickers/\(stickerId)", body: Payload(name: name, description: description, tags: tags))
    }

    public func deleteGuildSticker(guildId: GuildID, stickerId: StickerID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/stickers/\(stickerId)")
    }

    // MARK: - REST: Forum endpoints
    public func createForumThread(
        channelId: ChannelID,
        name: String,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        appliedTagIds: [ForumTagID]? = nil,
        autoArchiveDuration: Int? = nil,
        rateLimitPerUser: Int? = nil
    ) async throws -> Channel {
        struct Msg: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
        }
        struct Body: Encodable, Sendable {
            let name: String
            let auto_archive_duration: Int?
            let rate_limit_per_user: Int?
            let message: Msg?
            let applied_tags: [ForumTagID]?
        }
        let message = (content == nil && embeds == nil && components == nil) ? nil : Msg(content: content, embeds: embeds, components: components)
        let body = Body(
            name: name,
            auto_archive_duration: autoArchiveDuration,
            rate_limit_per_user: rateLimitPerUser,
            message: message,
            applied_tags: appliedTagIds
        )
        return try await http.post(path: "/channels/\(channelId)/threads", body: body)
    }

    // MARK: - REST: Audit Logs
    public func getGuildAuditLog(
        guildId: GuildID,
        userId: UserID? = nil,
        actionType: Int? = nil,
        before: AuditLogEntryID? = nil,
        limit: Int? = nil
    ) async throws -> AuditLog {
        let path = "/guilds/\(guildId)/audit-logs"
        var qs: [String] = []
        if let userId { qs.append("user_id=\(userId)") }
        if let actionType { qs.append("action_type=\(actionType)") }
        if let before { qs.append("before=\(before)") }
        if let limit { qs.append("limit=\(limit)") }
        let q = qs.isEmpty ? "" : "?" + qs.joined(separator: "&")
        return try await http.get(path: path + q)
    }

    // MARK: - REST: AutoModeration
    public func listAutoModerationRules(guildId: GuildID) async throws -> [AutoModerationRule] {
        try await http.get(path: "/guilds/\(guildId)/auto-moderation/rules")
    }

    public func getAutoModerationRule(guildId: GuildID, ruleId: AutoModerationRuleID) async throws -> AutoModerationRule {
        try await http.get(path: "/guilds/\(guildId)/auto-moderation/rules/\(ruleId)")
    }

    public func createAutoModerationRule(
        guildId: GuildID,
        name: String,
        eventType: Int,
        triggerType: Int,
        triggerMetadata: AutoModerationRule.TriggerMetadata? = nil,
        actions: [AutoModerationRule.Action],
        enabled: Bool = true,
        exemptRoles: [RoleID]? = nil,
        exemptChannels: [ChannelID]? = nil
    ) async throws -> AutoModerationRule {
        struct Body: Encodable, Sendable {
            let name: String
            let event_type: Int
            let trigger_type: Int
            let trigger_metadata: AutoModerationRule.TriggerMetadata?
            let actions: [AutoModerationRule.Action]
            let enabled: Bool?
            let exempt_roles: [RoleID]?
            let exempt_channels: [ChannelID]?
        }
        let body = Body(
            name: name,
            event_type: eventType,
            trigger_type: triggerType,
            trigger_metadata: triggerMetadata,
            actions: actions,
            enabled: enabled,
            exempt_roles: exemptRoles,
            exempt_channels: exemptChannels
        )
        return try await http.post(path: "/guilds/\(guildId)/auto-moderation/rules", body: body)
    }

    public func modifyAutoModerationRule(
        guildId: GuildID,
        ruleId: AutoModerationRuleID,
        name: String? = nil,
        eventType: Int? = nil,
        triggerMetadata: AutoModerationRule.TriggerMetadata? = nil,
        actions: [AutoModerationRule.Action]? = nil,
        enabled: Bool? = nil,
        exemptRoles: [RoleID]? = nil,
        exemptChannels: [ChannelID]? = nil
    ) async throws -> AutoModerationRule {
        struct Body: Encodable, Sendable {
            let name: String?
            let event_type: Int?
            let trigger_metadata: AutoModerationRule.TriggerMetadata?
            let actions: [AutoModerationRule.Action]?
            let enabled: Bool?
            let exempt_roles: [RoleID]?
            let exempt_channels: [ChannelID]?
        }
        let body = Body(
            name: name,
            event_type: eventType,
            trigger_metadata: triggerMetadata,
            actions: actions,
            enabled: enabled,
            exempt_roles: exemptRoles,
            exempt_channels: exemptChannels
        )
        return try await http.patch(path: "/guilds/\(guildId)/auto-moderation/rules/\(ruleId)", body: body)
    }

    public func deleteAutoModerationRule(guildId: GuildID, ruleId: AutoModerationRuleID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/auto-moderation/rules/\(ruleId)")
    }

    // MARK: - REST: Scheduled Events
    public func listGuildScheduledEvents(guildId: GuildID, withCounts: Bool = false) async throws -> [GuildScheduledEvent] {
        let suffix = withCounts ? "?with_user_count=true" : ""
        return try await http.get(path: "/guilds/\(guildId)/scheduled-events\(suffix)")
    }

    public func createGuildScheduledEvent(
        guildId: GuildID,
        channelId: ChannelID?,
        entityType: GuildScheduledEvent.EntityType,
        name: String,
        scheduledStartTimeISO8601: String,
        scheduledEndTimeISO8601: String? = nil,
        privacyLevel: Int = 2,
        description: String? = nil,
        entityMetadata: GuildScheduledEvent.EntityMetadata? = nil
    ) async throws -> GuildScheduledEvent {
        struct Body: Encodable, Sendable {
            let channel_id: ChannelID?
            let entity_type: Int
            let name: String
            let scheduled_start_time: String
            let scheduled_end_time: String?
            let privacy_level: Int
            let description: String?
            let entity_metadata: GuildScheduledEvent.EntityMetadata?
        }
        let body = Body(
            channel_id: channelId,
            entity_type: entityType.rawValue,
            name: name,
            scheduled_start_time: scheduledStartTimeISO8601,
            scheduled_end_time: scheduledEndTimeISO8601,
            privacy_level: privacyLevel,
            description: description,
            entity_metadata: entityMetadata
        )
        return try await http.post(path: "/guilds/\(guildId)/scheduled-events", body: body)
    }

    public func getGuildScheduledEvent(guildId: GuildID, eventId: GuildScheduledEventID, withCounts: Bool = false) async throws -> GuildScheduledEvent {
        let suffix = withCounts ? "?with_user_count=true" : ""
        return try await http.get(path: "/guilds/\(guildId)/scheduled-events/\(eventId)\(suffix)")
    }

    public func modifyGuildScheduledEvent(
        guildId: GuildID,
        eventId: GuildScheduledEventID,
        channelId: ChannelID? = nil,
        entityType: GuildScheduledEvent.EntityType? = nil,
        name: String? = nil,
        scheduledStartTimeISO8601: String? = nil,
        scheduledEndTimeISO8601: String? = nil,
        privacyLevel: Int? = nil,
        description: String? = nil,
        status: GuildScheduledEvent.Status? = nil,
        entityMetadata: GuildScheduledEvent.EntityMetadata? = nil
    ) async throws -> GuildScheduledEvent {
        struct Body: Encodable, Sendable {
            let channel_id: ChannelID?
            let entity_type: Int?
            let name: String?
            let scheduled_start_time: String?
            let scheduled_end_time: String?
            let privacy_level: Int?
            let description: String?
            let status: Int?
            let entity_metadata: GuildScheduledEvent.EntityMetadata?
        }
        let body = Body(
            channel_id: channelId,
            entity_type: entityType?.rawValue,
            name: name,
            scheduled_start_time: scheduledStartTimeISO8601,
            scheduled_end_time: scheduledEndTimeISO8601,
            privacy_level: privacyLevel,
            description: description,
            status: status?.rawValue,
            entity_metadata: entityMetadata
        )
        return try await http.patch(path: "/guilds/\(guildId)/scheduled-events/\(eventId)", body: body)
    }

    public func deleteGuildScheduledEvent(guildId: GuildID, eventId: GuildScheduledEventID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/scheduled-events/\(eventId)")
    }

    public func listGuildScheduledEventUsers(
        guildId: GuildID,
        eventId: GuildScheduledEventID,
        limit: Int? = nil,
        withMember: Bool = false,
        before: UserID? = nil,
        after: UserID? = nil
    ) async throws -> [GuildScheduledEventUser] {
        let path = "/guilds/\(guildId)/scheduled-events/\(eventId)/users"
        var qs: [String] = []
        if let limit { qs.append("limit=\(limit)") }
        if withMember { qs.append("with_member=true") }
        if let before { qs.append("before=\(before)") }
        if let after { qs.append("after=\(after)") }
        let q = qs.isEmpty ? "" : "?" + qs.joined(separator: "&")
        return try await http.get(path: path + q)
    }

    // MARK: - REST: Stage Instances
    public func createStageInstance(channelId: ChannelID, topic: String, privacyLevel: Int = 2, guildScheduledEventId: GuildScheduledEventID? = nil) async throws -> StageInstance {
        struct Body: Encodable, Sendable {
            let channel_id: ChannelID
            let topic: String
            let privacy_level: Int
            let guild_scheduled_event_id: GuildScheduledEventID?
        }
        let body = Body(channel_id: channelId, topic: topic, privacy_level: privacyLevel, guild_scheduled_event_id: guildScheduledEventId)
        return try await http.post(path: "/stage-instances", body: body)
    }

    public func getStageInstance(channelId: ChannelID) async throws -> StageInstance {
        try await http.get(path: "/stage-instances/\(channelId)")
    }

    public func modifyStageInstance(channelId: ChannelID, topic: String? = nil, privacyLevel: Int? = nil) async throws -> StageInstance {
        struct Body: Encodable, Sendable {
            let topic: String?
            let privacy_level: Int?
        }
        return try await http.patch(path: "/stage-instances/\(channelId)", body: Body(topic: topic, privacy_level: privacyLevel))
    }

    public func deleteStageInstance(channelId: ChannelID) async throws {
        try await http.delete(path: "/stage-instances/\(channelId)")
    }

    // MARK: - REST: Role Connections
    public func updateApplicationRoleConnectionMetadata(applicationId: ApplicationID, metadata: [ApplicationRoleConnectionMetadata]) async throws -> [ApplicationRoleConnectionMetadata] {
        return try await http.put(path: "/applications/\(applicationId)/role-connections/metadata", body: metadata)
    }

    public func getApplicationRoleConnectionMetadata(applicationId: ApplicationID) async throws -> [ApplicationRoleConnectionMetadata] {
        return try await http.get(path: "/applications/\(applicationId)/role-connections/metadata")
    }

    public func getUserApplicationRoleConnection(applicationId: ApplicationID) async throws -> ApplicationRoleConnection {
        return try await http.get(path: "/users/@me/applications/\(applicationId)/role-connection")
    }

    public func updateUserApplicationRoleConnection(applicationId: ApplicationID, platformName: String? = nil, platformUsername: String? = nil, metadata: [String: String] = [:]) async throws -> ApplicationRoleConnection {
        struct Body: Encodable, Sendable {
            let platformName: String?
            let platformUsername: String?
            let metadata: [String: String]
            
            enum CodingKeys: String, CodingKey {
                case platformName = "platform_name"
                case platformUsername = "platform_username"
                case metadata
            }
        }
        
        let body = Body(platformName: platformName, platformUsername: platformUsername, metadata: metadata)
        return try await http.put(path: "/users/@me/applications/\(applicationId)/role-connection", body: body)
    }

    // MARK: - REST: Soundboard
    public func listSoundboardSounds(guildId: GuildID) async throws -> [SoundboardSound] {
        try await http.get(path: "/guilds/\(guildId)/soundboard-sounds")
    }

    public func createSoundboardSound(guildId: GuildID, name: String, emojiId: EmojiID? = nil, emojiName: String? = nil, volume: Double? = nil, sound: FileAttachment) async throws -> SoundboardSound {
        struct Payload: Encodable, Sendable {
            let name: String
            let emoji_id: EmojiID?
            let emoji_name: String?
            let volume: Double?
        }
        let payload = Payload(name: name, emoji_id: emojiId, emoji_name: emojiName, volume: volume)
        return try await http.postMultipart(path: "/guilds/\(guildId)/soundboard-sounds", jsonBody: payload, files: [sound])
    }

    public func modifySoundboardSound(guildId: GuildID, soundId: SoundboardSoundID, name: String? = nil, emojiId: EmojiID? = nil, emojiName: String? = nil, volume: Double? = nil) async throws -> SoundboardSound {
        struct Payload: Encodable, Sendable {
            let name: String?
            let emoji_id: EmojiID?
            let emoji_name: String?
            let volume: Double?
        }
        return try await http.patch(path: "/guilds/\(guildId)/soundboard-sounds/\(soundId)", body: Payload(name: name, emoji_id: emojiId, emoji_name: emojiName, volume: volume))
    }

    public func deleteSoundboardSound(guildId: GuildID, soundId: SoundboardSoundID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/soundboard-sounds/\(soundId)")
    }

    /// Play a soundboard sound in a voice channel
    /// - Parameters:
    ///   - channelId: The voice channel to play the sound in
    ///   - soundId: The soundboard sound to play
    ///   - guildId: The guild containing the sound
    /// - Returns: The soundboard sound object
    public func playSoundboardSound(channelId: ChannelID, soundId: SoundboardSoundID, guildId: GuildID) async throws -> SoundboardSound {
        struct Body: Encodable, Sendable {
            let sound_id: SoundboardSoundID
            let guild_id: GuildID
        }
        return try await http.post(path: "/channels/\(channelId)/send-soundboard-sound", body: Body(sound_id: soundId, guild_id: guildId))
    }

    // MARK: - REST: Entitlements & SKUs (Monetization)

    public func listEntitlements(
        applicationId: ApplicationID,
        userId: UserID? = nil,
        guildId: GuildID? = nil,
        before: EntitlementID? = nil,
        after: EntitlementID? = nil,
        limit: Int? = nil,
        skuIds: [SKUID]? = nil
    ) async throws -> [Entitlement] {
        var qs: [String] = []
        if let userId { qs.append("user_id=\(userId)") }
        if let guildId { qs.append("guild_id=\(guildId)") }
        if let before { qs.append("before=\(before)") }
        if let after { qs.append("after=\(after)") }
        if let limit { qs.append("limit=\(limit)") }
        if let skuIds, !skuIds.isEmpty {
            let joined = skuIds.map { "\($0)" }.joined(separator: ",")
            qs.append("sku_ids=\(joined)")
        }
        let path = "/applications/\(applicationId)/entitlements" + (qs.isEmpty ? "" : "?" + qs.joined(separator: "&"))
        return try await http.get(path: path)
    }

    /// Create a test entitlement for validation in non-production contexts.
    public func createTestEntitlement(applicationId: ApplicationID, skuId: SKUID, ownerId: String, ownerType: Int = 1) async throws -> Entitlement {
        struct Body: Encodable, Sendable {
            let sku_id: SKUID
            let owner_id: String
            let owner_type: Int
        }
        return try await http.post(path: "/applications/\(applicationId)/entitlements", body: Body(sku_id: skuId, owner_id: ownerId, owner_type: ownerType))
    }

    /// Consume an entitlement (used for one-time items).
    public func consumeEntitlement(applicationId: ApplicationID, entitlementId: EntitlementID) async throws {
        struct Empty: Codable, Sendable {
        }
        let _: Empty = try await http.post(path: "/applications/\(applicationId)/entitlements/\(entitlementId)/consume", body: Empty())
    }

    public func listSKUs(applicationId: ApplicationID) async throws -> [SKU] {
        try await http.get(path: "/applications/\(applicationId)/skus")
    }

    // MARK: - REST: Onboarding / Server Guide
    public func getGuildOnboarding(guildId: GuildID) async throws -> Onboarding {
        try await http.get(path: "/guilds/\(guildId)/onboarding")
    }

    public func updateGuildOnboarding(
        guildId: GuildID,
        prompts: [OnboardingPrompt],
        defaultChannelIds: [ChannelID],
        enabled: Bool,
        mode: Int,
        defaultRecommendationChannelIds: [ChannelID]? = nil
    ) async throws -> Onboarding {
        struct Body: Encodable, Sendable {
            let prompts: [OnboardingPrompt]
            let default_channel_ids: [ChannelID]
            let enabled: Bool
            let mode: Int
            let default_recommendation_channel_ids: [ChannelID]?
        }
        let body = Body(
            prompts: prompts,
            default_channel_ids: defaultChannelIds,
            enabled: enabled,
            mode: mode,
            default_recommendation_channel_ids: defaultRecommendationChannelIds
        )
        return try await http.put(path: "/guilds/\(guildId)/onboarding", body: body)
    }

    // MARK: - REST: App Installs & Subscriptions (Monetization)

    /// List installs of this application (server-side view).
    public func listApplicationInstalls(applicationId: ApplicationID, after: AppInstallationID? = nil, limit: Int? = nil) async throws -> [AppInstallation] {
        var qs: [String] = []
        if let after { qs.append("after=\(after)") }
        if let limit { qs.append("limit=\(limit)") }
        let path = "/applications/\(applicationId)/installations" + (qs.isEmpty ? "" : "?" + qs.joined(separator: "&"))
        return try await http.get(path: path)
    }

    /// List installs for the current user of this application (user token scope).
    public func listCurrentUserInstalls(applicationId: ApplicationID, withAppToken: Bool = false) async throws -> [AppInstallation] {
        // Bot tokens may receive 403 here; this endpoint remains for API parity.
        try await http.get(path: "/users/@me/applications/\(applicationId)/installations")
    }

    /// List subscriptions for this application.
    public func listApplicationSubscriptions(applicationId: ApplicationID, status: String? = nil, limit: Int? = nil, before: AppSubscriptionID? = nil, after: AppSubscriptionID? = nil) async throws -> [AppSubscription] {
        var qs: [String] = []
        if let status { qs.append("status=\(status)") }
        if let limit { qs.append("limit=\(limit)") }
        if let before { qs.append("before=\(before)") }
        if let after { qs.append("after=\(after)") }
        let path = "/applications/\(applicationId)/subscriptions" + (qs.isEmpty ? "" : "?" + qs.joined(separator: "&"))
        return try await http.get(path: path)
    }

    /// Get a single subscription.
    public func getApplicationSubscription(applicationId: ApplicationID, subscriptionId: AppSubscriptionID) async throws -> AppSubscription {
        try await http.get(path: "/applications/\(applicationId)/subscriptions/\(subscriptionId)")
    }
}
