//
//  OAuth2Client.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Main OAuth2 client for Discord API authentication
public class OAuth2Client: Sendable {
    private let clientId: String
    private let clientSecret: String?
    private let redirectUri: String
    private let httpClient: OAuth2HTTPClient

    /// Initialize OAuth2 client
    /// - Parameters:
    ///   - clientId: Discord application client ID
    ///   - clientSecret: Discord application client secret (optional for PKCE flows)
    ///   - redirectUri: OAuth2 redirect URI
    ///   - httpClient: HTTP client for making requests
    public init(
        clientId: String,
        clientSecret: String? = nil,
        redirectUri: String,
        httpClient: OAuth2HTTPClient = OAuth2HTTPClient()
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectUri = redirectUri
        self.httpClient = httpClient
    }

    /// Generate authorization URL for authorization code flow
    /// - Parameters:
    ///   - scopes: Array of OAuth2 scopes to request
    ///   - state: Optional state parameter for CSRF protection
    ///   - prompt: Authentication prompt behavior
    ///   - guildId: Pre-select a guild for bot authorization
    ///   - disableGuildSelect: Disable guild selection for bot authorization
    ///   - permissions: Permission bitset for bot authorization
    /// - Returns: Authorization URL to redirect user to
    public func getAuthorizationURL(
        scopes: [OAuth2Scope],
        state: String? = nil,
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
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
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
            fatalError("Failed to construct authorization URL")
        }

        return url
    }

    /// Exchange authorization code for access token
    /// - Parameters:
    ///   - code: Authorization code from redirect
    ///   - codeVerifier: PKCE code verifier (optional)
    /// - Returns: Access token response
    public func exchangeCodeForToken(
        code: String,
        codeVerifier: String? = nil
    ) async throws -> AccessToken {
        var parameters: [String: Any] = [
            "grant_type": GrantType.authorizationCode.rawValue,
            "code": code,
            "redirect_uri": redirectUri
        ]

        if let clientSecret = clientSecret {
            parameters["client_secret"] = clientSecret
        }

        if let codeVerifier = codeVerifier {
            parameters["code_verifier"] = codeVerifier
        }

        let request = try HTTPRequest(
            method: .post,
            url: "https://discord.com/api/v10/oauth2/token",
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Authorization": "Basic \(Data("\(clientId):\(clientSecret ?? "")".utf8).base64EncodedString())"
            ],
            body: .formURLEncoded(parameters)
        )

        let response: AccessToken = try await httpClient.perform(request)
        return response
    }

    /// Refresh an access token
    /// - Parameter refreshToken: Refresh token to exchange
    /// - Returns: New access token response
    public func refreshToken(_ refreshToken: String) async throws -> AccessToken {
        var parameters: [String: Any] = [
            "grant_type": GrantType.refreshToken.rawValue,
            "refresh_token": refreshToken
        ]

        if let clientSecret = clientSecret {
            parameters["client_secret"] = clientSecret
        }

        let request = try HTTPRequest(
            method: .post,
            url: "https://discord.com/api/v10/oauth2/token",
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Authorization": "Basic \(Data("\(clientId):\(clientSecret ?? "")".utf8).base64EncodedString())"
            ],
            body: .formURLEncoded(parameters)
        )

        let response: AccessToken = try await httpClient.perform(request)
        return response
    }

    /// Revoke an access token or refresh token
    /// - Parameter token: Token to revoke
    public func revokeToken(_ token: String) async throws {
        var parameters: [String: Any] = [
            "token": token
        ]

        if let clientSecret = clientSecret {
            parameters["client_secret"] = clientSecret
        }

        let request = try HTTPRequest(
            method: .post,
            url: "https://discord.com/api/v10/oauth2/token/revoke",
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Authorization": "Basic \(Data("\(clientId):\(clientSecret ?? "")".utf8).base64EncodedString())"
            ],
            body: .formURLEncoded(parameters)
        )

        try await httpClient.perform(request) as EmptyResponse
    }

    /// Get current authorization information
    /// - Parameter accessToken: Access token to use for authentication
    /// - Returns: Authorization information
    public func getCurrentAuthorization(accessToken: String) async throws -> AuthorizationInfo {
        let request = try HTTPRequest(
            method: .get,
            url: "https://discord.com/api/v10/oauth2/@me",
            headers: [
                "Authorization": "Bearer \(accessToken)"
            ]
        )

        let response: AuthorizationInfo = try await httpClient.perform(request)
        return response
    }

    /// Get client credentials token (for application-only access)
    /// - Parameter scopes: Scopes to request
    /// - Returns: Access token for application
    public func getClientCredentialsToken(scopes: [OAuth2Scope]) async throws -> AccessToken {
        guard let clientSecret = clientSecret else {
            throw OAuth2Error.clientSecretRequired
        }

        let parameters: [String: Any] = [
            "grant_type": GrantType.clientCredentials.rawValue,
            "scope": scopes.map(\.rawValue).joined(separator: " ")
        ]

        let request = try HTTPRequest(
            method: .post,
            url: "https://discord.com/api/v10/oauth2/token",
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Authorization": "Basic \(Data("\(clientId):\(clientSecret)".utf8).base64EncodedString())"
            ],
            body: .formURLEncoded(parameters)
        )

        let response: AccessToken = try await httpClient.perform(request)
        return response
    }
}

/// OAuth2-specific errors
public enum OAuth2Error: Error {
    case clientSecretRequired
    case invalidGrant
    case invalidClient
    case invalidScope
    case invalidRequest
    case unauthorizedClient
    case unsupportedGrantType
    case accessDenied
    case serverError
    case temporarilyUnavailable
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/OAuth2/OAuth2Client.swift