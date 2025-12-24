import Foundation

public struct Template: Codable, Hashable {
    public struct TemplateGuild: Codable, Hashable { 
        public let id: GuildID?; 
        public let name: String? 
    }
    public let code: String
    public let name: String
    public let description: String?
    public let usage_count: Int
    public let creator_id: UserID
    public let creator: User?
    public let created_at: String
    public let updated_at: String
    public let source_guild_id: GuildID
    public let serialized_source_guild: TemplateGuild?
    public let is_dirty: Bool?
}

// MARK: - Template Create/Update
public struct TemplateCreate: Codable, Hashable {
    public let name: String
    public let description: String?
    
    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct TemplateUpdate: Codable, Hashable {
    public let name: String?
    public let description: String?
    
    public init(name: String? = nil, description: String? = nil) {
        self.name = name
        self.description = description
    }
}
