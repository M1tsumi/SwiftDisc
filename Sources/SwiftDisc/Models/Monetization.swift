import Foundation

/// Represents a stock-keeping unit for monetized applications.
public struct SKU: Codable, Hashable, Sendable {
    public let id: SKUID
    public let type: Int
    public let application_id: ApplicationID
    public let name: String
    public let slug: String?
    public let flags: Int?
    public let access_type: Int?
}

/// The type of a Discord entitlement.
public enum EntitlementType: Int, Codable, Sendable {
    /// Purchase.
    case purchase = 1
    /// Premium subscription.
    case premiumSubscription = 2
    /// Developer gift.
    case developerGift = 3
    /// Test mode purchase.
    case testModePurchase = 4
    /// Free purchase.
    case freePurchase = 5
    /// User gift.
    case userGift = 6
    /// Premium purchase.
    case premiumPurchase = 7
    /// Application subscription.
    case applicationSubscription = 8
    /// Unknown entitlement type (forward compatibility).
    case unknown = 999

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = EntitlementType(rawValue: rawValue) ?? .unknown
    }
}

/// Represents an entitlement (purchased premium feature) for a user or guild.
public struct Entitlement: Codable, Hashable, Sendable {
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
    public let type: EntitlementType?
    public let subscription_id: String?
}
