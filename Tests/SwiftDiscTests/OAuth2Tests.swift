//
//  OAuth2Tests.swift
//  SwiftDiscTests
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import XCTest
@testable import SwiftDisc

final class OAuth2Tests: XCTestCase {
    var oauth2Client: OAuth2Client!
    var mockHTTPClient: MockOAuth2HTTPClient!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockOAuth2HTTPClient()
        oauth2Client = OAuth2Client(
            clientId: "test_client_id",
            clientSecret: "test_client_secret",
            redirectUri: "https://example.com/callback",
            httpClient: mockHTTPClient
        )
    }

    override func tearDown() {
        oauth2Client = nil
        mockHTTPClient = nil
        super.tearDown()
    }

    // MARK: - OAuth2Client Tests

    func testGetAuthorizationURL() {
        let scopes: [OAuth2Scope] = [.identify, .email]
        let url = oauth2Client.getAuthorizationURL(scopes: scopes, state: "test_state")

        XCTAssertTrue(url.absoluteString.contains("client_id=test_client_id"))
        XCTAssertTrue(url.absoluteString.contains("redirect_uri=https://example.com/callback"))
        XCTAssertTrue(url.absoluteString.contains("response_type=code"))
        XCTAssertTrue(url.absoluteString.contains("scope=identify%20email"))
        XCTAssertTrue(url.absoluteString.contains("state=test_state"))
    }

    func testGetAuthorizationURLWithGuild() {
        let scopes: [OAuth2Scope] = [.bot]
        let url = oauth2Client.getAuthorizationURL(
            scopes: scopes,
            guildId: Snowflake("123456789"),
            disableGuildSelect: true,
            permissions: "8"
        )

        XCTAssertTrue(url.absoluteString.contains("guild_id=123456789"))
        XCTAssertTrue(url.absoluteString.contains("disable_guild_select=true"))
        XCTAssertTrue(url.absoluteString.contains("permissions=8"))
    }

    func testExchangeCodeForToken() async throws {
        let expectedToken = AccessToken(
            access_token: "test_access_token",
            token_type: "Bearer",
            expires_in: 604800,
            refresh_token: "test_refresh_token",
            scope: "identify email"
        )

        mockHTTPClient.mockResponse = expectedToken

        let token = try await oauth2Client.exchangeCodeForToken(code: "test_code")

        XCTAssertEqual(token.access_token, "test_access_token")
        XCTAssertEqual(token.token_type, "Bearer")
        XCTAssertEqual(token.expires_in, 604800)
        XCTAssertEqual(token.refresh_token, "test_refresh_token")
        XCTAssertEqual(token.scope, "identify email")
        XCTAssertEqual(token.scopes, [.identify, .email])
    }

    func testRefreshToken() async throws {
        let expectedToken = AccessToken(
            access_token: "new_access_token",
            token_type: "Bearer",
            expires_in: 604800,
            refresh_token: "new_refresh_token",
            scope: "identify email"
        )

        mockHTTPClient.mockResponse = expectedToken

        let token = try await oauth2Client.refreshToken("old_refresh_token")

        XCTAssertEqual(token.access_token, "new_access_token")
        XCTAssertEqual(token.refresh_token, "new_refresh_token")
    }

    func testRevokeToken() async throws {
        mockHTTPClient.mockResponse = EmptyResponse()

        try await oauth2Client.revokeToken("test_token")
        // If no error is thrown, the test passes
    }

    func testGetCurrentAuthorization() async throws {
        let expectedAuth = AuthorizationInfo(
            application: OAuth2Application(
                id: Snowflake("123456789"),
                name: "Test App",
                icon: nil,
                description: "Test Description",
                rpcOrigins: nil,
                botPublic: true,
                botRequireCodeGrant: false,
                botPermissions: nil,
                termsOfServiceUrl: nil,
                privacyPolicyUrl: nil,
                owner: nil,
                team: nil,
                guildId: nil,
                primarySkuId: nil,
                slug: nil,
                coverImage: nil,
                flags: nil,
                approximateGuildCount: nil,
                redirectUris: nil,
                interactionsEndpointUrl: nil,
                roleConnectionsVerificationUrl: nil,
                tags: nil,
                installParams: nil,
                integrationTypesConfig: nil,
                customInstallUrl: nil
            ),
            scopes: ["identify", "email"],
            expires: nil,
            user: nil
        )

        mockHTTPClient.mockResponse = expectedAuth

        let auth = try await oauth2Client.getCurrentAuthorization(accessToken: "test_token")

        XCTAssertEqual(auth.application.id, Snowflake("123456789"))
        XCTAssertEqual(auth.application.name, "Test App")
        XCTAssertEqual(auth.scopes, ["identify", "email"])
    }

    func testGetClientCredentialsToken() async throws {
        let expectedToken = AccessToken(
            access_token: "app_access_token",
            token_type: "Bearer",
            expires_in: 604800,
            refresh_token: nil,
            scope: "applications.commands"
        )

        mockHTTPClient.mockResponse = expectedToken

        let token = try await oauth2Client.getClientCredentialsToken(scopes: [.applicationsCommands])

        XCTAssertEqual(token.access_token, "app_access_token")
        XCTAssertNil(token.refresh_token)
    }

    // MARK: - OAuth2Manager Tests

    func testOAuth2ManagerStartAuthorization() {
        let manager = OAuth2Manager(
            clientId: "test_client_id",
            clientSecret: "test_client_secret",
            redirectUri: "https://example.com/callback"
        )

        let url = manager.startAuthorization(scopes: [.identify], state: "test_state")

        XCTAssertTrue(url.absoluteString.contains("client_id=test_client_id"))
        XCTAssertTrue(url.absoluteString.contains("state=test_state"))
    }

    func testOAuth2ManagerCompleteAuthorization() async throws {
        let manager = OAuth2Manager(
            clientId: "test_client_id",
            clientSecret: "test_client_secret",
            redirectUri: "https://example.com/callback",
            storage: InMemoryOAuth2Storage()
        )

        let expectedToken = AccessToken(
            access_token: "test_token",
            token_type: "Bearer",
            expires_in: 3600,
            refresh_token: "refresh_token",
            scope: "identify"
        )

        mockHTTPClient.mockResponse = expectedToken

        let grant = try await manager.completeAuthorization(code: "test_code", state: "test_state")

        XCTAssertEqual(grant.accessToken, "test_token")
        XCTAssertEqual(grant.refreshToken, "refresh_token")
        XCTAssertEqual(grant.scopes, [.identify])
    }

    // MARK: - AuthorizationCodeFlow Tests

    func testAuthorizationCodeFlow() {
        let flow = AuthorizationCodeFlow(client: oauth2Client, state: "test_state")

        let url = flow.getAuthorizationURL(scopes: [.identify])

        XCTAssertTrue(url.absoluteString.contains("code_challenge="))
        XCTAssertTrue(url.absoluteString.contains("code_challenge_method=S256"))
        XCTAssertTrue(url.absoluteString.contains("state=test_state"))
    }

    // MARK: - BotAuthorizationFlow Tests

    func testBotAuthorizationFlow() {
        let flow = BotAuthorizationFlow(client: oauth2Client)

        let url = flow.getAuthorizationURL(permissions: "8", guildId: Snowflake("123"))

        XCTAssertTrue(url.absoluteString.contains("permissions=8"))
        XCTAssertTrue(url.absoluteString.contains("guild_id=123"))
    }

    func testBotAuthorizationFlowWithPresets() {
        let flow = BotAuthorizationFlow(client: oauth2Client)

        let url = flow.getAuthorizationURL(preset: .general)

        XCTAssertTrue(url.absoluteString.contains("scope=bot"))
        XCTAssertTrue(url.absoluteString.contains("permissions="))
    }
}

// MARK: - Mock Classes

class MockOAuth2HTTPClient: OAuth2HTTPClient {
    var mockResponse: Encodable?

    override func perform<T: Decodable>(_ request: HTTPRequest) async throws -> T {
        guard let response = mockResponse as? T else {
            throw OAuth2Error.serverError
        }
        return response
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Tests/SwiftDiscTests/OAuth2Tests.swift