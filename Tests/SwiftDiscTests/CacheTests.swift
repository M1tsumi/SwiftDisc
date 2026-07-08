import XCTest
@testable import SwiftDisc

final class CacheTests: XCTestCase {
    func testRemoveMessageRemovesFromRecentMessagesByChannel() async throws {
        let cache = Cache()

        let user = try TestFixtures.makeUser()
        let message1 = try TestFixtures.makeMessage(id: "m1", channelId: "c1", content: "first", author: user)
        let message2 = try TestFixtures.makeMessage(id: "m2", channelId: "c1", content: "second", author: user)

        await cache.add(message: message1)
        await cache.add(message: message2)
        await cache.removeMessage(id: "m1")

        let recent = await cache.recentMessagesByChannel["c1"] ?? []
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.id, "m2")
    }

    func testUpsertAndGetUser() async throws {
        let cache = Cache()
        let user = try TestFixtures.makeUser(id: "u100", username: "alice")
        await cache.upsert(user: user)
        let retrieved = await cache.getUser(id: UserID("u100"))
        XCTAssertEqual(retrieved?.username, "alice")
        XCTAssertEqual(retrieved?.id.rawValue, "u100")
    }

    func testUpsertAndGetChannel() async throws {
        let cache = Cache()
        let channel = TestFixtures.makeChannel(id: "ch1", name: "test-channel")
        await cache.upsert(channel: channel)
        let retrieved = await cache.getChannel(id: ChannelID("ch1"))
        XCTAssertEqual(retrieved?.name, "test-channel")
        XCTAssertEqual(retrieved?.type, .guildText)
    }

    func testUpsertAndGetGuild() async throws {
        let cache = Cache()
        let guild = try TestFixtures.makeGuild(id: "g100", name: "Test Server")
        await cache.upsert(guild: guild)
        let retrieved = await cache.getGuild(id: GuildID("g100"))
        XCTAssertEqual(retrieved?.name, "Test Server")
        XCTAssertEqual(retrieved?.id.rawValue, "g100")
    }

    func testUpsertAndGetRole() async {
        let cache = Cache()
        let role = TestFixtures.makeRole(id: "r10", name: "Moderator")
        await cache.upsert(role: role, guildId: GuildID("g1"))
        let retrieved = await cache.getRole(id: RoleID("r10"), guildId: GuildID("g1"))
        XCTAssertEqual(retrieved?.name, "Moderator")
    }

    func testAddAndGetMessages() async throws {
        let cache = Cache()
        let user = try TestFixtures.makeUser()
        let msg1 = try TestFixtures.makeMessage(id: "m1", channelId: "c1", content: "first", author: user)
        let msg2 = try TestFixtures.makeMessage(id: "m2", channelId: "c1", content: "second", author: user)

        await cache.add(message: msg1)
        await cache.add(message: msg2)

        let messages = await cache.getMessages(channelId: ChannelID("c1"))
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].content, "first")
        XCTAssertEqual(messages[1].content, "second")
    }

    func testRemoveUser() async throws {
        let cache = Cache()
        let user = try TestFixtures.makeUser(id: "u_remove")
        await cache.upsert(user: user)
        var retrieved = await cache.getUser(id: UserID("u_remove"))
        XCTAssertNotNil(retrieved)
        await cache.removeUser(id: UserID("u_remove"))
        retrieved = await cache.getUser(id: UserID("u_remove"))
        XCTAssertNil(retrieved)
    }

    func testClearCache() async throws {
        let cache = Cache()
        let user = try TestFixtures.makeUser(id: "u1")
        let channel = TestFixtures.makeChannel(id: "ch1")
        let guild = try TestFixtures.makeGuild(id: "g1")
        await cache.upsert(user: user)
        await cache.upsert(channel: channel)
        await cache.upsert(guild: guild)

        await cache.clear()

        XCTAssertNil(await cache.getUser(id: UserID("u1")))
        XCTAssertNil(await cache.getChannel(id: ChannelID("ch1")))
        XCTAssertNil(await cache.getGuild(id: GuildID("g1")))
    }

    func testRemoveMessagesForChannel() async throws {
        let cache = Cache()
        let user = try TestFixtures.makeUser()
        let msg1 = try TestFixtures.makeMessage(id: "m1", channelId: "c_rm", content: "a", author: user)
        let msg2 = try TestFixtures.makeMessage(id: "m2", channelId: "c_rm", content: "b", author: user)
        let msg3 = try TestFixtures.makeMessage(id: "m3", channelId: "c_other", content: "c", author: user)

        await cache.add(message: msg1)
        await cache.add(message: msg2)
        await cache.add(message: msg3)

        await cache.removeMessagesForChannel(channelId: ChannelID("c_rm"))

        let remaining = await cache.getMessages(channelId: ChannelID("c_rm"))
        XCTAssertTrue(remaining.isEmpty)
        let otherMessages = await cache.getMessages(channelId: ChannelID("c_other"))
        XCTAssertEqual(otherMessages.count, 1)
    }

    func testEnsureChannelStub() async throws {
        let cache = Cache()
        await cache.ensureChannelStub(id: ChannelID("stub1"), type: .guildText)
        let channel = await cache.getChannel(id: ChannelID("stub1"))
        XCTAssertNotNil(channel)
        XCTAssertEqual(channel?.id.rawValue, "stub1")
        XCTAssertEqual(channel?.type, .guildText)

        // Ensure it does not overwrite existing
        let existing = TestFixtures.makeChannel(id: "stub1", name: "real-name")
        await cache.upsert(channel: existing)
        await cache.ensureChannelStub(id: ChannelID("stub1"), type: .dm)
        let after = await cache.getChannel(id: ChannelID("stub1"))
        XCTAssertEqual(after?.name, "real-name")
        XCTAssertEqual(after?.type, .guildText)
    }
}
