//
//  UserConnection.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Represents a user's connection to an external service
public struct UserConnection: Codable, Sendable {
    /// ID of the connection account
    public let id: String
    /// The username of the connection account
    public let name: String
    /// The service of the connection (twitch, youtube, etc)
    public let type: String
    /// Whether the connection is revoked
    public let revoked: Bool?
    /// An array of partial server integrations
    public let integrations: [Integration]?
    /// Whether the connection is verified
    public let verified: Bool
    /// Username of the connection account
    public let friend_sync: Bool
    /// Whether activities from this connection will be shown in presence updates
    public let show_activity: Bool
    /// Whether this connection has a corresponding third party OAuth access token
    public let two_way_link: Bool
    /// Visibility of this connection
    public let visibility: ConnectionVisibility

    public enum ConnectionVisibility: Int, Codable, Sendable {
        case none = 0
        case everyone = 1
    }
}

/// Represents a guild integration
public struct Integration: Codable, Sendable {
    /// Integration id
    public let id: Snowflake
    /// Integration name
    public let name: String
    /// Integration type (twitch, youtube, discord, etc)
    public let type: String
    /// Is this integration enabled
    public let enabled: Bool
    /// Is this integration syncing
    public let syncing: Bool?
    /// ID that this integration uses for "subscribers"
    public let role_id: Snowflake?
    /// Whether emoticons should be synced for this integration (twitch only currently)
    public let enable_emoticons: Bool?
    /// The behavior of expiring subscribers
    public let expire_behavior: ExpireBehavior?
    /// The grace period (in days) before expiring subscribers
    public let expire_grace_period: Int?
    /// User for this integration
    public let user: User?
    /// Integration account information
    public let account: IntegrationAccount
    /// When this integration was last synced
    public let synced_at: Date?
    /// How many subscribers this integration has
    public let subscriber_count: Int?
    /// Has this integration been revoked
    public let revoked: Bool?
    /// The bot/OAuth2 application for discord integrations
    public let application: IntegrationApplication?

    public enum ExpireBehavior: Int, Codable, Sendable {
        case removeRole = 0
        case kick = 1
    }
}

/// Integration account information
public struct IntegrationAccount: Codable, Sendable {
    /// ID of the account
    public let id: String
    /// Name of the account
    public let name: String
}

/// Integration application information
public struct IntegrationApplication: Codable, Sendable {
    /// The id of the app
    public let id: Snowflake
    /// The name of the app
    public let name: String
    /// The icon hash of the app
    public let icon: String?
    /// The description of the app
    public let description: String
    /// The summary of the app
    public let summary: String?
    /// The bot associated with this application
    public let bot: User?
}

/// Represents a subscription to an application
public struct Subscription: Codable, Sendable {
    /// ID of the subscription
    public let id: Snowflake
    /// ID of the user who is subscribed
    public let user_id: Snowflake
    /// List of SKUs subscribed to
    public let sku_ids: [Snowflake]
    /// List of entitlements granted for this subscription
    public let entitlement_ids: [Snowflake]
    /// Current status of the subscription
    public let status: SubscriptionStatus
    /// When the subscription was canceled
    public let canceled_at: Date?
    /// ISO3166-1 alpha-2 country code of the payment source used to purchase the subscription
    public let country: String?

    public enum SubscriptionStatus: Int, Codable, Sendable {
        case active = 0
        case ending = 1
        case inactive = 2
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/Models/UserConnection.swift