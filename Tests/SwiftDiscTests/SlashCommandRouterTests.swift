import XCTest
@testable import SwiftDisc

final class SlashCommandRouterTests: XCTestCase {
    func testSubcommandPathAndOptions() async throws {
        // Build an Interaction with nested options: /admin ban user:123
        let optUser = Interaction.ApplicationCommandData.Option(name: "user", type: 3, value: .string("123"), options: nil, focused: nil)
        let sub = Interaction.ApplicationCommandData.Option(name: "ban", type: 1, value: nil, options: [optUser], focused: nil)
        let data = Interaction.ApplicationCommandData(id: nil, name: "admin", type: 1, resolved: nil, options: [sub], custom_id: nil, component_type: nil, values: nil, target_id: nil, components: nil, attachments: nil)
        let interaction = Interaction(id: "1", application_id: "app", type: 2, data: data, guild_id: "guild", channel: nil, channel_id: "chan", member: nil, user: nil, token: "tok", version: nil, message: nil, app_permissions: nil, locale: nil, guild_locale: nil, authorizing_integration_owners: nil, context: nil)

        let client = DiscordClient(token: "x")
        let router = SlashCommandRouter()
        let exp = expectation(description: "handler")
        router.registerPath("admin ban") { ctx in
            XCTAssertEqual(ctx.path, "admin ban")
            XCTAssertEqual(ctx.string("user"), "123")
            exp.fulfill()
        }
        await router.handle(interaction: interaction, client: client)
        await fulfillment(of: [exp], timeout: 1.0)
    }
}
