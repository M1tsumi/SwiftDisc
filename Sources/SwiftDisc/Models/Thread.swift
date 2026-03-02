import Foundation

public struct ThreadMember: Codable, Hashable, Sendable {
    public let id: ChannelID?
    public let user_id: UserID?
    public let join_timestamp: String
    public let flags: Int
    public let member: GuildMember?
}

public struct ThreadListResponse: Codable, Hashable, Sendable {
    public let threads: [Channel]
    public let members: [ThreadMember]
    public let has_more: Bool
}
