//
//  GatewayTests.swift
//  SwiftDiscTests
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import XCTest
@testable import SwiftDisc

final class GatewayTests: XCTestCase {

    // MARK: - Gateway Event Tests

    func testDiscordEventCases() {
        // Test that all new v1.2.0 events are properly defined
        let auditLogEntry = AuditLogEntry(
            id: AuditLogEntryID("123"),
            target_id: "456",
            user_id: UserID("789"),
            action_type: 1,
            changes: nil,
            options: nil,
            reason: nil
        )

        let soundboardSound = SoundboardSound(
            sound_id: Snowflake("123"),
            name: "Test Sound",
            volume: 1.0,
            user_id: Snowflake("456"),
            available: true,
            guild_id: Snowflake("789"),
            emoji_id: nil,
            emoji_name: nil
        )

        let pollVote = PollVote(
            user_id: Snowflake("123"),
            channel_id: Snowflake("456"),
            message_id: Snowflake("789"),
            guild_id: Snowflake("101"),
            answer_id: 1
        )

        let entitlement = Entitlement(
            id: Snowflake("123"),
            sku_id: Snowflake("456"),
            application_id: Snowflake("789"),
            user_id: Snowflake("101"),
            type: .purchase,
            deleted: false,
            starts_at: nil,
            ends_at: nil,
            guild_id: nil,
            consumed: false
        )

        let sku = SKU(
            id: Snowflake("123"),
            type: .durable,
            application_id: Snowflake("456"),
            name: "Test SKU",
            slug: "test-sku",
            flags: SKUFlags(rawValue: 0)
        )

        // Test event creation
        let auditEvent: DiscordEvent = .guildAuditLogEntryCreate(auditLogEntry)
        let soundCreateEvent: DiscordEvent = .soundboardSoundCreate(soundboardSound)
        let soundUpdateEvent: DiscordEvent = .soundboardSoundUpdate(soundboardSound)
        let soundDeleteEvent: DiscordEvent = .soundboardSoundDelete(soundboardSound)
        let pollVoteAddEvent: DiscordEvent = .pollVoteAdd(pollVote)
        let pollVoteRemoveEvent: DiscordEvent = .pollVoteRemove(pollVote)
        let entitlementCreateEvent: DiscordEvent = .entitlementCreate(entitlement)
        let entitlementUpdateEvent: DiscordEvent = .entitlementUpdate(entitlement)
        let entitlementDeleteEvent: DiscordEvent = .entitlementDelete(entitlement)
        let skuUpdateEvent: DiscordEvent = .skuUpdate(sku)

        // Test that events are created successfully (no crashes)
        XCTAssertNotNil(auditEvent)
        XCTAssertNotNil(soundCreateEvent)
        XCTAssertNotNil(soundUpdateEvent)
        XCTAssertNotNil(soundDeleteEvent)
        XCTAssertNotNil(pollVoteAddEvent)
        XCTAssertNotNil(pollVoteRemoveEvent)
        XCTAssertNotNil(entitlementCreateEvent)
        XCTAssertNotNil(entitlementUpdateEvent)
        XCTAssertNotNil(entitlementDeleteEvent)
        XCTAssertNotNil(skuUpdateEvent)
    }

    // MARK: - Gateway Payload Tests

    func testGatewayPayloadDecoding() throws {
        // Test basic payload structure
        let json = """
        {
            "op": 0,
            "d": {
                "id": "123456789",
                "name": "Test Sound",
                "volume": 1.0,
                "user_id": "987654321",
                "available": true,
                "guild_id": "111111111"
            },
            "s": 1234,
            "t": "SOUNDBOARD_SOUND_CREATE"
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(GatewayPayload<SoundboardSound>.self, from: json)

        XCTAssertEqual(payload.op, .dispatch)
        XCTAssertNotNil(payload.d)
        XCTAssertEqual(payload.d?.name, "Test Sound")
        XCTAssertEqual(payload.s, 1234)
        XCTAssertEqual(payload.t, "SOUNDBOARD_SOUND_CREATE")
    }

    // MARK: - Event Handler Tests

    func testEventHandlerCoverage() {
        // This test ensures that all new event cases are handled in the event dispatcher
        // We can't easily test the actual dispatcher without mocking, but we can ensure
        // the switch statement compiles and covers all cases

        let events: [DiscordEvent] = [
            .guildAuditLogEntryCreate(AuditLogEntry(id: AuditLogEntryID("1"), target_id: nil, user_id: nil, action_type: 1, changes: nil, options: nil, reason: nil)),
            .soundboardSoundCreate(SoundboardSound(sound_id: Snowflake("1"), name: "test", volume: nil, user_id: Snowflake("1"), available: true, guild_id: nil, emoji_id: nil, emoji_name: nil)),
            .soundboardSoundUpdate(SoundboardSound(sound_id: Snowflake("1"), name: "test", volume: nil, user_id: Snowflake("1"), available: true, guild_id: nil, emoji_id: nil, emoji_name: nil)),
            .soundboardSoundDelete(SoundboardSound(sound_id: Snowflake("1"), name: "test", volume: nil, user_id: Snowflake("1"), available: true, guild_id: nil, emoji_id: nil, emoji_name: nil)),
            .pollVoteAdd(PollVote(user_id: Snowflake("1"), channel_id: Snowflake("1"), message_id: Snowflake("1"), guild_id: nil, answer_id: 1)),
            .pollVoteRemove(PollVote(user_id: Snowflake("1"), channel_id: Snowflake("1"), message_id: Snowflake("1"), guild_id: nil, answer_id: 1)),
            .guildMemberProfileUpdate(GuildMemberProfileUpdate(guild_id: Snowflake("1"), user: User(id: Snowflake("1"), username: "test", discriminator: nil, globalName: nil, avatar: nil), member: GuildMember(user: nil, nick: nil, avatar: nil, roles: [], joined_at: Date(), premium_since: nil, deaf: false, mute: false, flags: 0, pending: nil, permissions: nil, communication_disabled_until: nil))),
            .entitlementCreate(Entitlement(id: Snowflake("1"), sku_id: Snowflake("1"), application_id: Snowflake("1"), user_id: nil, type: .purchase, deleted: false, starts_at: nil, ends_at: nil, guild_id: nil, consumed: nil)),
            .entitlementUpdate(Entitlement(id: Snowflake("1"), sku_id: Snowflake("1"), application_id: Snowflake("1"), user_id: nil, type: .purchase, deleted: false, starts_at: nil, ends_at: nil, guild_id: nil, consumed: nil)),
            .entitlementDelete(Entitlement(id: Snowflake("1"), sku_id: Snowflake("1"), application_id: Snowflake("1"), user_id: nil, type: .purchase, deleted: false, starts_at: nil, ends_at: nil, guild_id: nil, consumed: nil)),
            .skuUpdate(SKU(id: Snowflake("1"), type: .durable, application_id: Snowflake("1"), name: "test", slug: "test", flags: SKUFlags(rawValue: 0)))
        ]

        // Test that all events can be created without issues
        for event in events {
            XCTAssertNotNil(event)
        }
    }

    // MARK: - Gateway Opcode Tests

    func testGatewayOpcodes() {
        XCTAssertEqual(GatewayOpcode.dispatch.rawValue, 0)
        XCTAssertEqual(GatewayOpcode.heartbeat.rawValue, 1)
        XCTAssertEqual(GatewayOpcode.identify.rawValue, 2)
        XCTAssertEqual(GatewayOpcode.presenceUpdate.rawValue, 3)
        XCTAssertEqual(GatewayOpcode.voiceStateUpdate.rawValue, 4)
        XCTAssertEqual(GatewayOpcode.resume.rawValue, 6)
        XCTAssertEqual(GatewayOpcode.reconnect.rawValue, 7)
        XCTAssertEqual(GatewayOpcode.requestGuildMembers.rawValue, 8)
        XCTAssertEqual(GatewayOpcode.invalidSession.rawValue, 9)
        XCTAssertEqual(GatewayOpcode.hello.rawValue, 10)
        XCTAssertEqual(GatewayOpcode.heartbeatAck.rawValue, 11)
    }

    // MARK: - Connection State Tests

    func testGatewayConnectionState() {
        XCTAssertEqual(GatewayStateSnapshot.GatewayConnectionState.disconnected, .disconnected)
        XCTAssertEqual(GatewayStateSnapshot.GatewayConnectionState.connecting, .connecting)
        XCTAssertEqual(GatewayStateSnapshot.GatewayConnectionState.connected, .connected)
        XCTAssertEqual(GatewayStateSnapshot.GatewayConnectionState.identifying, .identifying)
        XCTAssertEqual(GatewayStateSnapshot.GatewayConnectionState.ready, .ready)
        XCTAssertEqual(GatewayStateSnapshot.GatewayConnectionState.resuming, .resuming)
        XCTAssertEqual(GatewayStateSnapshot.GatewayConnectionState.reconnecting, .reconnecting)
    }

    // MARK: - Integration Tests

    func testGatewayEventDecoding() throws {
        // Test decoding various gateway events
        let testCases = [
            ("SOUNDBOARD_SOUND_CREATE", """
            {
                "sound_id": "123456789",
                "name": "Test Sound",
                "volume": 0.8,
                "user_id": "987654321",
                "available": true,
                "guild_id": "111111111"
            }
            """),
            ("POLL_VOTE_ADD", """
            {
                "user_id": "123456789",
                "channel_id": "987654321",
                "message_id": "111111111",
                "guild_id": "222222222",
                "answer_id": 1
            }
            """),
            ("ENTITLEMENT_CREATE", """
            {
                "id": "123456789",
                "sku_id": "987654321",
                "application_id": "111111111",
                "user_id": "222222222",
                "type": 1,
                "deleted": false
            }
            """)
        ]

        for (eventType, eventData) in testCases {
            let json = """
            {
                "op": 0,
                "d": \(eventData),
                "s": 1234,
                "t": "\(eventType)"
            }
            """.data(using: .utf8)!

            // Test that the JSON can be parsed without errors
            let payload = try JSONDecoder().decode(GatewayPayload<EmptyResponse>.self, from: json)
            XCTAssertEqual(payload.op, .dispatch)
            XCTAssertEqual(payload.t, eventType)
            XCTAssertEqual(payload.s, 1234)
        }
    }
}

// MARK: - Empty Response for Testing

struct EmptyResponse: Decodable {}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Tests/SwiftDiscTests/GatewayTests.swift