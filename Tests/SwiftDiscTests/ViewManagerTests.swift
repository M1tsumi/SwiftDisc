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

        let handled = expectation(description: "one-shot view handler called")
        let handlers: [String: ViewHandler] = ["btn_ok": { _, _ in handled.fulfill() }]
        let view = View(id: "oneshot", timeout: nil, handlers: handlers, oneShot: true)
        await manager.register(view, client: client)

        let interaction = TestFixtures.makeComponentInteraction(customId: "btn_ok")

        await client._internalEmitEvent(.interactionCreate(interaction))
        await fulfillment(of: [handled], timeout: 1.0)

        // Give manager a moment to process one-shot cleanup.
        try? await Task.sleep(nanoseconds: 50_000_000)
        let list = await manager.list()
        XCTAssertFalse(list.contains("oneshot"))
    }
}
