//
//  BotAuthorizationFlow.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Bot Authorization Flow for adding bots to guilds
public class BotAuthorizationFlow: Sendable {
    private let client: OAuth2Client

    /// Initialize bot authorization flow
    /// - Parameter client: OAuth2 client
    public init(client: OAuth2Client) {
        self.client = client
    }

    /// Generate bot authorization URL
    /// - Parameters:
    ///   - permissions: Permission bitset as integer or string
    ///   - guildId: Pre-select a specific guild
    ///   - disableGuildSelect: Disable guild selection (requires guild_id)
    ///   - scope: Additional scopes beyond bot (default includes bot scope)
    /// - Returns: Authorization URL for bot installation
    public func getAuthorizationURL(
        permissions: String,
        guildId: Snowflake? = nil,
        disableGuildSelect: Bool? = nil,
        scope: [OAuth2Scope] = []
    ) -> URL {
        var scopes = scope
        if !scopes.contains(.bot) {
            scopes.append(.bot)
        }

        return client.getAuthorizationURL(
            scopes: scopes,
            state: nil,
            prompt: .auto,
            guildId: guildId,
            disableGuildSelect: disableGuildSelect,
            permissions: permissions
        )
    }

    /// Generate bot authorization URL with permission flags
    /// - Parameters:
    ///   - permissions: Array of permission bitsets
    ///   - guildId: Pre-select a specific guild
    ///   - disableGuildSelect: Disable guild selection (requires guild_id)
    ///   - scope: Additional scopes beyond bot (default includes bot scope)
    /// - Returns: Authorization URL for bot installation
    public func getAuthorizationURL(
        permissions: [PermissionBitset],
        guildId: Snowflake? = nil,
        disableGuildSelect: Bool? = nil,
        scope: [OAuth2Scope] = []
    ) -> URL {
        let permissionBitset = permissions.reduce(PermissionBitset(rawValue: 0)) { $0.union($1) }.rawValue
        return getAuthorizationURL(
            permissions: String(permissionBitset),
            guildId: guildId,
            disableGuildSelect: disableGuildSelect,
            scope: scope
        )
    }

    /// Common permission presets for bots
    public enum BotPermissionPreset {
        case general
        case moderation
        case music
        case management

        var permissions: [PermissionBitset] {
            switch self {
            case .general:
                return [.viewChannel, .sendMessages, .readMessageHistory, .useApplicationCommands]
            case .moderation:
                return [.viewChannel, .sendMessages, .readMessageHistory, .useApplicationCommands,
                       .kickMembers, .banMembers, .manageMessages, .moderateMembers]
            case .music:
                return [.viewChannel, .sendMessages, .readMessageHistory, .useApplicationCommands,
                       .connect, .speak, .useVAD]
            case .management:
                return [.viewChannel, .sendMessages, .readMessageHistory, .useApplicationCommands,
                       .manageChannels, .manageRoles, .manageGuild]
            }
        }
    }

    /// Get authorization URL with permission preset
    /// - Parameters:
    ///   - preset: Permission preset
    ///   - guildId: Pre-select a specific guild
    ///   - disableGuildSelect: Disable guild selection (requires guild_id)
    ///   - scope: Additional scopes beyond bot (default includes bot scope)
    /// - Returns: Authorization URL for bot installation
    public func getAuthorizationURL(
        preset: BotPermissionPreset,
        guildId: Snowflake? = nil,
        disableGuildSelect: Bool? = nil,
        scope: [OAuth2Scope] = []
    ) -> URL {
        getAuthorizationURL(
            permissions: preset.permissions,
            guildId: guildId,
            disableGuildSelect: disableGuildSelect,
            scope: scope
        )
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/OAuth2/BotAuthorizationFlow.swift