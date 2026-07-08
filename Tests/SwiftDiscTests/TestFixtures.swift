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

    /// Creates a minimal decodable `Guild` fixture with required fields.
    static func makeGuild(id: String = "g1", name: String = "Test Guild") throws -> Guild {
        let payload: [String: Any] = [
            "id": id,
            "name": name
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(Guild.self, from: data)
    }

    /// Creates a minimal `Role` fixture.
    static func makeRole(id: String = "r1", name: String = "Test Role") -> Role {
        Role(id: RoleID(id), name: name, color: nil, colors: nil, hoist: nil, position: nil, permissions: nil, managed: nil, mentionable: nil, icon: nil, unicode_emoji: nil)
    }

    /// Creates a minimal `Emoji` fixture.
    static func makeEmoji(id: String = "e1", name: String = "testemoji") -> Emoji {
        Emoji(id: EmojiID(id), name: name, roles: nil, user: nil, require_colons: nil, managed: nil, animated: nil, available: nil)
    }

    /// Creates a Channel fixture with the specified fields.
    static func makeChannel(id: String = "c1", type: ChannelType = .guildText, name: String = "general", guildId: String = "g1", position: Int = 0, topic: String? = nil, nsfw: Bool? = nil, lastMessageId: String? = "lm1", parentId: String? = nil) -> Channel {
        Channel(
            id: ChannelID(id),
            type: type,
            name: name,
            topic: topic,
            nsfw: nsfw,
            position: position,
            parent_id: parentId.map(ChannelID.init),
            last_message_id: lastMessageId.map(MessageID.init),
            permission_overwrites: [PermissionOverwrite(id: OverwriteID("ow1"), type: 0, allow: "1024", deny: "0")]
        )
    }

    /// Creates a GuildMember fixture.
    static func makeGuildMember(userId: String = "u1", nick: String? = nil, roles: [RoleID] = [RoleID("r1")]) throws -> GuildMember {
        GuildMember(
            user: try makeUser(id: userId),
            nick: nick,
            avatar: nil,
            roles: roles,
            joined_at: "2024-01-01T00:00:00.000000+00:00",
            deaf: false,
            mute: false,
            permissions: "1024",
            banner: nil,
            avatar_decoration_data: nil,
            collectibles: nil,
            flags: nil,
            communication_disabled_until: nil,
            pending: nil
        )
    }

    /// Creates a full Embed fixture.
    static func makeEmbed() -> Embed {
        Embed(
            title: "Test Title",
            description: "Test description text",
            url: nil,
            color: 0x00FF00,
            footer: Embed.Footer(text: "Footer text", icon_url: "https://example.com/icon.png", proxy_icon_url: nil),
            author: Embed.Author(name: "Author Name", url: "https://example.com", icon_url: "https://example.com/avatar.png"),
            fields: [
                Embed.Field(name: "Field 1", value: "Value 1", inline: true),
                Embed.Field(name: "Field 2", value: "Value 2", inline: false)
            ],
            thumbnail: nil,
            image: nil,
            video: nil,
            provider: nil,
            timestamp: "2024-01-01T12:00:00.000Z"
        )
    }

    /// Creates a Thread fixture (Channel with .guildPublicThread type).
    static func makeThread(id: String = "t1", name: String = "Test Thread", guildId: String = "g1", parentId: String = "c1") -> Channel {
        Channel(
            id: ChannelID(id),
            type: .guildPublicThread,
            name: name,
            parent_id: ChannelID(parentId),
            thread_metadata: ThreadMetadata(
                archived: false,
                auto_archive_duration: 1440,
                archive_timestamp: "2024-01-01T00:00:00.000000+00:00",
                locked: false,
                invitable: true,
                create_timestamp: "2024-01-01T00:00:00.000000+00:00"
            )
        )
    }

    /// Creates a MessageComponents fixture (ActionRow with a Button).
    static func makeMessageComponents() -> [MessageComponent] {
        let button = MessageComponent.Button(style: 1, label: "Click Me", custom_id: "btn_click")
        let row = MessageComponent.ActionRow(components: [.button(button)])
        return [.actionRow(row)]
    }

    /// Creates a PresenceUpdate fixture.
    static func makePresenceUpdate() throws -> PresenceUpdate {
        PresenceUpdate(
            user: try makeUser(),
            guild_id: GuildID("g1"),
            status: "online",
            activities: [],
            client_status: PresenceUpdate.ClientStatus(desktop: nil, mobile: nil, web: "online")
        )
    }

    /// Creates a minimal VoiceState fixture for API compliance.
    static func makeVoiceState(userId: String = "u1", sessionId: String = "sess1", channelId: String? = nil) -> VoiceState {
        VoiceState(user_id: UserID(userId), session_id: sessionId, channel_id: channelId.map(ChannelID.init))
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
            type: .messageComponent,
            data: data,
            guild_id: gid,
            channel: nil,
            channel_id: cid,
            member: nil,
            user: nil,
            token: token,
            version: 1,
            message: nil,
            app_permissions: nil,
            locale: nil,
            guild_locale: nil,
            authorizing_integration_owners: nil,
            context: nil
        )
    }
}