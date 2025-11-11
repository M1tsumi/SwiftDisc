import XCTest
@testable import SwiftDisc

final class SwiftDiscTests: XCTestCase {
    func testInit() {
        let client = DiscordClient(token: "x")
        XCTAssertEqual(client.token, "x")
    }
}
