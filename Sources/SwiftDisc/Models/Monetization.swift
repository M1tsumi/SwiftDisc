import Foundation

public struct SKU: Codable, Hashable {
    public let id: SKUID
    public let type: Int
    public let application_id: ApplicationID
    public let name: String
    public let slug: String?
    public let flags: Int?
    public let access_type: Int?
}

public struct Entitlement: Codable, Hashable {
    public let id: EntitlementID
    public let sku_id: SKUID
    public let application_id: ApplicationID
    public let user_id: UserID?
    public let guild_id: GuildID?
    public let owner_id: String?
    public let owner_type: Int?
    public let starts_at: String?
    public let ends_at: String?
    public let consumed: Bool?
    public let deleted: Bool?
    public let type: Int?
    public let subscription_id: String?
}
