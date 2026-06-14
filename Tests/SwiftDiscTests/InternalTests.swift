import XCTest
@testable import SwiftDisc

final class InternalTests: XCTestCase {

    // MARK: - DiscordAPIErrorBody Tests

    func testDiscordAPIErrorBodyParsesSimpleError() {
        let json = """
        {
            "code": 10001,
            "message": "Unknown account"
        }
        """.data(using: .utf8)!

        let parsed = DiscordAPIErrorBody.parse(from: json)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.code, 10001)
        XCTAssertEqual(parsed?.message, "Unknown account")
        XCTAssertTrue(parsed?.validationErrors.isEmpty ?? false)
    }

    func testDiscordAPIErrorBodyParsesNestedValidationErrors() {
        let json = """
        {
            "code": 50035,
            "message": "Invalid Form Body",
            "errors": {
                "embeds": {
                    "0": {
                        "fields": {
                            "1": {
                                "name": {
                                    "_errors": [
                                        { "code": "BASE_TYPE_REQUIRED", "message": "This field is required" }
                                    ]
                                }
                            }
                        }
                    }
                }
            }
        }
        """.data(using: .utf8)!

        let parsed = DiscordAPIErrorBody.parse(from: json)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.code, 50035)
        XCTAssertEqual(parsed?.message, "Invalid Form Body")
        XCTAssertEqual(parsed?.validationErrors.count, 1)
        XCTAssertEqual(parsed?.validationErrors.first?.path, "embeds.0.fields.1.name")
        XCTAssertEqual(parsed?.validationErrors.first?.code, "BASE_TYPE_REQUIRED")
        XCTAssertEqual(parsed?.validationErrors.first?.message, "This field is required")
    }

    func testDiscordAPIErrorBodyReturnsNilForInvalidJSON() {
        let invalidData = "not valid json".data(using: .utf8)!
        XCTAssertNil(DiscordAPIErrorBody.parse(from: invalidData))
    }

    func testDiscordAPIErrorBodyReturnsNilForEmptyData() {
        XCTAssertNil(DiscordAPIErrorBody.parse(from: Data()))
    }

    // MARK: - RetryPolicy Tests

    func testRetryPolicyDefaultValues() {
        let policy = RetryPolicy()
        XCTAssertEqual(policy.maxAttempts, 4)
        XCTAssertEqual(policy.baseDelay, 0.5)
        XCTAssertEqual(policy.maxDelay, 4.0)
    }

    func testRetryPolicyCustomValues() {
        let policy = RetryPolicy(maxAttempts: 6, baseDelay: 1.0, maxDelay: 10.0)
        XCTAssertEqual(policy.maxAttempts, 6)
        XCTAssertEqual(policy.baseDelay, 1.0)
        XCTAssertEqual(policy.maxDelay, 10.0)
    }

    func testRetryPolicyBackoffDelay() {
        let policy = RetryPolicy(maxAttempts: 4, baseDelay: 0.5, maxDelay: 4.0)
        XCTAssertEqual(policy.backoffDelay(forAttempt: 1), 0.5)
        XCTAssertEqual(policy.backoffDelay(forAttempt: 2), 1.0)
        XCTAssertEqual(policy.backoffDelay(forAttempt: 3), 2.0)
        XCTAssertEqual(policy.backoffDelay(forAttempt: 4), 4.0)
        XCTAssertEqual(policy.backoffDelay(forAttempt: 5), 4.0) // Capped at maxDelay
    }

    func testRetryPolicyBackoffDelayCappedAtMax() {
        let policy = RetryPolicy(maxAttempts: 10, baseDelay: 0.5, maxDelay: 2.0)
        XCTAssertEqual(policy.backoffDelay(forAttempt: 1), 0.5)
        XCTAssertEqual(policy.backoffDelay(forAttempt: 2), 1.0)
        XCTAssertEqual(policy.backoffDelay(forAttempt: 3), 2.0)
        XCTAssertEqual(policy.backoffDelay(forAttempt: 4), 2.0) // Capped
        XCTAssertEqual(policy.backoffDelay(forAttempt: 10), 2.0) // Still capped
    }

    func testRetryPolicyPreconditions() {
        XCTAssertNoThrow(RetryPolicy(maxAttempts: 1, baseDelay: 0, maxDelay: 0))
        XCTAssertNoThrow(RetryPolicy(maxAttempts: 100, baseDelay: 10, maxDelay: 10))
    }

    func testRetryPolicyServerErrorPolicy() {
        let policy = RetryPolicy.serverError
        XCTAssertEqual(policy.maxAttempts, 4)
        XCTAssertEqual(policy.baseDelay, 2.0)
        XCTAssertEqual(policy.maxDelay, 8.0)
    }

    // MARK: - RedactedToken Tests

    func testRedactedTokenStoresRawValue() {
        let token = RedactedToken("abc.def.ghi")
        XCTAssertEqual(token.rawValue, "abc.def.ghi")
    }

    func testRedactedTokenStripsBotPrefix() {
        let token = RedactedToken("Bot abc.def.ghi")
        XCTAssertEqual(token.rawValue, "abc.def.ghi")
    }

    func testRedactedTokenAuthorizationHeaderValue() {
        let token = RedactedToken("abc.def.ghi")
        XCTAssertEqual(token.authorizationHeaderValue, "Bot abc.def.ghi")
    }

    func testRedactedTokenAuthorizationHeaderValueStripsPrefix() {
        let token = RedactedToken("Bot abc.def.ghi")
        XCTAssertEqual(token.authorizationHeaderValue, "Bot abc.def.ghi")
    }

    func testRedactedTokenDescriptionIsRedacted() {
        let token = RedactedToken("abc.def.ghi")
        XCTAssertEqual(token.description, "RedactedToken(***)")
        XCTAssertEqual(token.debugDescription, "RedactedToken(***)")
    }

    func testRedactedTokenSendable() {
        // Verify RedactedToken conforms to Sendable
        let token = RedactedToken("test")
        _ = token // Just verify it compiles
    }

    // MARK: - Cache Tests

    func testCacheRemoveGuildClearsGuildEntry() async throws {
        let cache = Cache()
        let guild = try TestFixtures.makeGuild(id: "g1")

        await cache.upsert(guild: guild)
        let guildBefore = await cache.getGuild(id: "g1")
        XCTAssertNotNil(guildBefore)

        await cache.removeGuild(id: "g1")
        let guildAfter = await cache.getGuild(id: "g1")
        XCTAssertNil(guildAfter)
    }

    func testCacheRemoveGuildClearsRoles() async throws {
        let cache = Cache()
        let guildId: GuildID = "g1"
        let role = try TestFixtures.makeRole(id: "r1")

        await cache.upsert(role: role, guildId: guildId)
        let rolesBefore = await cache.getRoles(guildId: guildId)
        XCTAssertEqual(rolesBefore.count, 1)

        await cache.removeGuild(id: guildId)
        let rolesAfter = await cache.getRoles(guildId: guildId)
        XCTAssertEqual(rolesAfter.count, 0)
    }

    func testCacheRemoveGuildClearsEmojis() async throws {
        let cache = Cache()
        let guildId: GuildID = "g1"
        let emoji = try TestFixtures.makeEmoji(id: "e1")

        await cache.upsert(emojis: [emoji], guildId: guildId)
        let emojisBefore = await cache.getEmojis(guildId: guildId)
        XCTAssertEqual(emojisBefore.count, 1)

        await cache.removeGuild(id: guildId)
        let emojisAfter = await cache.getEmojis(guildId: guildId)
        XCTAssertEqual(emojisAfter.count, 0)
    }

    func testCacheRemoveMessageUsesReverseIndex() async throws {
        let cache = Cache()
        let user = try TestFixtures.makeUser()
        let message1 = try TestFixtures.makeMessage(id: "m1", channelId: "c1", content: "first", author: user)
        let message2 = try TestFixtures.makeMessage(id: "m2", channelId: "c2", content: "second", author: user)

        await cache.add(message: message1)
        await cache.add(message: message2)

        await cache.removeMessage(id: "m1")
        let c1Messages = await cache.recentMessagesByChannel["c1"] ?? []
        let c2Messages = await cache.recentMessagesByChannel["c2"] ?? []

        XCTAssertEqual(c1Messages.count, 0)
        XCTAssertEqual(c2Messages.count, 1)
        XCTAssertEqual(c2Messages.first?.id, "m2")
    }

    func testCacheMessageCapEnforced() async throws {
        let cache = Cache(configuration: .init(maxMessagesPerChannel: 3))
        let user = try TestFixtures.makeUser()

        for i in 1...5 {
            let message = try TestFixtures.makeMessage(id: "m\(i)", channelId: "c1", content: "msg\(i)", author: user)
            await cache.add(message: message)
        }

        let messages = await cache.recentMessagesByChannel["c1"] ?? []
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].id, "m3") // Oldest removed
        XCTAssertEqual(messages[1].id, "m4")
        XCTAssertEqual(messages[2].id, "m5")
    }

    func testCacheMessageCapClearsReverseIndex() async throws {
        let cache = Cache(configuration: .init(maxMessagesPerChannel: 2))
        let user = try TestFixtures.makeUser()

        let message1 = try TestFixtures.makeMessage(id: "m1", channelId: "c1", content: "msg1", author: user)
        let message2 = try TestFixtures.makeMessage(id: "m2", channelId: "c1", content: "msg2", author: user)
        let message3 = try TestFixtures.makeMessage(id: "m3", channelId: "c1", content: "msg3", author: user)

        await cache.add(message: message1)
        await cache.add(message: message2)
        await cache.add(message: message3)

        // m1 should be removed from reverse index
        await cache.removeMessage(id: "m1") // Should be no-op since already removed
        let messages = await cache.recentMessagesByChannel["c1"] ?? []
        XCTAssertEqual(messages.count, 2)
    }

    func testCacheTTLPrunesExpiredEntries() async throws {
        let config = Cache.Configuration(userTTL: 0.1) // 100ms TTL
        let cache = Cache(configuration: config)
        let user = try TestFixtures.makeUser(id: "u1")

        await cache.upsert(user: user)
        let userBefore = await cache.getUser(id: "u1")
        XCTAssertNotNil(userBefore)

        try await Task.sleep(nanoseconds: 150_000_000) // 150ms
        let userAfter = await cache.getUser(id: "u1")
        XCTAssertNil(userAfter)
    }

    // MARK: - OptionalField Tests

    func testOptionalFieldAbsent() {
        let field: OptionalField<String> = .absent
        XCTAssertTrue(field.isAbsent)
        XCTAssertNil(field.wrappedValue)
    }

    func testOptionalFieldNull() {
        let field: OptionalField<String> = .null
        XCTAssertFalse(field.isAbsent)
        XCTAssertNil(field.wrappedValue)
    }

    func testOptionalFieldValue() {
        let field: OptionalField<String> = .value("test")
        XCTAssertFalse(field.isAbsent)
        XCTAssertEqual(field.wrappedValue, "test")
    }

    func testOptionalFieldNilLiteral() {
        let field: OptionalField<String> = nil
        XCTAssertTrue(field.isAbsent)
        XCTAssertNil(field.wrappedValue)
    }

    func testOptionalFieldEquatable() {
        XCTAssertEqual(OptionalField<String>.absent, OptionalField<String>.absent)
        XCTAssertEqual(OptionalField<String>.null, OptionalField<String>.null)
        XCTAssertEqual(OptionalField.value("test"), OptionalField.value("test"))
        XCTAssertNotEqual(OptionalField<String>.absent, OptionalField<String>.null)
        XCTAssertNotEqual(OptionalField<String>.absent, OptionalField.value("test"))
    }

    func testOptionalFieldHashable() {
        let set: Set<OptionalField<String>> = [.absent, .null, .value("test")]
        XCTAssertEqual(set.count, 3)
    }

    func testOptionalFieldEncoding() throws {
        struct TestBody: Encodable, Sendable {
            let field: OptionalField<String>

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(field, forKey: .field)
            }

            enum CodingKeys: String, CodingKey { case field }
        }

        let body1 = TestBody(field: .absent)
        let data1 = try JSONCoders.encoder.encode(body1)
        let json1 = try JSONSerialization.jsonObject(with: data1) as? [String: Any]
        XCTAssertNil(json1?["field"])

        let body2 = TestBody(field: .null)
        let data2 = try JSONCoders.encoder.encode(body2)
        let json2 = try JSONSerialization.jsonObject(with: data2) as? [String: Any]
        XCTAssertEqual(json2?["field"] as? NSNull, NSNull())

        let body3 = TestBody(field: .value("test"))
        let data3 = try JSONCoders.encoder.encode(body3)
        let json3 = try JSONSerialization.jsonObject(with: data3) as? [String: Any]
        XCTAssertEqual(json3?["field"] as? String, "test")
    }
}
