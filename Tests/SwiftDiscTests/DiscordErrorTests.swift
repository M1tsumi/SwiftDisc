import XCTest
@testable import SwiftDisc

final class DiscordErrorTests: XCTestCase {
    func testHttpErrorDescriptionIncludesStatusAndBody() {
        let error = DiscordError.http(404, "missing")
        XCTAssertEqual(error.description, "HTTP error 404: missing")
        XCTAssertEqual(error.errorDescription, "HTTP error 404: missing")
    }

    func testHttpErrorDescriptionWithDebugContext() {
        let error = DiscordError.http(404, "missing", debugContext: "Endpoint: GET /channels/123")
        XCTAssertEqual(error.description, "HTTP error 404: missing - Context: Endpoint: GET /channels/123")
    }

    func testGatewayErrorDescriptionIsHumanReadable() {
        let error = DiscordError.gateway("bad hello payload")
        XCTAssertEqual(error.description, "Gateway error: bad hello payload")
    }

    func testGatewayErrorDescriptionWithDebugContext() {
        let error = DiscordError.gateway("bad hello payload", debugContext: "Shard 0")
        XCTAssertEqual(error.description, "Gateway error: bad hello payload - Context: Shard 0")
    }

    func testValidationErrorDescriptionIsHumanReadable() {
        let error = DiscordError.validation("file too large")
        XCTAssertEqual(error.description, "Validation failed: file too large")
    }

    func testValidationErrorDescriptionWithDebugContext() {
        let error = DiscordError.validation("file too large", debugContext: "Upload endpoint")
        XCTAssertEqual(error.description, "Validation failed: file too large - Context: Upload endpoint")
    }
}