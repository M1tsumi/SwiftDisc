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

        let data = Interaction.ApplicationCommandData(
            id: nil,
            name: nil,
            type: nil,
            resolved: nil,
            options: nil,
            custom_id: "btn_ok",
            component_type: 2,
            values: nil,
            target_id: nil,
            components: nil,
            attachments: nil
        )
        let interaction = Interaction(
            id: "1",
            application_id: "app",
            type: 3,
            data: data,
            guild_id: "guild",
            channel: nil,
            channel_id: "chan",
            member: nil,
            user: nil,
            token: "tok",
            version: nil,
            message: nil,
            app_permissions: nil,
            locale: nil,
            guild_locale: nil,
            authorizing_integration_owners: nil,
            context: nil
        )

        await client._internalEmitEvent(.interactionCreate(interaction))
        await fulfillment(of: [handled], timeout: 1.0)

        // Give manager a moment to process one-shot cleanup.
        try? await Task.sleep(nanoseconds: 50_000_000)
        let list = await manager.list()
        XCTAssertFalse(list.contains("oneshot"))
    }
}
