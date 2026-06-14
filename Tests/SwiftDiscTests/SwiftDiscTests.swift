import XCTest
@testable import SwiftDisc

final class SwiftDiscTests: XCTestCase {
    func testInit() {
        let client = DiscordClient(token: "x")
        XCTAssertFalse(client.token.isEmpty)
    }
}
