import Foundation


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let heartbeat_interval: Int
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let id: ChannelID
    public let guild_id: GuildID
    public let member_count: Int
    public let added_members: [ThreadMember]?
    public let removed_member_ids: [UserID]?
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID?
    public let channel_id: ChannelID?
    public let user_id: UserID
    public let session_id: String
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let token: String
    public let guild_id: GuildID
    public let endpoint: String?
}

public enum GatewayOpcode: Int, Codable, Sendable {
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


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let op: GatewayOpcode
    public let d: D?
    public let s: Int?
    public let t: String?
}

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
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let id: MessageID
    public let channel_id: ChannelID
    public let guild_id: GuildID?
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let ids: [MessageID]
    public let channel_id: ChannelID
    public let guild_id: GuildID?
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let user_id: UserID
    public let channel_id: ChannelID
    public let message_id: MessageID
    public let guild_id: GuildID?
    public let member: GuildMember?
    public let emoji: PartialEmoji
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let user_id: UserID
    public let channel_id: ChannelID
    public let message_id: MessageID
    public let guild_id: GuildID?
    public let emoji: PartialEmoji
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let channel_id: ChannelID
    public let message_id: MessageID
    public let guild_id: GuildID?
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let channel_id: ChannelID
    public let message_id: MessageID
    public let guild_id: GuildID?
    public let emoji: PartialEmoji
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let user: User
    public let session_id: String?
}

// Note: Guild model lives in Sources/SwiftDisc/Models/Guild.swift


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let id: GuildID
    public let unavailable: Bool?
}

// Note: Interaction model lives in Sources/SwiftDisc/Models/Interaction.swift

// MARK: - Guild Member Events

        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
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


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID
    public let user: User
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID
    public let user: User
    public let nick: String?
    public let roles: [RoleID]
    public let premium_since: String?
    public let pending: Bool?
}

// MARK: - Role CRUD Events

        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID
    public let role: Role
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID
    public let role: Role
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID
    public let role_id: RoleID
}

// MARK: - Emoji / Sticker Update

        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID
    public let emojis: [Emoji]
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID
    public let stickers: [Sticker]
}

// MARK: - Request/Receive Guild Members

        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let op: Int = 8
    public let d: Payload
    
        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
        public let guild_id: GuildID
        public let query: String?
        public let limit: Int?
        public let presences: Bool?
        public let user_ids: [UserID]?
        public let nonce: String?
    }
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    }


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID
    public let members: [GuildMember]
    public let chunk_index: Int
    public let chunk_count: Int
    public let not_found: [UserID]?
    public let presences: [Presence]?
    public let nonce: String?
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
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


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
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


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let token: String
    public let session_id: String
    public let seq: Int
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    
        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
        
        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
     public let start: Int64?; public let end: Int64? }
        
        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
     public let large_image: String?; public let large_text: String?; public let small_image: String?; public let small_text: String? }
        
        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
     public let id: String?; public let size: [Int]? }
        
        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
     public let join: String?; public let spectate: String?; public let match: String? }
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
    
        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
        public let since: Int?
        public let activities: [Activity]
        public let status: String
        public let afk: Bool
    }
    public let d: Data
}

// MARK: - New Gateway Events (v1.1.0)


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let channel_id: ChannelID
    public let guild_id: GuildID?
    public let user_id: UserID
    public let timestamp: Int
    public let member: GuildMember?
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID?
    public let channel_id: ChannelID
    public let last_pin_timestamp: String?
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let user: User
    public let guild_id: GuildID
    public let status: String
    public let activities: [PresenceUpdatePayload.Activity]
    public let client_status: ClientStatus
    
    
        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
        public let desktop: String?
        public let mobile: String?
        public let web: String?
    }
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID
    public let user: User
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID
    public let user: User
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID
    public let channel_id: ChannelID
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
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
    
    
        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
        public let id: ApplicationID
        public let name: String
        public let icon: String?
        public let description: String
    }
}


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let channel_id: ChannelID
    public let guild_id: GuildID?
    public let code: String
}

// MARK: - Auto Moderation


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
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


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let guild_id: GuildID
    public let entry: AuditLogEntry
}

// MARK: - Poll Votes


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
    public let user_id: UserID
    public let channel_id: ChannelID
    public let guild_id: GuildID?
    public let message_id: MessageID
    public let answer_id: Int
}

// MARK: - Soundboard


        $m = $args[0]
        if ($m.Value -match "Sendable") { $m.Value }
        else { "$($m.Groups[1].Value): $($m.Groups[2].Value)Sendable {" }
    
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
