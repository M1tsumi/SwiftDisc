//
//  OAuth2Manager.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// High-level OAuth2 manager for Discord API authentication
public class OAuth2Manager: Sendable {
    private let client: OAuth2Client
    private let storage: OAuth2Storage
    private let tokenRefreshQueue = DispatchQueue(label: "com.swiftdisc.oauth2.refresh")

    /// Initialize OAuth2 manager
    /// - Parameters:
    ///   - clientId: Discord application client ID
    ///   - clientSecret: Discord application client secret
    ///   - redirectUri: OAuth2 redirect URI
    ///   - storage: Storage for tokens and grants
    public init(
        clientId: String,
        clientSecret: String? = nil,
        redirectUri: String,
        storage: OAuth2Storage = InMemoryOAuth2Storage()
    ) {
        self.client = OAuth2Client(
            clientId: clientId,
            clientSecret: clientSecret,
            redirectUri: redirectUri
        )
        self.storage = storage
    }

    /// Start OAuth2 authorization flow
    /// - Parameters:
    ///   - scopes: Scopes to request
    ///   - state: State parameter for CSRF protection
    ///   - prompt: Authentication prompt
    /// - Returns: Authorization URL to redirect user to
    public func startAuthorization(
        scopes: [OAuth2Scope],
        state: String? = nil,
        prompt: AuthPrompt = .auto
    ) -> URL {
        client.getAuthorizationURL(
            scopes: scopes,
            state: state,
            prompt: prompt
        )
    }

    /// Complete authorization with code from redirect
    /// - Parameters:
    ///   - code: Authorization code
    ///   - state: State parameter (should match what was sent)
    ///   - codeVerifier: PKCE code verifier
    /// - Returns: Authorization grant
    public func completeAuthorization(
        code: String,
        state: String? = nil,
        codeVerifier: String? = nil
    ) async throws -> AuthorizationGrant {
        let token = try await client.exchangeCodeForToken(
            code: code,
            codeVerifier: codeVerifier
        )

        let grant = AuthorizationGrant(
            accessToken: token.access_token,
            refreshToken: token.refresh_token,
            scopes: token.scopes,
            expiresAt: token.expiresAt,
            userId: nil // Will be populated when we get user info
        )

        try await storage.storeGrant(grant)
        return grant
    }

    /// Get valid access token, refreshing if necessary
    /// - Parameter userId: User ID to get token for
    /// - Returns: Valid access token
    public func getValidAccessToken(for userId: Snowflake? = nil) async throws -> String {
        guard let grant = try await storage.getGrant(for: userId) else {
            throw OAuth2Error.invalidGrant
        }

        if !grant.isExpired {
            return grant.accessToken
        }

        guard let refreshToken = grant.refreshToken else {
            throw OAuth2Error.invalidGrant
        }

        // Refresh token
        let newToken = try await client.refreshToken(refreshToken)

        let updatedGrant = AuthorizationGrant(
            accessToken: newToken.access_token,
            refreshToken: newToken.refresh_token ?? refreshToken,
            scopes: newToken.scopes,
            expiresAt: newToken.expiresAt,
            userId: grant.userId
        )

        try await storage.storeGrant(updatedGrant)
        return updatedGrant.accessToken
    }

    /// Revoke authorization for a user
    /// - Parameter userId: User ID to revoke authorization for
    public func revokeAuthorization(for userId: Snowflake? = nil) async throws {
        guard let grant = try await storage.getGrant(for: userId) else {
            return
        }

        try await client.revokeToken(grant.accessToken)
        try await storage.removeGrant(for: userId)
    }

    /// Get current user information
    /// - Parameter userId: User ID to get info for
    /// - Returns: Authorization info with user details
    public func getCurrentUser(for userId: Snowflake? = nil) async throws -> AuthorizationInfo {
        let accessToken = try await getValidAccessToken(for: userId)
        return try await client.getCurrentAuthorization(accessToken: accessToken)
    }

    /// Check if user is authorized
    /// - Parameter userId: User ID to check
    /// - Returns: True if user has valid authorization
    public func isAuthorized(for userId: Snowflake? = nil) async -> Bool {
        do {
            let grant = try await storage.getGrant(for: userId)
            return grant?.isExpired == false
        } catch {
            return false
        }
    }

    /// Get client credentials token for application-only access
    /// - Parameter scopes: Scopes to request
    /// - Returns: Access token for application
    public func getClientCredentialsToken(scopes: [OAuth2Scope]) async throws -> AccessToken {
        try await client.getClientCredentialsToken(scopes: scopes)
    }
}

/// Protocol for OAuth2 token storage
public protocol OAuth2Storage: Sendable {
    func storeGrant(_ grant: AuthorizationGrant) async throws
    func getGrant(for userId: Snowflake?) async throws -> AuthorizationGrant?
    func removeGrant(for userId: Snowflake?) async throws
}

/// In-memory OAuth2 storage implementation
public class InMemoryOAuth2Storage: OAuth2Storage {
    private var grants: [String: AuthorizationGrant] = [:]
    private let queue = DispatchQueue(label: "com.swiftdisc.oauth2.storage")

    public init() {}

    public func storeGrant(_ grant: AuthorizationGrant) async throws {
        await withCheckedContinuation { continuation in
            queue.async {
                let key = grant.userId?.description ?? "default"
                self.grants[key] = grant
                continuation.resume()
            }
        }
    }

    public func getGrant(for userId: Snowflake?) async throws -> AuthorizationGrant? {
        await withCheckedContinuation { continuation in
            queue.async {
                let key = userId?.description ?? "default"
                let grant = self.grants[key]
                continuation.resume(returning: grant)
            }
        }
    }

    public func removeGrant(for userId: Snowflake?) async throws {
        await withCheckedContinuation { continuation in
            queue.async {
                let key = userId?.description ?? "default"
                self.grants.removeValue(forKey: key)
                continuation.resume()
            }
        }
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/OAuth2/OAuth2Manager.swift