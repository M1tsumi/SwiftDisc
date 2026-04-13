import XCTest
@testable import SwiftDisc

final class DiscordErrorTests: XCTestCase {
    func testHttpErrorDescriptionIncludesStatusAndBody() {
        let error = DiscordError.http(404, "missing")
        XCTAssertEqual(error.description, "HTTP error 404: missing")
        XCTAssertEqual(error.errorDescription, "HTTP error 404: missing")
    }

    func testGatewayErrorDescriptionIsHumanReadable() {
        let error = DiscordError.gateway("bad hello payload")
        XCTAssertEqual(error.description, "Gateway error: bad hello payload")
    }

    func testValidationErrorDescriptionIsHumanReadable() {
        let error = DiscordError.validation("file too large")
        XCTAssertEqual(error.description, "Validation failed: file too large")
    }
}