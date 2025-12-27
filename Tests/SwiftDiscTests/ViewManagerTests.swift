import XCTest
@testable import SwiftDisc

final class ViewManagerTests: XCTestCase {
    func testRegisterAndUnregisterView() async {
        let client = DiscordClient(token: "")
        let manager = ViewManager()
        client.useViewManager(manager)

        let called = ManagedAtomicInt(0)
        let handlers: [String: ViewHandler] = ["btn_ok": { _, _ in await { _ in }(); }]

        let view = View(id: "v1", timeout: 0.1, handlers: handlers, prefixMatch: false, oneShot: false)
        await manager.register(view, client: client)
        let list = await manager.list()
        XCTAssertTrue(list.contains(view.id))

        await manager.unregister(view.id)
        let list2 = await manager.list()
        XCTAssertFalse(list2.contains(view.id))
    }
}
