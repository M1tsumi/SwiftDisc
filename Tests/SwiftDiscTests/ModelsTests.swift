//
//  ModelsTests.swift
//  SwiftDiscTests
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import XCTest
@testable import SwiftDisc

final class ModelsTests: XCTestCase {

    // MARK: - Entitlement Tests

    func testEntitlementDecoding() throws {
        let json = """
        {
            "id": "123456789",
            "sku_id": "987654321",
            "application_id": "111111111",
            "user_id": "222222222",
            "type": 1,
            "deleted": false,
            "consumed": false
        }
        """.data(using: .utf8)!

        let entitlement = try JSONDecoder().decode(Entitlement.self, from: json)

        XCTAssertEqual(entitlement.id, Snowflake("123456789"))
        XCTAssertEqual(entitlement.sku_id, Snowflake("987654321"))
        XCTAssertEqual(entitlement.type, .purchase)
        XCTAssertFalse(entitlement.deleted)
        XCTAssertFalse(entitlement.consumed ?? true)
    }

    func testSKUDecoding() throws {
        let json = """
        {
            "id": "123456789",
            "type": 1,
            "application_id": "111111111",
            "name": "Premium Subscription",
            "slug": "premium-subscription",
            "flags": 4
        }
        """.data(using: .utf8)!

        let sku = try JSONDecoder().decode(SKU.self, from: json)

        XCTAssertEqual(sku.id, Snowflake("123456789"))
        XCTAssertEqual(sku.type, .durable)
        XCTAssertEqual(sku.name, "Premium Subscription")
        XCTAssertEqual(sku.slug, "premium-subscription")
        XCTAssertTrue(sku.flags.contains(.available))
    }

    // MARK: - Soundboard Tests

    func testSoundboardSoundDecoding() throws {
        let json = """
        {
            "sound_id": "123456789",
            "name": "Epic Sound",
            "volume": 0.8,
            "user_id": "111111111",
            "available": true,
            "guild_id": "222222222",
            "emoji_name": "🔊"
        }
        """.data(using: .utf8)!

        let sound = try JSONDecoder().decode(SoundboardSound.self, from: json)

        XCTAssertEqual(sound.sound_id, Snowflake("123456789"))
        XCTAssertEqual(sound.name, "Epic Sound")
        XCTAssertEqual(sound.volume, 0.8)
        XCTAssertTrue(sound.available)
        XCTAssertEqual(sound.emoji_name, "🔊")
    }

    func testCreateGuildSoundboardSound() {
        let sound = CreateGuildSoundboardSound(
            name: "Test Sound",
            sound: "base64data",
            volume: 0.9,
            emojiId: Snowflake("123"),
            emojiName: "🎵"
        )

        XCTAssertEqual(sound.name, "Test Sound")
        XCTAssertEqual(sound.sound, "base64data")
        XCTAssertEqual(sound.volume, 0.9)
        XCTAssertEqual(sound.emoji_id, Snowflake("123"))
        XCTAssertEqual(sound.emoji_name, "🎵")
    }

    // MARK: - Poll Tests

    func testPollDecoding() throws {
        let json = """
        {
            "question": {
                "text": "What's your favorite color?"
            },
            "answers": [
                {
                    "answer_id": 1,
                    "poll_media": {
                        "text": "Red"
                    }
                },
                {
                    "answer_id": 2,
                    "poll_media": {
                        "text": "Blue"
                    }
                }
            ],
            "expiry": null,
            "allow_multiselect": false,
            "layout_type": 1,
            "results": {
                "is_finalized": false,
                "answer_counts": [
                    {
                        "id": 1,
                        "count": 5,
                        "me_voted": true
                    },
                    {
                        "id": 2,
                        "count": 3,
                        "me_voted": false
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let poll = try JSONDecoder().decode(Poll.self, from: json)

        XCTAssertEqual(poll.question.text, "What's your favorite color?")
        XCTAssertEqual(poll.answers.count, 2)
        XCTAssertEqual(poll.answers[0].poll_media.text, "Red")
        XCTAssertEqual(poll.answers[1].poll_media.text, "Blue")
        XCTAssertFalse(poll.allow_multiselect)
        XCTAssertEqual(poll.layout_type, .default)
        XCTAssertNotNil(poll.results)
        XCTAssertEqual(poll.results?.answer_counts[0].count, 5)
        XCTAssertTrue(poll.results?.answer_counts[0].me_voted ?? false)
    }

    func testCreateMessagePoll() {
        let poll = CreateMessagePoll(
            question: PollMedia(text: "Best programming language?", emoji: nil),
            answers: [
                PollAnswer(answer_id: 1, poll_media: PollMedia(text: "Swift", emoji: nil)),
                PollAnswer(answer_id: 2, poll_media: PollMedia(text: "Rust", emoji: nil)),
                PollAnswer(answer_id: 3, poll_media: PollMedia(text: "Go", emoji: nil))
            ],
            duration: 168,
            allowMultiselect: true,
            layoutType: .default
        )

        XCTAssertEqual(poll.question.text, "Best programming language?")
        XCTAssertEqual(poll.answers.count, 3)
        XCTAssertEqual(poll.duration, 168)
        XCTAssertTrue(poll.allow_multiselect ?? false)
        XCTAssertEqual(poll.layout_type, .default)
    }

    // MARK: - UserConnection Tests

    func testUserConnectionDecoding() throws {
        let json = """
        {
            "id": "123456789",
            "name": "TestUser",
            "type": "twitch",
            "revoked": false,
            "verified": true,
            "friend_sync": false,
            "show_activity": true,
            "two_way_link": false,
            "visibility": 1
        }
        """.data(using: .utf8)!

        let connection = try JSONDecoder().decode(UserConnection.self, from: json)

        XCTAssertEqual(connection.id, "123456789")
        XCTAssertEqual(connection.name, "TestUser")
        XCTAssertEqual(connection.type, "twitch")
        XCTAssertTrue(connection.verified)
        XCTAssertEqual(connection.visibility, .everyone)
    }

    func testSubscriptionDecoding() throws {
        let json = """
        {
            "id": "123456789",
            "user_id": "111111111",
            "sku_ids": ["222222222", "333333333"],
            "entitlement_ids": ["444444444"],
            "status": 0,
            "country": "US"
        }
        """.data(using: .utf8)!

        let subscription = try JSONDecoder().decode(Subscription.self, from: json)

        XCTAssertEqual(subscription.id, Snowflake("123456789"))
        XCTAssertEqual(subscription.user_id, Snowflake("111111111"))
        XCTAssertEqual(subscription.sku_ids.count, 2)
        XCTAssertEqual(subscription.status, .active)
        XCTAssertEqual(subscription.country, "US")
    }

    // MARK: - Gateway State Tests

    func testGatewayStateSnapshot() {
        let snapshot = GatewayStateSnapshot(
            state: .ready,
            lastHeartbeatSent: Date(),
            lastHeartbeatAck: Date(),
            heartbeatInterval: 41.25,
            missedHeartbeats: 0,
            lastSequence: 1234,
            sessionId: "session_123",
            resumeUrl: "wss://resume.example.com",
            connectionAttempts: 1,
            lastError: nil,
            uptime: 3600
        )

        XCTAssertEqual(snapshot.state, .ready)
        XCTAssertEqual(snapshot.missedHeartbeats, 0)
        XCTAssertEqual(snapshot.lastSequence, 1234)
        XCTAssertEqual(snapshot.sessionId, "session_123")
        XCTAssertEqual(snapshot.uptime, 3600)
    }

    func testGatewayHealthMetrics() {
        let metrics = GatewayHealthMetrics(
            averageLatency: 45.2,
            p95Latency: 89.5,
            heartbeatsSent: 100,
            heartbeatsAcked: 98,
            heartbeatSuccessRate: 0.98,
            reconnections: 2,
            messagesReceived: 1500,
            messagesSent: 800,
            uptime: 7200
        )

        XCTAssertEqual(metrics.averageLatency, 45.2)
        XCTAssertEqual(metrics.p95Latency, 89.5)
        XCTAssertEqual(metrics.heartbeatsSent, 100)
        XCTAssertEqual(metrics.heartbeatsAcked, 98)
        XCTAssertEqual(metrics.heartbeatSuccessRate, 0.98)
        XCTAssertEqual(metrics.reconnections, 2)
        XCTAssertEqual(metrics.messagesReceived, 1500)
        XCTAssertEqual(metrics.messagesSent, 800)
        XCTAssertEqual(metrics.uptime, 7200)
    }

    // MARK: - OAuth2 Model Tests

    func testAccessToken() {
        let token = AccessToken(
            access_token: "test_token",
            token_type: "Bearer",
            expires_in: 3600,
            refresh_token: "refresh_token",
            scope: "identify email guilds"
        )

        XCTAssertEqual(token.access_token, "test_token")
        XCTAssertEqual(token.token_type, "Bearer")
        XCTAssertEqual(token.expires_in, 3600)
        XCTAssertEqual(token.refresh_token, "refresh_token")
        XCTAssertEqual(token.scope, "identify email guilds")
        XCTAssertEqual(token.scopes, [.identify, .email, .guilds])
        XCTAssertFalse(token.isExpired) // Should not be expired immediately
    }

    func testOAuth2Scope() {
        XCTAssertEqual(OAuth2Scope.identify.rawValue, "identify")
        XCTAssertEqual(OAuth2Scope.email.rawValue, "email")
        XCTAssertEqual(OAuth2Scope.guildsJoin.rawValue, "guilds.join")
        XCTAssertEqual(OAuth2Scope.applicationsCommands.rawValue, "applications.commands")
    }

    func testAuthorizationGrant() {
        let grant = AuthorizationGrant(
            accessToken: "access_token",
            refreshToken: "refresh_token",
            scopes: [.identify, .email],
            expiresAt: Date().addingTimeInterval(3600),
            userId: Snowflake("123")
        )

        XCTAssertEqual(grant.accessToken, "access_token")
        XCTAssertEqual(grant.refreshToken, "refresh_token")
        XCTAssertEqual(grant.scopes, [.identify, .email])
        XCTAssertEqual(grant.userId, Snowflake("123"))
        XCTAssertFalse(grant.isExpired)
    }

    // MARK: - Partial Emoji Tests

    func testPartialEmojiDecoding() throws {
        let json = """
        {
            "id": "123456789",
            "name": "test_emoji",
            "animated": true
        }
        """.data(using: .utf8)!

        let emoji = try JSONDecoder().decode(PartialEmoji.self, from: json)

        XCTAssertEqual(emoji.id, Snowflake("123456789"))
        XCTAssertEqual(emoji.name, "test_emoji")
        XCTAssertTrue(emoji.animated ?? false)
    }

    // MARK: - Poll Voter Tests

    func testPollVoterDecoding() throws {
        let json = """
        {
            "user": {
                "id": "123456789",
                "username": "testuser"
            }
        }
        """.data(using: .utf8)!

        let voter = try JSONDecoder().decode(PollVoter.self, from: json)

        XCTAssertEqual(voter.user.id, Snowflake("123456789"))
        XCTAssertEqual(voter.user.username, "testuser")
    }

    // MARK: - Gateway Event Tests

    func testPollVoteDecoding() throws {
        let json = """
        {
            "user_id": "123456789",
            "channel_id": "987654321",
            "message_id": "111111111",
            "guild_id": "222222222",
            "answer_id": 1
        }
        """.data(using: .utf8)!

        let vote = try JSONDecoder().decode(PollVote.self, from: json)

        XCTAssertEqual(vote.user_id, Snowflake("123456789"))
        XCTAssertEqual(vote.channel_id, Snowflake("987654321"))
        XCTAssertEqual(vote.message_id, Snowflake("111111111"))
        XCTAssertEqual(vote.guild_id, Snowflake("222222222"))
        XCTAssertEqual(vote.answer_id, 1)
    }

    func testGuildMemberProfileUpdateDecoding() throws {
        let json = """
        {
            "guild_id": "123456789",
            "user": {
                "id": "987654321",
                "username": "testuser"
            },
            "member": {
                "user": {
                    "id": "987654321",
                    "username": "testuser"
                },
                "nick": "Test Nick",
                "roles": [],
                "joined_at": "2023-01-01T00:00:00.000000+00:00",
                "deaf": false,
                "mute": false
            }
        }
        """.data(using: .utf8)!

        let update = try JSONDecoder().decode(GuildMemberProfileUpdate.self, from: json)

        XCTAssertEqual(update.guild_id, Snowflake("123456789"))
        XCTAssertEqual(update.user.id, Snowflake("987654321"))
        XCTAssertEqual(update.member.user?.username, "testuser")
        XCTAssertEqual(update.member.nick, "Test Nick")
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Tests/SwiftDiscTests/ModelsTests.swift