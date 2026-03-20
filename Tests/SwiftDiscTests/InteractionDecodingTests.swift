import XCTest
@testable import SwiftDisc

final class InteractionDecodingTests: XCTestCase {
    func testDecodesComponentInteractionWithoutCommandName() throws {
        let json = #"""
        {
          "op": 0,
          "t": "INTERACTION_CREATE",
          "s": 42,
          "d": {
            "id": "123456789012345678",
            "application_id": "222222222222222222",
            "type": 3,
            "data": {
              "custom_id": "btn:confirm",
              "component_type": 2
            },
            "guild_id": "333333333333333333",
            "channel_id": "444444444444444444",
            "token": "interaction-token",
            "version": 1
          }
        }
        """#

        let payload = try JSONDecoder().decode(
            GatewayPayload<Interaction>.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(payload.t, "INTERACTION_CREATE")
        XCTAssertEqual(payload.d?.type, 3)
        XCTAssertEqual(payload.d?.data?.custom_id, "btn:confirm")
        XCTAssertEqual(payload.d?.data?.name, nil)
    }

    func testDecodesSlashInteractionWithCommandName() throws {
        let json = #"""
        {
          "id": "1",
          "application_id": "2",
          "type": 2,
          "data": {
            "id": "99",
            "name": "ping",
            "type": 1
          },
          "token": "tok"
        }
        """#

        let interaction = try JSONDecoder().decode(Interaction.self, from: Data(json.utf8))
        XCTAssertEqual(interaction.type, 2)
        XCTAssertEqual(interaction.data?.name, "ping")
    }
}
