import XCTest
@testable import SwiftDisc

final class CooldownTests: XCTestCase {
    func testCooldownSetAndCheck() async {
        let manager = CooldownManager()
        let cmd = "testcmd"
        let key = "user123"
        let initialCooldown = await manager.isOnCooldown(command: cmd, key: key)
        XCTAssertFalse(initialCooldown)
        await manager.setCooldown(command: cmd, key: key, duration: 1.0)
        let afterCooldown = await manager.isOnCooldown(command: cmd, key: key)
        XCTAssertTrue(afterCooldown)
    }
}
