//
//  AuthorizationCodeFlow.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation
import CryptoKit

/// Authorization Code Flow implementation with PKCE support
public class AuthorizationCodeFlow: Sendable {
    private let client: OAuth2Client
    private let codeVerifier: String
    private let codeChallenge: String
    private let state: String?

    /// Initialize authorization code flow
    /// - Parameters:
    ///   - client: OAuth2 client
    ///   - state: State parameter for CSRF protection
    public init(client: OAuth2Client, state: String? = nil) {
        self.client = client
        self.state = state

        // Generate PKCE code verifier and challenge
        self.codeVerifier = Self.generateCodeVerifier()
        self.codeChallenge = Self.generateCodeChallenge(from: codeVerifier)
    }

    /// Generate authorization URL with PKCE
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
        var url = client.getAuthorizationURL(
            scopes: scopes,
            state: state,
            prompt: prompt,
            guildId: guildId,
            disableGuildSelect: disableGuildSelect,
            permissions: permissions
        )

        // Add PKCE parameters
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems?.append(URLQueryItem(name: "code_challenge", value: codeChallenge))
        components?.queryItems?.append(URLQueryItem(name: "code_challenge_method", value: "S256"))

        guard let finalURL = components?.url else {
            fatalError("Failed to construct authorization URL with PKCE")
        }

        return finalURL
    }

    /// Exchange authorization code for tokens
    /// - Parameter code: Authorization code from redirect
    /// - Returns: Access token response
    public func exchangeCodeForToken(code: String) async throws -> AccessToken {
        try await client.exchangeCodeForToken(code: code, codeVerifier: codeVerifier)
    }

    /// Generate cryptographically secure code verifier
    private static func generateCodeVerifier() -> String {
        let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        let data = Data(bytes)
        return data.base64URLEncodedString()
    }

    /// Generate code challenge from code verifier using SHA256
    private static func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }
}

private extension Data {
    /// Base64 URL-safe encoding
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/OAuth2/AuthorizationCodeFlow.swift