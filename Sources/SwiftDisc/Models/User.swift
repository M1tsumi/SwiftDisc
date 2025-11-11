import Foundation

public struct User: Codable, Hashable {
    public let id: Snowflake
    public let username: String
    public let discriminator: String?
    public let globalName: String?
    public let avatar: String?
}
