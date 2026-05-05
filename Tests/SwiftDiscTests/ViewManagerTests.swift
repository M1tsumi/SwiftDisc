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
        await client.useViewManager(manager)

        let handlers: [String: ViewHandler] = ["btn_ok": { _, _ in }]
        let view = View(id: "oneshot", timeout: nil, handlers: handlers, oneShot: true)
        await manager.register(view, client: client)

        let interaction = TestFixtures.makeComponentInteraction(customId: "btn_ok")

        // Emit the interaction event - this should trigger the one-shot removal
        await client._internalEmitEvent(.interactionCreate(interaction))

        // Give the async handler task time to execute and remove the one-shot view
        try? await Task.sleep(nanoseconds: 100_000_000)
        let list = await manager.list()
        XCTAssertFalse(list.contains("oneshot"))
    }
}
