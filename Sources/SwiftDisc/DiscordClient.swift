import Foundation

/// The primary client for interacting with the Discord API.
///
/// `DiscordClient` is an `actor`, giving every method and stored property
/// automatic data-race safety. `let` stored properties (e.g. `token`, `cache`)
/// are accessible from any context without `await`.
public actor DiscordClient {
    public nonisolated let token: String
    let http: HTTPClient
    private let gateway: GatewayClient
    private let configuration: DiscordConfiguration
    private let dispatcher = EventDispatcher()
    private var currentUserId: UserID?

    private let eventStream: AsyncStream<DiscordEvent>
    private var eventContinuation: AsyncStream<DiscordEvent>.Continuation?

    public let cache = Cache()

    // Loaded extensions are tracked so they can be unloaded cleanly.
    private var loadedExtensions: [SwiftDiscExtension] = []

    public var events: AsyncStream<DiscordEvent> { eventStream }

    // MARK: - Event Callbacks
    // Assign any of these to be notified of specific gateway events.
    // All callbacks are @Sendable so they can be used safely across actor / task boundaries.

    // -- Ready --
    public var onReady: (@Sendable (ReadyEvent) async -> Void)?

    // -- Messages --
    public var onMessage: (@Sendable (Message) async -> Void)?
    public var onMessageUpdate: (@Sendable (Message) async -> Void)?
    public var onMessageDelete: (@Sendable (MessageDelete) async -> Void)?
    public var onMessageDeleteBulk: (@Sendable (MessageDeleteBulk) async -> Void)?

    // -- Reactions --
    public var onReactionAdd: (@Sendable (MessageReactionAdd) async -> Void)?
    public var onReactionRemove: (@Sendable (MessageReactionRemove) async -> Void)?
    public var onReactionRemoveAll: (@Sendable (MessageReactionRemoveAll) async -> Void)?
    public var onReactionRemoveEmoji: (@Sendable (MessageReactionRemoveEmoji) async -> Void)?

    // -- Guilds --
    public var onGuildCreate: (@Sendable (Guild) async -> Void)?
    public var onGuildUpdate: (@Sendable (Guild) async -> Void)?
    public var onGuildDelete: (@Sendable (GuildDelete) async -> Void)?

    // -- Members --
    public var onGuildMemberAdd: (@Sendable (GuildMemberAdd) async -> Void)?
    public var onGuildMemberRemove: (@Sendable (GuildMemberRemove) async -> Void)?
    public var onGuildMemberUpdate: (@Sendable (GuildMemberUpdate) async -> Void)?

    // -- Channels --
    public var onChannelCreate: (@Sendable (Channel) async -> Void)?
    public var onChannelUpdate: (@Sendable (Channel) async -> Void)?
    public var onChannelDelete: (@Sendable (Channel) async -> Void)?

    // -- Threads --
    public var onThreadCreate: (@Sendable (Channel) async -> Void)?
    public var onThreadUpdate: (@Sendable (Channel) async -> Void)?
    public var onThreadDelete: (@Sendable (Channel) async -> Void)?
    public var onThreadMembersUpdate: (@Sendable (ThreadMembersUpdate) async -> Void)?

    // -- Roles --
    public var onGuildRoleCreate: (@Sendable (GuildRoleCreate) async -> Void)?
    public var onGuildRoleUpdate: (@Sendable (GuildRoleUpdate) async -> Void)?
    public var onGuildRoleDelete: (@Sendable (GuildRoleDelete) async -> Void)?

    // -- Moderation --
    public var onGuildBanAdd: (@Sendable (GuildBanAdd) async -> Void)?
    public var onGuildBanRemove: (@Sendable (GuildBanRemove) async -> Void)?
    public var onAutoModerationActionExecution: (@Sendable (AutoModerationActionExecution) async -> Void)?

    // -- Interactions --
    public var onInteractionCreate: (@Sendable (Interaction) async -> Void)?
    public var onApplicationCommandPermissionsUpdate: (@Sendable (ApplicationCommandPermissionsUpdate) async -> Void)?

    // -- Presence & Typing --
    public var onTypingStart: (@Sendable (TypingStart) async -> Void)?
    public var onPresenceUpdate: (@Sendable (PresenceUpdate) async -> Void)?

    // -- Scheduled Events --
    public var onGuildScheduledEventCreate: (@Sendable (GuildScheduledEvent) async -> Void)?
    public var onGuildScheduledEventUpdate: (@Sendable (GuildScheduledEvent) async -> Void)?
    public var onGuildScheduledEventDelete: (@Sendable (GuildScheduledEvent) async -> Void)?

    // -- Polls --
    public var onPollVoteAdd: (@Sendable (PollVote) async -> Void)?
    public var onPollVoteRemove: (@Sendable (PollVote) async -> Void)?

    // -- Entitlements / Monetization --
    public var onEntitlementCreate: (@Sendable (Entitlement) async -> Void)?
    public var onEntitlementUpdate: (@Sendable (Entitlement) async -> Void)?
    public var onEntitlementDelete: (@Sendable (Entitlement) async -> Void)?

    // -- Soundboard --
    public var onSoundboardSoundCreate: (@Sendable (SoundboardSound) async -> Void)?
    public var onSoundboardSoundUpdate: (@Sendable (SoundboardSound) async -> Void)?
    public var onSoundboardSoundDelete: (@Sendable (SoundboardSound) async -> Void)?

    // Command framework entry point.
    public var commands: CommandRouter?
    public func useCommands(_ router: CommandRouter) { self.commands = router }

    // View manager handles persistent component state and dispatch.
    public var viewManager: ViewManager?
    public func useViewManager(_ manager: ViewManager) {
        self.viewManager = manager
        manager.start(client: self)
    }

    // Slash command router entry point.
    public var slashCommands: SlashCommandRouter?
    public func useSlashCommands(_ router: SlashCommandRouter) { self.slashCommands = router }

    // Autocomplete router for slash option suggestions.
    public var autocomplete: AutocompleteRouter?
    public func useAutocomplete(_ router: AutocompleteRouter) { self.autocomplete = router }


    public init(token: String, configuration: DiscordConfiguration = .init()) {
        self.token = token
        self.http = HTTPClient(token: token, configuration: configuration)
        self.gateway = GatewayClient(token: token, configuration: configuration)
        self.configuration = configuration

        self.eventStream = AsyncStream<DiscordEvent> { continuation in
            continuation.onTermination = { @Sendable _ in }
            self.eventContinuation = continuation
        }
    }

    // MARK: - Extensions/Cogs
    public func loadExtension(_ ext: SwiftDiscExtension) async {
        loadedExtensions.append(ext)
        await ext.onRegister(client: self)
    }

    public func unloadExtensions() async {
        let exts = loadedExtensions
        loadedExtensions.removeAll()
        for ext in exts { await ext.onUnload(client: self) }
    }
    // MARK: - REST: Bulk Messages and Crosspost

    /// Sets the callback invoked when the READY event is received.
    public func setOnReady(_ handler: (@Sendable (ReadyEvent) async -> Void)?) {
        self.onReady = handler
    }

    /// Sets the callback invoked for MESSAGE_CREATE events.
    public func setOnMessage(_ handler: (@Sendable (Message) async -> Void)?) {
        self.onMessage = handler
    }

    // Bulk delete supports 2...100 messages that are newer than Discord's 14-day limit.
    public func bulkDeleteMessages(channelId: ChannelID, messageIds: [MessageID]) async throws {
        struct Body: Encodable, Sendable {
            let messages: [MessageID]
        }
        struct Ack: Decodable, Sendable {
        }
        let body = Body(messages: messageIds)
        let _: Ack = try await http.post(path: "/channels/\(channelId)/messages/bulk-delete", body: body)
    }

    // Publish a news-channel message to follower channels.
    public func crosspostMessage(channelId: ChannelID, messageId: MessageID) async throws -> Message {
        struct Empty: Encodable, Sendable {
        }
        return try await http.post(path: "/channels/\(channelId)/messages/\(messageId)/crosspost", body: Empty())
    }

    // MARK: - REST: Pins
    public func getPinnedMessages(channelId: ChannelID) async throws -> [Message] {
        try await http.get(path: "/channels/\(channelId)/pins")
    }

    public func pinMessage(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.put(path: "/channels/\(channelId)/pins/\(messageId)")
    }

    public func unpinMessage(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.delete(path: "/channels/\(channelId)/pins/\(messageId)")
    }

    // MARK: - REST: Paginated Pins (new endpoints)
    /// Uses the paginated pins endpoint: `GET /channels/{channel.id}/messages/pins`.
    public func getChannelPinsPaginated(channelId: ChannelID, limit: Int? = nil, after: MessageID? = nil) async throws -> [Message] {
        var query = ""
        if let limit { query += (query.isEmpty ? "?" : "&") + "limit=\(limit)" }
        if let after { query += (query.isEmpty ? "?" : "&") + "after=\(after)" }
        return try await http.get(path: "/channels/\(channelId)/messages/pins\(query)")
    }

    /// Typed wrappers for newer pin endpoints, kept alongside legacy routes for compatibility.
    public func pinMessageV2(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.put(path: "/channels/\(channelId)/messages/pins/\(messageId)")
    }

    public func unpinMessageV2(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/pins/\(messageId)")
    }

    // MARK: - REST: Messages with Files
    public func sendMessageWithFiles(
        channelId: ChannelID,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        allowedMentions: AllowedMentions? = nil,
        messageReference: MessageReference? = nil,
        tts: Bool? = nil,
        flags: Int? = nil,
        stickerIds: [StickerID]? = nil,
        attachments: [PartialAttachment]? = nil,
        poll: Poll? = nil,
        files: [FileAttachment]
    ) async throws -> Message {
        struct Payload: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
            let allowed_mentions: AllowedMentions?
            let message_reference: MessageReference?
            let tts: Bool?
            let flags: Int?
            let sticker_ids: [StickerID]?
            let attachments: [PartialAttachment]?
            let poll: Poll?
        }
        let body = Payload(
            content: content,
            embeds: embeds,
            components: components,
            allowed_mentions: allowedMentions,
            message_reference: messageReference,
            tts: tts,
            flags: flags,
            sticker_ids: stickerIds,
            attachments: attachments,
            poll: poll
        )
        return try await http.postMultipart(path: "/channels/\(channelId)/messages", jsonBody: body, files: files)
    }

    public func editMessageWithFiles(
        channelId: ChannelID,
        messageId: MessageID,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        files: [FileAttachment]? = nil,
        attachments: [PartialAttachment]? = nil
    ) async throws -> Message {
        struct Payload: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
            let attachments: [PartialAttachment]?
        }
        let body = Payload(content: content, embeds: embeds, components: components, attachments: attachments)
        return try await http.patchMultipart(path: "/channels/\(channelId)/messages/\(messageId)", jsonBody: body, files: files)
    }

    // MARK: - REST: Interaction Follow-ups
    public func getOriginalInteractionResponse(applicationId: ApplicationID, interactionToken: String) async throws -> Message {
        try await http.get(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/@original")
    }

    public func editOriginalInteractionResponse(applicationId: ApplicationID, interactionToken: String, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
        }
        return try await http.patch(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/@original", body: Body(content: content, embeds: embeds, components: components))
    }

    public func deleteOriginalInteractionResponse(applicationId: ApplicationID, interactionToken: String) async throws {
        try await http.delete(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/@original")
    }

    public func createFollowupMessage(applicationId: ApplicationID, interactionToken: String, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil, ephemeral: Bool = false) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
            let flags: Int?
        }
        let flags = ephemeral ? 64 : nil
        return try await http.post(path: "/webhooks/\(applicationId)/\(interactionToken)", body: Body(content: content, embeds: embeds, components: components, flags: flags))
    }

    /// Create a follow-up message with file attachments (multipart). Returns the created `Message` when `wait=true` is used.
    public func createFollowupMessageWithFiles(applicationId: ApplicationID, interactionToken: String, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil, files: [FileAttachment]) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
        }
        // `wait=true` makes the webhook endpoint return the created message payload.
        return try await http.postMultipart(path: "/webhooks/\(applicationId)/\(interactionToken)?wait=true", jsonBody: Body(content: content, embeds: embeds, components: components), files: files)
    }

    /// Respond to an interaction (initial response) with files via webhook. This posts to the webhook URL and returns the created message when `wait=true` is used.
    public func createInteractionResponseWithFiles(applicationId: ApplicationID, interactionToken: String, payload: [String: JSONValue], files: [FileAttachment]) async throws -> Message {
        return try await http.postMultipart(path: "/webhooks/\(applicationId)/\(interactionToken)?wait=true", jsonBody: payload, files: files)
    }

    public func getFollowupMessage(applicationId: ApplicationID, interactionToken: String, messageId: MessageID) async throws -> Message {
        try await http.get(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/\(messageId)")
    }

    public func editFollowupMessage(applicationId: ApplicationID, interactionToken: String, messageId: MessageID, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
        }
        return try await http.patch(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/\(messageId)", body: Body(content: content, embeds: embeds, components: components))
    }

    public func deleteFollowupMessage(applicationId: ApplicationID, interactionToken: String, messageId: MessageID) async throws {
        try await http.delete(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/\(messageId)")
    }

    // MARK: - Application command localization endpoints
    public func setCommandLocalizations(applicationId: ApplicationID, commandId: ApplicationCommandID, nameLocalizations: [String: String]?, descriptionLocalizations: [String: String]?) async throws -> ApplicationCommand {
        struct Body: Encodable, Sendable {
            let name_localizations: [String: String]?
            let description_localizations: [String: String]?
        }
        return try await http.patch(path: "/applications/\(applicationId)/commands/\(commandId)", body: Body(name_localizations: nameLocalizations, description_localizations: descriptionLocalizations))
    }

    // MARK: - Forward message by reference
    public func forwardMessageByReference(targetChannelId: ChannelID, sourceChannelId: ChannelID, messageId: MessageID) async throws -> Message {
        // Send a message in targetChannelId that references the source message.
        let payload: [String: JSONValue] = [
            "message_reference": .object([
                "channel_id": .string(String(describing: sourceChannelId)),
                "message_id": .string(String(describing: messageId))
            ])
        ]
        return try await http.post(path: "/channels/\(targetChannelId)/messages", body: payload)
    }

    // MARK: - Components V2 and poll endpoints
    // Low-level send entry point for JSONValue payloads such as Components V2 bodies.
    public func postMessage(channelId: ChannelID, payload: [String: JSONValue]) async throws -> Message {
        try await http.post(path: "/channels/\(channelId)/messages", body: payload)
    }

    // Merges optional message fields with a raw `poll` payload.
    public func createPollMessage(channelId: ChannelID, content: String? = nil, poll: [String: JSONValue], flags: Int? = nil, components: [JSONValue]? = nil) async throws -> Message {
        var body: [String: JSONValue] = [
            "poll": .object(poll)
        ]
        if let content { body["content"] = .string(content) }
        if let flags { body["flags"] = .int(flags) }
        if let components { body["components"] = .array(components) }
        return try await http.post(path: "/channels/\(channelId)/messages", body: body)
    }

    // MARK: - Components V2 typed payload
    public func sendComponentsV2Message(channelId: ChannelID, payload: V2MessagePayload) async throws -> Message {
        try await http.post(path: "/channels/\(channelId)/messages", body: payload.asJSON())
    }

    // MARK: - Poll typed payload
    public func createPollMessage(channelId: ChannelID, payload: PollPayload, content: String? = nil, flags: Int? = nil, components: [JSONValue]? = nil) async throws -> Message {
        var body: [String: JSONValue] = [
            "poll": .object(payload.pollJSON())
        ]
        if let content { body["content"] = .string(content) }
        if let flags { body["flags"] = .int(flags) }
        if let components { body["components"] = .array(components) }
        return try await http.post(path: "/channels/\(channelId)/messages", body: body)
    }

    // MARK: - App emoji endpoints
    public func createAppEmoji(applicationId: ApplicationID, name: String, imageBase64: String, options: [String: JSONValue]? = nil) async throws -> JSONValue {
        var payload: [String: JSONValue] = [
            "name": .string(name),
            "image": .string(imageBase64)
        ]
        if let options { for (k, v) in options { payload[k] = v } }
        return try await postApplicationResource(applicationId: applicationId, relativePath: "app-emojis", payload: payload)
    }

    public func updateAppEmoji(applicationId: ApplicationID, emojiId: String, updates: [String: JSONValue]) async throws -> JSONValue {
        try await patchApplicationResource(applicationId: applicationId, relativePath: "app-emojis/\(emojiId)", payload: updates)
    }

    public func deleteAppEmoji(applicationId: ApplicationID, emojiId: String) async throws {
        try await deleteApplicationResource(applicationId: applicationId, relativePath: "app-emojis/\(emojiId)")
    }

    // MARK: - User app resource endpoints
    public func createUserAppResource(applicationId: ApplicationID, relativePath: String, payload: [String: JSONValue]) async throws -> JSONValue {
        try await postApplicationResource(applicationId: applicationId, relativePath: relativePath, payload: payload)
    }

    public func updateUserAppResource(applicationId: ApplicationID, relativePath: String, payload: [String: JSONValue]) async throws -> JSONValue {
        try await patchApplicationResource(applicationId: applicationId, relativePath: relativePath, payload: payload)
    }

    public func deleteUserAppResource(applicationId: ApplicationID, relativePath: String) async throws {
        try await deleteApplicationResource(applicationId: applicationId, relativePath: relativePath)
    }

    // Guild widget settings endpoints.
    public func getGuildWidgetSettings(guildId: GuildID) async throws -> GuildWidgetSettings {
        try await http.get(path: "/guilds/\(guildId)/widget")
    }

    public func modifyGuildWidgetSettings(guildId: GuildID, enabled: Bool, channelId: ChannelID?) async throws -> GuildWidgetSettings {
        struct Body: Encodable, Sendable {
            let enabled: Bool
            let channel_id: ChannelID?
        }
        return try await http.patch(path: "/guilds/\(guildId)/widget", body: Body(enabled: enabled, channel_id: channelId))
    }

    // MARK: - REST: Emojis
    public func listGuildEmojis(guildId: GuildID) async throws -> [Emoji] {
        try await http.get(path: "/guilds/\(guildId)/emojis")
    }

    public func getGuildEmoji(guildId: GuildID, emojiId: EmojiID) async throws -> Emoji {
        try await http.get(path: "/guilds/\(guildId)/emojis/\(emojiId)")
    }

    public func createGuildEmoji(guildId: GuildID, name: String, image: String, roles: [RoleID]? = nil) async throws -> Emoji {
        struct Body: Encodable, Sendable {
            let name: String
            let image: String
            let roles: [RoleID]?
        }
        return try await http.post(path: "/guilds/\(guildId)/emojis", body: Body(name: name, image: image, roles: roles))
    }

    public func modifyGuildEmoji(guildId: GuildID, emojiId: EmojiID, name: String? = nil, roles: [RoleID]? = nil) async throws -> Emoji {
        struct Body: Encodable, Sendable {
            let name: String?
            let roles: [RoleID]?
        }
        return try await http.patch(path: "/guilds/\(guildId)/emojis/\(emojiId)", body: Body(name: name, roles: roles))
    }

    public func deleteGuildEmoji(guildId: GuildID, emojiId: EmojiID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/emojis/\(emojiId)")
    }

    // MARK: - REST: Guild member advanced operations
    // Adds a user to a guild with an OAuth2 access token.
    public func addGuildMember(guildId: GuildID, userId: UserID, accessToken: String, nick: String? = nil, roles: [RoleID]? = nil, mute: Bool? = nil, deaf: Bool? = nil) async throws -> GuildMember {
        struct Body: Encodable, Sendable {
            let access_token: String
            let nick: String?
            let roles: [RoleID]?
            let mute: Bool?
            let deaf: Bool?
        }
        return try await http.put(path: "/guilds/\(guildId)/members/\(userId)", body: Body(access_token: accessToken, nick: nick, roles: roles, mute: mute, deaf: deaf))
    }

    // Kicks a member from the guild.
    public func removeGuildMember(guildId: GuildID, userId: UserID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/members/\(userId)")
    }

    // Updates the current bot member profile inside a guild.
    /// Supports `nick`, `avatar`, `banner`, and `bio` fields.
    /// `avatar` and `banner` should be base64 data URIs (e.g. `data:image/png;base64,...`).
    /// Availability of `avatar`, `banner`, and `bio` added 2025-09-10.
    public func modifyCurrentMember(
        guildId: GuildID,
        nick: String? = nil,
        avatar: String? = nil,
        banner: String? = nil,
        bio: String? = nil
    ) async throws -> GuildMember {
        struct Body: Encodable, Sendable {
            let nick: String?
            let avatar: String?
            let banner: String?
            let bio: String?
        }
        return try await http.patch(path: "/guilds/\(guildId)/members/@me", body: Body(nick: nick, avatar: avatar, banner: banner, bio: bio))
    }

    // Legacy nickname endpoint kept for compatibility.
    public func modifyCurrentUserNick(guildId: GuildID, nick: String?) async throws -> String {
        struct Body: Encodable, Sendable {
            let nick: String?
        }
        struct Resp: Decodable, Sendable {
            let nick: String
        }
        let resp: Resp = try await http.patch(path: "/guilds/\(guildId)/members/@me/nick", body: Body(nick: nick))
        return resp.nick
    }

    // Grants a role to a member.
    public func addGuildMemberRole(guildId: GuildID, userId: UserID, roleId: RoleID) async throws {
        try await http.put(path: "/guilds/\(guildId)/members/\(userId)/roles/\(roleId)")
    }

    // Removes a role from a member.
    public func removeGuildMemberRole(guildId: GuildID, userId: UserID, roleId: RoleID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/members/\(userId)/roles/\(roleId)")
    }

    // Searches guild members by prefix match.
    public func searchGuildMembers(guildId: GuildID, query: String, limit: Int = 1) async throws -> [GuildMember] {
        try await http.get(path: "/guilds/\(guildId)/members/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&limit=\(limit)")
    }

    // MARK: - REST: User and bot profile
    // Fetches any user by ID.
    public func getUser(userId: UserID) async throws -> User {
        try await http.get(path: "/users/\(userId)")
    }

    // Updates username/avatar for the current bot user.
    public func modifyCurrentUser(username: String? = nil, avatar: String? = nil) async throws -> User {
        struct Body: Encodable, Sendable {
            let username: String?
            let avatar: String?
        }
        return try await http.patch(path: "/users/@me", body: Body(username: username, avatar: avatar))
    }

    // Lists guilds visible to the current user/bot account.
    public func getCurrentUserGuilds(before: GuildID? = nil, after: GuildID? = nil, limit: Int = 200) async throws -> [PartialGuild] {
        var parts: [String] = ["limit=\(limit)"]
        if let before { parts.append("before=\(before)") }
        if let after { parts.append("after=\(after)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/users/@me/guilds\(q)")
    }

    // Leaves a guild as the current user/bot.
    public func leaveGuild(guildId: GuildID) async throws {
        try await http.delete(path: "/users/@me/guilds/\(guildId)")
    }

    // Opens a direct-message channel with the target user.
    public func createDM(recipientId: UserID) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let recipient_id: UserID
        }
        return try await http.post(path: "/users/@me/channels", body: Body(recipient_id: recipientId))
    }

    /// Open a DM channel with `userId` and send a message in one call.
    ///
    /// Internally calls `createDM(recipientId:)` followed by `sendMessage(...)`.
    /// - Returns: The sent `Message`.
    @discardableResult
    public func sendDM(
        userId: UserID,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil
    ) async throws -> Message {
        let dm = try await createDM(recipientId: userId)
        return try await sendMessage(
            channelId: dm.id,
            content: content,
            embeds: embeds,
            components: components
        )
    }

    // Creates a group DM using user OAuth2 access tokens.
    public func createGroupDM(accessTokens: [String], nicks: [UserID: String]) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let access_tokens: [String]
            let nicks: [UserID: String]
        }
        return try await http.post(path: "/users/@me/channels", body: Body(access_tokens: accessTokens, nicks: nicks))
    }

    // Typed request/response payloads for guild prune operations.
    public struct PrunePayload: Codable, Sendable {
        public let days: Int
        public let compute_prune_count: Bool?
        public let include_roles: [RoleID]?

        public init(days: Int, compute_prune_count: Bool? = nil, include_roles: [RoleID]? = nil) {
            self.days = days
            self.compute_prune_count = compute_prune_count
            self.include_roles = include_roles
        }
    }

    public struct PruneResponse: Codable, Sendable {
        public let pruned: Int

        public init(pruned: Int) {
            self.pruned = pruned
        }
    }

    public func getGuildPruneCount(guildId: GuildID, days: Int = 7) async throws -> Int {
        let resp: PruneResponse = try await http.get(path: "/guilds/\(guildId)/prune?days=\(days)")
        return resp.pruned
    }

    public func beginGuildPrune(guildId: GuildID, days: Int = 7, computePruneCount: Bool = true) async throws -> Int {
        let resp: PruneResponse = try await http.post(path: "/guilds/\(guildId)/prune", body: PrunePayload(days: days, compute_prune_count: computePruneCount, include_roles: nil))
        return resp.pruned
    }

    public func pruneGuild(guildId: GuildID, payload: PrunePayload) async throws -> PruneResponse {
        try await http.post(path: "/guilds/\(guildId)/prune", body: payload)
    }

    public func bulkModifyRolePositions(guildId: GuildID, positions: [(id: RoleID, position: Int)]) async throws -> [Role] {
        struct Entry: Encodable, Sendable {
            let id: RoleID
            let position: Int
        }
        let body = positions.map { Entry(id: $0.id, position: $0.position) }
        return try await http.patch(path: "/guilds/\(guildId)/roles", body: body)
    }
    

    public func loginAndConnect(intents: GatewayIntents) async throws {
        try await gateway.connect(intents: intents, shard: nil, eventSink: { @Sendable event in
            Task { [self] in await self.dispatcher.process(event: event, client: self) }
        })
    }

    // Connects this client as a specific shard index.
    public func loginAndConnectSharded(index: Int, total: Int, intents: GatewayIntents) async throws {
        try await gateway.connect(intents: intents, shard: (index, total), eventSink: { @Sendable event in
            Task { [self] in await self.dispatcher.process(event: event, client: self) }
        })
    }

    public func getCurrentUser() async throws -> User {
        try await http.get(path: "/users/@me")
    }

    public func sendMessage(channelId: ChannelID, content: String) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String
        }
        return try await http.post(path: "/channels/\(channelId)/messages", body: Body(content: content))
    }

    // Overload for content plus embeds.
    public func sendMessage(channelId: ChannelID, content: String? = nil, embeds: [Embed]) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]
        }
        return try await http.post(path: "/channels/\(channelId)/messages", body: Body(content: content, embeds: embeds))
    }

    // Full send overload that exposes all common Discord message fields.
    public func sendMessage(
        channelId: ChannelID,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        allowedMentions: AllowedMentions? = nil,
        messageReference: MessageReference? = nil,
        tts: Bool? = nil,
        flags: Int? = nil,
        stickerIds: [StickerID]? = nil,
        attachments: [PartialAttachment]? = nil,
        poll: Poll? = nil
    ) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
            let allowed_mentions: AllowedMentions?
            let message_reference: MessageReference?
            let tts: Bool?
            let flags: Int?
            let sticker_ids: [StickerID]?
            let attachments: [PartialAttachment]?
            let poll: Poll?

            public init(
                content: String? = nil,
                embeds: [Embed]? = nil,
                components: [MessageComponent]? = nil,
                allowedMentions: AllowedMentions? = nil,
                messageReference: MessageReference? = nil,
                tts: Bool? = nil,
                flags: Int? = nil,
                stickerIds: [StickerID]? = nil,
                attachments: [PartialAttachment]? = nil,
                poll: Poll? = nil
            ) {
                self.content = content
                self.embeds = embeds
                self.components = components
                self.allowed_mentions = allowedMentions
                self.message_reference = messageReference
                self.tts = tts
                self.flags = flags
                self.sticker_ids = stickerIds
                self.attachments = attachments
                self.poll = poll
            }
        }
        let body = Body(
            content: content,
            embeds: embeds,
            components: components,
            allowedMentions: allowedMentions,
            messageReference: messageReference,
            tts: tts,
            flags: flags,
            stickerIds: stickerIds,
            attachments: attachments,
            poll: poll
        )
        return try await http.post(path: "/channels/\(channelId)/messages", body: body)
    }

    /// End a poll attached to a message (closes voting).
    public func endPoll(channelId: ChannelID, messageId: MessageID, pollId: String) async throws -> Poll {
        struct Empty: Encodable, Sendable {}
        return try await http.post(path: "/channels/\(channelId)/messages/\(messageId)/polls/\(pollId)/expire", body: Empty())
    }

    // Presence updates for status and activity changes.
    public func setPresence(status: String, activities: [PresenceUpdatePayload.Activity] = [], afk: Bool = false, since: Int? = nil) async {
        await gateway.setPresence(status: status, activities: activities, afk: afk, since: since)
    }

    public func setStatus(_ status: String) async {
        await gateway.setPresence(status: status, activities: [], afk: false, since: nil)
    }

    public func setActivity(name: String, type: Int = 0, state: String? = nil, details: String? = nil, buttons: [String]? = nil) async {
        let act = PresenceUpdatePayload.Activity(
            name: name,
            type: type,
            state: state,
            details: details,
            timestamps: nil,
            assets: nil,
            party: nil,
            secrets: nil
        )
        await gateway.setPresence(status: "online", activities: [act], afk: false, since: nil)
    }


    // MARK: - Internal voice wiring used by EventDispatcher
    func _internalSetCurrentUserId(_ id: UserID) async {
        self.currentUserId = id
    }


    // MARK: - Internal event emission used by EventDispatcher
    func _internalEmitEvent(_ event: DiscordEvent) {
        eventContinuation?.yield(event)
    }

    // MARK: - Raw REST passthroughs for endpoints not yet wrapped
    public func rawGET<T: Decodable>(_ path: String) async throws -> T { try await http.get(path: path) }
    public func rawPOST<B: Encodable & Sendable, T: Decodable>(_ path: String, body: B) async throws -> T { try await http.post(path: path, body: body) }
    public func rawPATCH<B: Encodable & Sendable, T: Decodable>(_ path: String, body: B) async throws -> T { try await http.patch(path: path, body: body) }
    public func rawPUT<B: Encodable & Sendable, T: Decodable>(_ path: String, body: B) async throws -> T { try await http.put(path: path, body: body) }
    public func rawDELETE<T: Decodable>(_ path: String) async throws -> T { try await http.delete(path: path) }

    // MARK: - Generic application-scoped endpoints
    public func postApplicationResource(applicationId: ApplicationID, relativePath: String, payload: [String: JSONValue]) async throws -> JSONValue {
        try await http.post(path: "/applications/\(applicationId)/\(relativePath)", body: payload)
    }

    public func patchApplicationResource(applicationId: ApplicationID, relativePath: String, payload: [String: JSONValue]) async throws -> JSONValue {
        try await http.patch(path: "/applications/\(applicationId)/\(relativePath)", body: payload)
    }

    public func deleteApplicationResource(applicationId: ApplicationID, relativePath: String) async throws {
        try await http.delete(path: "/applications/\(applicationId)/\(relativePath)")
    }

    // MARK: - REST: Channels
    public func getChannel(id: ChannelID) async throws -> Channel {
        try await http.get(path: "/channels/\(id)")
    }

    // MARK: - REST: Guild endpoints
    /// Get counts of members per-role using the new role member counts endpoint.
    /// Endpoint: GET /guilds/{guild.id}/roles/member-counts
    public func getGuildRoleMemberCounts(guildId: GuildID) async throws -> [RoleMemberCount] {
        try await http.get(path: "/guilds/\(guildId)/roles/member-counts")
    }

    /// Returns the count for a single role, or `0` when the role is absent in the response.
    public func getGuildRoleMemberCount(guildId: GuildID, roleId: RoleID) async throws -> Int {
        let counts = try await getGuildRoleMemberCounts(guildId: guildId)
        return counts.first(where: { $0.role_id == roleId })?.count ?? 0
    }

    // MARK: - Stream utilities
    /// Stream pinned messages for a channel using the paginated pins endpoint.
    /// This returns an `AsyncStream<Message>` that fetches pages under the hood.
    public func streamChannelPins(channelId: ChannelID, pageLimit: Int = 50) -> AsyncStream<Message> {
        AsyncStream(Message.self) { @Sendable continuation in
            Task { @Sendable in
                var after: MessageID? = nil
                var lastSeen: String? = nil
                while true {
                    do {
                        let page = try await getChannelPinsPaginated(channelId: channelId, limit: pageLimit, after: after)
                        if page.isEmpty { break }
                        for msg in page {
                            continuation.yield(msg)
                        }
                        // Guard against accidental loops if pagination stops advancing.
                        if let last = page.last?.id.description {
                            if last == lastSeen { break }
                            lastSeen = last
                            after = page.last?.id
                        } else {
                            break
                        }
                    } catch {
                        continuation.finish()
                        return
                    }
                }
                continuation.finish()
            }
        }
    }

    public func modifyChannelName(id: ChannelID, name: String) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let name: String
        }
        return try await http.patch(path: "/channels/\(id)", body: Body(name: name))
    }

    // General channel patch endpoint for common mutable fields.
    public func modifyChannel(id: ChannelID, topic: String? = nil, nsfw: Bool? = nil, position: Int? = nil, parentId: ChannelID? = nil) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let topic: String?
            let nsfw: Bool?
            let position: Int?
            let parent_id: ChannelID?
        }
        return try await http.patch(path: "/channels/\(id)", body: Body(topic: topic, nsfw: nsfw, position: position, parent_id: parentId))
    }

    public func deleteMessage(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)")
    }

    // Fetches a single message by ID.
    public func getMessage(channelId: ChannelID, messageId: MessageID) async throws -> Message {
        try await http.get(path: "/channels/\(channelId)/messages/\(messageId)")
    }

    // Edits message content, embeds, and/or components.
    public func editMessage(channelId: ChannelID, messageId: MessageID, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
        }
        return try await http.patch(path: "/channels/\(channelId)/messages/\(messageId)", body: Body(content: content, embeds: embeds, components: components))
    }

    // Lists recent channel messages with a simple `limit` query.
    public func listChannelMessages(channelId: ChannelID, limit: Int = 50) async throws -> [Message] {
        try await http.get(path: "/channels/\(channelId)/messages?limit=\(limit)")
    }

    // Searches messages within a guild. Requires READ_MESSAGE_HISTORY and MESSAGE_CONTENT intents.
    public func searchGuildMessages(guildId: GuildID, query: String? = nil, authorId: UserID? = nil, minId: MessageID? = nil, maxId: MessageID? = nil, has: String? = nil, limit: Int? = nil, offset: Int? = nil) async throws -> [Message] {
        var queryParams: [String] = []
        if let q = query { queryParams.append("content=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)") }
        if let aid = authorId { queryParams.append("author_id=\(aid)") }
        if let mid = minId { queryParams.append("min_id=\(mid)") }
        if let mid = maxId { queryParams.append("max_id=\(mid)") }
        if let h = has { queryParams.append("has=\(h)") }
        if let l = limit { queryParams.append("limit=\(l)") }
        if let o = offset { queryParams.append("offset=\(o)") }
        let queryString = queryParams.isEmpty ? "" : "?" + queryParams.joined(separator: "&")
        return try await http.get(path: "/guilds/\(guildId)/messages/search\(queryString)")
    }

    // MARK: - Message Reactions

    /// Typed emoji reference for reaction methods.
    ///
    /// Use `.unicode("👍")` for standard Unicode emoji and
    /// `.custom(name:id:)` for guild custom emoji.
    ///
    /// ```swift
    /// try await client.addReaction(channelId: cid, messageId: mid, emoji: .unicode("🔥"))
    /// try await client.addReaction(channelId: cid, messageId: mid, emoji: .custom(name: "pepega", id: emojiId))
    /// ```
    public enum EmojiRef: Sendable {
        /// A standard Unicode emoji, e.g. `"👍"` or `"🔥"`.
        case unicode(String)
        /// A custom guild emoji. `name` is the emoji name and `id` is its snowflake.
        case custom(name: String, id: EmojiID)

        /// The percent-encoded string Discord expects in reaction URL paths.
        public var encoded: String {
            switch self {
            case .unicode(let char):
                return char.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? char
            case .custom(let name, let id):
                let raw = "\(name):\(id)"
                return raw.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? raw
            }
        }
    }

    private func encodeEmoji(_ emoji: String) -> String {
        emoji.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? emoji
    }

    // Adds the bot's reaction to a message.
    public func addReaction(channelId: ChannelID, messageId: MessageID, emoji: String) async throws {
        let e = encodeEmoji(emoji)
        try await http.put(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)/@me")
    }

    // Removes the bot's own reaction from a message.
    public func removeOwnReaction(channelId: ChannelID, messageId: MessageID, emoji: String) async throws {
        let e = encodeEmoji(emoji)
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)/@me")
    }

    // Removes another user's reaction from a message.
    public func removeUserReaction(channelId: ChannelID, messageId: MessageID, emoji: String, userId: UserID) async throws {
        let e = encodeEmoji(emoji)
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)/\(userId)")
    }

    // Returns users who reacted with a specific emoji.
    public func getReactions(channelId: ChannelID, messageId: MessageID, emoji: String, limit: Int? = 25) async throws -> [User] {
        let e = encodeEmoji(emoji)
        let q = limit != nil ? "?limit=\(limit!)" : ""
        return try await http.get(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)\(q)")
    }

    // Removes every reaction on the message.
    public func removeAllReactions(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions")
    }

    // Removes all reactions for one specific emoji.
    public func removeAllReactionsForEmoji(channelId: ChannelID, messageId: MessageID, emoji: String) async throws {
        let e = encodeEmoji(emoji)
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)")
    }

    // MARK: Typed EmojiRef reaction overloads

    /// Add a reaction using a typed ``EmojiRef``.
    public func addReaction(channelId: ChannelID, messageId: MessageID, emoji: EmojiRef) async throws {
        try await http.put(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(emoji.encoded)/@me")
    }

    /// Remove the bot's own reaction using a typed ``EmojiRef``.
    public func removeOwnReaction(channelId: ChannelID, messageId: MessageID, emoji: EmojiRef) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(emoji.encoded)/@me")
    }

    /// Remove another user's reaction using a typed ``EmojiRef``.
    public func removeUserReaction(channelId: ChannelID, messageId: MessageID, emoji: EmojiRef, userId: UserID) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(emoji.encoded)/\(userId)")
    }

    /// Fetch all users who reacted with a typed ``EmojiRef``.
    public func getReactions(channelId: ChannelID, messageId: MessageID, emoji: EmojiRef, limit: Int? = 25) async throws -> [User] {
        let q = limit != nil ? "?limit=\(limit!)" : ""
        return try await http.get(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(emoji.encoded)\(q)")
    }

    /// Remove all reactions for a typed ``EmojiRef``.
    public func removeAllReactionsForEmoji(channelId: ChannelID, messageId: MessageID, emoji: EmojiRef) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(emoji.encoded)")
    }

    // MARK: - REST: Guilds
    public func getGuild(id: GuildID) async throws -> Guild {
        try await http.get(path: "/guilds/\(id)")
    }

    public func getGuildChannels(guildId: GuildID) async throws -> [Channel] {
        try await http.get(path: "/guilds/\(guildId)/channels")
    }

    public func getGuildMember(guildId: GuildID, userId: UserID) async throws -> GuildMember {
        try await http.get(path: "/guilds/\(guildId)/members/\(userId)")
    }

    public func listGuildMembers(guildId: GuildID, limit: Int = 1000, after: UserID? = nil) async throws -> [GuildMember] {
        var path = "/guilds/\(guildId)/members?limit=\(limit)"
        if let after { path += "&after=\(after)" }
        return try await http.get(path: path)
    }

    // Create and delete guild channels.
    public func createGuildChannel(guildId: GuildID, name: String, type: Int? = nil, topic: String? = nil, nsfw: Bool? = nil, parentId: ChannelID? = nil, position: Int? = nil) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let name: String
            let type: Int?
            let topic: String?
            let nsfw: Bool?
            let parent_id: ChannelID?
            let position: Int?
        }
        return try await http.post(path: "/guilds/\(guildId)/channels", body: Body(name: name, type: type, topic: topic, nsfw: nsfw, parent_id: parentId, position: position))
    }

    public func deleteChannel(channelId: ChannelID) async throws {
        try await http.delete(path: "/channels/\(channelId)")
    }

    // Bulk update channel positions within a guild.
    public func bulkModifyGuildChannelPositions(guildId: GuildID, positions: [(id: ChannelID, position: Int)]) async throws -> [Channel] {
        struct Entry: Encodable, Sendable {
            let id: ChannelID
            let position: Int
        }
        let body = positions.map { Entry(id: $0.id, position: $0.position) }
        return try await http.patch(path: "/guilds/\(guildId)/channels", body: body)
    }

    // Upserts a channel permission overwrite.
    // `type` values: 0 = role overwrite, 1 = member overwrite.
    public func editChannelPermission(channelId: ChannelID, overwriteId: OverwriteID, type: Int, allow: String? = nil, deny: String? = nil) async throws {
        struct Body: Encodable, Sendable {
            let allow: String?
            let deny: String?
            let type: Int
        }
        struct EmptyDecodable: Decodable, Sendable {
        }
        let _: EmptyDecodable = try await http.put(path: "/channels/\(channelId)/permissions/\(overwriteId)", body: Body(allow: allow, deny: deny, type: type))
    }

    public func deleteChannelPermission(channelId: ChannelID, overwriteId: OverwriteID) async throws {
        try await http.delete(path: "/channels/\(channelId)/permissions/\(overwriteId)")
    }

    // Triggers the typing indicator in a channel.
    public func triggerTypingIndicator(channelId: ChannelID) async throws {
        struct Empty: Encodable, Sendable {
        }
        struct EmptyDecodable: Decodable, Sendable {
        }
        let _: EmptyDecodable = try await http.post(path: "/channels/\(channelId)/typing", body: Empty())
    }

    // Role endpoints.
    public func listGuildRoles(guildId: GuildID) async throws -> [Role] {
        try await http.get(path: "/guilds/\(guildId)/roles")
    }

    /// Fetch a single role by ID.
    /// `GET /guilds/{guild.id}/roles/{role.id}` - Added 2025-08-12.
    public func getGuildRole(guildId: GuildID, roleId: RoleID) async throws -> Role {
        try await http.get(path: "/guilds/\(guildId)/roles/\(roleId)")
    }

    public struct RoleCreate: Codable, Sendable {
        public let name: String
        public let permissions: String?
        public let color: Int?
        public let hoist: Bool?
        public let icon: String?
        public let unicode_emoji: String?
        public let mentionable: Bool?

        public init(
            name: String,
            permissions: String? = nil,
            color: Int? = nil,
            hoist: Bool? = nil,
            icon: String? = nil,
            unicode_emoji: String? = nil,
            mentionable: Bool? = nil
        ) {
            self.name = name
            self.permissions = permissions
            self.color = color
            self.hoist = hoist
            self.icon = icon
            self.unicode_emoji = unicode_emoji
            self.mentionable = mentionable
        }
    }

    public struct RoleUpdate: Codable, Sendable {
        public let name: String?
        public let permissions: String?
        public let color: Int?
        public let hoist: Bool?
        public let icon: String?
        public let unicode_emoji: String?
        public let mentionable: Bool?

        public init(
            name: String? = nil,
            permissions: String? = nil,
            color: Int? = nil,
            hoist: Bool? = nil,
            icon: String? = nil,
            unicode_emoji: String? = nil,
            mentionable: Bool? = nil
        ) {
            self.name = name
            self.permissions = permissions
            self.color = color
            self.hoist = hoist
            self.icon = icon
            self.unicode_emoji = unicode_emoji
            self.mentionable = mentionable
        }
    }

    public func modifyRole(guildId: GuildID, roleId: RoleID, payload: RoleUpdate) async throws -> Role {
        try await http.patch(path: "/guilds/\(guildId)/roles/\(roleId)", body: payload)
    }

    public func createRole(guildId: GuildID, payload: RoleCreate) async throws -> Role {
        try await http.post(path: "/guilds/\(guildId)/roles", body: payload)
    }

    public func deleteRole(guildId: GuildID, roleId: RoleID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/roles/\(roleId)")
    }

    // Sets default member permissions for an application command.
    public func setApplicationCommandDefaultPermissions(applicationId: ApplicationID, commandId: ApplicationCommandID, defaultMemberPermissions: String?) async throws -> ApplicationCommand {
        struct Body: Encodable, Sendable {
            let default_member_permissions: String?
        }
        return try await http.patch(path: "/applications/\(applicationId)/commands/\(commandId)", body: Body(default_member_permissions: defaultMemberPermissions))
    }

    // Ban endpoints.
    public func listGuildBans(guildId: GuildID) async throws -> [GuildBan] {
        try await http.get(path: "/guilds/\(guildId)/bans")
    }

    public func getBan(guildId: GuildID, userId: UserID) async throws -> GuildBan {
        try await http.get(path: "/guilds/\(guildId)/bans/\(userId)")
    }

    public func getBans(guildId: GuildID, limit: Int? = nil, before: UserID? = nil, after: UserID? = nil) async throws -> [GuildBan] {
        var parts: [String] = []
        if let limit { parts.append("limit=\(limit)") }
        if let before { parts.append("before=\(before)") }
        if let after { parts.append("after=\(after)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/guilds/\(guildId)/bans\(q)")
    }

    public func banMember(guildId: GuildID, userId: UserID, deleteMessageDays: Int? = nil, reason: String? = nil) async throws {
        struct Body: Encodable, Sendable {
            let delete_message_days: Int?
        }
        var path = "/guilds/\(guildId)/bans/\(userId)"
        if let reason, let encoded = reason.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "?reason=\(encoded)"
        }
        struct EmptyResponse: Decodable, Sendable {
        }
        let _: EmptyResponse = try await http.put(path: path, body: Body(delete_message_days: deleteMessageDays))
    }

    public func unbanMember(guildId: GuildID, userId: UserID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/bans/\(userId)")
    }

    public func createGuildBan(guildId: GuildID, userId: UserID, deleteMessageSeconds: Int? = nil) async throws {
        struct Empty: Encodable, Sendable {
        }
        var path = "/guilds/\(guildId)/bans/\(userId)"
        if let s = deleteMessageSeconds { path += "?delete_message_seconds=\(s)" }
        let _: ApplicationCommand = try await http.put(path: path, body: Empty())
    }

    public func deleteGuildBan(guildId: GuildID, userId: UserID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/bans/\(userId)")
    }

    
    public func modifyGuildMember(guildId: GuildID, userId: UserID, nick: String? = nil, roles: [RoleID]? = nil, flags: Int? = nil) async throws -> GuildMember {
        struct Body: Encodable, Sendable {
            let nick: String?
            let roles: [RoleID]?
            let flags: Int?
        }
        return try await http.patch(path: "/guilds/\(guildId)/members/\(userId)", body: Body(nick: nick, roles: roles, flags: flags))
    }

    // Sets `communication_disabled_until` for timeout moderation.
    public func setMemberTimeout(guildId: GuildID, userId: UserID, until date: Date) async throws -> GuildMember {
        struct Body: Encodable, Sendable {
            let communication_disabled_until: String
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let body = Body(communication_disabled_until: iso.string(from: date))
        return try await http.patch(path: "/guilds/\(guildId)/members/\(userId)", body: body)
    }

    public func clearMemberTimeout(guildId: GuildID, userId: UserID) async throws -> GuildMember {
        struct Body: Encodable, Sendable {
            let communication_disabled_until: String?
        }
        return try await http.patch(path: "/guilds/\(guildId)/members/\(userId)", body: Body(communication_disabled_until: nil))
    }

    // Updates core guild-level settings.
    public func modifyGuild(guildId: GuildID, name: String? = nil, verificationLevel: Int? = nil, defaultMessageNotifications: Int? = nil, systemChannelId: ChannelID? = nil, explicitContentFilter: Int? = nil) async throws -> Guild {
        struct Body: Encodable, Sendable {
            let name: String?
            let verification_level: Int?
            let default_message_notifications: Int?
            let system_channel_id: ChannelID?
            let explicit_content_filter: Int?
        }
        let body = Body(name: name, verification_level: verificationLevel, default_message_notifications: defaultMessageNotifications, system_channel_id: systemChannelId, explicit_content_filter: explicitContentFilter)
        return try await http.patch(path: "/guilds/\(guildId)", body: body)
    }

    public func deleteGuild(guildId: GuildID) async throws {
        try await http.delete(path: "/guilds/\(guildId)")
    }

    public func getGuildVanityURL(guildId: GuildID) async throws -> VanityURL {
        try await http.get(path: "/guilds/\(guildId)/vanity-url")
    }

    public func getGuildPreview(guildId: GuildID) async throws -> GuildPreview {
        try await http.get(path: "/guilds/\(guildId)/preview")
    }

    // MARK: - REST: Threads
    // Starts a thread from an existing message.
    public func startThreadFromMessage(
        channelId: ChannelID,
        messageId: MessageID,
        name: String,
        autoArchiveDuration: Int? = nil,
        rateLimitPerUser: Int? = nil
    ) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let name: String
            let auto_archive_duration: Int?
            let rate_limit_per_user: Int?
        }
        let body = Body(name: name, auto_archive_duration: autoArchiveDuration, rate_limit_per_user: rateLimitPerUser)
        return try await http.post(path: "/channels/\(channelId)/messages/\(messageId)/threads", body: body)
    }

    // Starts a standalone thread in a channel.
    public func startThreadWithoutMessage(
        channelId: ChannelID,
        name: String,
        autoArchiveDuration: Int? = nil,
        type: Int? = nil,
        invitable: Bool? = nil,
        rateLimitPerUser: Int? = nil
    ) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let name: String
            let auto_archive_duration: Int?
            let type: Int?
            let invitable: Bool?
            let rate_limit_per_user: Int?
        }
        let body = Body(name: name, auto_archive_duration: autoArchiveDuration, type: type, invitable: invitable, rate_limit_per_user: rateLimitPerUser)
        return try await http.post(path: "/channels/\(channelId)/threads", body: body)
    }

    // Joins the current user to a thread.
    public func joinThread(channelId: ChannelID) async throws {
        try await http.put(path: "/channels/\(channelId)/thread-members/@me")
    }

    // Leaves a thread.
    public func leaveThread(channelId: ChannelID) async throws {
        try await http.delete(path: "/channels/\(channelId)/thread-members/@me")
    }

    // Adds a specific member to a thread.
    public func addThreadMember(channelId: ChannelID, userId: UserID) async throws {
        try await http.put(path: "/channels/\(channelId)/thread-members/\(userId)")
    }

    // Removes a specific member from a thread.
    public func removeThreadMember(channelId: ChannelID, userId: UserID) async throws {
        try await http.delete(path: "/channels/\(channelId)/thread-members/\(userId)")
    }

    /// Archive (and optionally lock) a thread channel.
    ///
    /// - Parameters:
    ///   - channelId: The thread channel ID to archive.
    ///   - locked: When `true`, only members with `MANAGE_THREADS` can unarchive the thread.
    ///             Defaults to `false`.
    /// - Returns: The updated ``Channel`` object.
    @discardableResult
    public func archiveThread(channelId: ChannelID, locked: Bool = false) async throws -> Channel {
        struct Body: Encodable, Sendable {
            let archived: Bool = true
            let locked: Bool
        }
        return try await http.patch(path: "/channels/\(channelId)", body: Body(locked: locked))
    }

    // Fetches one thread member.
    public func getThreadMember(channelId: ChannelID, userId: UserID, withMember: Bool = false) async throws -> ThreadMember {
        let q = withMember ? "?with_member=true" : ""
        return try await http.get(path: "/channels/\(channelId)/thread-members/\(userId)\(q)")
    }

    // Lists thread members with optional pagination.
    public func listThreadMembers(channelId: ChannelID, withMember: Bool = false, after: UserID? = nil, limit: Int? = 100) async throws -> [ThreadMember] {
        var parts: [String] = []
        if withMember { parts.append("with_member=true") }
        if let after { parts.append("after=\(after)") }
        if let limit { parts.append("limit=\(limit)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/channels/\(channelId)/thread-members\(q)")
    }

    // Lists active threads in a guild.
    public func listActiveThreads(guildId: GuildID) async throws -> ThreadListResponse {
        try await http.get(path: "/guilds/\(guildId)/threads/active")
    }

    // Lists public archived threads for a channel.
    public func listPublicArchivedThreads(channelId: ChannelID, before: String? = nil, limit: Int? = 50) async throws -> ThreadListResponse {
        var parts: [String] = []
        if let before { parts.append("before=\(before)") }
        if let limit { parts.append("limit=\(limit)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/channels/\(channelId)/threads/archived/public\(q)")
    }

    // Lists private archived threads for a channel.
    public func listPrivateArchivedThreads(channelId: ChannelID, before: String? = nil, limit: Int? = 50) async throws -> ThreadListResponse {
        var parts: [String] = []
        if let before { parts.append("before=\(before)") }
        if let limit { parts.append("limit=\(limit)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/channels/\(channelId)/threads/archived/private\(q)")
    }

    // Lists joined private archived threads for the current user.
    public func listJoinedPrivateArchivedThreads(channelId: ChannelID, before: MessageID? = nil, limit: Int? = 50) async throws -> ThreadListResponse {
        var parts: [String] = []
        if let before { parts.append("before=\(before)") }
        if let limit { parts.append("limit=\(limit)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/channels/\(channelId)/users/@me/threads/archived/private\(q)")
    }

    // MARK: - REST: Interactions
    // Sends a basic interaction callback (type 4: ChannelMessageWithSource).
    public func createInteractionResponse(interactionId: InteractionID, token: String, content: String) async throws {
        struct DataObj: Encodable, Sendable {
            let content: String
        }
        struct Body: Encodable, Sendable {
            let type: Int = 4
            let data: DataObj
        }
        struct Ack: Decodable, Sendable {
        }
        let body = Body(data: DataObj(content: content))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    // Interaction callback overload with optional content + embeds.
    public func createInteractionResponse(interactionId: InteractionID, token: String, content: String? = nil, embeds: [Embed]) async throws {
        struct DataObj: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]
        }
        struct Body: Encodable, Sendable {
            let type: Int = 4
            let data: DataObj
        }
        struct Ack: Decodable, Sendable {
        }
        let body = Body(data: DataObj(content: content, embeds: embeds))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    public enum InteractionResponseType: Int, Codable, Sendable {
        case pong = 1
        case channelMessageWithSource = 4
        case deferredChannelMessageWithSource = 5
        case deferredUpdateMessage = 6
        case updateMessage = 7
        case autocompleteResult = 8
        case modal = 9
        /// Launch a linked Activity. Added 2024-08-26.
        case launchActivity = 12
    }

    public func createInteractionResponse(interactionId: InteractionID, token: String, type: InteractionResponseType, content: String? = nil, embeds: [Embed]? = nil) async throws {
        struct DataObj: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
        }
        struct Body: Encodable, Sendable {
            let type: Int
            let data: DataObj?
        }
        struct Ack: Decodable, Sendable {
        }
        let data = (content == nil && embeds == nil) ? nil : DataObj(content: content, embeds: embeds)
        let body = Body(type: type.rawValue, data: data)
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    // Type 8 autocomplete response payload.
    public struct AutocompleteChoice: Codable, Sendable {
        public let name: String
        public let value: String
        public init(name: String, value: String) { self.name = name; self.value = value }
    }

    public func createAutocompleteResponse(interactionId: InteractionID, token: String, choices: [AutocompleteChoice]) async throws {
        struct DataObj: Encodable, Sendable {
            let choices: [AutocompleteChoice]
        }
        struct Body: Encodable, Sendable {
            let type: Int
            let data: DataObj
        }
        struct Ack: Decodable, Sendable {
        }
        let body = Body(type: InteractionResponseType.autocompleteResult.rawValue, data: DataObj(choices: choices))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    // Type 9 modal callback endpoint.
    public func createInteractionModal(
        interactionId: InteractionID,
        token: String,
        title: String,
        customId: String,
        components: [MessageComponent]
    ) async throws {
        struct DataObj: Encodable, Sendable {
            let custom_id: String
            let title: String
            let components: [MessageComponent]
        }
        struct Body: Encodable, Sendable {
            let type: Int
            let data: DataObj
        }
        struct Ack: Decodable, Sendable {
        }
        let body = Body(type: InteractionResponseType.modal.rawValue, data: DataObj(custom_id: customId, title: title, components: components))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    public func shutdown() async {
        await gateway.close()
        eventContinuation?.finish()
    }

    // MARK: - Slash command REST endpoints
    public struct ApplicationCommand: Codable, Sendable {
        public let id: ApplicationCommandID
        public let application_id: ApplicationID
        public let name: String
        public let description: String
    }

    public struct ApplicationCommandOption: Codable, Sendable {
        public enum ApplicationCommandOptionType: Int, Codable, Sendable {
            case subCommand = 1
            case subCommandGroup = 2
            case string = 3
            case integer = 4
            case boolean = 5
            case user = 6
            case channel = 7
            case role = 8
            case mentionable = 9
            case number = 10
            case attachment = 11
        }
        public let type: ApplicationCommandOptionType
        public let name: String
        public let description: String
        public let required: Bool?
        public struct Choice: Codable, Sendable {
            public let name: String
            public let value: String
        }
        public let choices: [Choice]?
        public init(type: ApplicationCommandOptionType, name: String, description: String, required: Bool? = nil, choices: [Choice]? = nil) {
            self.type = type
            self.name = name
            self.description = description
            self.required = required
            self.choices = choices
        }
    }

    public struct ApplicationCommandCreate: Encodable, Sendable {
        public let name: String
        public let description: String
        public let options: [ApplicationCommandOption]?
        public let default_member_permissions: String?
        public let dm_permission: Bool?
        public init(name: String, description: String, options: [ApplicationCommandOption]? = nil, default_member_permissions: String? = nil, dm_permission: Bool? = nil) {
            self.name = name
            self.description = description
            self.options = options
            self.default_member_permissions = default_member_permissions
            self.dm_permission = dm_permission
        }
    }

    public func createGlobalCommand(name: String, description: String) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable, Sendable {
            let name: String
            let description: String
        }
        return try await http.post(path: "/applications/\(appId)/commands", body: Body(name: name, description: description))
    }

    public func createGuildCommand(guildId: GuildID, name: String, description: String) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable, Sendable {
            let name: String
            let description: String
        }
        return try await http.post(path: "/applications/\(appId)/guilds/\(guildId)/commands", body: Body(name: name, description: description))
    }

    public func createGlobalCommand(name: String, description: String, options: [ApplicationCommandOption]) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable, Sendable {
            let name: String
            let description: String
            let options: [ApplicationCommandOption]
        }
        return try await http.post(path: "/applications/\(appId)/commands", body: Body(name: name, description: description, options: options))
    }

    public func createGuildCommand(guildId: GuildID, name: String, description: String, options: [ApplicationCommandOption]) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable, Sendable {
            let name: String
            let description: String
            let options: [ApplicationCommandOption]
        }
        return try await http.post(path: "/applications/\(appId)/guilds/\(guildId)/commands", body: Body(name: name, description: description, options: options))
    }

    public func createGlobalCommand(_ command: ApplicationCommandCreate) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        return try await http.post(path: "/applications/\(appId)/commands", body: command)
    }

    public func createGuildCommand(guildId: GuildID, _ command: ApplicationCommandCreate) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        return try await http.post(path: "/applications/\(appId)/guilds/\(guildId)/commands", body: command)
    }

    public func listGlobalCommands() async throws -> [ApplicationCommand] {
        let appId = try await getCurrentUser().id
        return try await http.get(path: "/applications/\(appId)/commands")
    }

    public func listGuildCommands(guildId: GuildID) async throws -> [ApplicationCommand] {
        let appId = try await getCurrentUser().id
        return try await http.get(path: "/applications/\(appId)/guilds/\(guildId)/commands")
    }

    public func deleteGlobalCommand(commandId: ApplicationCommandID) async throws {
        let appId = try await getCurrentUser().id
        try await http.delete(path: "/applications/\(appId)/commands/\(commandId)")
    }

    public func deleteGuildCommand(guildId: GuildID, commandId: ApplicationCommandID) async throws {
        let appId = try await getCurrentUser().id
        try await http.delete(path: "/applications/\(appId)/guilds/\(guildId)/commands/\(commandId)")
    }

    public func bulkOverwriteGlobalCommands(_ commands: [ApplicationCommandCreate]) async throws -> [ApplicationCommand] {
        let appId = try await getCurrentUser().id
        return try await http.put(path: "/applications/\(appId)/commands", body: commands)
    }

    public func bulkOverwriteGuildCommands(guildId: GuildID, _ commands: [ApplicationCommandCreate]) async throws -> [ApplicationCommand] {
        let appId = try await getCurrentUser().id
        return try await http.put(path: "/applications/\(appId)/guilds/\(guildId)/commands", body: commands)
    }

    /// Sync the desired application commands with Discord.
    ///
    /// Fetches the currently registered commands, compares name sets, and only
    /// calls `bulkOverwrite` when there is a difference (new commands, deleted
    /// commands, or a name change). This avoids unnecessary API writes during
    /// repeated bot restarts.
    ///
    /// - Parameters:
    ///   - desired: The full list of commands you want registered.
    ///   - guildId: Target guild for guild-scoped commands, or `nil` for global commands.
    /// - Returns: The commands now registered with Discord.
    @discardableResult
    public func syncCommands(
        _ desired: [ApplicationCommandCreate],
        guildId: GuildID? = nil
    ) async throws -> [ApplicationCommand] {
        let existing: [ApplicationCommand]
        if let guildId {
            existing = try await listGuildCommands(guildId: guildId)
        } else {
            existing = try await listGlobalCommands()
        }

        let existingNames = Set(existing.map(\.name).sorted())
        let desiredNames  = Set(desired.map(\.name).sorted())

        guard existingNames != desiredNames else {
            // Nothing changed at the command-name level, so keep the existing registration.
            return existing
        }

        if let guildId {
            return try await bulkOverwriteGuildCommands(guildId: guildId, desired)
        } else {
            return try await bulkOverwriteGlobalCommands(desired)
        }
    }

    // MARK: - REST: Webhooks
    public func createWebhook(channelId: ChannelID, name: String) async throws -> Webhook {
        struct Body: Encodable, Sendable {
            let name: String
        }
        return try await http.post(path: "/channels/\(channelId)/webhooks", body: Body(name: name))
    }

    public func createWebhook(channelId: ChannelID, name: String, avatar: String?) async throws -> Webhook {
        struct Body: Encodable, Sendable {
            let name: String
            let avatar: String?
        }
        return try await http.post(path: "/channels/\(channelId)/webhooks", body: Body(name: name, avatar: avatar))
    }

    public func getChannelWebhooks(channelId: ChannelID) async throws -> [Webhook] {
        try await http.get(path: "/channels/\(channelId)/webhooks")
    }

    public func getGuildWebhooks(guildId: GuildID) async throws -> [Webhook] {
        try await http.get(path: "/guilds/\(guildId)/webhooks")
    }

    public func getWebhook(webhookId: WebhookID) async throws -> Webhook {
        try await http.get(path: "/webhooks/\(webhookId)")
    }

    public func modifyWebhook(webhookId: WebhookID, name: String? = nil, avatar: String? = nil, channelId: ChannelID? = nil) async throws -> Webhook {
        struct Body: Encodable, Sendable {
            let name: String?
            let avatar: String?
            let channel_id: ChannelID?
        }
        return try await http.patch(path: "/webhooks/\(webhookId)", body: Body(name: name, avatar: avatar, channel_id: channelId))
    }

    public func deleteWebhook(webhookId: WebhookID) async throws {
        try await http.delete(path: "/webhooks/\(webhookId)")
    }

    public func executeWebhook(webhookId: WebhookID, token: String, content: String) async throws -> Message {
        struct Body: Encodable, Sendable {
            let content: String
        }
        return try await http.post(path: "/webhooks/\(webhookId)/\(token)", body: Body(content: content))
    }

    public func executeWebhook(webhookId: WebhookID, token: String, content: String? = nil, username: String? = nil, avatarUrl: String? = nil, embeds: [Embed]? = nil, wait: Bool = false) async throws -> Message? {
        struct Body: Encodable, Sendable {
            let content: String?
            let username: String?
            let avatar_url: String?
            let embeds: [Embed]?
        }
        let body = Body(content: content, username: username, avatar_url: avatarUrl, embeds: embeds)
        let waitParam = wait ? "?wait=true" : ""
        if wait {
            return try await http.post(path: "/webhooks/\(webhookId)/\(token)\(waitParam)", body: body)
        } else {
            struct EmptyResponse: Decodable, Sendable {
            }
            let _: EmptyResponse = try await http.post(path: "/webhooks/\(webhookId)/\(token)", body: body)
            return nil
        }
    }

    /// Create an invite for a channel.
    /// `role_ids` assigns roles when accepted. `targetUsersFile` is a CSV `FileAttachment`
    /// (`user_id` column) restricting who can accept. Both added 2026-01-13.
    public func createChannelInvite(
        channelId: ChannelID,
        maxAge: Int? = nil,
        maxUses: Int? = nil,
        temporary: Bool? = nil,
        unique: Bool? = nil,
        roleIds: [RoleID]? = nil,
        targetUsersFile: FileAttachment? = nil
    ) async throws -> Invite {
        struct Body: Encodable, Sendable {
            let max_age: Int?
            let max_uses: Int?
            let temporary: Bool?
            let unique: Bool?
            let role_ids: [RoleID]?
        }
        let body = Body(max_age: maxAge, max_uses: maxUses, temporary: temporary, unique: unique, role_ids: roleIds)
        if let file = targetUsersFile {
            return try await http.postMultipart(path: "/channels/\(channelId)/invites", jsonBody: body, files: [file])
        }
        return try await http.post(path: "/channels/\(channelId)/invites", body: body)
    }

    public func listChannelInvites(channelId: ChannelID) async throws -> [Invite] {
        try await http.get(path: "/channels/\(channelId)/invites")
    }

    public func listGuildInvites(guildId: GuildID) async throws -> [Invite] {
        try await http.get(path: "/guilds/\(guildId)/invites")
    }

    public func getInvite(code: String, withCounts: Bool = false, withExpiration: Bool = false) async throws -> Invite {
        let path = "/invites/\(code)?with_counts=\(withCounts)&with_expiration=\(withExpiration)"
        return try await http.get(path: path)
    }

    public func deleteInvite(code: String) async throws {
        try await http.delete(path: "/invites/\(code)")
    }

    // MARK: - REST: Community Invite Target Users (Added 2026-01-13)

    /// Response from the Get Target Users Job Status endpoint.
    public struct InviteTargetUsersJobStatus: Codable, Sendable {
        public let job_id: String
        public let status: String  // e.g. "pending", "complete", "failed"
        public let invite_code: String
    }

    /// Get the raw CSV of user IDs allowed to accept a restricted invite.
    /// The response is CSV bytes with a `user_id` header column (not JSON).
    /// Decode with `String(data: result, encoding: .utf8)` to get the CSV text.
    /// `GET /invites/{code}/users` — Added 2026-01-13, updated 2026-02-05 (header always `user_id`).
    public func getInviteTargetUsers(code: String) async throws -> Data {
        try await http.getRaw(path: "/invites/\(code)/users")
    }

    /// Replace the list of users allowed to accept a restricted invite by uploading a CSV file.
    /// The CSV must have a `user_id` column. Returns the async job status.
    /// `PATCH /invites/{code}/users` — Added 2026-01-13.
    public func updateInviteTargetUsers(code: String, file: FileAttachment) async throws -> InviteTargetUsersJobStatus {
        struct Empty: Encodable, Sendable {
        }
        return try await http.patchMultipart(path: "/invites/\(code)/users", jsonBody: Empty(), files: [file])
    }

    /// Check the status of the background job that processes a target-users CSV upload.
    /// `GET /invites/{code}/users/jobs/{job_id}` — Added 2026-01-13.
    public func getInviteTargetUsersJobStatus(code: String, jobId: String) async throws -> InviteTargetUsersJobStatus {
        try await http.get(path: "/invites/\(code)/users/jobs/\(jobId)")
    }

    public func getTemplate(code: String) async throws -> Template {
        try await http.get(path: "/guilds/templates/\(code)")
    }

    public func listGuildTemplates(guildId: GuildID) async throws -> [Template] {
        try await http.get(path: "/guilds/\(guildId)/templates")
    }

    public func createGuildTemplate(guildId: GuildID, name: String, description: String? = nil) async throws -> Template {
        struct Body: Encodable, Sendable {
            let name: String
            let description: String?
        }
        return try await http.post(path: "/guilds/\(guildId)/templates", body: Body(name: name, description: description))
    }

    public func modifyGuildTemplate(guildId: GuildID, code: String, name: String? = nil, description: String? = nil) async throws -> Template {
        struct Body: Encodable, Sendable {
            let name: String?
            let description: String?
        }
        return try await http.patch(path: "/guilds/\(guildId)/templates/\(code)", body: Body(name: name, description: description))
    }

    public func syncGuildTemplate(guildId: GuildID, code: String) async throws -> Template {
        struct Empty: Encodable, Sendable {
        }
        return try await http.put(path: "/guilds/\(guildId)/templates/\(code)", body: Empty())
    }

    public func deleteGuildTemplate(guildId: GuildID, code: String) async throws {
        try await http.delete(path: "/guilds/\(guildId)/templates/\(code)")
    }

    // MARK: - REST: Stickers
    public func getSticker(id: StickerID) async throws -> Sticker {
        try await http.get(path: "/stickers/\(id)")
    }

    public func listStickerPacks() async throws -> [StickerPack] {
        struct Packs: Decodable, Sendable {
            let sticker_packs: [StickerPack]
        }
        let resp: Packs = try await http.get(path: "/sticker-packs")
        return resp.sticker_packs
    }

    public func listGuildStickers(guildId: GuildID) async throws -> [Sticker] {
        try await http.get(path: "/guilds/\(guildId)/stickers")
    }

    public func getGuildSticker(guildId: GuildID, stickerId: StickerID) async throws -> Sticker {
        try await http.get(path: "/guilds/\(guildId)/stickers/\(stickerId)")
    }

    public func createGuildSticker(guildId: GuildID, name: String, description: String? = nil, tags: String, file: FileAttachment) async throws -> Sticker {
        struct Payload: Encodable, Sendable {
            let name: String
            let description: String?
            let tags: String
        }
        let payload = Payload(name: name, description: description, tags: tags)
        return try await http.postMultipart(path: "/guilds/\(guildId)/stickers", jsonBody: payload, files: [file])
    }

    public func modifyGuildSticker(guildId: GuildID, stickerId: StickerID, name: String? = nil, description: String? = nil, tags: String? = nil) async throws -> Sticker {
        struct Payload: Encodable, Sendable {
            let name: String?
            let description: String?
            let tags: String?
        }
        return try await http.patch(path: "/guilds/\(guildId)/stickers/\(stickerId)", body: Payload(name: name, description: description, tags: tags))
    }

    public func deleteGuildSticker(guildId: GuildID, stickerId: StickerID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/stickers/\(stickerId)")
    }

    // MARK: - REST: Forum endpoints
    public func createForumThread(
        channelId: ChannelID,
        name: String,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        appliedTagIds: [ForumTagID]? = nil,
        autoArchiveDuration: Int? = nil,
        rateLimitPerUser: Int? = nil
    ) async throws -> Channel {
        struct Msg: Encodable, Sendable {
            let content: String?
            let embeds: [Embed]?
            let components: [MessageComponent]?
        }
        struct Body: Encodable, Sendable {
            let name: String
            let auto_archive_duration: Int?
            let rate_limit_per_user: Int?
            let message: Msg?
            let applied_tags: [ForumTagID]?
        }
        let message = (content == nil && embeds == nil && components == nil) ? nil : Msg(content: content, embeds: embeds, components: components)
        let body = Body(
            name: name,
            auto_archive_duration: autoArchiveDuration,
            rate_limit_per_user: rateLimitPerUser,
            message: message,
            applied_tags: appliedTagIds
        )
        return try await http.post(path: "/channels/\(channelId)/threads", body: body)
    }

    // MARK: - REST: Audit Logs
    public func getGuildAuditLog(
        guildId: GuildID,
        userId: UserID? = nil,
        actionType: Int? = nil,
        before: AuditLogEntryID? = nil,
        limit: Int? = nil
    ) async throws -> AuditLog {
        let path = "/guilds/\(guildId)/audit-logs"
        var qs: [String] = []
        if let userId { qs.append("user_id=\(userId)") }
        if let actionType { qs.append("action_type=\(actionType)") }
        if let before { qs.append("before=\(before)") }
        if let limit { qs.append("limit=\(limit)") }
        let q = qs.isEmpty ? "" : "?" + qs.joined(separator: "&")
        return try await http.get(path: path + q)
    }

    // MARK: - REST: AutoModeration
    public func listAutoModerationRules(guildId: GuildID) async throws -> [AutoModerationRule] {
        try await http.get(path: "/guilds/\(guildId)/auto-moderation/rules")
    }

    public func getAutoModerationRule(guildId: GuildID, ruleId: AutoModerationRuleID) async throws -> AutoModerationRule {
        try await http.get(path: "/guilds/\(guildId)/auto-moderation/rules/\(ruleId)")
    }

    public func createAutoModerationRule(
        guildId: GuildID,
        name: String,
        eventType: Int,
        triggerType: Int,
        triggerMetadata: AutoModerationRule.TriggerMetadata? = nil,
        actions: [AutoModerationRule.Action],
        enabled: Bool = true,
        exemptRoles: [RoleID]? = nil,
        exemptChannels: [ChannelID]? = nil
    ) async throws -> AutoModerationRule {
        struct Body: Encodable, Sendable {
            let name: String
            let event_type: Int
            let trigger_type: Int
            let trigger_metadata: AutoModerationRule.TriggerMetadata?
            let actions: [AutoModerationRule.Action]
            let enabled: Bool?
            let exempt_roles: [RoleID]?
            let exempt_channels: [ChannelID]?
        }
        let body = Body(
            name: name,
            event_type: eventType,
            trigger_type: triggerType,
            trigger_metadata: triggerMetadata,
            actions: actions,
            enabled: enabled,
            exempt_roles: exemptRoles,
            exempt_channels: exemptChannels
        )
        return try await http.post(path: "/guilds/\(guildId)/auto-moderation/rules", body: body)
    }

    public func modifyAutoModerationRule(
        guildId: GuildID,
        ruleId: AutoModerationRuleID,
        name: String? = nil,
        eventType: Int? = nil,
        triggerMetadata: AutoModerationRule.TriggerMetadata? = nil,
        actions: [AutoModerationRule.Action]? = nil,
        enabled: Bool? = nil,
        exemptRoles: [RoleID]? = nil,
        exemptChannels: [ChannelID]? = nil
    ) async throws -> AutoModerationRule {
        struct Body: Encodable, Sendable {
            let name: String?
            let event_type: Int?
            let trigger_metadata: AutoModerationRule.TriggerMetadata?
            let actions: [AutoModerationRule.Action]?
            let enabled: Bool?
            let exempt_roles: [RoleID]?
            let exempt_channels: [ChannelID]?
        }
        let body = Body(
            name: name,
            event_type: eventType,
            trigger_metadata: triggerMetadata,
            actions: actions,
            enabled: enabled,
            exempt_roles: exemptRoles,
            exempt_channels: exemptChannels
        )
        return try await http.patch(path: "/guilds/\(guildId)/auto-moderation/rules/\(ruleId)", body: body)
    }

    public func deleteAutoModerationRule(guildId: GuildID, ruleId: AutoModerationRuleID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/auto-moderation/rules/\(ruleId)")
    }

    // MARK: - REST: Scheduled Events
    public func listGuildScheduledEvents(guildId: GuildID, withCounts: Bool = false) async throws -> [GuildScheduledEvent] {
        let suffix = withCounts ? "?with_user_count=true" : ""
        return try await http.get(path: "/guilds/\(guildId)/scheduled-events\(suffix)")
    }

    public func createGuildScheduledEvent(
        guildId: GuildID,
        channelId: ChannelID?,
        entityType: GuildScheduledEvent.EntityType,
        name: String,
        scheduledStartTimeISO8601: String,
        scheduledEndTimeISO8601: String? = nil,
        privacyLevel: Int = 2,
        description: String? = nil,
        entityMetadata: GuildScheduledEvent.EntityMetadata? = nil
    ) async throws -> GuildScheduledEvent {
        struct Body: Encodable, Sendable {
            let channel_id: ChannelID?
            let entity_type: Int
            let name: String
            let scheduled_start_time: String
            let scheduled_end_time: String?
            let privacy_level: Int
            let description: String?
            let entity_metadata: GuildScheduledEvent.EntityMetadata?
        }
        let body = Body(
            channel_id: channelId,
            entity_type: entityType.rawValue,
            name: name,
            scheduled_start_time: scheduledStartTimeISO8601,
            scheduled_end_time: scheduledEndTimeISO8601,
            privacy_level: privacyLevel,
            description: description,
            entity_metadata: entityMetadata
        )
        return try await http.post(path: "/guilds/\(guildId)/scheduled-events", body: body)
    }

    public func getGuildScheduledEvent(guildId: GuildID, eventId: GuildScheduledEventID, withCounts: Bool = false) async throws -> GuildScheduledEvent {
        let suffix = withCounts ? "?with_user_count=true" : ""
        return try await http.get(path: "/guilds/\(guildId)/scheduled-events/\(eventId)\(suffix)")
    }

    public func modifyGuildScheduledEvent(
        guildId: GuildID,
        eventId: GuildScheduledEventID,
        channelId: ChannelID? = nil,
        entityType: GuildScheduledEvent.EntityType? = nil,
        name: String? = nil,
        scheduledStartTimeISO8601: String? = nil,
        scheduledEndTimeISO8601: String? = nil,
        privacyLevel: Int? = nil,
        description: String? = nil,
        status: GuildScheduledEvent.Status? = nil,
        entityMetadata: GuildScheduledEvent.EntityMetadata? = nil
    ) async throws -> GuildScheduledEvent {
        struct Body: Encodable, Sendable {
            let channel_id: ChannelID?
            let entity_type: Int?
            let name: String?
            let scheduled_start_time: String?
            let scheduled_end_time: String?
            let privacy_level: Int?
            let description: String?
            let status: Int?
            let entity_metadata: GuildScheduledEvent.EntityMetadata?
        }
        let body = Body(
            channel_id: channelId,
            entity_type: entityType?.rawValue,
            name: name,
            scheduled_start_time: scheduledStartTimeISO8601,
            scheduled_end_time: scheduledEndTimeISO8601,
            privacy_level: privacyLevel,
            description: description,
            status: status?.rawValue,
            entity_metadata: entityMetadata
        )
        return try await http.patch(path: "/guilds/\(guildId)/scheduled-events/\(eventId)", body: body)
    }

    public func deleteGuildScheduledEvent(guildId: GuildID, eventId: GuildScheduledEventID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/scheduled-events/\(eventId)")
    }

    public func listGuildScheduledEventUsers(
        guildId: GuildID,
        eventId: GuildScheduledEventID,
        limit: Int? = nil,
        withMember: Bool = false,
        before: UserID? = nil,
        after: UserID? = nil
    ) async throws -> [GuildScheduledEventUser] {
        let path = "/guilds/\(guildId)/scheduled-events/\(eventId)/users"
        var qs: [String] = []
        if let limit { qs.append("limit=\(limit)") }
        if withMember { qs.append("with_member=true") }
        if let before { qs.append("before=\(before)") }
        if let after { qs.append("after=\(after)") }
        let q = qs.isEmpty ? "" : "?" + qs.joined(separator: "&")
        return try await http.get(path: path + q)
    }

    // MARK: - REST: Stage Instances
    public func createStageInstance(channelId: ChannelID, topic: String, privacyLevel: Int = 2, guildScheduledEventId: GuildScheduledEventID? = nil) async throws -> StageInstance {
        struct Body: Encodable, Sendable {
            let channel_id: ChannelID
            let topic: String
            let privacy_level: Int
            let guild_scheduled_event_id: GuildScheduledEventID?
        }
        let body = Body(channel_id: channelId, topic: topic, privacy_level: privacyLevel, guild_scheduled_event_id: guildScheduledEventId)
        return try await http.post(path: "/stage-instances", body: body)
    }

    public func getStageInstance(channelId: ChannelID) async throws -> StageInstance {
        try await http.get(path: "/stage-instances/\(channelId)")
    }

    public func modifyStageInstance(channelId: ChannelID, topic: String? = nil, privacyLevel: Int? = nil) async throws -> StageInstance {
        struct Body: Encodable, Sendable {
            let topic: String?
            let privacy_level: Int?
        }
        return try await http.patch(path: "/stage-instances/\(channelId)", body: Body(topic: topic, privacy_level: privacyLevel))
    }

    public func deleteStageInstance(channelId: ChannelID) async throws {
        try await http.delete(path: "/stage-instances/\(channelId)")
    }

    // MARK: - REST: Role Connections
    public func updateApplicationRoleConnectionMetadata(applicationId: ApplicationID, metadata: [ApplicationRoleConnectionMetadata]) async throws -> [ApplicationRoleConnectionMetadata] {
        return try await http.put(path: "/applications/\(applicationId)/role-connections/metadata", body: metadata)
    }

    public func getApplicationRoleConnectionMetadata(applicationId: ApplicationID) async throws -> [ApplicationRoleConnectionMetadata] {
        return try await http.get(path: "/applications/\(applicationId)/role-connections/metadata")
    }

    public func getUserApplicationRoleConnection(applicationId: ApplicationID) async throws -> ApplicationRoleConnection {
        return try await http.get(path: "/users/@me/applications/\(applicationId)/role-connection")
    }

    public func updateUserApplicationRoleConnection(applicationId: ApplicationID, platformName: String? = nil, platformUsername: String? = nil, metadata: [String: String] = [:]) async throws -> ApplicationRoleConnection {
        struct Body: Encodable, Sendable {
            let platformName: String?
            let platformUsername: String?
            let metadata: [String: String]
            
            enum CodingKeys: String, CodingKey {
                case platformName = "platform_name"
                case platformUsername = "platform_username"
                case metadata
            }
        }
        
        let body = Body(platformName: platformName, platformUsername: platformUsername, metadata: metadata)
        return try await http.put(path: "/users/@me/applications/\(applicationId)/role-connection", body: body)
    }

    // MARK: - REST: Soundboard
    public func listSoundboardSounds(guildId: GuildID) async throws -> [SoundboardSound] {
        try await http.get(path: "/guilds/\(guildId)/soundboard-sounds")
    }

    public func createSoundboardSound(guildId: GuildID, name: String, emojiId: EmojiID? = nil, emojiName: String? = nil, volume: Double? = nil, sound: FileAttachment) async throws -> SoundboardSound {
        struct Payload: Encodable, Sendable {
            let name: String
            let emoji_id: EmojiID?
            let emoji_name: String?
            let volume: Double?
        }
        let payload = Payload(name: name, emoji_id: emojiId, emoji_name: emojiName, volume: volume)
        return try await http.postMultipart(path: "/guilds/\(guildId)/soundboard-sounds", jsonBody: payload, files: [sound])
    }

    public func modifySoundboardSound(guildId: GuildID, soundId: SoundboardSoundID, name: String? = nil, emojiId: EmojiID? = nil, emojiName: String? = nil, volume: Double? = nil) async throws -> SoundboardSound {
        struct Payload: Encodable, Sendable {
            let name: String?
            let emoji_id: EmojiID?
            let emoji_name: String?
            let volume: Double?
        }
        return try await http.patch(path: "/guilds/\(guildId)/soundboard-sounds/\(soundId)", body: Payload(name: name, emoji_id: emojiId, emoji_name: emojiName, volume: volume))
    }

    public func deleteSoundboardSound(guildId: GuildID, soundId: SoundboardSoundID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/soundboard-sounds/\(soundId)")
    }

    // MARK: - REST: Entitlements & SKUs (Monetization)

    public func listEntitlements(
        applicationId: ApplicationID,
        userId: UserID? = nil,
        guildId: GuildID? = nil,
        before: EntitlementID? = nil,
        after: EntitlementID? = nil,
        limit: Int? = nil,
        skuIds: [SKUID]? = nil
    ) async throws -> [Entitlement] {
        var qs: [String] = []
        if let userId { qs.append("user_id=\(userId)") }
        if let guildId { qs.append("guild_id=\(guildId)") }
        if let before { qs.append("before=\(before)") }
        if let after { qs.append("after=\(after)") }
        if let limit { qs.append("limit=\(limit)") }
        if let skuIds, !skuIds.isEmpty {
            let joined = skuIds.map { "\($0)" }.joined(separator: ",")
            qs.append("sku_ids=\(joined)")
        }
        let path = "/applications/\(applicationId)/entitlements" + (qs.isEmpty ? "" : "?" + qs.joined(separator: "&"))
        return try await http.get(path: path)
    }

    /// Create a test entitlement for validation in non-production contexts.
    public func createTestEntitlement(applicationId: ApplicationID, skuId: SKUID, ownerId: String, ownerType: Int = 1) async throws -> Entitlement {
        struct Body: Encodable, Sendable {
            let sku_id: SKUID
            let owner_id: String
            let owner_type: Int
        }
        return try await http.post(path: "/applications/\(applicationId)/entitlements", body: Body(sku_id: skuId, owner_id: ownerId, owner_type: ownerType))
    }

    /// Consume an entitlement (used for one-time items).
    public func consumeEntitlement(applicationId: ApplicationID, entitlementId: EntitlementID) async throws {
        struct Empty: Codable, Sendable {
        }
        let _: Empty = try await http.post(path: "/applications/\(applicationId)/entitlements/\(entitlementId)/consume", body: Empty())
    }

    public func listSKUs(applicationId: ApplicationID) async throws -> [SKU] {
        try await http.get(path: "/applications/\(applicationId)/skus")
    }

    // MARK: - REST: Onboarding / Server Guide
    public func getGuildOnboarding(guildId: GuildID) async throws -> Onboarding {
        try await http.get(path: "/guilds/\(guildId)/onboarding")
    }

    public func updateGuildOnboarding(
        guildId: GuildID,
        prompts: [OnboardingPrompt],
        defaultChannelIds: [ChannelID],
        enabled: Bool,
        mode: Int,
        defaultRecommendationChannelIds: [ChannelID]? = nil
    ) async throws -> Onboarding {
        struct Body: Encodable, Sendable {
            let prompts: [OnboardingPrompt]
            let default_channel_ids: [ChannelID]
            let enabled: Bool
            let mode: Int
            let default_recommendation_channel_ids: [ChannelID]?
        }
        let body = Body(
            prompts: prompts,
            default_channel_ids: defaultChannelIds,
            enabled: enabled,
            mode: mode,
            default_recommendation_channel_ids: defaultRecommendationChannelIds
        )
        return try await http.put(path: "/guilds/\(guildId)/onboarding", body: body)
    }

    // MARK: - REST: App Installs & Subscriptions (Monetization)

    /// List installs of this application (server-side view).
    public func listApplicationInstalls(applicationId: ApplicationID, after: AppInstallationID? = nil, limit: Int? = nil) async throws -> [AppInstallation] {
        var qs: [String] = []
        if let after { qs.append("after=\(after)") }
        if let limit { qs.append("limit=\(limit)") }
        let path = "/applications/\(applicationId)/installations" + (qs.isEmpty ? "" : "?" + qs.joined(separator: "&"))
        return try await http.get(path: path)
    }

    /// List installs for the current user of this application (user token scope).
    public func listCurrentUserInstalls(applicationId: ApplicationID, withAppToken: Bool = false) async throws -> [AppInstallation] {
        // Bot tokens may receive 403 here; this endpoint remains for API parity.
        try await http.get(path: "/users/@me/applications/\(applicationId)/installations")
    }

    /// List subscriptions for this application.
    public func listApplicationSubscriptions(applicationId: ApplicationID, status: String? = nil, limit: Int? = nil, before: AppSubscriptionID? = nil, after: AppSubscriptionID? = nil) async throws -> [AppSubscription] {
        var qs: [String] = []
        if let status { qs.append("status=\(status)") }
        if let limit { qs.append("limit=\(limit)") }
        if let before { qs.append("before=\(before)") }
        if let after { qs.append("after=\(after)") }
        let path = "/applications/\(applicationId)/subscriptions" + (qs.isEmpty ? "" : "?" + qs.joined(separator: "&"))
        return try await http.get(path: path)
    }

    /// Get a single subscription.
    public func getApplicationSubscription(applicationId: ApplicationID, subscriptionId: AppSubscriptionID) async throws -> AppSubscription {
        try await http.get(path: "/applications/\(applicationId)/subscriptions/\(subscriptionId)")
    }
}
