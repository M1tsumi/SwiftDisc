import XCTest
@testable import SwiftDisc

final class ViewManagerTests: XCTestCase {
    func testRegisterAndUnregisterView() async {
        let client = DiscordClient(token: "")
        let manager = ViewManager()
        await client.useViewManager(manager)

        let handlers: [String: ViewHandler] = ["btn_ok": { _, _ in }]

        let view = View(id: "v1", timeout: 0.1, handlers: handlers, oneShot: false)
        await manager.register(view, client: client)
        let list = await manager.list()
        XCTAssertTrue(list.contains(view.id))

        await manager.unregister(view.id)
        let list2 = await manager.list()
        XCTAssertFalse(list2.contains(view.id))
    }

    func testOneShotViewIsRemovedAfterMatchingInteraction() async {
        let client = DiscordClient(token: "")
        let manager = ViewManager()
        
        let handlers: [String: ViewHandler] = ["btn_ok": { _, _ in }]
        let view = View(id: "oneshot", timeout: nil, handlers: handlers, oneShot: true)
        await manager.register(view, client: client)

        let interaction = TestFixtures.makeComponentInteraction(customId: "btn_ok")

        // Directly call routeInteraction to test one-shot removal without relying on event stream
        // This avoids race conditions with async handler execution
        await manager.routeInteraction(customId: "btn_ok", interaction: interaction, client: client)

        // The one-shot view should be removed immediately after routing
        let list = await manager.list()
        XCTAssertFalse(list.contains("oneshot"))
    }
}
