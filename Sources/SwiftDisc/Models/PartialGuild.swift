import Foundation

public struct PartialGuild: Codable, Hashable, Sendable {
    public let id: GuildID
    public let name: String
}
