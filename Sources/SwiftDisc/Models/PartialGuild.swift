import Foundation

/// A minimal guild object with only ID and name.
public struct PartialGuild: Codable, Hashable, Sendable {
    public let id: GuildID
    public let name: String
}
