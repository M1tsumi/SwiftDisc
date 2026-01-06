//
//  ClientCredentialsFlow.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Client Credentials Flow for application-only access
public class ClientCredentialsFlow: Sendable {
    private let client: OAuth2Client

    /// Initialize client credentials flow
    /// - Parameter client: OAuth2 client with client secret
    public init(client: OAuth2Client) {
        self.client = client
    }

    /// Get access token for application-only access
    /// - Parameter scopes: Scopes to request (must be application-level scopes)
    /// - Returns: Access token for application
    public func getAccessToken(scopes: [OAuth2Scope]) async throws -> AccessToken {
        try await client.getClientCredentialsToken(scopes: scopes)
    }

    /// Validate that requested scopes are appropriate for client credentials
    /// - Parameter scopes: Scopes to validate
    /// - Returns: True if all scopes are valid for client credentials
    public func validateScopesForClientCredentials(_ scopes: [OAuth2Scope]) -> Bool {
        let validScopes: Set<OAuth2Scope> = [
            .applicationsCommandsUpdate,
            .applicationsEntitlements,
            .applicationsBuildsRead,
            .applicationsBuildsUpload,
            .applicationsStoreUpdate,
            .bot,
            .webhookIncoming
        ]

        return scopes.allSatisfy { validScopes.contains($0) }
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/OAuth2/ClientCredentialsFlow.swift