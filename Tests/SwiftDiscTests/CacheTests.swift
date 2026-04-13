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
}
