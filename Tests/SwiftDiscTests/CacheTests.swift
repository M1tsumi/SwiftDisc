import XCTest
@testable import SwiftDisc

final class CacheTests: XCTestCase {
    func testRemoveMessageRemovesFromRecentMessagesByChannel() async {
        let cache = Cache()

        let user = User(
            id: "u1",
            username: "tester",
            discriminator: nil,
            global_name: nil,
            avatar: nil,
            bot: nil,
            system: nil,
            mfa_enabled: nil,
            banner: nil,
            accent_color: nil,
            locale: nil,
            verified: nil,
            email: nil,
            flags: nil,
            premium_type: nil,
            public_flags: nil,
            avatar_decoration_data: nil,
            collectibles: nil,
            primary_guild: nil
        )

        let message1 = Message(
            id: "m1",
            channel_id: "c1",
            guild_id: nil,
            author: user,
            member: nil,
            content: "first",
            timestamp: nil,
            edited_timestamp: nil,
            tts: nil,
            mention_everyone: nil,
            mentions: nil,
            mention_roles: nil,
            mention_channels: nil,
            attachments: nil,
            embeds: nil,
            reactions: nil,
            nonce: nil,
            pinned: nil,
            type: nil,
            activity: nil,
            application: nil,
            application_id: nil,
            message_reference: nil,
            referenced_message: nil,
            flags: nil,
            interaction: nil,
            interaction_metadata: nil,
            thread: nil,
            components: nil,
            sticker_items: nil,
            stickers: nil,
            position: nil,
            role_subscription_data: nil,
            resolved: nil,
            poll: nil,
            call: nil,
            webhook_id: nil,
            message_snapshots: nil,
            authorizing_integration_owners: nil,
            application_avatar_url: nil,
            gift_info: nil,
            purchase_notification: nil,
            role_subscription_purchase_data: nil,
            webhook_attachments: nil,
            triggering_interaction_metadata: nil
        )

        let message2 = Message(
            id: "m2",
            channel_id: "c1",
            guild_id: nil,
            author: user,
            member: nil,
            content: "second",
            timestamp: nil,
            edited_timestamp: nil,
            tts: nil,
            mention_everyone: nil,
            mentions: nil,
            mention_roles: nil,
            mention_channels: nil,
            attachments: nil,
            embeds: nil,
            reactions: nil,
            nonce: nil,
            pinned: nil,
            type: nil,
            activity: nil,
            application: nil,
            application_id: nil,
            message_reference: nil,
            referenced_message: nil,
            flags: nil,
            interaction: nil,
            interaction_metadata: nil,
            thread: nil,
            components: nil,
            sticker_items: nil,
            stickers: nil,
            position: nil,
            role_subscription_data: nil,
            resolved: nil,
            poll: nil,
            call: nil,
            webhook_id: nil,
            message_snapshots: nil,
            authorizing_integration_owners: nil,
            application_avatar_url: nil,
            gift_info: nil,
            purchase_notification: nil,
            role_subscription_purchase_data: nil,
            webhook_attachments: nil,
            triggering_interaction_metadata: nil
        )

        await cache.add(message: message1)
        await cache.add(message: message2)
        await cache.removeMessage(id: "m1")

        let recent = await cache.recentMessagesByChannel["c1"] ?? []
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.id, "m2")
    }
}
