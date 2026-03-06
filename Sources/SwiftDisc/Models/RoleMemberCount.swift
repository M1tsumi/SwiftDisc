import Foundation

public struct RoleMemberCount: Decodable, Sendable {
    public let role_id: RoleID
    public let count: Int
}
