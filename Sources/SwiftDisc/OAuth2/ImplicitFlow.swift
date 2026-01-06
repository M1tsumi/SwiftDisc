//
//  ImplicitFlow.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Implicit Grant Flow implementation
/// Note: Implicit flow is less secure than authorization code flow and is being phased out by OAuth2 spec.
/// Use AuthorizationCodeFlow with PKCE instead when possible.
public class ImplicitFlow: Sendable {
    private let client: OAuth2Client
    private let state: String?

    /// Initialize implicit flow
    /// - Parameters:
    ///   - client: OAuth2 client
    ///   - state: State parameter for CSRF protection
    public init(client: OAuth2Client, state: String? = nil) {
        self.client = client
        self.state = state
    }

    /// Generate authorization URL for implicit flow
    /// - Parameters:
    ///   - scopes: Scopes to request
    ///   - prompt: Authentication prompt
    ///   - guildId: Pre-select guild for bot authorization
    ///   - disableGuildSelect: Disable guild selection
    ///   - permissions: Permission bitset for bot authorization
    /// - Returns: Authorization URL
    public func getAuthorizationURL(
        scopes: [OAuth2Scope],
        prompt: AuthPrompt = .auto,
        guildId: Snowflake? = nil,
        disableGuildSelect: Bool? = nil,
        permissions: String? = nil
    ) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "discord.com"
        components.path = "/api/oauth2/authorize"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: client.clientId),
            URLQueryItem(name: "response_type", value: "token"),
            URLQueryItem(name: "scope", value: scopes.map(\.rawValue).joined(separator: " "))
        ]

        if let state = state {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }

        if prompt != .auto {
            queryItems.append(URLQueryItem(name: "prompt", value: prompt.rawValue))
        }

        if let guildId = guildId {
            queryItems.append(URLQueryItem(name: "guild_id", value: guildId.description))
        }

        if let disableGuildSelect = disableGuildSelect, disableGuildSelect {
            queryItems.append(URLQueryItem(name: "disable_guild_select", value: "true"))
        }

        if let permissions = permissions {
            queryItems.append(URLQueryItem(name: "permissions", value: permissions))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            fatalError("Failed to construct implicit authorization URL")
        }

        return url
    }

    /// Parse access token from redirect URL fragment
    /// - Parameter url: Redirect URL with fragment containing token
    /// - Returns: Access token if successfully parsed
    public func parseTokenFromRedirectURL(_ url: URL) -> AccessToken? {
        guard let fragment = url.fragment else { return nil }

        let components = URLComponents(string: "?\(fragment)")
        guard let queryItems = components?.queryItems else { return nil }

        var tokenType: String?
        var accessToken: String?
        var expiresIn: Int?
        var scope: String?

        for item in queryItems {
            switch item.name {
            case "token_type":
                tokenType = item.value
            case "access_token":
                accessToken = item.value
            case "expires_in":
                expiresIn = Int(item.value ?? "")
            case "scope":
                scope = item.value
            default:
                break
            }
        }

        guard let token = accessToken,
              let type = tokenType,
              let expires = expiresIn,
              let scopes = scope else {
            return nil
        }

        return AccessToken(
            access_token: token,
            token_type: type,
            expires_in: expires,
            refresh_token: nil,
            scope: scopes
        )
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/OAuth2/ImplicitFlow.swift