import Foundation

public struct AppInstallation: Codable, Hashable {
    public let id: Snowflake<AppInstallation>
    public let application_id: ApplicationID
    public let user_id: UserID?
    public let guild_id: GuildID?
    public let sku_ids: [SKUID]?
    public let scopes: [String]?
    public let created_at: String?
}

public struct AppSubscription: Codable, Hashable {
    public let id: Snowflake<AppSubscription>
    public let application_id: ApplicationID
    public let sku_id: SKUID
    public let user_id: UserID?
    public let guild_id: GuildID?
    public let status: String?
    public let current_period_start: String?
    public let current_period_end: String?
    public let canceled_at: String?
    public let trial_ends_at: String?
}
