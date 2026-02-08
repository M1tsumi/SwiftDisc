import Foundation

// Box class to break infinite recursion for value types
public final class Box<T: Codable & Hashable>: Codable, Hashable {
    public let value: T
    public init(_ value: T) { self.value = value }
    public static func == (lhs: Box<T>, rhs: Box<T>) -> Bool { lhs.value == rhs.value }
    public func hash(into hasher: inout Hasher) { hasher.combine(value) }
}

/// Discord message model with broad field coverage, including polls, interaction metadata,
/// replies, voice messages, and components.
public struct Message: Codable, Hashable {
    public let id: MessageID
    public let channel_id: ChannelID
    public let guild_id: GuildID?
    public let author: User
    public let member: GuildMember?
    public let content: String?
    public let timestamp: String?
    public let edited_timestamp: String?
    public let tts: Bool?
    public let mention_everyone: Bool?
    public let mentions: [User]?
    public let mention_roles: [RoleID]?
    public let mention_channels: [ChannelMention]?
    public let attachments: [Attachment]?
    public let embeds: [Embed]?
    public let reactions: [Reaction]?
    public let nonce: JSONValue?
    public let pinned: Bool?
    public let type: Int?
    public let activity: MessageActivity?
    public let application: MessageApplication?
    public let application_id: ApplicationID?
    public let message_reference: MessageReference?
    public let referenced_message: Box<Message>?
    public let flags: Int?
    public let interaction_metadata: MessageInteractionMetadata?
    public let thread: Channel?
    public let components: [MessageComponent]?
    public let sticker_items: [StickerItem]?
    public let position: Int?
    public let role_subscription_data: RoleSubscriptionData?
    public let poll: Poll?
    public let resolved: ResolvedData?
    public let attachments_sync_status: Int?
}

public struct ChannelMention: Codable, Hashable {
    public let id: ChannelID
    public let guild_id: GuildID
    public let type: Int
    public let name: String
}

public struct MessageReference: Codable, Hashable {
    public let message_id: MessageID?
    public let channel_id: ChannelID?
    public let guild_id: GuildID?
    public let fail_if_not_exists: Bool?
}

public struct MessageActivity: Codable, Hashable {
    public let type: Int
    public let party_id: String?
}

public struct MessageApplication: Codable, Hashable {
    public let id: ApplicationID
    public let cover_image: String?
    public let description: String
    public let icon: String?
    public let name: String
}

public struct MessageInteractionMetadata: Codable, Hashable {
    public let id: InteractionID
    public let type: Int
    public let user: User?
    public let authorizing_integration_owners: [String: String]?
    public let original_response_message_id: MessageID?
    public let interacted_message_id: MessageID?
    public let triggering_interaction_metadata: Box<MessageInteractionMetadata>?
}

public struct RoleSubscriptionData: Codable, Hashable {
    public let role_subscription_listing_id: Snowflake<Role>
    public let tier_name: String
    public let total_months_subscribed: Int
    public let is_renewal: Bool
}

public struct ResolvedData: Codable, Hashable {
    public let attachments: [AttachmentID: Attachment]?
    public let users: [UserID: User]?
    public let members: [UserID: GuildMember]?
    public let roles: [RoleID: Role]?
    public let channels: [ChannelID: Channel]?
    public let messages: [MessageID: Box<Message>]?
}

public struct Poll: Codable, Hashable {
    public struct Media: Codable, Hashable {
        public let text: String?
        public let emoji: PartialEmoji?
    }

    public struct Answer: Codable, Hashable {
        public let answer_id: Int
        public let poll_media: Media
    }

    public struct Results: Codable, Hashable {
        public struct Count: Codable, Hashable {
            public let id: Int
            public let count: Int
            public let me_voted: Bool?
        }
        public let is_finalized: Bool?
        public let answer_counts: [Count]?
    }

    public let id: String?
    public let question: Media
    public let answers: [Answer]
    public let expiry: String?
    public let allow_multiselect: Bool?
    public let layout_type: Int?
    public let results: Results?
}

public struct AllowedMentions: Codable, Hashable {
    public let parse: [String]?
    public let roles: [RoleID]?
    public let users: [UserID]?
    public let replied_user: Bool?
}

public struct Reaction: Codable, Hashable {
    public let count: Int
    public let me: Bool
    public let emoji: PartialEmoji
}

public struct PartialEmoji: Codable, Hashable {
    public let id: EmojiID?
    public let name: String?
    public let animated: Bool?
}
