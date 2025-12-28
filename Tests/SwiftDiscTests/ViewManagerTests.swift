import XCTest
@testable import SwiftDisc

final class ViewManagerTests: XCTestCase {
    func testRegisterAndUnregisterView() async {
        let client = DiscordClient(token: "")
        let manager = ViewManager()
        client.useViewManager(manager)

        var called = false
        let handlers: [String: ViewHandler] = ["btn_ok": { _, _ in called = true }]

        let view = View(id: "v1", timeout: 0.1, handlers: handlers, oneShot: false)
        await manager.register(view, client: client)
        let list = await manager.list()
        XCTAssertTrue(list.contains(view.id))

        await manager.unregister(view.id)
        let list2 = await manager.list()
        XCTAssertFalse(list2.contains(view.id))
    }
}
