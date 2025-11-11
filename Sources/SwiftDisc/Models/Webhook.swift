import Foundation

public struct Webhook: Codable, Hashable {
    public let id: Snowflake
    public let type: Int
    public let channel_id: Snowflake?
    public let guild_id: Snowflake?
    public let name: String?
    public let token: String?
}
