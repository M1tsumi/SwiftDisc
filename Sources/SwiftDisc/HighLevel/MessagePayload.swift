import Foundation

/// A fluent, composable payload for sending or editing Discord messages.
///
/// `MessagePayload` consolidates every message-send overload into one type.
/// Build it with chained calls then pass it to `client.send(to:_:)` or
/// `client.edit(channelId:messageId:_:)`.
///
/// ```swift
/// let payload = MessagePayload()
///     .content("Hello!")
///     .embed(EmbedBuilder().title("World").color(0x5865F2).build())
///     .component(ActionRowBuilder().add(ButtonBuilder().label("OK").customId("ok").build()).build())
///     .ephemeral()       // marks as ephemeral (interaction-only)
///
/// try await client.send(to: channelId, payload)
/// ```
public struct MessagePayload: Sendable {
    public var content: String?
    public var embeds: [Embed]?
    public var components: [MessageComponent]?
    public var allowedMentions: AllowedMentions?
    public var messageReference: MessageReference?
    public var tts: Bool?
    public var flags: Int?
    public var stickerIds: [StickerID]?
    public var files: [FileAttachment]?
    public var poll: Poll?
    public var threadName: String?
    public var threadId: ChannelID?

    public init() {}

    // MARK: - Content

    /// Set the plain-text message content.
    public func content(_ text: String) -> Self { var c = self; c.content = text; return c }

    /// Append a single `Embed` to the message.
    public func embed(_ embed: Embed) -> Self {
        var c = self
        c.embeds = (c.embeds ?? []) + [embed]
        return c
    }

    /// Set the full list of embeds (replaces any previously added embeds).
    public func embeds(_ embeds: [Embed]) -> Self { var c = self; c.embeds = embeds; return c }

    // MARK: - Components

    /// Append a single component (typically an `ActionRow`) to the message.
    public func component(_ row: MessageComponent) -> Self {
        var c = self
        c.components = (c.components ?? []) + [row]
        return c
    }

    /// Set the full list of component rows (replaces previously added rows).
    public func components(_ rows: [MessageComponent]) -> Self { var c = self; c.components = rows; return c }

    // MARK: - Replies & Mentions

    /// Turn this message into a reply to `target`.
    ///
    /// Sets `message_reference` automatically. Pass `mention: false` to suppress the
    /// @-ping on the replied-to author (defaults to `true`).
    public func reply(to target: Message, mention: Bool = true) -> Self {
        var c = self
        c.messageReference = MessageReference(
            message_id: target.id,
            channel_id: target.channel_id,
            guild_id: target.guild_id,
            fail_if_not_exists: false
        )
        if !mention {
            c.allowedMentions = AllowedMentions(
                parse: [],
                roles: nil,
                users: nil,
                replied_user: false
            )
        }
        return c
    }

    /// Override the allowed-mentions control object.
    public func allowedMentions(_ am: AllowedMentions) -> Self { var c = self; c.allowedMentions = am; return c }

    // MARK: - Flags

    /// Mark the message as *ephemeral* — only visible to the interaction invoker.
    /// Only effective in interaction responses.
    public func ephemeral() -> Self {
        var c = self; c.flags = (c.flags ?? 0) | (1 << 6); return c
    }

    /// Suppress link embeds (Discord flag bit 2).
    public func suppressEmbeds() -> Self {
        var c = self; c.flags = (c.flags ?? 0) | (1 << 2); return c
    }

    /// Mark the message as *silent* — no push/desktop notification (Discord flag bit 12).
    public func silent() -> Self {
        var c = self; c.flags = (c.flags ?? 0) | (1 << 12); return c
    }

    /// Set raw message flags (replaces any previously OR'd flags).
    public func flags(_ f: Int) -> Self { var c = self; c.flags = f; return c }

    // MARK: - TTS & Stickers

    /// Send with text-to-speech.
    public func tts(_ enabled: Bool = true) -> Self { var c = self; c.tts = enabled; return c }

    /// Attach sticker IDs to the message.
    public func stickers(_ ids: [StickerID]) -> Self { var c = self; c.stickerIds = ids; return c }

    // MARK: - Files

    /// Append a single file attachment.
    public func file(_ f: FileAttachment) -> Self {
        var c = self
        c.files = (c.files ?? []) + [f]
        return c
    }

    /// Set the full list of file attachments (replaces any previously added files).
    public func files(_ fs: [FileAttachment]) -> Self { var c = self; c.files = fs; return c }
    
    // MARK: - Polls
    
    /// Attach a poll to the message.
    /// - Parameter poll: The poll to attach
    public func poll(_ poll: Poll) -> Self { var c = self; c.poll = poll; return c }
    
    // MARK: - Threads
    
    /// Create a thread from this message with the given name.
    /// - Parameter name: The thread name
    public func thread(_ name: String) -> Self { var c = self; c.threadName = name; return c }
    
    /// Create a thread in an existing thread channel.
    /// - Parameter threadId: The parent thread ID
    public func inThread(_ threadId: ChannelID) -> Self { var c = self; c.threadId = threadId; return c }
}

// MARK: - DiscordClient send and edit API

public extension DiscordClient {
    /// Send a `MessagePayload` to a channel, automatically choosing between
    /// multipart (when files are present) and JSON requests.
    ///
    /// ```swift
    /// try await client.send(to: channelId, MessagePayload()
    ///     .content("Hello")
    ///     .embed(embed)
    ///     .ephemeral())
    /// ```
    @discardableResult
    func send(to channelId: ChannelID, _ payload: MessagePayload) async throws -> Message {
        if let files = payload.files, !files.isEmpty {
            return try await sendMessageWithFiles(
                channelId: channelId,
                content: payload.content,
                embeds: payload.embeds,
                components: payload.components,
                tts: payload.tts,
                flags: payload.flags,
                poll: payload.poll,
                files: files
            )
        }
        return try await sendMessage(
            channelId: channelId,
            content: payload.content,
            embeds: payload.embeds,
            components: payload.components,
            allowedMentions: payload.allowedMentions,
            messageReference: payload.messageReference,
            tts: payload.tts,
            flags: payload.flags,
            stickerIds: payload.stickerIds,
            poll: payload.poll
        )
    }

    /// Edit an existing message using a `MessagePayload`.
    @discardableResult
    func edit(channelId: ChannelID, messageId: MessageID, _ payload: MessagePayload) async throws -> Message {
        if let files = payload.files, !files.isEmpty {
            return try await editMessageWithFiles(
                channelId: channelId,
                messageId: messageId,
                content: payload.content,
                embeds: payload.embeds,
                components: payload.components,
                files: files
            )
        }
        return try await editMessage(
            channelId: channelId,
            messageId: messageId,
            content: payload.content,
            embeds: payload.embeds,
            components: payload.components
        )
    }

    /// Respond to an interaction with a `MessagePayload`.
    ///
    /// Automatically uses `createInteractionResponse` with type 4 (channel message)
    /// or type 5 (deferred) when `payload.content` and `.embeds` are both nil.
    func respond(
        to interaction: Interaction,
        with payload: MessagePayload,
        deferred: Bool = false
    ) async throws {
        let type: InteractionResponseType = deferred
            ? .deferredChannelMessageWithSource
            : .channelMessageWithSource
        struct DataObj: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
            let flags: Int?
            let tts: Bool?
            let allowed_mentions: AllowedMentions?
        }
        struct Body: Encodable, Sendable {
            let type: Int
            let data: DataObj
        }
        let data = DataObj(
            content: payload.content,
            embeds: payload.embeds,
            components: payload.components,
            flags: payload.flags,
            tts: payload.tts,
            allowed_mentions: payload.allowedMentions
        )
        struct Ack: Decodable, Sendable {
        }
        let _: Ack = try await http.post(
            path: "/interactions/\(interaction.id)/\(interaction.token)/callback",
            body: Body(type: type.rawValue, data: data)
        )
    }
}
