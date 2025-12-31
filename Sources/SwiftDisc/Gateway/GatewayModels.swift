import Foundation

public struct GatewayHello: Codable {
    public let heartbeat_interval: Int
}

public struct ThreadMembersUpdate: Codable, Hashable {
    public let id: ChannelID
    public let guild_id: GuildID
    public let member_count: Int
    public let added_members: [ThreadMember]?
    public let removed_member_ids: [UserID]?
}

public struct VoiceState: Codable, Hashable {
    public let guild_id: GuildID?
    public let channel_id: ChannelID?
    public let user_id: UserID
    public let session_id: String
}

public struct VoiceServerUpdate: Codable, Hashable {
    public let token: String
    public let guild_id: GuildID
    public let endpoint: String?
}

public enum GatewayOpcode: Int, Codable {
    case dispatch = 0
    case heartbeat = 1
    case presenceUpdate = 3
    case identify = 2
    case voiceStateUpdate = 4
    case resume = 6
    case reconnect = 7
    case requestGuildMembers = 8
    case invalidSession = 9
    case hello = 10
    case heartbeatAck = 11
}

public struct GatewayPayload<D: Codable>: Codable {
    public let op: GatewayOpcode
    public let d: D?
    public let s: Int?
    public let t: String?
}

public enum DiscordEvent: Hashable {
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
    case voiceStateUpdate(VoiceState)
    case voiceServerUpdate(VoiceServerUpdate)
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
    // Scheduled Events
    case guildScheduledEventCreate(GuildScheduledEvent)
    case guildScheduledEventUpdate(GuildScheduledEvent)
    case guildScheduledEventDelete(GuildScheduledEvent)
    case guildScheduledEventUserAdd(GuildScheduledEventUser)
    case guildScheduledEventUserRemove(GuildScheduledEventUser)
}

public struct MessageDelete: Codable, Hashable {
    public let id: MessageID
    public let channel_id: ChannelID
    public let guild_id: GuildID?
}

public struct MessageDeleteBulk: Codable, Hashable {
    public let ids: [MessageID]
    public let channel_id: ChannelID
    public let guild_id: GuildID?
}

public struct MessageReactionAdd: Codable, Hashable {
    public let user_id: UserID
    public let channel_id: ChannelID
    public let message_id: MessageID
    public let guild_id: GuildID?
    public let member: GuildMember?
    public let emoji: PartialEmoji
}

public struct MessageReactionRemove: Codable, Hashable {
    public let user_id: UserID
    public let channel_id: ChannelID
    public let message_id: MessageID
    public let guild_id: GuildID?
    public let emoji: PartialEmoji
}

public struct MessageReactionRemoveAll: Codable, Hashable {
    public let channel_id: ChannelID
    public let message_id: MessageID
    public let guild_id: GuildID?
}

public struct MessageReactionRemoveEmoji: Codable, Hashable {
    public let channel_id: ChannelID
    public let message_id: MessageID
    public let guild_id: GuildID?
    public let emoji: PartialEmoji
}

public struct ReadyEvent: Codable, Hashable {
    public let user: User
    public let session_id: String?
}

// Note: Guild model lives in Sources/SwiftDisc/Models/Guild.swift

public struct GuildDelete: Codable, Hashable {
    public let id: GuildID
    public let unavailable: Bool?
}

// Note: Interaction model lives in Sources/SwiftDisc/Models/Interaction.swift

// MARK: - Guild Member Events
public struct GuildMemberAdd: Codable, Hashable {
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

public struct GuildMemberRemove: Codable, Hashable {
    public let guild_id: GuildID
    public let user: User
}

public struct GuildMemberUpdate: Codable, Hashable {
    public let guild_id: GuildID
    public let user: User
    public let nick: String?
    public let roles: [RoleID]
    public let premium_since: String?
    public let pending: Bool?
}

// MARK: - Role CRUD Events
public struct GuildRoleCreate: Codable, Hashable {
    public let guild_id: GuildID
    public let role: Role
}

public struct GuildRoleUpdate: Codable, Hashable {
    public let guild_id: GuildID
    public let role: Role
}

public struct GuildRoleDelete: Codable, Hashable {
    public let guild_id: GuildID
    public let role_id: RoleID
}

// MARK: - Emoji / Sticker Update
public struct GuildEmojisUpdate: Codable, Hashable {
    public let guild_id: GuildID
    public let emojis: [Emoji]
}

public struct GuildStickersUpdate: Codable, Hashable {
    public let guild_id: GuildID
    public let stickers: [Sticker]
}

// MARK: - Request/Receive Guild Members
public struct RequestGuildMembers: Codable, Hashable {
    public let op: Int = 8
    public let d: Payload
    public struct Payload: Codable, Hashable {
        public let guild_id: GuildID
        public let query: String?
        public let limit: Int?
        public let presences: Bool?
        public let user_ids: [UserID]?
        public let nonce: String?
    }
}

public struct Presence: Codable, Hashable {}

public struct GuildMembersChunk: Codable, Hashable {
    public let guild_id: GuildID
    public let members: [GuildMember]
    public let chunk_index: Int
    public let chunk_count: Int
    public let not_found: [UserID]?
    public let presences: [Presence]?
    public let nonce: String?
}

public struct IdentifyPayload: Codable {
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

public struct IdentifyConnectionProperties: Codable {
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

public struct ResumePayload: Codable {
    public let token: String
    public let session_id: String
    public let seq: Int
}

public struct PresenceUpdatePayload: Codable {
    public struct Activity: Codable {
        public struct Timestamps: Codable { public let start: Int64?; public let end: Int64? }
        public struct Assets: Codable { public let large_image: String?; public let large_text: String?; public let small_image: String?; public let small_text: String? }
        public struct Party: Codable { public let id: String?; public let size: [Int]? }
        public struct Secrets: Codable { public let join: String?; public let spectate: String?; public let match: String? }
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
    public struct Data: Codable {
        public let since: Int?
        public let activities: [Activity]
        public let status: String
        public let afk: Bool
    }
    public let d: Data
}

// MARK: - New Gateway Events (v1.1.0)

public struct TypingStart: Codable, Hashable {
    public let channel_id: ChannelID
    public let guild_id: GuildID?
    public let user_id: UserID
    public let timestamp: Int
    public let member: GuildMember?
}

public struct ChannelPinsUpdate: Codable, Hashable {
    public let guild_id: GuildID?
    public let channel_id: ChannelID
    public let last_pin_timestamp: String?
}

public struct PresenceUpdate: Codable, Hashable {
    public let user: User
    public let guild_id: GuildID
    public let status: String
    public let activities: [PresenceUpdatePayload.Activity]
    public let client_status: ClientStatus
    
    public struct ClientStatus: Codable, Hashable {
        public let desktop: String?
        public let mobile: String?
        public let web: String?
    }
}

public struct GuildBanAdd: Codable, Hashable {
    public let guild_id: GuildID
    public let user: User
}

public struct GuildBanRemove: Codable, Hashable {
    public let guild_id: GuildID
    public let user: User
}

public struct WebhooksUpdate: Codable, Hashable {
    public let guild_id: GuildID
    public let channel_id: ChannelID
}

public struct GuildIntegrationsUpdate: Codable, Hashable {
    public let guild_id: GuildID
}

public struct InviteCreate: Codable, Hashable {
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
    
    public struct PartialApplication: Codable, Hashable {
        public let id: ApplicationID
        public let name: String
        public let icon: String?
        public let description: String
    }
}

public struct InviteDelete: Codable, Hashable {
    public let channel_id: ChannelID
    public let guild_id: GuildID?
    public let code: String
}
