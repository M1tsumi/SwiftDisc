import Foundation

public struct Emoji: Codable, Hashable {
    public let id: Snowflake?
    public let name: String?
    public let roles: [RoleID]?
    public let user: User?
    public let require_colons: Bool?
    public let managed: Bool?
    public let animated: Bool?
    public let available: Bool?
}
