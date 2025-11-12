import Foundation

public struct ThreadMember: Codable, Hashable {
    public let id: Snowflake?
    public let user_id: Snowflake?
    public let join_timestamp: String
    public let flags: Int
    public let member: GuildMember?
}

public struct ThreadListResponse: Codable, Hashable {
    public let threads: [Channel]
    public let members: [ThreadMember]
    public let has_more: Bool
}
