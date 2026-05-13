import Foundation

/// Represents the HELLO gateway event.
///
/// Sent by the gateway when a connection is first established.
/// Contains the heartbeat interval in milliseconds.
public struct GatewayHello: Codable, Sendable {
    /// The heartbeat interval in milliseconds.
    ///
    /// The client must send a heartbeat every `heartbeat_interval` milliseconds.
    public let heartbeat_interval: Int
}

/// Represents a THREAD_MEMBERS_UPDATE gateway event.
///
/// Sent when members are added to or removed from a thread.
public struct ThreadMembersUpdate: Codable, Hashable, Sendable {
    /// The ID of the thread.
    public let id: ChannelID
    
    /// The ID of the guild.
    public let guild_id: GuildID
    
    /// The approximate number of members in the thread.
    public let member_count: Int
    
    /// Members added to the thread.
    public let added_members: [ThreadMember]?
    
    /// IDs of members removed from the thread.
    public let removed_member_ids: [UserID]?
}

/// Represents a THREAD_LIST_SYNC gateway event.
///
/// Sent when the thread list for a guild is synced.
public struct ThreadListSync: Codable, Hashable, Sendable {
    /// The ID of the guild.
    public let guild_id: GuildID
    
    /// The IDs of the channels that are threads.
    public let channel_ids: [ChannelID]
    
    /// The thread objects.
    public let threads: [Channel]
    
    /// The thread member objects.
    public let members: [ThreadMember]
}

/// Gateway opcodes.
///
/// Opcodes are used to indicate the purpose of a gateway payload.
///
/// ## Opcode Values
/// - `0`: DISPATCH - An event was dispatched.
/// - `1`: HEARTBEAT - A heartbeat keep-alive.
/// - `2`: IDENTIFY - Client identification.
/// - `3`: PRESENCE_UPDATE - Client presence update.
/// - `6`: RESUME - Resume a previous session.
/// - `7`: RECONNECT - Request to reconnect.
/// - `8`: REQUEST_GUILD_MEMBERS - Request guild members.
/// - `9`: INVALID_SESSION - Invalid session.
/// - `10`: HELLO - Hello from server.
/// - `11`: HEARTBEAT_ACK - Heartbeat acknowledged.
/// - `12`: RATE_LIMITED - Rate limited.
public enum GatewayOpcode: Int, Codable, Sendable {
    /// Dispatch (event).
    case dispatch = 0
    
    /// Heartbeat.
    case heartbeat = 1
    
    /// Identify.
    case identify = 2
    
    /// Presence update.
    case presenceUpdate = 3
    
    /// Resume.
    case resume = 6
    
    /// Reconnect.
    case reconnect = 7
    
    /// Request guild members.
    case requestGuildMembers = 8
    
    /// Invalid session.
    case invalidSession = 9
    
    /// Hello.
    case hello = 10
    
    /// Heartbeat acknowledged.
    case heartbeatAck = 11
    
    /// Rate limited.
    case rateLimited = 12
}

/// Represents a gateway payload.
///
/// Gateway payloads are the messages sent between the client and Discord's gateway.
///
/// ## Fields
/// - `op`: The opcode for this payload.
/// - `d`: The event data (if applicable).
/// - `s`: The sequence number (for dispatch events).
/// - `t`: The event name (for dispatch events).
public struct GatewayPayload<D: Codable>: Codable {
    /// The opcode for this payload.
    public let op: GatewayOpcode
    
    /// The event data (if applicable).
    public let d: D?
    
    /// The sequence number (for dispatch events).
    public let s: Int?
    
    /// The event name (for dispatch events).
    public let t: String?
}
extension GatewayPayload: Sendable where D: Sendable {}

/// Represents a Discord gateway event.
///
/// This enum covers all possible events that can be dispatched from Discord's gateway.
///
/// ## Example
///
/// ```swift
/// await client.setOnReady { ready in
///     print("Bot is ready!")
/// }
///
/// await client.setOnMessage { message in
///     print("Message: \(message.content ?? "")")
/// }
///
/// await client.setOnInteraction { interaction in
///     print("Interaction received")
/// }
/// ```
///
/// ## See Also
/// - `DiscordClient.setOnReady(_:)`
/// - `DiscordClient.setOnMessage(_:)`
/// - `DiscordClient.setOnInteraction(_:)`
public enum DiscordEvent: Hashable, Sendable {
    /// The bot is ready to start receiving events.
    case ready(ReadyEvent)
    
    /// A message was created.
    case messageCreate(Message)
    
    /// A message was updated.
    case messageUpdate(Message)
    
    /// A message was deleted.
    case messageDelete(MessageDelete)
    
    /// Multiple messages were deleted.
    case messageDeleteBulk(MessageDeleteBulk)
    
    /// A reaction was added to a message.
    case messageReactionAdd(MessageReactionAdd)
    
    /// A reaction was removed from a message.
    case messageReactionRemove(MessageReactionRemove)
    
    /// All reactions were removed from a message.
    case messageReactionRemoveAll(MessageReactionRemoveAll)
    
    /// A specific emoji reaction was removed from a message.
    case messageReactionRemoveEmoji(MessageReactionRemoveEmoji)
    
    /// A guild was created or the bot joined a guild.
    case guildCreate(Guild)
    
    /// A guild was updated.
    case guildUpdate(Guild)
    
    /// A guild was deleted or the bot left a guild.
    case guildDelete(GuildDelete)
    
    /// A channel was created.
    case channelCreate(Channel)
    
    /// A channel was updated.
    case channelUpdate(Channel)
    
    /// A channel was deleted.
    case channelDelete(Channel)
    
    /// An interaction was created (slash command, button, etc.).
    case interactionCreate(Interaction)
    
    /// A member joined a guild.
    case guildMemberAdd(GuildMemberAdd)
    
    /// A member was removed from a guild.
    case guildMemberRemove(GuildMemberRemove)
    
    /// A guild member was updated.
    case guildMemberUpdate(GuildMemberUpdate)
    
    /// A guild role was created.
    case guildRoleCreate(GuildRoleCreate)
    
    /// A guild role was updated.
    case guildRoleUpdate(GuildRoleUpdate)
    
    /// A guild role was deleted.
    case guildRoleDelete(GuildRoleDelete)
    
    /// Guild emojis were updated.
    case guildEmojisUpdate(GuildEmojisUpdate)
    
    /// Guild stickers were updated.
    case guildStickersUpdate(GuildStickersUpdate)
    
    /// Guild members chunk was received.
    case guildMembersChunk(GuildMembersChunk)
    
    /// A user started typing.
    case typingStart(TypingStart)
    
    /// Channel pins were updated.
    case channelPinsUpdate(ChannelPinsUpdate)
    
    /// A user's presence was updated.
    case presenceUpdate(PresenceUpdate)
    
    /// A user was banned from a guild.
    case guildBanAdd(GuildBanAdd)
    
    /// A user was unbanned from a guild.
    case guildBanRemove(GuildBanRemove)
    
    /// Guild webhooks were updated.
    case webhooksUpdate(WebhooksUpdate)
    
    /// Guild integrations were updated.
    case guildIntegrationsUpdate(GuildIntegrationsUpdate)
    
    /// An invite was created.
    case inviteCreate(InviteCreate)
    
    /// An invite was deleted.
    case inviteDelete(InviteDelete)
    
    /// Catch-all for any gateway dispatch we don't model explicitly.
    case raw(String, Data)
    
    /// A thread was created.
    case threadCreate(Channel)
    
    /// A thread was updated.
    case threadUpdate(Channel)
    
    /// A thread was deleted.
    case threadDelete(Channel)
    
    /// A thread member was updated.
    case threadMemberUpdate(ThreadMember)
    
    /// Thread members were updated.
    case threadMembersUpdate(ThreadMembersUpdate)
    
    /// Thread list was synced.
    case threadListSync(ThreadListSync)
    
    /// Application command permissions were updated.
    case applicationCommandPermissionsUpdate(ApplicationCommandPermissionsUpdate)
    
    /// Channel info was received.
    case channelInfo(Channel)
    
    /// A scheduled event was created.
    case guildScheduledEventCreate(GuildScheduledEvent)
    
    /// A scheduled event was updated.
    case guildScheduledEventUpdate(GuildScheduledEvent)
    
    /// A scheduled event was deleted.
    case guildScheduledEventDelete(GuildScheduledEvent)
    
    /// A user was added to a scheduled event.
    case guildScheduledEventUserAdd(GuildScheduledEventUser)
    
    /// A user was removed from a scheduled event.
    case guildScheduledEventUserRemove(GuildScheduledEventUser)
    
    /// An auto moderation rule was created.
    case autoModerationRuleCreate(AutoModerationRule)
    
    /// An auto moderation rule was updated.
    case autoModerationRuleDelete(AutoModerationRule)
    case autoModerationActionExecution(AutoModerationActionExecution)
    // Audit log
    case guildAuditLogEntryCreate(AuditLogEntry)
    // Poll votes
    case pollVoteAdd(PollVote)
    case pollVoteRemove(PollVote)
    // Soundboard
    case soundboardSoundCreate(SoundboardSound)
    case soundboardSoundUpdate(SoundboardSound)
    case soundboardSoundDelete(SoundboardSound)
    // Entitlements
    case entitlementCreate(Entitlement)
    case entitlementUpdate(Entitlement)
    case entitlementDelete(Entitlement)
    // Session events
    case sessionInvalidated
    case disconnected(reason: String)
}

public struct MessageDelete: Codable, Hashable, Sendable {
    public let id: MessageID
    public let channel_id: ChannelID
    public let guild_id: GuildID?
}

public struct MessageDeleteBulk: Codable, Hashable, Sendable {
    public let ids: [MessageID]
    public let channel_id: ChannelID
    public let guild_id: GuildID?
}

public struct MessageReactionAdd: Codable, Hashable, Sendable {
    public let user_id: UserID
    public let channel_id: ChannelID
    public let message_id: MessageID
    public let guild_id: GuildID?
    public let member: GuildMember?
    public let emoji: PartialEmoji
}

public struct MessageReactionRemove: Codable, Hashable, Sendable {
    public let user_id: UserID
    public let channel_id: ChannelID
    public let message_id: MessageID
    public let guild_id: GuildID?
    public let emoji: PartialEmoji
}

public struct MessageReactionRemoveAll: Codable, Hashable, Sendable {
    public let channel_id: ChannelID
    public let message_id: MessageID
    public let guild_id: GuildID?
}

public struct MessageReactionRemoveEmoji: Codable, Hashable, Sendable {
    public let channel_id: ChannelID
    public let message_id: MessageID
    public let guild_id: GuildID?
    public let emoji: PartialEmoji
}

public struct ReadyEvent: Codable, Hashable, Sendable {
    public let user: User
    public let session_id: String
    public let resume_gateway_url: String?
}

// Note: Guild model lives in Sources/SwiftDisc/Models/Guild.swift

public struct GuildDelete: Codable, Hashable, Sendable {
    public let id: GuildID
    public let unavailable: Bool?
}

// Note: Interaction model lives in Sources/SwiftDisc/Models/Interaction.swift

// MARK: - Guild Member Events
public struct GuildMemberAdd: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let user: User
    public let nick: String?
    public let avatar: String?
    public let roles: [RoleID]
    public let joined_at: String
    public let premium_since: String?
    public let deaf: Bool
    public let mute: Bool
    public let pending: Bool?
    public let permissions: String?
}

public struct GuildMemberRemove: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let user: User
}

public struct GuildMemberUpdate: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let user: User
    public let nick: String?
    public let roles: [RoleID]
    public let premium_since: String?
    public let pending: Bool?
}

// MARK: - Role CRUD Events
public struct GuildRoleCreate: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let role: Role
}

public struct GuildRoleUpdate: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let role: Role
}

public struct GuildRoleDelete: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let role_id: RoleID
}

// MARK: - Emoji / Sticker Update
public struct GuildEmojisUpdate: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let emojis: [Emoji]
}

public struct GuildStickersUpdate: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let stickers: [Sticker]
}

// MARK: - Request/Receive Guild Members
public struct RequestGuildMembers: Codable, Hashable, Sendable {
    public let op: Int
    public let d: Payload
    public struct Payload: Codable, Hashable, Sendable {
        public let guild_id: GuildID
        public let query: String?
        public let limit: Int?
        public let presences: Bool?
        public let user_ids: [UserID]?
        public let nonce: String?
    }

    public init(d: Payload) {
        self.op = 8
        self.d = d
    }
}

public struct Presence: Codable, Hashable, Sendable {
}

public struct GuildMembersChunk: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let members: [GuildMember]
    public let chunk_index: Int
    public let chunk_count: Int
    public let not_found: [UserID]?
    public let presences: [Presence]?
    public let nonce: String?
}

public struct IdentifyPayload: Codable, Sendable {
    public let token: String
    public let intents: UInt64
    public let properties: IdentifyConnectionProperties
    public let compress: Bool?
    public let large_threshold: Int?
    public let shard: [Int]?

    public init(token: String, intents: UInt64, properties: IdentifyConnectionProperties = .default, compress: Bool? = nil, large_threshold: Int? = nil, shard: [Int]? = nil) {
        self.token = token
        self.intents = intents
        self.properties = properties
        self.compress = compress
        self.large_threshold = large_threshold
        self.shard = shard
    }
}

public struct IdentifyConnectionProperties: Codable, Sendable {
    public let os: String
    public let browser: String
    public let device: String

    public static var `default`: IdentifyConnectionProperties {
        #if os(iOS)
        let osName = "iOS"
        #elseif os(macOS)
        let osName = "macOS"
        #elseif os(Windows)
        let osName = "Windows"
        #elseif os(tvOS)
        let osName = "tvOS"
        #elseif os(watchOS)
        let osName = "watchOS"
        #else
        let osName = "SwiftOS"
        #endif
        return IdentifyConnectionProperties(os: osName, browser: "SwiftDisc", device: "SwiftDisc")
    }

    enum CodingKeys: String, CodingKey {
        case os
        case browser
        case device
    }
}

public typealias HeartbeatPayload = Int?

public struct ResumePayload: Codable, Sendable {
    public let token: String
    public let session_id: String
    public let seq: Int
}

public struct PresenceUpdatePayload: Codable, Sendable {
    public struct Activity: Codable, Hashable, Sendable { 
        public struct Timestamps: Codable, Hashable, Sendable { 
            public let start: Int64?
            public let end: Int64?
        }
        public struct Assets: Codable, Hashable, Sendable { 
            public let large_image: String?
            public let large_text: String?
            public let small_image: String?
            public let small_text: String?
        }
        public struct Party: Codable, Hashable, Sendable { 
            public let id: String?
            public let size: [Int]?
        }
        public struct Secrets: Codable, Hashable, Sendable { 
            public let join: String?
            public let spectate: String?
            public let match: String?
        }
        public let name: String
        public let type: Int
        public let state: String?
        public let details: String?
        public let timestamps: Timestamps?
        public let assets: Assets?
        public let buttons: [String]?
        public let party: Party?
        public let secrets: Secrets?
        public init(
            name: String,
            type: Int,
            state: String? = nil,
            details: String? = nil,
            timestamps: Timestamps? = nil,
            assets: Assets? = nil,
            buttons: [String]? = nil,
            party: Party? = nil,
            secrets: Secrets? = nil
        ) {
            self.name = name
            self.type = type
            self.state = state
            self.details = details
            self.timestamps = timestamps
            self.assets = assets
            self.buttons = buttons
            self.party = party
            self.secrets = secrets
        }
    }
    public struct Data: Codable, Sendable {
        public let since: Int?
        public let activities: [Activity]
        public let status: String
        public let afk: Bool
    }
    public let d: Data
}

// MARK: - New Gateway Events (v1.1.0)

public struct TypingStart: Codable, Hashable, Sendable {
    public let channel_id: ChannelID
    public let guild_id: GuildID?
    public let user_id: UserID
    public let timestamp: Int
    public let member: GuildMember?
}

public struct ChannelPinsUpdate: Codable, Hashable, Sendable {
    public let guild_id: GuildID?
    public let channel_id: ChannelID
    public let last_pin_timestamp: String?
}

public struct PresenceUpdate: Codable, Hashable, Sendable {
    public let user: User
    public let guild_id: GuildID
    public let status: String
    public let activities: [PresenceUpdatePayload.Activity]
    public let client_status: ClientStatus
    
    public struct ClientStatus: Codable, Hashable, Sendable {
        public let desktop: String?
        public let mobile: String?
        public let web: String?
    }
}

public struct GuildBanAdd: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let user: User
}

public struct GuildBanRemove: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let user: User
}

public struct WebhooksUpdate: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let channel_id: ChannelID
}

public struct GuildIntegrationsUpdate: Codable, Hashable, Sendable {
    public let guild_id: GuildID
}

public struct InviteCreate: Codable, Hashable, Sendable {
    public let channel_id: ChannelID
    public let code: String
    public let created_at: String
    public let guild_id: GuildID?
    public let inviter: User?
    public let max_age: Int
    public let max_uses: Int
    public let target_type: Int?
    public let target_user: User?
    public let target_application: PartialApplication?
    public let temporary: Bool
    public let uses: Int
    
    public struct PartialApplication: Codable, Hashable, Sendable {
        public let id: ApplicationID
        public let name: String
        public let icon: String?
        public let description: String
    }
}

public struct InviteDelete: Codable, Hashable, Sendable {
    public let channel_id: ChannelID
    public let guild_id: GuildID?
    public let code: String
}

// MARK: - Auto Moderation

public struct AutoModerationActionExecution: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let action: AutoModerationRule.Action
    public let rule_id: AutoModerationRuleID
    public let rule_trigger_type: Int
    public let user_id: UserID
    public let channel_id: ChannelID?
    public let message_id: MessageID?
    public let alert_system_message_id: MessageID?
    public let content: String?
    public let matched_keyword: String?
    public let matched_content: String?
}

// MARK: - Audit Log

public struct GuildAuditLogEntryCreate: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let entry: AuditLogEntry
}

// MARK: - Poll Votes

public struct PollVote: Codable, Hashable, Sendable {
    public let user_id: UserID
    public let channel_id: ChannelID
    public let guild_id: GuildID?
    public let message_id: MessageID
    public let answer_id: Int
}

// MARK: - Soundboard

public struct SoundboardSound: Codable, Hashable, Sendable {
    public let id: SoundboardSoundID
    public let guild_id: GuildID?
    public let name: String
    public let volume: Double?
    public let user_id: UserID?
    public let emoji_id: EmojiID?
    public let emoji_name: String?
    public let available: Bool?
}

// MARK: - Entitlements

// Entitlement model in Models/Monetization.swift

// MARK: - Application Commands

public struct ApplicationCommandPermissionsUpdate: Codable, Hashable, Sendable {
    public let id: ApplicationCommandID
    public let application_id: ApplicationID
    public let guild_id: GuildID
    public let permissions: [ApplicationCommandPermissions]
}

public struct ApplicationCommandPermissions: Codable, Hashable, Sendable {
    public let id: ApplicationCommandID
    public let type: Int
    public let permissions: String
}
