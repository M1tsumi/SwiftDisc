import Foundation

// `Box` breaks recursive value-type cycles during Codable decoding.
// It is `@unchecked Sendable` because it only stores immutable state (`let value`).
// That keeps instances effectively safe to share across tasks.
public final class Box<T: Codable & Hashable>: Codable, Hashable, @unchecked Sendable {
    public let value: T
    public init(_ value: T) { self.value = value }
    public static func == (lhs: Box<T>, rhs: Box<T>) -> Bool { lhs.value == rhs.value }
    public func hash(into hasher: inout Hasher) { hasher.combine(value) }
}

/// Represents a Discord message.
///
/// Messages are the primary way users communicate in Discord. This struct includes support for:
/// - Text content and embeds
/// - Attachments and stickers
/// - Reactions
/// - Message components (buttons, select menus)
/// - Polls
/// - Message references (replies, forwards)
/// - Interaction metadata
///
/// ## Example
///
/// ```swift
/// await client.setOnMessage { message in
///     print("Author: \(message.author.username)")
///     if let content = message.content {
///         print("Content: \(content)")
///     }
///     if let attachments = message.attachments, !attachments.isEmpty {
///         print("Attachments: \(attachments.count)")
///     }
/// }
/// ```
///
/// ## Related Topics
/// - ``DiscordClient/sendMessage(channelId:content:)``
/// - ``DiscordClient/editMessage(channelId:messageId:content:embeds:components:)``
/// - ``DiscordClient/deleteMessage(channelId:messageId:)``
public struct Message: Codable, Hashable, Sendable {
    /// The unique ID of the message.
    public let id: MessageID
    
    /// The ID of the channel the message was sent in.
    public let channel_id: ChannelID
    
    /// The ID of the guild the message was sent in (null for DMs).
    public let guild_id: GuildID?
    
    /// The author of the message.
    public let author: User
    
    /// The member properties for the author (only in guild messages).
    public let member: GuildMember?
    
    /// The message content (up to 2000 characters).
    public let content: String?
    
    /// The timestamp when the message was created (ISO8601 timestamp).
    public let timestamp: String?
    
    /// The timestamp when the message was last edited (ISO8601 timestamp, null if never edited).
    public let edited_timestamp: String?
    
    /// Whether this was a TTS (text-to-speech) message.
    public let tts: Bool?
    
    /// Whether this message mentions everyone.
    public let mention_everyone: Bool?
    
    /// Users specifically mentioned in the message.
    public let mentions: [User]?
    
    /// Roles specifically mentioned in the message.
    public let mention_roles: [RoleID]?
    
    /// Channels specifically mentioned in the message.
    public let mention_channels: [ChannelMention]?
    
    /// Attachments in the message.
    public let attachments: [Attachment]?
    
    /// Embeds in the message.
    public let embeds: [Embed]?
    
    /// Reactions to the message.
    public let reactions: [Reaction]?
    
    /// Used for validating a message was sent (nonce).
    public let nonce: JSONValue?
    
    /// Whether this message is pinned.
    public let pinned: Bool?
    
    /// The type of message (see Discord documentation for type values).
    public let type: Int?
    
    /// Activity information for rich presence-related messages.
    public let activity: MessageActivity?
    
    /// Application information for application-related messages.
    public let application: MessageApplication?
    
    /// The ID of the application that sent the message (if applicable).
    public let application_id: ApplicationID?
    
    /// Data showing the source of crossposts, channel follow adds, pins, or replies.
    public let message_reference: MessageReference?
    
    /// The message referenced in the message_reference field (for replies/forwards).
    public let referenced_message: Box<Message>?
    
    /// Message flags combined as a bitfield.
    public let flags: Int?
    
    /// Metadata for interaction-related messages.
    public let interaction_metadata: MessageInteractionMetadata?
    
    /// The thread that was started from this message (includes channel object).
    public let thread: Channel?
    
    /// Message components (buttons, select menus, etc.) attached to the message.
    public let components: [MessageComponent]?
    
    /// Stickers in the message.
    public let sticker_items: [StickerItem]?
    
    /// The position of the message (for thread starting messages).
    public let position: Int?
    
    /// Data for role subscription-related messages.
    public let role_subscription_data: RoleSubscriptionData?
    
    /// Poll data if the message contains a poll.
    public let poll: Poll?
    
    /// Resolved data for interaction responses.
    public let resolved: ResolvedData?
    
    /// The sync status of attachments.
    public let attachments_sync_status: Int?
}

/// Represents a channel mention in a message.
///
/// This struct provides information about channels that are mentioned in a message.
public struct ChannelMention: Codable, Hashable, Sendable {
    /// The ID of the mentioned channel.
    public let id: ChannelID
    
    /// The ID of the guild the mentioned channel is in.
    public let guild_id: GuildID
    
    /// The type of channel.
    public let type: Int
    
    /// The name of the mentioned channel.
    public let name: String
}

/// Represents a reference to another message.
///
/// Used for replies, forwards, and other message reference scenarios.
///
/// ## Example
///
/// ```swift
/// let reference = MessageReference(
///     message_id: messageId,
///     channel_id: channelId,
///     guild_id: guildId
/// )
/// ```
public struct MessageReference: Codable, Hashable, Sendable {
    /// The ID of the referenced message.
    public let message_id: MessageID?
    
    /// The ID of the channel the referenced message is in.
    public let channel_id: ChannelID?
    
    /// The ID of the guild the referenced message is in.
    public let guild_id: GuildID?
    
    /// Whether to throw an error if the referenced message doesn't exist.
    public let fail_if_not_exists: Bool?
    
    public init(message_id: MessageID? = nil, channel_id: ChannelID? = nil, guild_id: GuildID? = nil, fail_if_not_exists: Bool? = nil) {
        self.message_id = message_id
        self.channel_id = channel_id
        self.guild_id = guild_id
        self.fail_if_not_exists = fail_if_not_exists
    }
}

/// Represents activity information for rich presence-related messages.
///
/// Used for messages that invite users to join activities (e.g., "Join to play").
public struct MessageActivity: Codable, Hashable, Sendable {
    /// The type of activity (1: JOIN, 2: SPECTATE, 3: LISTEN, 5: JOIN_REQUEST).
    public let type: Int
    
    /// The party ID from the rich presence event.
    public let party_id: String?
}

/// Represents application information for application-related messages.
///
/// Used for messages sent by applications (e.g., game invites).
public struct MessageApplication: Codable, Hashable, Sendable {
    /// The ID of the application.
    public let id: ApplicationID
    
    /// The cover image hash of the application.
    public let cover_image: String?
    
    /// The description of the application.
    public let description: String
    
    /// The icon hash of the application.
    public let icon: String?
    
    /// The name of the application.
    public let name: String
}

/// Represents metadata for interaction-related messages.
///
/// Used for messages generated by interactions (slash commands, buttons, etc.).
public struct MessageInteractionMetadata: Codable, Hashable, Sendable {
    /// The ID of the interaction.
    public let id: InteractionID
    
    /// The type of interaction.
    public let type: Int
    
    /// The user who triggered the interaction.
    public let user: User?
    
    /// The authorizing integration owners.
    public let authorizing_integration_owners: [String: String]?
    
    /// The ID of the original response message.
    public let original_response_message_id: MessageID?
    
    /// The ID of the message that was interacted with.
    public let interacted_message_id: MessageID?
    
    /// Metadata for the triggering interaction (for nested interactions).
    public let triggering_interaction_metadata: Box<MessageInteractionMetadata>?
}

/// Represents role subscription data for subscription-related messages.
///
/// Used for messages related to role subscriptions.
public struct RoleSubscriptionData: Codable, Hashable, Sendable {
    /// The ID of the role subscription listing.
    public let role_subscription_listing_id: Snowflake<Role>
    
    /// The name of the tier.
    public let tier_name: String
    
    /// The total months the user has been subscribed.
    public let total_months_subscribed: Int
    
    /// Whether this is a renewal.
    public let is_renewal: Bool
}

/// Represents resolved data for interaction responses.
///
/// Contains resolved entities (users, members, roles, channels, messages, attachments)
/// for interaction responses.
public struct ResolvedData: Codable, Hashable, Sendable {
    /// Resolved attachments.
    public let attachments: [AttachmentID: Attachment]?
    
    /// Resolved users.
    public let users: [UserID: User]?
    
    /// Resolved guild members.
    public let members: [UserID: GuildMember]?
    
    /// Resolved roles.
    public let roles: [RoleID: Role]?
    
    /// Resolved channels.
    public let channels: [ChannelID: Channel]?
    
    /// Resolved messages.
    public let messages: [MessageID: Box<Message>]?
}

/// Represents a poll attached to a message.
///
/// Polls allow users to vote on multiple-choice questions.
///
/// ## Example
///
/// ```swift
/// if let poll = message.poll {
///     print("Poll question: \(poll.question.text ?? "")")
///     for answer in poll.answers {
///         print("Answer: \(answer.poll_media.text ?? "")")
///     }
/// }
/// ```
public struct Poll: Codable, Hashable, Sendable {
    /// Represents media (text and emoji) for a poll question or answer.
    public struct Media: Codable, Hashable, Sendable {
        /// The text of the poll question or answer.
        public let text: String?
        
        /// The emoji for the poll answer.
        public let emoji: PartialEmoji?
    }

    /// Represents a single answer in a poll.
    public struct Answer: Codable, Hashable, Sendable {
        /// The ID of the answer.
        public let answer_id: Int
        
        /// The media (text and emoji) for this answer.
        public let poll_media: Media
    }

    /// Represents the results of a poll.
    public struct Results: Codable, Hashable, Sendable {
        /// Represents the count for a single poll answer.
        public struct Count: Codable, Hashable, Sendable {
            /// The answer ID.
            public let id: Int
            
            /// The number of votes for this answer.
            public let count: Int
            
            /// Whether the current user voted for this answer.
            public let me_voted: Bool?
        }
        
        /// Whether the poll has been finalized and can no longer be voted on.
        public let is_finalized: Bool?
        
        /// The vote counts for each answer.
        public let answer_counts: [Count]?
    }

    /// The ID of the poll.
    public let id: String?
    
    /// The question for the poll.
    public let question: Media
    
    /// The available answers for the poll.
    public let answers: [Answer]
    
    /// The timestamp when the poll expires (ISO8601 timestamp).
    public let expiry: String?
    
    /// Whether users can select multiple answers.
    public let allow_multiselect: Bool?
    
    /// The layout type of the poll.
    public let layout_type: Int?
    
    /// The results of the poll (if the poll has ended).
    public let results: Results?
}

/// Response from the poll answer voters endpoint.
///
/// Contains a paginated list of users who voted for a specific poll answer.
///
/// ## Example
///
/// ```swift
/// let voters = try await client.getPollAnswerVoters(
///     channelId: channelId,
///     messageId: messageId,
///     answerId: 1
/// )
/// print("\(voters.users.count) users voted for this answer")
/// if voters.has_more {
///     print("More users available")
/// }
/// ```
public struct PollAnswerUsers: Codable, Hashable, Sendable {
    /// Whether there are more users after this batch.
    public let has_more: Bool?
    
    /// List of users who voted for this answer.
    public let users: [User]
    
    /// User ID to use for pagination (for the `after` parameter).
    public let after: UserID?
}

/// Controls which mentions are allowed to trigger notifications in a message.
///
/// Use this to prevent unwanted pings when sending messages.
///
/// ## Example
///
/// ```swift
/// // Allow only specific roles to be pinged
/// let mentions = AllowedMentions(
///     parse: ["roles"],
///     roles: [roleId1, roleId2],
///     users: nil
/// )
///
/// // Suppress all mentions
/// let noMentions = AllowedMentions(parse: [])
/// ```
///
/// ## Parse Values
/// - `"users"`: Allow user mentions
/// - `"roles"`: Allow role mentions
/// - `"everyone"`: Allow @everyone and @here mentions
public struct AllowedMentions: Codable, Hashable, Sendable {
    /// The types of mentions to parse ("users", "roles", "everyone").
    /// If empty, no mentions will be parsed.
    public let parse: [String]?
    
    /// Specific role IDs that are allowed to be mentioned.
    public let roles: [RoleID]?
    
    /// Specific user IDs that are allowed to be mentioned.
    public let users: [UserID]?
    
    /// Whether to mention the author of the message being replied to.
    public let replied_user: Bool?

    public init(parse: [String]? = nil, roles: [RoleID]? = nil, users: [UserID]? = nil, replied_user: Bool? = nil) {
        self.parse = parse
        self.roles = roles
        self.users = users
        self.replied_user = replied_user
    }
}

/// Represents a reaction to a message.
///
/// Reactions are emoji-based responses to messages.
///
/// ## Example
///
/// ```swift
/// if let reactions = message.reactions {
///     for reaction in reactions {
///         print("\(reaction.count) users reacted with \(reaction.emoji.name ?? "")")
///         if reaction.me {
///             print("  (you reacted)")
///         }
///     }
/// }
/// ```
public struct Reaction: Codable, Hashable, Sendable {
    /// The number of users who have reacted with this emoji.
    public let count: Int
    
    /// Whether the current user has reacted with this emoji.
    public let me: Bool
    
    /// The emoji information for this reaction.
    public let emoji: PartialEmoji
}

/// Represents a partial emoji object.
///
/// Used in reactions and other contexts where full emoji information may not be available.
///
/// ## Example
///
/// ```swift
/// if let reaction = message.reactions?.first {
///     let emoji = reaction.emoji
///     if let id = emoji.id {
///         print("Custom emoji ID: \(id)")
///     } else if let name = emoji.name {
///         print("Unicode emoji: \(name)")
///     }
/// }
/// ```
public struct PartialEmoji: Codable, Hashable, Sendable {
    /// The ID of the custom emoji (null for Unicode emoji).
    public let id: EmojiID?
    
    /// The name of the emoji (Unicode character or custom emoji name).
    public let name: String?
    
    /// Whether this emoji is animated (custom emoji only).
    public let animated: Bool?
}

// MARK: - Reply API

public extension Message {
    /// Replies to this message in the same channel.
    ///
    /// This convenience method automatically sets the message reference and handles mention settings.
    ///
    /// - Parameters:
    ///   - client: The `DiscordClient` to use for the HTTP call.
    ///   - content: Plain-text content for the reply (optional).
    ///   - embeds: Optional embeds to attach.
    ///   - components: Optional component rows to attach.
    ///   - mention: When `false`, suppresses the @mention ping on the replied-to author.
    ///                Defaults to `true` (Discord default behavior).
    ///
    /// - Returns: The newly created reply message.
    /// - Throws: `DiscordError` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// await client.setOnMessage { message in
    ///     guard message.content?.lowercased() == "!reply" else { return }
    ///     // Reply without pinging the author
    ///     try await message.reply(
    ///         client: client,
    ///         content: "Hello!",
    ///         mention: false
    ///     )
    /// }
    /// ```
    @discardableResult
    func reply(
        client: DiscordClient,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        mention: Bool = true
    ) async throws -> Message {
        let ref = MessageReference(
            message_id: id,
            channel_id: channel_id,
            guild_id: guild_id,
            fail_if_not_exists: false
        )
        let allowed: AllowedMentions? = mention
            ? nil
            : AllowedMentions(parse: [], roles: nil, users: nil, replied_user: false)
        return try await client.sendMessage(
            channelId: channel_id,
            content: content,
            embeds: embeds,
            components: components,
            allowedMentions: allowed,
            messageReference: ref
        )
    }
}
