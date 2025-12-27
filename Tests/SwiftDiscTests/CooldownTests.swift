import XCTest
@testable import SwiftDisc

final class CooldownTests: XCTestCase {
    func testCooldownSetAndCheck() {
        let manager = CooldownManager()
        let cmd = "testcmd"
        let key = "user123"
        XCTAssertFalse(manager.isOnCooldown(command: cmd, key: key))
        manager.setCooldown(command: cmd, key: key, duration: 1.0)
        XCTAssertTrue(manager.isOnCooldown(command: cmd, key: key))
    }
}
