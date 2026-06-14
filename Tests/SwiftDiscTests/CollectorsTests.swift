import XCTest
@testable import SwiftDisc

final class CollectorsTests: XCTestCase {
    func testCreateMessageCollectorReturnsStream() async {
        let client = DiscordClient(token: "")
        let stream = await client.createMessageCollector()
        // Ensure the returned type is an AsyncStream<Message> by obtaining it and then cancelling.
        let iter = stream.makeAsyncIterator()
        // We don't iterate (no network) — this test ensures the API exists and compiles.
        XCTAssertNotNil(iter)
    }

    func testStreamGuildMembersReturnsStream() async {
        let client = DiscordClient(token: "")
        let stream = await client.streamGuildMembers(guildId: "0")
        let iter = stream.makeAsyncIterator()
        XCTAssertNotNil(iter)
    }
}
