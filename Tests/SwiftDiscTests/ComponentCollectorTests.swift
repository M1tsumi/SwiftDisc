import XCTest
@testable import SwiftDisc

final class ComponentCollectorTests: XCTestCase {
    func testCreateComponentCollectorReturnsStream() async {
        let client = DiscordClient(token: "")
        let stream = await client.createComponentCollector(customId: nil)
        var iter = stream.makeAsyncIterator()
        XCTAssertNotNil(iter)
    }
}
