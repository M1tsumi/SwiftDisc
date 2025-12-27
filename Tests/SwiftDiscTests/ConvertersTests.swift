import XCTest
@testable import SwiftDisc

final class ConvertersTests: XCTestCase {
    func testParseSnowflakeFromPlainId() {
        let id: UserID? = Converters.parseUserId("1234567890")
        XCTAssertNotNil(id)
        XCTAssertEqual(id?.rawValue, "1234567890")
    }

    func testParseSnowflakeFromMention() {
        let id: UserID? = Converters.parseUserId("<@!987654321>")
        XCTAssertNotNil(id)
        XCTAssertEqual(id?.rawValue, "987654321")
    }
}
