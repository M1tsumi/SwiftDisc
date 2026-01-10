//
//  OAuth2Models.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Represents an OAuth2 access token response
public struct AccessToken: Codable, Sendable {
    /// The access token string
    public let access_token: String
    /// The token type (usually "Bearer")
    public let token_type: String
    /// Number of seconds until expiration
    public let expires_in: Int
    /// Optional refresh token
    public let refresh_token: String?
    /// Space-separated list of scopes
    public let scope: String

    /// Computed property for expiration date
    public var expiresAt: Date {
        Date().addingTimeInterval(TimeInterval(expires_in))
    }

    /// Check if the token is expired
    public var isExpired: Bool {
        Date() > expiresAt
    }

    /// Get scopes as an array
    public var scopes: [OAuth2Scope] {
        scope.split(separator: " ").compactMap { OAuth2Scope(rawValue: String($0)) }
    }
}

/// OAuth2 scopes for Discord API
public enum OAuth2Scope: String, CaseIterable, Codable, Sendable {
    case identify
    case email
    case profile
    case connections
    case guilds
    case guildsJoin = "guilds.join"
    case guildsMembersRead = "guilds.members.read"
    case dmChannelsRead = "dm_channels.read"
    case activitiesRead = "activities.read"
    case activitiesWrite = "activities.write"
    case applicationsCommands = "applications.commands"
    case applicationsCommandsUpdate = "applications.commands.update"
    case applicationRoleConnectionWrite = "role_connections.write"
    case webhookIncoming = "webhook.incoming"
    case voice
    case dmChannelsWrite = "dm_channels.write"
    case messagesRead = "messages.read"
    case applicationsBuildsUpload = "applications.builds.upload"
    case applicationsBuildsRead = "applications.builds.read"
    case applicationsStoreUpdate = "applications.store.update"
    case applicationsEntitlements = "applications.entitlements"
    case bots
    case applicationsCommandsPermissionsUpdate = "applications.commands.permissions.update"
    case delegationsRead = "delegations.read"
    case delegationsWrite = "delegations.write"
    case dmChannelsMessagesRead = "dm_channels.messages.read"
    case dmChannelsMessagesWrite = "dm_channels.messages.write"
    case guildsMembersWrite = "guilds.members.write"
    case guildsChannelsRead = "guilds.channels.read"
    case guildsChannelsWrite = "guilds.channels.write"
    case guildsVoiceStatesRead = "guilds.voice_states.read"
    case guildsVoiceStatesWrite = "guilds.voice_states.write"
    case guildsInvitesRead = "guilds.invites.read"
    case guildsInvitesWrite = "guilds.invites.write"
    case guildsRolesRead = "guilds.roles.read"
    case guildsRolesWrite = "guilds.roles.write"
    case guildsEmojisRead = "guilds.emojis.read"
    case guildsEmojisWrite = "guilds.emojis.write"
    case guildsStickersRead = "guilds.stickers.read"
    case guildsStickersWrite = "guilds.stickers.write"
    case guildsEventsRead = "guilds.events.read"
    case guildsEventsWrite = "guilds.events.write"
    case guildsIntegrationsRead = "guilds.integrations.read"
    case guildsIntegrationsWrite = "guilds.integrations.write"
    case guildsWebhooksRead = "guilds.webhooks.read"
    case guildsWebhooksWrite = "guilds.webhooks.write"
    case guildsAuditLogRead = "guilds.audit_log.read"
    case guildsThreadsRead = "guilds.threads.read"
    case guildsThreadsWrite = "guilds.threads.write"
    case guildsExpressionsRead = "guilds.expressions.read"
    case guildsExpressionsWrite = "guilds.expressions.write"
    case guildsModerationRead = "guilds.moderation.read"
    case guildsModerationWrite = "guilds.modulation.write"
}

/// Authorization grant types
public enum GrantType: String, Codable, Sendable {
    case authorizationCode = "authorization_code"
    case refreshToken = "refresh_token"
    case clientCredentials = "client_credentials"
    case implicit = "implicit"
}

/// Authorization request parameters
public struct AuthorizationRequest: Codable, Sendable {
    public let responseType: String
    public let clientId: String
    public let scope: String
    public let redirectUri: String
    public let state: String?
    public let prompt: AuthPrompt?
    public let guildId: Snowflake?
    public let disableGuildSelect: Bool?
    public let permissions: String?

    enum CodingKeys: String, CodingKey {
        case responseType = "response_type"
        case clientId = "client_id"
        case scope
        case redirectUri = "redirect_uri"
        case state
        case prompt
        case guildId = "guild_id"
        case disableGuildSelect = "disable_guild_select"
        case permissions
    }
}

/// Authentication prompt options
public enum AuthPrompt: String, Codable, Sendable {
    case auto
    case consent
    case none
}

/// Token refresh request
public struct TokenRefreshRequest: Codable, Sendable {
    public let grantType: String
    public let refreshToken: String
    public let clientId: String
    public let clientSecret: String?

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
        case clientId = "client_id"
        case clientSecret = "client_secret"
    }
}

/// Authorization information for current user
public struct AuthorizationInfo: Codable, Sendable {
    public let application: OAuth2Application
    public let scopes: [String]
    public let expires: Date?
    public let user: User?
}

/// OAuth2 application information
public struct OAuth2Application: Codable, Sendable {
    public let id: Snowflake
    public let name: String
    public let icon: String?
    public let description: String
    public let rpcOrigins: [String]?
    public let botPublic: Bool?
    public let botRequireCodeGrant: Bool?
    public let botPermissions: String?
    public let termsOfServiceUrl: String?
    public let privacyPolicyUrl: String?
    public let owner: User?
    public let team: Team?
    public let guildId: Snowflake?
    public let primarySkuId: Snowflake?
    public let slug: String?
    public let coverImage: String?
    public let flags: Int?
    public let approximateGuildCount: Int?
    public let redirectUris: [String]?
    public let interactionsEndpointUrl: String?
    public let roleConnectionsVerificationUrl: String?
    public let tags: [String]?
    public let installParams: InstallParams?
    public let integrationTypesConfig: [String: IntegrationTypeConfig]?
    public let customInstallUrl: String?
}

/// Team information for applications
public struct Team: Codable, Sendable {
    public let icon: String?
    public let id: Snowflake
    public let members: [TeamMember]
    public let name: String
    public let ownerUserId: Snowflake
}

/// Team member
public struct TeamMember: Codable, Sendable {
    public let membershipState: Int
    public let permissions: [String]
    public let teamId: Snowflake
    public let user: User
}

/// Install parameters for applications
public struct InstallParams: Codable, Sendable {
    public let scopes: [String]
    public let permissions: String
}

/// Integration type configuration
public struct IntegrationTypeConfig: Codable, Sendable {
    public let oauth2InstallParams: InstallParams?
}

/// Cached authorization grant
public struct AuthorizationGrant: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let scopes: [OAuth2Scope]
    public let expiresAt: Date
    public let userId: Snowflake?

    public var isExpired: Bool {
        Date() > expiresAt
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/OAuth2/OAuth2Models.swift