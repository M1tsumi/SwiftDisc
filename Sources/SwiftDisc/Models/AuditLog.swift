import Foundation

/// The type of an audit log event.
public enum AuditLogEventType: Int, Codable, Sendable {
    case guildUpdate = 1
    case channelCreate = 10
    case channelUpdate = 11
    case channelDelete = 12
    case channelOverwriteCreate = 13
    case channelOverwriteUpdate = 14
    case channelOverwriteDelete = 15
    case memberKick = 20
    case memberPrune = 21
    case memberBanAdd = 22
    case memberBanRemove = 23
    case memberUpdate = 24
    case memberRoleUpdate = 25
    case memberMove = 26
    case memberDisconnect = 27
    case botAdd = 28
    case roleCreate = 30
    case roleUpdate = 31
    case roleDelete = 32
    case inviteCreate = 40
    case inviteUpdate = 41
    case inviteDelete = 42
    case webhookCreate = 50
    case webhookUpdate = 51
    case webhookDelete = 52
    case emojiCreate = 60
    case emojiUpdate = 61
    case emojiDelete = 62
    case messageDelete = 72
    case messageBulkDelete = 73
    case messagePin = 74
    case messageUnpin = 75
    case integrationCreate = 80
    case integrationUpdate = 81
    case integrationDelete = 82
    case stageInstanceCreate = 83
    case stageInstanceUpdate = 84
    case stageInstanceDelete = 85
    case stickerCreate = 90
    case stickerUpdate = 91
    case stickerDelete = 92
    case scheduledEventCreate = 100
    case scheduledEventUpdate = 101
    case scheduledEventDelete = 102
    case scheduledEventExceptionCreate = 103
    case scheduledEventExceptionUpdate = 104
    case scheduledEventExceptionDelete = 105
    case threadCreate = 110
    case threadUpdate = 111
    case threadDelete = 112
    case permissionOverwriteType = 121
    case autoModerationRuleCreate = 140
    case autoModerationRuleUpdate = 141
    case autoModerationRuleDelete = 142
    case autoModerationBlockMessage = 143
    case autoModerationFlagToChannel = 144
    case autoModerationUserCommunicationDisabled = 145
    case creatorMonoRequestCreated = 150
    case creatorMonoTermsAccepted = 151
    case onboardingCreate = 160
    case onboardingUpdate = 161
    case homeSettingsCreate = 170
    case homeSettingsUpdate = 171
    case voiceChannelStatusUpdate = 192
    case voiceChannelStatusDelete = 193
    case unknown = -1

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = AuditLogEventType(rawValue: rawValue) ?? .unknown
    }
}

/// Represents a guild audit log.
public struct AuditLog: Codable, Hashable, Sendable {
    public let audit_log_entries: [AuditLogEntry]
    public let users: [User]?
    public let webhooks: [Webhook]?
}

/// A single entry in a guild audit log.
public struct AuditLogEntry: Codable, Hashable, Sendable {
    /// Describes a property change for an audit log entry.
    public struct Change: Codable, Hashable, Sendable {
        public let key: String
        public let new_value: CodableValue?
        public let old_value: CodableValue?
    }
    /// Optional additional information for an audit log entry.
    public struct OptionalInfo: Codable, Hashable, Sendable {
        public let channel_id: ChannelID?
        public let count: String?
        public let delete_member_days: String?
        public let id: AuditLogEntryID?
        public let members_removed: String?
        public let message_id: MessageID?
        public let role_name: String?
        public let type: String?
        public let application_id: ApplicationID?
        /// Voice channel status (for VOICE_CHANNEL_STATUS_UPDATE entries).
        public let status: String?
    }
    public let id: AuditLogEntryID
    public let target_id: String?
    public let user_id: UserID?
    public let action_type: AuditLogEventType
    public let changes: [Change]?
    public let options: OptionalInfo?
    public let reason: String?
}

/// A dynamically-typed JSON value used in audit log entries.
public enum CodableValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: CodableValue])
    case array([CodableValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode([String: CodableValue].self) { self = .object(v); return }
        if let v = try? container.decode([CodableValue].self) { self = .array(v); return }
        self = .null
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }
}
