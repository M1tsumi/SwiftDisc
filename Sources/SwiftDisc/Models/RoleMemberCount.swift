import Foundation

public struct RoleMemberCount: Codable, Hashable, Sendable {
    public let role_id: RoleID
    public let count: Int
}
