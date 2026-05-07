import Foundation

public struct Template: Codable, Hashable, Sendable {
    public struct TemplateGuild: Codable, Hashable, Sendable {
        public let id: GuildID?
        public let name: String?
    }
    public let code: String
    public let name: String
    public let description: String?
    public let usage_count: Int
    public let creator_id: UserID
    public let created_at: String
    public let updated_at: String
    public let source_guild_id: GuildID
    public let serialized_source_guild: TemplateGuild?
    public let is_dirty: Bool?
}
