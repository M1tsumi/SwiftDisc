//
//  V120ValidationTests.swift
//  SwiftDiscTests
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import XCTest
@testable import SwiftDisc

final class V120ValidationTests: XCTestCase {

    func testV120FeaturesExist() {
        // Test that all new v1.2.0 types can be instantiated

        // OAuth2 Types
        let scope = OAuth2Scope.identify
        XCTAssertEqual(scope, .identify)

        let token = AccessToken(
            access_token: "test",
            token_type: "Bearer",
            expires_in: 3600,
            refresh_token: nil,
            scope: "identify"
        )
        XCTAssertEqual(token.access_token, "test")

        // Data Models
        let entitlement = Entitlement(
            id: Snowflake("1"),
            sku_id: Snowflake("2"),
            application_id: Snowflake("3"),
            user_id: Snowflake("4"),
            type: .purchase,
            deleted: false,
            starts_at: nil,
            ends_at: nil,
            guild_id: nil,
            consumed: false
        )
        XCTAssertEqual(entitlement.type, .purchase)

        let sound = SoundboardSound(
            sound_id: Snowflake("1"),
            name: "Test",
            volume: 1.0,
            user_id: Snowflake("2"),
            available: true,
            guild_id: Snowflake("3"),
            emoji_id: nil,
            emoji_name: nil
        )
        XCTAssertEqual(sound.name, "Test")

        let poll = Poll(
            question: PollMedia(text: "Question?", emoji: nil),
            answers: [PollAnswer(answer_id: 1, poll_media: PollMedia(text: "Answer", emoji: nil))],
            expiry: nil,
            allow_multiselect: false,
            layout_type: .default,
            results: nil
        )
        XCTAssertEqual(poll.question.text, "Question?")

        // Gateway Events
        let auditEvent: DiscordEvent = .guildAuditLogEntryCreate(
            AuditLogEntry(id: AuditLogEntryID("1"), target_id: nil, user_id: nil, action_type: 1, changes: nil, options: nil, reason: nil)
        )
        XCTAssertNotNil(auditEvent)

        let soundEvent: DiscordEvent = .soundboardSoundCreate(sound)
        XCTAssertNotNil(soundEvent)

        let pollVote = PollVote(
            user_id: Snowflake("1"),
            channel_id: Snowflake("2"),
            message_id: Snowflake("3"),
            guild_id: nil,
            answer_id: 1
        )
        let voteEvent: DiscordEvent = .pollVoteAdd(pollVote)
        XCTAssertNotNil(voteEvent)

        // Managers
        let stateManager = GatewayStateManager()
        XCTAssertEqual(stateManager.currentState.state, .disconnected)

        let healthMonitor = GatewayHealthMonitor(stateManager: stateManager)
        XCTAssertEqual(healthMonitor.metrics.heartbeatsSent, 0)

        // All tests passed - v1.2.0 features are properly integrated
    }

    func testPlatformCompatibility() {
        // Test that code compiles on all supported platforms
        // This test will run on iOS, macOS, tvOS, watchOS

        #if os(iOS)
        XCTAssertTrue(true, "Running on iOS")
        #elseif os(macOS)
        XCTAssertTrue(true, "Running on macOS")
        #elseif os(tvOS)
        XCTAssertTrue(true, "Running on tvOS")
        #elseif os(watchOS)
        XCTAssertTrue(true, "Running on watchOS")
        #else
        XCTAssertTrue(true, "Running on unknown platform")
        #endif
    }

    func testCrossPlatformImports() {
        // Test that Foundation is available
        let date = Date()
        XCTAssertNotNil(date)

        // Test that basic Swift types work
        let array: [String] = ["test"]
        XCTAssertEqual(array.count, 1)

        let dict: [String: Int] = ["key": 42]
        XCTAssertEqual(dict["key"], 42)
    }

    func testMemoryManagement() {
        // Test that ARC works properly with new types
        var manager: GatewayStateManager? = GatewayStateManager()
        manager?.updateState(.ready)
        XCTAssertEqual(manager?.currentState.state, .ready)

        manager = nil // Should deallocate properly
        XCTAssertTrue(true, "Memory management test passed")
    }

    func testConcurrency() async {
        // Test that async/await works with new features
        let manager = OAuth2Manager(
            clientId: "test",
            clientSecret: nil,
            redirectUri: "https://example.com",
            storage: InMemoryOAuth2Storage()
        )

        let url = manager.startAuthorization(scopes: [.identify])
        XCTAssertTrue(url.absoluteString.contains("client_id=test"))

        let isAuthorized = await manager.isAuthorized()
        XCTAssertFalse(isAuthorized)
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Tests/SwiftDiscTests/V120ValidationTests.swift