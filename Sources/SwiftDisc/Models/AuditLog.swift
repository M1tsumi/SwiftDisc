//
//  AuditLog.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public struct AuditLog: Codable, Hashable {
    public let audit_log_entries: [AuditLogEntry]
    public let users: [User]?
    public let webhooks: [Webhook]?
}

public struct AuditLogEntry: Codable, Hashable {
    public struct Change: Codable, Hashable {
        public let key: String
        public let new_value: CodableValue?
        public let old_value: CodableValue?
    }
    public struct OptionalInfo: Codable, Hashable {
        public let channel_id: ChannelID?
        public let count: String?
        public let delete_member_days: String?
        public let id: AuditLogEntryID?
        public let members_removed: String?
        public let message_id: MessageID?
        public let role_name: String?
        public let type: String?
        public let application_id: ApplicationID?
    }
    public let id: AuditLogEntryID
    public let target_id: String?
    public let user_id: UserID?
    public let action_type: Int
    public let changes: [Change]?
    public let options: OptionalInfo?
    public let reason: String?
}

public enum CodableValue: Codable, Hashable {
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
