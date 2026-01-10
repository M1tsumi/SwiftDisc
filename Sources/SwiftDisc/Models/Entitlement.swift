//
//  Entitlement.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Represents a Discord entitlement (subscription/purchase)
public struct Entitlement: Codable, Sendable {
    /// ID of the entitlement
    public let id: Snowflake
    /// ID of the SKU
    public let sku_id: Snowflake
    /// ID of the parent application
    public let application_id: Snowflake
    /// ID of the user that is granted access to the entitlement's sku
    public let user_id: Snowflake?
    /// Type of entitlement
    public let type: EntitlementType
    /// Entitlement was deleted
    public let deleted: Bool
    /// Start date at which the entitlement is valid. Not present when using test entitlements.
    public let starts_at: Date?
    /// Date at which the entitlement is no longer valid. Not present when using test entitlements.
    public let ends_at: Date?
    /// ID of the guild that is granted access to the entitlement's sku
    public let guild_id: Snowflake?
    /// For consumable items, whether or not the entitlement has been consumed
    public let consumed: Bool?

    public enum EntitlementType: Int, Codable, Sendable {
        case purchase = 1
        case premiumSubscription = 2
        case developerGift = 3
        case testModePurchase = 4
        case freePurchase = 5
        case userGift = 6
        case premiumPurchase = 7
        case applicationSubscription = 8
    }
}

/// Represents a Discord SKU (Stock Keeping Unit)
public struct SKU: Codable, Sendable {
    /// ID of SKU
    public let id: Snowflake
    /// Type of SKU
    public let type: SKUType
    /// ID of the parent application
    public let application_id: Snowflake
    /// Customer-facing name of the SKU
    public let name: String
    /// System-generated URL slug based on the SKU's name
    public let slug: String
    /// SKU flags
    public let flags: SKUFlags

    public enum SKUType: Int, Codable, Sendable {
        case durable = 1
        case consumable = 2
        case subscription = 3
        case subscriptionGroup = 4
    }

    public struct SKUFlags: OptionSet, Codable, Sendable {
        public let rawValue: Int

        public static let available = SKUFlags(rawValue: 1 << 2)
        public static let guildSubscription = SKUFlags(rawValue: 1 << 7)
        public static let userSubscription = SKUFlags(rawValue: 1 << 8)

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/Models/Entitlement.swift