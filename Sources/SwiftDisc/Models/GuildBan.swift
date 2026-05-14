import Foundation

/// Represents a guild ban entry.
public struct GuildBan: Codable, Hashable, Sendable {
    public let reason: String?
    public let user: User
}

/// Response from the bulk ban endpoint
public struct BulkBanResponse: Codable, Hashable, Sendable {
    /// List of user IDs that were successfully banned
    public let banned_users: [UserID]
}
