import XCTest
@testable import SwiftDisc

final class CacheTests: XCTestCase {
    func testRemoveMessageRemovesFromRecentMessagesByChannel() async throws {
        let cache = Cache()

        let user = try makeUser(id: "u1", username: "tester")
        let message1 = try makeMessage(id: "m1", channelId: "c1", content: "first", author: user)
        let message2 = try makeMessage(id: "m2", channelId: "c1", content: "second", author: user)

        await cache.add(message: message1)
        await cache.add(message: message2)
        await cache.removeMessage(id: "m1")

        let recent = await cache.recentMessagesByChannel["c1"] ?? []
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.id, "m2")
    }

    private func makeUser(id: String, username: String) throws -> User {
        let payload: [String: Any] = [
            "id": id,
            "username": username
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(User.self, from: data)
    }

    private func makeMessage(id: String, channelId: String, content: String, author: User) throws -> Message {
        let encoder = JSONEncoder()
        let authorData = try encoder.encode(author)
        let authorObject = try JSONSerialization.jsonObject(with: authorData)

        let payload: [String: Any] = [
            "id": id,
            "channel_id": channelId,
            "author": authorObject,
            "content": content
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(Message.self, from: data)
    }
}
