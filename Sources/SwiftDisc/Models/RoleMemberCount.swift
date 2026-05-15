import Foundation

/// Represents the approximate member count for a role.
public struct RoleMemberCount: Codable, Hashable, Sendable {
    public let role_id: RoleID
    public let count: Int
}
