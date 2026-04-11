import Foundation
@testable import SwiftDisc

enum TestFixtures {
    /// Creates a minimal decodable `User` fixture for tests.
    static func makeUser(id: String = "u1", username: String = "tester") throws -> User {
        let payload: [String: Any] = [
            "id": id,
            "username": username
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(User.self, from: data)
    }

    /// Creates a minimal decodable `Message` fixture with author and content fields.
    static func makeMessage(id: String = "m1", channelId: String = "c1", content: String = "hello", author: User? = nil) throws -> Message {
        let resolvedAuthor = try author ?? makeUser()
        let encoder = JSONEncoder()
        let authorData = try encoder.encode(resolvedAuthor)
        let authorObject = try JSONSerialization.jsonObject(with: authorData)

        let payload: [String: Any] = [
            "id": id,
            "channel_id": channelId,
            "author": authorObject,
            "content": content
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(Message.self, from: data)
    }

    /// Creates a minimal component `Interaction` fixture for collector and router tests.
    static func makeComponentInteraction(customId: String, guildId: String = "guild", channelId: String = "chan", id: String = "1", applicationId: String = "app", token: String = "tok") -> Interaction {
        let interactionId = InteractionID(id)
        let appId = ApplicationID(applicationId)
        let gid = GuildID(guildId)
        let cid = ChannelID(channelId)

        let data = Interaction.ApplicationCommandData(
            id: nil,
            name: nil,
            type: nil,
            resolved: nil,
            options: nil,
            custom_id: customId,
            component_type: 2,
            values: nil,
            target_id: nil,
            components: nil,
            attachments: nil
        )

        return Interaction(
            id: interactionId,
            application_id: appId,
            type: 3,
            data: data,
            guild_id: gid,
            channel: nil,
            channel_id: cid,
            member: nil,
            user: nil,
            token: token,
            version: nil,
            message: nil,
            app_permissions: nil,
            locale: nil,
            guild_locale: nil,
            authorizing_integration_owners: nil,
            context: nil
        )
    }
}