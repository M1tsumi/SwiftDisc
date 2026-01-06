//
//  RESTClientTests.swift
//  SwiftDiscTests
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import XCTest
@testable import SwiftDisc

final class RESTClientTests: XCTestCase {
    var restClient: RESTClient!
    var mockHTTPClient: MockHTTPClient!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        restClient = RESTClient(token: "test_token", httpClient: mockHTTPClient)
    }

    override func tearDown() {
        restClient = nil
        mockHTTPClient = nil
        super.tearDown()
    }

    // MARK: - Entitlements Tests

    func testGetEntitlements() async throws {
        let expectedEntitlements = [
            Entitlement(
                id: Snowflake("123"),
                sku_id: Snowflake("456"),
                application_id: Snowflake("789"),
                user_id: Snowflake("101112"),
                type: .purchase,
                deleted: false,
                starts_at: nil,
                ends_at: nil,
                guild_id: nil,
                consumed: false
            )
        ]

        mockHTTPClient.mockResponse = expectedEntitlements

        let entitlements = try await restClient.getEntitlements()

        XCTAssertEqual(entitlements.count, 1)
        XCTAssertEqual(entitlements[0].id, Snowflake("123"))
        XCTAssertEqual(entitlements[0].type, .purchase)
    }

    func testGetSKUs() async throws {
        let expectedSKUs = [
            SKU(
                id: Snowflake("123"),
                type: .durable,
                application_id: Snowflake("456"),
                name: "Test SKU",
                slug: "test-sku",
                flags: SKUFlags(rawValue: 0)
            )
        ]

        mockHTTPClient.mockResponse = expectedSKUs

        let skus = try await restClient.getSKUs()

        XCTAssertEqual(skus.count, 1)
        XCTAssertEqual(skus[0].name, "Test SKU")
        XCTAssertEqual(skus[0].type, .durable)
    }

    func testConsumeEntitlement() async throws {
        mockHTTPClient.mockResponse = EmptyResponse()

        try await restClient.consumeEntitlement(entitlementId: Snowflake("123"))
        // If no error is thrown, the test passes
    }

    // MARK: - Soundboard Tests

    func testGetSoundboardSounds() async throws {
        let expectedSounds = [
            SoundboardSound(
                sound_id: Snowflake("123"),
                name: "Test Sound",
                volume: 0.8,
                user_id: Snowflake("456"),
                available: true,
                guild_id: Snowflake("789"),
                emoji_id: nil,
                emoji_name: nil
            )
        ]

        mockHTTPClient.mockResponse = expectedSounds

        let sounds = try await restClient.getSoundboardSounds(guildId: Snowflake("789"))

        XCTAssertEqual(sounds.count, 1)
        XCTAssertEqual(sounds[0].name, "Test Sound")
        XCTAssertEqual(sounds[0].volume, 0.8)
    }

    func testCreateGuildSoundboardSound() async throws {
        let sound = CreateGuildSoundboardSound(
            name: "New Sound",
            sound: "base64data",
            volume: 1.0,
            emojiId: Snowflake("123"),
            emojiName: "🔊"
        )

        let expectedResponse = SoundboardSound(
            sound_id: Snowflake("456"),
            name: "New Sound",
            volume: 1.0,
            user_id: Snowflake("789"),
            available: true,
            guild_id: Snowflake("101112"),
            emoji_id: Snowflake("123"),
            emoji_name: "🔊"
        )

        mockHTTPClient.mockResponse = expectedResponse

        let response = try await restClient.createGuildSoundboardSound(
            guildId: Snowflake("101112"),
            sound: sound
        )

        XCTAssertEqual(response.name, "New Sound")
        XCTAssertEqual(response.emoji_name, "🔊")
    }

    func testSendSoundboardSound() async throws {
        mockHTTPClient.mockResponse = EmptyResponse()

        try await restClient.sendSoundboardSound(
            channelId: Snowflake("123"),
            soundId: Snowflake("456"),
            sourceGuildId: Snowflake("789")
        )
        // If no error is thrown, the test passes
    }

    // MARK: - Poll Tests

    func testCreateMessagePoll() async throws {
        let poll = CreateMessagePoll(
            question: PollMedia(text: "What's your favorite color?", emoji: nil),
            answers: [
                PollAnswer(answer_id: 1, poll_media: PollMedia(text: "Red", emoji: nil)),
                PollAnswer(answer_id: 2, poll_media: PollMedia(text: "Blue", emoji: nil))
            ],
            duration: 24,
            allowMultiselect: false,
            layoutType: .default
        )

        let expectedMessage = Message(
            id: Snowflake("123"),
            channel_id: Snowflake("456"),
            author: User(id: Snowflake("789"), username: "test", discriminator: nil, globalName: nil, avatar: nil),
            content: "",
            timestamp: Date(),
            edited_timestamp: nil,
            tts: false,
            mention_everyone: false,
            mentions: [],
            mention_roles: [],
            mention_channels: [],
            attachments: [],
            embeds: [],
            reactions: [],
            nonce: nil,
            pinned: false,
            webhook_id: nil,
            type: .default,
            activity: nil,
            application: nil,
            application_id: nil,
            message_reference: nil,
            flags: [],
            referenced_message: nil,
            interaction: nil,
            components: [],
            sticker_items: [],
            stickers: [],
            position: nil,
            role_subscription_data: nil,
            poll: nil
        )

        mockHTTPClient.mockResponse = expectedMessage

        let message = try await restClient.createMessagePoll(channelId: Snowflake("456"), poll: poll)

        XCTAssertEqual(message.channel_id, Snowflake("456"))
    }

    func testEndPoll() async throws {
        let expectedMessage = Message(
            id: Snowflake("123"),
            channel_id: Snowflake("456"),
            author: User(id: Snowflake("789"), username: "test", discriminator: nil, globalName: nil, avatar: nil),
            content: "",
            timestamp: Date(),
            edited_timestamp: nil,
            tts: false,
            mention_everyone: false,
            mentions: [],
            mention_roles: [],
            mention_channels: [],
            attachments: [],
            embeds: [],
            reactions: [],
            nonce: nil,
            pinned: false,
            webhook_id: nil,
            type: .default,
            activity: nil,
            application: nil,
            application_id: nil,
            message_reference: nil,
            flags: [],
            referenced_message: nil,
            interaction: nil,
            components: [],
            sticker_items: [],
            stickers: [],
            position: nil,
            role_subscription_data: nil,
            poll: nil
        )

        mockHTTPClient.mockResponse = expectedMessage

        let message = try await restClient.endPoll(channelId: Snowflake("456"), messageId: Snowflake("123"))

        XCTAssertEqual(message.id, Snowflake("123"))
    }

    func testGetPollVoters() async throws {
        let expectedVoters = [
            PollVoter(user: User(id: Snowflake("123"), username: "user1", discriminator: nil, globalName: nil, avatar: nil)),
            PollVoter(user: User(id: Snowflake("456"), username: "user2", discriminator: nil, globalName: nil, avatar: nil))
        ]

        mockHTTPClient.mockResponse = expectedVoters

        let voters = try await restClient.getPollVoters(
            channelId: Snowflake("789"),
            messageId: Snowflake("101"),
            answerId: 1
        )

        XCTAssertEqual(voters.count, 2)
        XCTAssertEqual(voters[0].user.username, "user1")
        XCTAssertEqual(voters[1].user.username, "user2")
    }

    // MARK: - User Profile Tests

    func testGetUserConnections() async throws {
        let expectedConnections = [
            UserConnection(
                id: "123",
                name: "Test Connection",
                type: "twitch",
                revoked: false,
                integrations: [],
                verified: true,
                friend_sync: false,
                show_activity: true,
                two_way_link: false,
                visibility: .everyone
            )
        ]

        mockHTTPClient.mockResponse = expectedConnections

        let connections = try await restClient.getUserConnections()

        XCTAssertEqual(connections.count, 1)
        XCTAssertEqual(connections[0].type, "twitch")
        XCTAssertEqual(connections[0].visibility, .everyone)
    }

    func testGetUserApplicationRoleConnection() async throws {
        let expectedConnection = ApplicationRoleConnection(
            platformName: "Test Platform",
            platformUsername: "testuser",
            metadata: ["key": "value"]
        )

        mockHTTPClient.mockResponse = expectedConnection

        let connection = try await restClient.getUserApplicationRoleConnection(applicationId: Snowflake("123"))

        XCTAssertEqual(connection.platformName, "Test Platform")
        XCTAssertEqual(connection.platformUsername, "testuser")
    }

    func testUpdateUserApplicationRoleConnection() async throws {
        let connection = ApplicationRoleConnection(
            platformName: "Updated Platform",
            platformUsername: "updateduser",
            metadata: ["newkey": "newvalue"]
        )

        mockHTTPClient.mockResponse = connection

        let updated = try await restClient.updateUserApplicationRoleConnection(
            applicationId: Snowflake("123"),
            connection: connection
        )

        XCTAssertEqual(updated.platformName, "Updated Platform")
        XCTAssertEqual(updated.metadata["newkey"], "newvalue")
    }

    // MARK: - Subscription Tests

    func testListApplicationSubscriptions() async throws {
        let expectedSubscriptions = [
            Subscription(
                id: Snowflake("123"),
                user_id: Snowflake("456"),
                sku_ids: [Snowflake("789")],
                entitlement_ids: [Snowflake("101")],
                status: .active,
                canceled_at: nil,
                country: "US"
            )
        ]

        mockHTTPClient.mockResponse = expectedSubscriptions

        let subscriptions = try await restClient.listApplicationSubscriptions()

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(subscriptions[0].status, .active)
        XCTAssertEqual(subscriptions[0].country, "US")
    }

    func testGetSubscriptionInfo() async throws {
        let expectedSubscriptions = [
            Subscription(
                id: Snowflake("123"),
                user_id: Snowflake("456"),
                sku_ids: [Snowflake("789")],
                entitlement_ids: [Snowflake("101")],
                status: .active,
                canceled_at: nil,
                country: nil
            )
        ]

        mockHTTPClient.mockResponse = expectedSubscriptions

        let subscriptions = try await restClient.getSubscriptionInfo(guildId: Snowflake("999"))

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(subscriptions[0].user_id, Snowflake("456"))
    }
}

// MARK: - Mock Classes

class MockHTTPClient: HTTPClient {
    var mockResponse: Encodable?

    init() {
        // Create a minimal configuration for testing
        let config = DiscordConfiguration()
        super.init(token: "test_token", configuration: config)
    }

    override func get<T: Decodable>(path: String) async throws -> T {
        guard let response = mockResponse as? T else {
            throw DiscordError.decoding(NSError(domain: "MockError", code: -1))
        }
        return response
    }

    override func post<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        guard let response = mockResponse as? T else {
            throw DiscordError.decoding(NSError(domain: "MockError", code: -1))
        }
        return response
    }

    override func patch<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        guard let response = mockResponse as? T else {
            throw DiscordError.decoding(NSError(domain: "MockError", code: -1))
        }
        return response
    }

    override func put<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        guard let response = mockResponse as? T else {
            throw DiscordError.decoding(NSError(domain: "MockError", code: -1))
        }
        return response
    }

    override func delete<T: Decodable>(path: String) async throws -> T {
        guard let response = mockResponse as? T else {
            throw DiscordError.decoding(NSError(domain: "MockError", code: -1))
        }
        return response
    }

    override func delete(path: String) async throws {
        // No-op for testing
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Tests/SwiftDiscTests/RESTClientTests.swift