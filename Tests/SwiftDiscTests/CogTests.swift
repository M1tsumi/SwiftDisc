import XCTest
@testable import SwiftDisc

final class CogTests: XCTestCase {
    func testLoadUnloadCog() async throws {
        let manager = ExtensionManager()
        struct TestCog: Cog {
            let name = "test"
            func onLoad(client: DiscordClient) async throws {}
            func onUnload(client: DiscordClient) async throws {}
        }

        let client = DiscordClient(token: "")
        let cog = TestCog()

        try await manager.load(cog, client: client)
        XCTAssertTrue(manager.list().contains(cog.name))

        try await manager.unload(cog.name, client: client)
        XCTAssertFalse(manager.list().contains(cog.name))
    }
}
