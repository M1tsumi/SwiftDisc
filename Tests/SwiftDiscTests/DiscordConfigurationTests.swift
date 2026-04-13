import XCTest
@testable import SwiftDisc

final class DiscordConfigurationTests: XCTestCase {
    func testGatewayDecodeDiagnosticsDefaultsToDisabled() {
        let config = DiscordConfiguration()
        XCTAssertFalse(config.enableGatewayDecodeDiagnostics)
    }

    func testGatewayDecodeDiagnosticsCanBeEnabled() {
        let config = DiscordConfiguration(enableGatewayDecodeDiagnostics: true)
        XCTAssertTrue(config.enableGatewayDecodeDiagnostics)
    }

    func testRateLimitObserverDefaultsToNil() {
        let config = DiscordConfiguration()
        XCTAssertNil(config.onRateLimit)
    }
}
