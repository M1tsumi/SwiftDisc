import Foundation

public struct GatewayHello: Codable, Sendable {
    public let heartbeat_interval: Int
}

public struct ThreadMembersUpdate: Codable, Hashable, Sendable {
    public let id: ChannelID
    public let guild_id: GuildID
    public let member_count: Int
    public let added_members: [ThreadMember]?
    public let removed_member_ids: [UserID]?
}

public struct ThreadListSync: Codable, Hashable, Sendable {
    public let guild_id: GuildID
    public let channel_ids: [ChannelID]
    public let threads: [Channel]
    public let members: [ThreadMember]
}

public enum GatewayOpcode: Int, Codable, Sendable {
    case dispatch = 0
    case heartbeat = 1
    case presenceUpdate = 3
    case identify = 2
    case resume = 6
    case reconnect = 7
    case requestGuildMembers = 8
    case invalidSession = 9
    case hello = 10
    case heartbeatAck = 11
    case rateLimited = 12
}

public struct GatewayPayload<D: Codable>: Codable {
    public let op: GatewayOpcode
    public let d: D?
    public let s: Int?
    public let t: String?
}
extension GatewayPayload: Sendable where D: Sendable {}

public enum DiscordEvent: Hashable, Sendable {
    case ready(ReadyEvent)
    case messageCreate(Message)
    case messageUpdate(Message)
    case messageDelete(MessageDelete)
    case messageDeleteBulk(MessageDeleteBulk)
    case messageReactionAdd(MessageReactionAdd)
    case messageReactionRemove(MessageReactionRemove)
    case messageReactionRemoveAll(MessageReactionRemoveAll)
    case messageReactionRemoveEmoji(MessageReactionRemoveEmoji)
    case guildCreate(Guild)
    case guildUpdate(Guild)
    case guildDelete(GuildDelete)
    case channelCreate(Channel)
    case channelUpdate(Channel)
    case channelDelete(Channel)
    case interactionCreate(Interaction)
    case guildMemberAdd(GuildMemberAdd)
    case guildMemberRemove(GuildMemberRemove)
    case guildMemberUpdate(GuildMemberUpdate)
    case guildRoleCreate(GuildRoleCreate)
    case guildRoleUpdate(GuildRoleUpdate)
    case guildRoleDelete(GuildRoleDelete)
    case guildEmojisUpdate(GuildEmojisUpdate)
    case guildStickersUpdate(GuildStickersUpdate)
    case guildMembersChunk(GuildMembersChunk)
    case typingStart(TypingStart)
    case channelPinsUpdate(ChannelPinsUpdate)
    case presenceUpdate(PresenceUpdate)
    case guildBanAdd(GuildBanAdd)
    case guildBanRemove(GuildBanRemove)
    case webhooksUpdate(WebhooksUpdate)
    case guildIntegrationsUpdate(GuildIntegrationsUpdate)
    case inviteCreate(InviteCreate)
    case inviteDelete(InviteDelete)
    // Catch-all for any gateway dispatch we don't model explicitly
    case raw(String, Data)
    // Threads
    case threadCreate(Channel)
    case threadUpdate(Channel)
    case threadDelete(Channel)
    case threadMemberUpdate(ThreadMember)
    case threadMembersUpdate(ThreadMembersUpdate)
    case threadListSync(ThreadListSync)
    // Application Commands
    case applicationCommandPermissionsUpdate(ApplicationCommandPermissionsUpdate)
    // Channel Info
    case channelInfo(Channel)
    // Scheduled Events
    case guildScheduledEventCreate(GuildScheduledEvent)
    case guildScheduledEventUpdate(GuildScheduledEvent)
    case guildScheduledEventDelete(GuildScheduledEvent)
    case guildScheduledEventUserAdd(GuildScheduledEventUser)
    case guildScheduledEventUserRemove(GuildScheduledEventUser)
    // AutoMod
    case autoModerationRuleCreate(AutoModerationRule)
    case autoModerationRuleUpdate(AutoModerationRule)
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
    public let op: Int = 8
    public let d: Payload
    public struct Payload: Codable, Hashable, Sendable {
        public let guild_id: GuildID
        public let query: String?
        public let limit: Int?
        public let presences: Bool?
        public let user_ids: [UserID]?
        public let nonce: String?
    }
}

public struct Presence: Codable, Hashable, Sendable {}

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
        case os = "$os"
        case browser = "$browser"
        case device = "$device"
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
        public struct Timestamps: Codable, Hashable, Sendable { public let start: Int64?; public let end: Int64? }
        public struct Assets: Codable, Hashable, Sendable { public let large_image: String?; public let large_text: String?; public let small_image: String?; public let small_text: String? }
        public struct Party: Codable, Hashable, Sendable { public let id: String?; public let size: [Int]? }
        public struct Secrets: Codable, Hashable, Sendable { public let join: String?; public let spectate: String?; public let match: String? }
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
    public let id: CommandID
    public let application_id: ApplicationID
    public let guild_id: GuildID
    public let permissions: [ApplicationCommandPermissions]
}

public struct ApplicationCommandPermissions: Codable, Hashable, Sendable {
    public let id: CommandID
    public let type: Int
    public let permissions: String
}
