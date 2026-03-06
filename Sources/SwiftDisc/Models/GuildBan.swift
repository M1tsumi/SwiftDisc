import Foundation

public struct GuildBan: Codable, Hashable, Sendable {
    public let reason: String?
    public let user: User
}
