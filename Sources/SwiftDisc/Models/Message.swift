import Foundation

public struct Message: Codable, Hashable {
    public let id: Snowflake
    public let channel_id: Snowflake
    public let author: User
    public let content: String
}
