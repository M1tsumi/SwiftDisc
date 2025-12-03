import Foundation

public final class DiscordClient {
    public let token: String
    private let http: HTTPClient
    private let gateway: GatewayClient
    private let configuration: DiscordConfiguration
    private let dispatcher = EventDispatcher()
    private let voiceClient: VoiceClient?
    private var currentUserId: UserID?

    private var eventStream: AsyncStream<DiscordEvent>!
    private var eventContinuation: AsyncStream<DiscordEvent>.Continuation!

    public let cache = Cache()

    // Extensions/Cogs registry
    private var loadedExtensions: [SwiftDiscExtension] = []

    public var events: AsyncStream<DiscordEvent> { eventStream }

    // Phase 3: Callback adapters
    public var onReady: ((ReadyEvent) async -> Void)?
    public var onMessage: ((Message) async -> Void)?
    public var onMessageUpdate: ((Message) async -> Void)?
    public var onMessageDelete: ((MessageDelete) async -> Void)?
    public var onReactionAdd: ((MessageReactionAdd) async -> Void)?
    public var onReactionRemove: ((MessageReactionRemove) async -> Void)?
    public var onReactionRemoveAll: ((MessageReactionRemoveAll) async -> Void)?
    public var onReactionRemoveEmoji: ((MessageReactionRemoveEmoji) async -> Void)?
    public var onGuildCreate: ((Guild) async -> Void)?

    // Phase 3: Command framework
    public var commands: CommandRouter?
    public func useCommands(_ router: CommandRouter) { self.commands = router }

    // Phase 4+: Slash command router
    public var slashCommands: SlashCommandRouter?
    public func useSlashCommands(_ router: SlashCommandRouter) { self.slashCommands = router }

    // Autocomplete router
    public var autocomplete: AutocompleteRouter?
    public func useAutocomplete(_ router: AutocompleteRouter) { self.autocomplete = router }

    public var onVoiceFrame: ((VoiceFrame) async -> Void)?

    public init(token: String, configuration: DiscordConfiguration = .init()) {
        self.token = token
        self.http = HTTPClient(token: token, configuration: configuration)
        self.gateway = GatewayClient(token: token, configuration: configuration)
        self.configuration = configuration
        if configuration.enableVoiceExperimental {
            self.voiceClient = VoiceClient(
                token: token,
                configuration: configuration,
                sendVoiceStateUpdate: { [weak gateway] (guildId, channelId, selfMute, selfDeaf) async in
                    await gateway?.updateVoiceState(guildId: guildId, channelId: channelId, selfMute: selfMute, selfDeaf: selfDeaf)
                }
            )
        } else {
            self.voiceClient = nil
        }

        if let vc = self.voiceClient {
            vc.setOnFrame { [weak self] frame in
                guard let self, let cb = self.onVoiceFrame else { return }
                Task {
                    await cb(frame)
                }
            }
        }

        var localContinuation: AsyncStream<DiscordEvent>.Continuation!
        self.eventStream = AsyncStream<DiscordEvent> { continuation in
            continuation.onTermination = { _ in }
            localContinuation = continuation
        }
        self.eventContinuation = localContinuation
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
    // Bulk delete messages (2-100, not older than 14 days)
    public func bulkDeleteMessages(channelId: ChannelID, messageIds: [MessageID]) async throws {
        struct Body: Encodable { let messages: [MessageID] }
        struct Ack: Decodable {}
        let body = Body(messages: messageIds)
        let _: Ack = try await http.post(path: "/channels/\(channelId)/messages/bulk-delete", body: body)
    }

    // Crosspost message
    public func crosspostMessage(channelId: ChannelID, messageId: MessageID) async throws -> Message {
        struct Empty: Encodable {}
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

    // MARK: - REST: Messages with Files
    public func sendMessageWithFiles(
        channelId: ChannelID,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        files: [FileAttachment]
    ) async throws -> Message {
        struct Payload: Encodable { let content: String?; let embeds: [Embed]?; let components: [MessageComponent]? }
        let body = Payload(content: content, embeds: embeds, components: components)
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
        struct Payload: Encodable { let content: String?; let embeds: [Embed]?; let components: [MessageComponent]?; let attachments: [PartialAttachment]? }
        let body = Payload(content: content, embeds: embeds, components: components, attachments: attachments)
        return try await http.patchMultipart(path: "/channels/\(channelId)/messages/\(messageId)", jsonBody: body, files: files)
    }

    // MARK: - REST: Interaction Follow-ups
    public func getOriginalInteractionResponse(applicationId: ApplicationID, interactionToken: String) async throws -> Message {
        try await http.get(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/@original")
    }

    public func editOriginalInteractionResponse(applicationId: ApplicationID, interactionToken: String, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil) async throws -> Message {
        struct Body: Encodable { let content: String?; let embeds: [Embed]?; let components: [MessageComponent]? }
        return try await http.patch(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/@original", body: Body(content: content, embeds: embeds, components: components))
    }

    public func deleteOriginalInteractionResponse(applicationId: ApplicationID, interactionToken: String) async throws {
        try await http.delete(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/@original")
    }

    public func createFollowupMessage(applicationId: ApplicationID, interactionToken: String, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil, ephemeral: Bool = false) async throws -> Message {
        struct Body: Encodable { let content: String?; let embeds: [Embed]?; let components: [MessageComponent]?; let flags: Int? }
        let flags = ephemeral ? 64 : nil
        return try await http.post(path: "/webhooks/\(applicationId)/\(interactionToken)", body: Body(content: content, embeds: embeds, components: components, flags: flags))
    }

    public func getFollowupMessage(applicationId: ApplicationID, interactionToken: String, messageId: MessageID) async throws -> Message {
        try await http.get(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/\(messageId)")
    }

    public func editFollowupMessage(applicationId: ApplicationID, interactionToken: String, messageId: MessageID, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil) async throws -> Message {
        struct Body: Encodable { let content: String?; let embeds: [Embed]?; let components: [MessageComponent]? }
        return try await http.patch(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/\(messageId)", body: Body(content: content, embeds: embeds, components: components))
    }

    public func deleteFollowupMessage(applicationId: ApplicationID, interactionToken: String, messageId: MessageID) async throws {
        try await http.delete(path: "/webhooks/\(applicationId)/\(interactionToken)/messages/\(messageId)")
    }

    // MARK: - Localization helpers (Application Commands)
    public func setCommandLocalizations(applicationId: ApplicationID, commandId: ApplicationCommandID, nameLocalizations: [String: String]?, descriptionLocalizations: [String: String]?) async throws -> ApplicationCommand {
        struct Body: Encodable { let name_localizations: [String: String]?; let description_localizations: [String: String]? }
        return try await http.patch(path: "/applications/\(applicationId)/commands/\(commandId)", body: Body(name_localizations: nameLocalizations, description_localizations: descriptionLocalizations))
    }

    // MARK: - Forwarding helper (via message reference)
    public func forwardMessageByReference(targetChannelId: ChannelID, sourceChannelId: ChannelID, messageId: MessageID) async throws -> Message {
        // Posts a message in targetChannelId that references the source message
        let payload: [String: JSONValue] = [
            "message_reference": .object([
                "channel_id": .string(String(describing: sourceChannelId)),
                "message_id": .string(String(describing: messageId))
            ])
        ]
        return try await http.post(path: "/channels/\(targetChannelId)/messages", body: payload)
    }

    // MARK: - Components V2 & Polls (generic helpers)
    // Send a message with arbitrary payload (e.g., Components V2). Use JSONValue to construct the payload safely.
    public func postMessage(channelId: ChannelID, payload: [String: JSONValue]) async throws -> Message {
        try await http.post(path: "/channels/\(channelId)/messages", body: payload)
    }

    // Convenience for Poll messages: merges content and `poll` object into message payload
    public func createPollMessage(channelId: ChannelID, content: String? = nil, poll: [String: JSONValue], flags: Int? = nil, components: [JSONValue]? = nil) async throws -> Message {
        var body: [String: JSONValue] = [
            "poll": .object(poll)
        ]
        if let content { body["content"] = .string(content) }
        if let flags { body["flags"] = .int(flags) }
        if let components { body["components"] = .array(components) }
        return try await http.post(path: "/channels/\(channelId)/messages", body: body)
    }

    // MARK: - Components V2 (typed envelope)
    public func sendComponentsV2Message(channelId: ChannelID, payload: V2MessagePayload) async throws -> Message {
        try await http.post(path: "/channels/\(channelId)/messages", body: payload.asJSON())
    }

    // MARK: - Polls (typed envelope)
    public func createPollMessage(channelId: ChannelID, payload: PollPayload, content: String? = nil, flags: Int? = nil, components: [JSONValue]? = nil) async throws -> Message {
        var body: [String: JSONValue] = [
            "poll": .object(payload.pollJSON())
        ]
        if let content { body["content"] = .string(content) }
        if let flags { body["flags"] = .int(flags) }
        if let components { body["components"] = .array(components) }
        return try await http.post(path: "/channels/\(channelId)/messages", body: body)
    }

    // MARK: - App Emoji (typed top-level + JSONValue internals)
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

    // MARK: - UserApps (typed wrapper names over generic helpers)
    public func createUserAppResource(applicationId: ApplicationID, relativePath: String, payload: [String: JSONValue]) async throws -> JSONValue {
        try await postApplicationResource(applicationId: applicationId, relativePath: relativePath, payload: payload)
    }

    public func updateUserAppResource(applicationId: ApplicationID, relativePath: String, payload: [String: JSONValue]) async throws -> JSONValue {
        try await patchApplicationResource(applicationId: applicationId, relativePath: relativePath, payload: payload)
    }

    public func deleteUserAppResource(applicationId: ApplicationID, relativePath: String) async throws {
        try await deleteApplicationResource(applicationId: applicationId, relativePath: relativePath)
    }

    // Guild widget settings
    public func getGuildWidgetSettings(guildId: GuildID) async throws -> GuildWidgetSettings {
        try await http.get(path: "/guilds/\(guildId)/widget")
    }

    public func modifyGuildWidgetSettings(guildId: GuildID, enabled: Bool, channelId: ChannelID?) async throws -> GuildWidgetSettings {
        struct Body: Encodable { let enabled: Bool; let channel_id: ChannelID? }
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
        struct Body: Encodable { let name: String; let image: String; let roles: [RoleID]? }
        return try await http.post(path: "/guilds/\(guildId)/emojis", body: Body(name: name, image: image, roles: roles))
    }

    public func modifyGuildEmoji(guildId: GuildID, emojiId: EmojiID, name: String? = nil, roles: [RoleID]? = nil) async throws -> Emoji {
        struct Body: Encodable { let name: String?; let roles: [RoleID]? }
        return try await http.patch(path: "/guilds/\(guildId)/emojis/\(emojiId)", body: Body(name: name, roles: roles))
    }

    public func deleteGuildEmoji(guildId: GuildID, emojiId: EmojiID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/emojis/\(emojiId)")
    }

    // MARK: - REST: Guild Member Advanced Operations
    // Add guild member (OAuth2 access token)
    public func addGuildMember(guildId: GuildID, userId: UserID, accessToken: String, nick: String? = nil, roles: [RoleID]? = nil, mute: Bool? = nil, deaf: Bool? = nil) async throws -> GuildMember {
        struct Body: Encodable { let access_token: String; let nick: String?; let roles: [RoleID]?; let mute: Bool?; let deaf: Bool? }
        return try await http.put(path: "/guilds/\(guildId)/members/\(userId)", body: Body(access_token: accessToken, nick: nick, roles: roles, mute: mute, deaf: deaf))
    }

    // Remove guild member (kick)
    public func removeGuildMember(guildId: GuildID, userId: UserID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/members/\(userId)")
    }

    // Modify current member (bot user)
    public func modifyCurrentMember(guildId: GuildID, nick: String? = nil) async throws -> GuildMember {
        struct Body: Encodable { let nick: String? }
        return try await http.patch(path: "/guilds/\(guildId)/members/@me", body: Body(nick: nick))
    }

    // Modify current user nickname (deprecated but still available)
    public func modifyCurrentUserNick(guildId: GuildID, nick: String?) async throws -> String {
        struct Body: Encodable { let nick: String? }
        struct Resp: Decodable { let nick: String }
        let resp: Resp = try await http.patch(path: "/guilds/\(guildId)/members/@me/nick", body: Body(nick: nick))
        return resp.nick
    }

    // Add guild member role
    public func addGuildMemberRole(guildId: GuildID, userId: UserID, roleId: RoleID) async throws {
        try await http.put(path: "/guilds/\(guildId)/members/\(userId)/roles/\(roleId)")
    }

    // Remove guild member role
    public func removeGuildMemberRole(guildId: GuildID, userId: UserID, roleId: RoleID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/members/\(userId)/roles/\(roleId)")
    }

    // Search guild members
    public func searchGuildMembers(guildId: GuildID, query: String, limit: Int = 1) async throws -> [GuildMember] {
        try await http.get(path: "/guilds/\(guildId)/members/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&limit=\(limit)")
    }

    // MARK: - REST: User/Bot Profile Management
    // Get user
    public func getUser(userId: UserID) async throws -> User {
        try await http.get(path: "/users/\(userId)")
    }

    // Modify current user
    public func modifyCurrentUser(username: String? = nil, avatar: String? = nil) async throws -> User {
        struct Body: Encodable { let username: String?; let avatar: String? }
        return try await http.patch(path: "/users/@me", body: Body(username: username, avatar: avatar))
    }

    // Get current user guilds
    public func getCurrentUserGuilds(before: GuildID? = nil, after: GuildID? = nil, limit: Int = 200) async throws -> [PartialGuild] {
        var parts: [String] = ["limit=\(limit)"]
        if let before { parts.append("before=\(before)") }
        if let after { parts.append("after=\(after)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/users/@me/guilds\(q)")
    }

    // Leave guild
    public func leaveGuild(guildId: GuildID) async throws {
        try await http.delete(path: "/users/@me/guilds/\(guildId)")
    }

    // Create DM channel
    public func createDM(recipientId: UserID) async throws -> Channel {
        struct Body: Encodable { let recipient_id: UserID }
        return try await http.post(path: "/users/@me/channels", body: Body(recipient_id: recipientId))
    }

    // Create group DM
    public func createGroupDM(accessTokens: [String], nicks: [UserID: String]) async throws -> Channel {
        struct Body: Encodable { let access_tokens: [String]; let nicks: [UserID: String] }
        return try await http.post(path: "/users/@me/channels", body: Body(access_tokens: accessTokens, nicks: nicks))
    }

    // Guild prune (typed)
    public struct PrunePayload: Codable { public let days: Int; public let compute_prune_count: Bool?; public let include_roles: [RoleID]? }
    public struct PruneResponse: Codable { public let pruned: Int }

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
        struct Entry: Encodable { let id: RoleID; let position: Int }
        let body = positions.map { Entry(id: $0.id, position: $0.position) }
        return try await http.patch(path: "/guilds/\(guildId)/roles", body: body)
    }
    

    public func loginAndConnect(intents: GatewayIntents) async throws {
        try await gateway.connect(intents: intents, shard: nil, eventSink: { [weak self] event in
            guard let self = self else { return }
            Task { await self.dispatcher.process(event: event, client: self) }
        })
    }

    // Sharded connect helper
    public func loginAndConnectSharded(index: Int, total: Int, intents: GatewayIntents) async throws {
        try await gateway.connect(intents: intents, shard: (index, total), eventSink: { [weak self] event in
            guard let self = self else { return }
            Task { await self.dispatcher.process(event: event, client: self) }
        })
    }

    public func getCurrentUser() async throws -> User {
        try await http.get(path: "/users/@me")
    }

    public func sendMessage(channelId: ChannelID, content: String) async throws -> Message {
        struct Body: Encodable { let content: String }
        return try await http.post(path: "/channels/\(channelId)/messages", body: Body(content: content))
    }

    // Overload: send message with embeds
    public func sendMessage(channelId: ChannelID, content: String? = nil, embeds: [Embed]) async throws -> Message {
        struct Body: Encodable { let content: String?; let embeds: [Embed] }
        return try await http.post(path: "/channels/\(channelId)/messages", body: Body(content: content, embeds: embeds))
    }

    // Overload: send message with embeds and components
    public func sendMessage(channelId: ChannelID, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil) async throws -> Message {
        struct Body: Encodable { let content: String?; let embeds: [Embed]?; let components: [MessageComponent]? }
        return try await http.post(path: "/channels/\(channelId)/messages", body: Body(content: content, embeds: embeds, components: components))
    }

    // Phase 3: Presence helpers
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
            buttons: buttons,
            party: nil,
            secrets: nil
        )
        await gateway.setPresence(status: "online", activities: [act], afk: false, since: nil)
    }

    public func joinVoice(guildId: GuildID, channelId: ChannelID, selfMute: Bool = false, selfDeaf: Bool = false) async throws {
        guard let voiceClient else { throw VoiceError.disabled }
        try await voiceClient.joinVoiceChannel(guildId: guildId, channelId: channelId, selfMute: selfMute, selfDeaf: selfDeaf)
    }

    public func leaveVoice(guildId: GuildID) async throws {
        guard let voiceClient else { throw VoiceError.disabled }
        try await voiceClient.leaveVoiceChannel(guildId: guildId)
    }

    public func playVoiceOpus(guildId: GuildID, data: Data) async throws {
        guard let voiceClient else { throw VoiceError.disabled }
        try await voiceClient.playOpusFrames(guildId: guildId, pcmOrOpusData: data)
    }

    // MARK: - Internal voice wiring (called by EventDispatcher)
    func _internalSetCurrentUserId(_ id: UserID) async {
        self.currentUserId = id
    }

    func _internalOnVoiceStateUpdate(_ state: VoiceState) async {
        guard let voiceClient else { return }
        await voiceClient.onVoiceStateUpdate(state)
    }

    func _internalOnVoiceServerUpdate(_ vsu: VoiceServerUpdate) async {
        guard let voiceClient, let userId = self.currentUserId else { return }
        await voiceClient.onVoiceServerUpdate(vsu, botUserId: userId)
    }

    // MARK: - Internal event emission (called by EventDispatcher)
    func _internalEmitEvent(_ event: DiscordEvent) {
        eventContinuation?.yield(event)
    }

    // MARK: - Raw REST passthroughs (coverage helper)
    public func rawGET<T: Decodable>(_ path: String) async throws -> T { try await http.get(path: path) }
    public func rawPOST<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T { try await http.post(path: path, body: body) }
    public func rawPATCH<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T { try await http.patch(path: path, body: body) }
    public func rawPUT<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T { try await http.put(path: path, body: body) }
    public func rawDELETE<T: Decodable>(_ path: String) async throws -> T { try await http.delete(path: path) }

    // MARK: - Generic Application-scoped helpers (for userApps/appEmoji and future endpoints)
    public func postApplicationResource(applicationId: ApplicationID, relativePath: String, payload: [String: JSONValue]) async throws -> JSONValue {
        try await http.post(path: "/applications/\(applicationId)/\(relativePath)", body: payload)
    }

    public func patchApplicationResource(applicationId: ApplicationID, relativePath: String, payload: [String: JSONValue]) async throws -> JSONValue {
        try await http.patch(path: "/applications/\(applicationId)/\(relativePath)", body: payload)
    }

    public func deleteApplicationResource(applicationId: ApplicationID, relativePath: String) async throws {
        try await http.delete(path: "/applications/\(applicationId)/\(relativePath)")
    }

    // MARK: - Phase 2 REST: Channels
    public func getChannel(id: ChannelID) async throws -> Channel {
        try await http.get(path: "/channels/\(id)")
    }

    public func modifyChannelName(id: ChannelID, name: String) async throws -> Channel {
        struct Body: Encodable { let name: String }
        return try await http.patch(path: "/channels/\(id)", body: Body(name: name))
    }

    // Broader channel modify helper
    public func modifyChannel(id: ChannelID, topic: String? = nil, nsfw: Bool? = nil, position: Int? = nil, parentId: ChannelID? = nil) async throws -> Channel {
        struct Body: Encodable { let topic: String?; let nsfw: Bool?; let position: Int?; let parent_id: ChannelID? }
        return try await http.patch(path: "/channels/\(id)", body: Body(topic: topic, nsfw: nsfw, position: position, parent_id: parentId))
    }

    public func deleteMessage(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)")
    }

    // Message retrieval
    public func getMessage(channelId: ChannelID, messageId: MessageID) async throws -> Message {
        try await http.get(path: "/channels/\(channelId)/messages/\(messageId)")
    }

    // Message edit (content and/or embeds)
    public func editMessage(channelId: ChannelID, messageId: MessageID, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil) async throws -> Message {
        struct Body: Encodable { let content: String?; let embeds: [Embed]?; let components: [MessageComponent]? }
        return try await http.patch(path: "/channels/\(channelId)/messages/\(messageId)", body: Body(content: content, embeds: embeds, components: components))
    }

    // List channel messages (simple limit)
    public func listChannelMessages(channelId: ChannelID, limit: Int = 50) async throws -> [Message] {
        try await http.get(path: "/channels/\(channelId)/messages?limit=\(limit)")
    }

    // MARK: - Message Reactions
    private func encodeEmoji(_ emoji: String) -> String {
        emoji.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? emoji
    }

    // Add reaction to message
    public func addReaction(channelId: ChannelID, messageId: MessageID, emoji: String) async throws {
        let e = encodeEmoji(emoji)
        try await http.put(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)/@me")
    }

    // Remove own reaction
    public func removeOwnReaction(channelId: ChannelID, messageId: MessageID, emoji: String) async throws {
        let e = encodeEmoji(emoji)
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)/@me")
    }

    // Remove user's reaction
    public func removeUserReaction(channelId: ChannelID, messageId: MessageID, emoji: String, userId: UserID) async throws {
        let e = encodeEmoji(emoji)
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)/\(userId)")
    }

    // Get reactions for emoji
    public func getReactions(channelId: ChannelID, messageId: MessageID, emoji: String, limit: Int? = 25) async throws -> [User] {
        let e = encodeEmoji(emoji)
        let q = limit != nil ? "?limit=\(limit!)" : ""
        return try await http.get(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)\(q)")
    }

    // Remove all reactions
    public func removeAllReactions(channelId: ChannelID, messageId: MessageID) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions")
    }

    // Remove all reactions for specific emoji
    public func removeAllReactionsForEmoji(channelId: ChannelID, messageId: MessageID, emoji: String) async throws {
        let e = encodeEmoji(emoji)
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)/reactions/\(e)")
    }

    // MARK: - Phase 2 REST: Guilds
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

    // Create/delete channels
    public func createGuildChannel(guildId: GuildID, name: String, type: Int? = nil, topic: String? = nil, nsfw: Bool? = nil, parentId: ChannelID? = nil, position: Int? = nil) async throws -> Channel {
        struct Body: Encodable { let name: String; let type: Int?; let topic: String?; let nsfw: Bool?; let parent_id: ChannelID?; let position: Int? }
        return try await http.post(path: "/guilds/\(guildId)/channels", body: Body(name: name, type: type, topic: topic, nsfw: nsfw, parent_id: parentId, position: position))
    }

    public func deleteChannel(channelId: ChannelID) async throws {
        try await http.delete(path: "/channels/\(channelId)")
    }

    // Bulk modify channel positions (guild)
    public func bulkModifyGuildChannelPositions(guildId: GuildID, positions: [(id: ChannelID, position: Int)]) async throws -> [Channel] {
        struct Entry: Encodable { let id: ChannelID; let position: Int }
        let body = positions.map { Entry(id: $0.id, position: $0.position) }
        return try await http.patch(path: "/guilds/\(guildId)/channels", body: body)
    }

    // Channel permission overwrites
    // type: 0 = role, 1 = member
    public func editChannelPermission(channelId: ChannelID, overwriteId: OverwriteID, type: Int, allow: String? = nil, deny: String? = nil) async throws {
        struct Body: Encodable { let allow: String?; let deny: String?; let type: Int }
        struct EmptyDecodable: Decodable {}
        let _: EmptyDecodable = try await http.put(path: "/channels/\(channelId)/permissions/\(overwriteId)", body: Body(allow: allow, deny: deny, type: type))
    }

    public func deleteChannelPermission(channelId: ChannelID, overwriteId: OverwriteID) async throws {
        try await http.delete(path: "/channels/\(channelId)/permissions/\(overwriteId)")
    }

    // Channel typing indicator
    public func triggerTypingIndicator(channelId: ChannelID) async throws {
        struct Empty: Encodable {}
        struct EmptyDecodable: Decodable {}
        let _: EmptyDecodable = try await http.post(path: "/channels/\(channelId)/typing", body: Empty())
    }

    // Roles
    public func listGuildRoles(guildId: GuildID) async throws -> [Role] {
        try await http.get(path: "/guilds/\(guildId)/roles")
    }

    public struct RoleCreate: Codable { public let name: String; public let permissions: String?; public let color: Int?; public let hoist: Bool?; public let icon: String?; public let unicode_emoji: String?; public let mentionable: Bool? }
    public struct RoleUpdate: Codable { public let name: String?; public let permissions: String?; public let color: Int?; public let hoist: Bool?; public let icon: String?; public let unicode_emoji: String?; public let mentionable: Bool? }

    public func modifyRole(guildId: GuildID, roleId: RoleID, payload: RoleUpdate) async throws -> Role {
        try await http.patch(path: "/guilds/\(guildId)/roles/\(roleId)", body: payload)
    }

    public func createRole(guildId: GuildID, payload: RoleCreate) async throws -> Role {
        try await http.post(path: "/guilds/\(guildId)/roles", body: payload)
    }

    public func deleteRole(guildId: GuildID, roleId: RoleID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/roles/\(roleId)")
    }

    // Application Command default permissions (perms v2 related)
    public func setApplicationCommandDefaultPermissions(applicationId: ApplicationID, commandId: ApplicationCommandID, defaultMemberPermissions: String?) async throws -> ApplicationCommand {
        struct Body: Encodable { let default_member_permissions: String? }
        return try await http.patch(path: "/applications/\(applicationId)/commands/\(commandId)", body: Body(default_member_permissions: defaultMemberPermissions))
    }

    // Bans
    public func listGuildBans(guildId: GuildID) async throws -> [GuildBan] {
        try await http.get(path: "/guilds/\(guildId)/bans")
    }

    public func createGuildBan(guildId: GuildID, userId: UserID, deleteMessageSeconds: Int? = nil) async throws {
        struct Empty: Encodable {}
        var path = "/guilds/\(guildId)/bans/\(userId)"
        if let s = deleteMessageSeconds { path += "?delete_message_seconds=\(s)" }
        let _: ApplicationCommand = try await http.put(path: path, body: Empty())
    }

    public func deleteGuildBan(guildId: GuildID, userId: UserID) async throws {
        try await http.delete(path: "/guilds/\(guildId)/bans/\(userId)")
    }

    
    public func modifyGuildMember(guildId: GuildID, userId: UserID, nick: String? = nil, roles: [RoleID]? = nil) async throws -> GuildMember {
        struct Body: Encodable { let nick: String?; let roles: [RoleID]? }
        return try await http.patch(path: "/guilds/\(guildId)/members/\(userId)", body: Body(nick: nick, roles: roles))
    }

    // Timeout (communication_disabled_until)
    public func setMemberTimeout(guildId: GuildID, userId: UserID, until date: Date) async throws -> GuildMember {
        struct Body: Encodable {
            let communication_disabled_until: String
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let body = Body(communication_disabled_until: iso.string(from: date))
        return try await http.patch(path: "/guilds/\(guildId)/members/\(userId)", body: body)
    }

    public func clearMemberTimeout(guildId: GuildID, userId: UserID) async throws -> GuildMember {
        struct Body: Encodable { let communication_disabled_until: String? }
        return try await http.patch(path: "/guilds/\(guildId)/members/\(userId)", body: Body(communication_disabled_until: nil))
    }

    // Guild settings
    public func modifyGuild(guildId: GuildID, name: String? = nil, verificationLevel: Int? = nil, defaultMessageNotifications: Int? = nil, systemChannelId: ChannelID? = nil, explicitContentFilter: Int? = nil) async throws -> Guild {
        struct Body: Encodable {
            let name: String?
            let verification_level: Int?
            let default_message_notifications: Int?
            let system_channel_id: ChannelID?
            let explicit_content_filter: Int?
        }
        let body = Body(name: name, verification_level: verificationLevel, default_message_notifications: defaultMessageNotifications, system_channel_id: systemChannelId, explicit_content_filter: explicitContentFilter)
        return try await http.patch(path: "/guilds/\(guildId)", body: body)
    }

    // MARK: - REST: Threads
    // Start thread from message
    public func startThreadFromMessage(
        channelId: ChannelID,
        messageId: MessageID,
        name: String,
        autoArchiveDuration: Int? = nil,
        rateLimitPerUser: Int? = nil
    ) async throws -> Channel {
        struct Body: Encodable { let name: String; let auto_archive_duration: Int?; let rate_limit_per_user: Int? }
        let body = Body(name: name, auto_archive_duration: autoArchiveDuration, rate_limit_per_user: rateLimitPerUser)
        return try await http.post(path: "/channels/\(channelId)/messages/\(messageId)/threads", body: body)
    }

    // Start thread without message (in text channels)
    public func startThreadWithoutMessage(
        channelId: ChannelID,
        name: String,
        autoArchiveDuration: Int? = nil,
        type: Int? = nil,
        invitable: Bool? = nil,
        rateLimitPerUser: Int? = nil
    ) async throws -> Channel {
        struct Body: Encodable { let name: String; let auto_archive_duration: Int?; let type: Int?; let invitable: Bool?; let rate_limit_per_user: Int? }
        let body = Body(name: name, auto_archive_duration: autoArchiveDuration, type: type, invitable: invitable, rate_limit_per_user: rateLimitPerUser)
        return try await http.post(path: "/channels/\(channelId)/threads", body: body)
    }

    // Join thread
    public func joinThread(channelId: ChannelID) async throws {
        try await http.put(path: "/channels/\(channelId)/thread-members/@me")
    }

    // Leave thread
    public func leaveThread(channelId: ChannelID) async throws {
        try await http.delete(path: "/channels/\(channelId)/thread-members/@me")
    }

    // Add thread member
    public func addThreadMember(channelId: ChannelID, userId: UserID) async throws {
        try await http.put(path: "/channels/\(channelId)/thread-members/\(userId)")
    }

    // Remove thread member
    public func removeThreadMember(channelId: ChannelID, userId: UserID) async throws {
        try await http.delete(path: "/channels/\(channelId)/thread-members/\(userId)")
    }

    // Get thread member
    public func getThreadMember(channelId: ChannelID, userId: UserID, withMember: Bool = false) async throws -> ThreadMember {
        let q = withMember ? "?with_member=true" : ""
        return try await http.get(path: "/channels/\(channelId)/thread-members/\(userId)\(q)")
    }

    // List thread members
    public func listThreadMembers(channelId: ChannelID, withMember: Bool = false, after: UserID? = nil, limit: Int? = 100) async throws -> [ThreadMember] {
        var parts: [String] = []
        if withMember { parts.append("with_member=true") }
        if let after { parts.append("after=\(after)") }
        if let limit { parts.append("limit=\(limit)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/channels/\(channelId)/thread-members\(q)")
    }

    // List active threads in a guild
    public func listActiveThreads(guildId: GuildID) async throws -> ThreadListResponse {
        try await http.get(path: "/guilds/\(guildId)/threads/active")
    }

    // List public archived threads
    public func listPublicArchivedThreads(channelId: ChannelID, before: String? = nil, limit: Int? = 50) async throws -> ThreadListResponse {
        var parts: [String] = []
        if let before { parts.append("before=\(before)") }
        if let limit { parts.append("limit=\(limit)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/channels/\(channelId)/threads/archived/public\(q)")
    }

    // List private archived threads
    public func listPrivateArchivedThreads(channelId: ChannelID, before: String? = nil, limit: Int? = 50) async throws -> ThreadListResponse {
        var parts: [String] = []
        if let before { parts.append("before=\(before)") }
        if let limit { parts.append("limit=\(limit)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/channels/\(channelId)/threads/archived/private\(q)")
    }

    // List joined private archived threads
    public func listJoinedPrivateArchivedThreads(channelId: ChannelID, before: MessageID? = nil, limit: Int? = 50) async throws -> ThreadListResponse {
        var parts: [String] = []
        if let before { parts.append("before=\(before)") }
        if let limit { parts.append("limit=\(limit)") }
        let q = parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
        return try await http.get(path: "/channels/\(channelId)/users/@me/threads/archived/private\(q)")
    }

    // MARK: - Phase 2 REST: Interactions
    // Minimal interaction response helper (type 4 = ChannelMessageWithSource)
    public func createInteractionResponse(interactionId: InteractionID, token: String, content: String) async throws {
        struct DataObj: Encodable { let content: String }
        struct Body: Encodable { let type: Int = 4; let data: DataObj }
        struct Ack: Decodable {}
        let body = Body(data: DataObj(content: content))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    // Overload: interaction response with embeds
    public func createInteractionResponse(interactionId: InteractionID, token: String, content: String? = nil, embeds: [Embed]) async throws {
        struct DataObj: Encodable { let content: String?; let embeds: [Embed] }
        struct Body: Encodable { let type: Int = 4; let data: DataObj }
        struct Ack: Decodable {}
        let body = Body(data: DataObj(content: content, embeds: embeds))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    public enum InteractionResponseType: Int, Codable {
        case pong = 1
        case channelMessageWithSource = 4
        case deferredChannelMessageWithSource = 5
        case deferredUpdateMessage = 6
        case updateMessage = 7
        case autocompleteResult = 8
        case modal = 9
    }

    public func createInteractionResponse(interactionId: InteractionID, token: String, type: InteractionResponseType, content: String? = nil, embeds: [Embed]? = nil) async throws {
        struct DataObj: Encodable { let content: String?; let embeds: [Embed]? }
        struct Body: Encodable { let type: Int; let data: DataObj? }
        struct Ack: Decodable {}
        let data = (content == nil && embeds == nil) ? nil : DataObj(content: content, embeds: embeds)
        let body = Body(type: type.rawValue, data: data)
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    // Autocomplete result helper (type 8)
    public struct AutocompleteChoice: Codable {
        public let name: String
        public let value: String
        public init(name: String, value: String) { self.name = name; self.value = value }
    }

    public func createAutocompleteResponse(interactionId: InteractionID, token: String, choices: [AutocompleteChoice]) async throws {
        struct DataObj: Encodable { let choices: [AutocompleteChoice] }
        struct Body: Encodable { let type: Int; let data: DataObj }
        struct Ack: Decodable {}
        let body = Body(type: InteractionResponseType.autocompleteResult.rawValue, data: DataObj(choices: choices))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    // Modal response helper (type 9)
    public func createInteractionModal(
        interactionId: InteractionID,
        token: String,
        title: String,
        customId: String,
        components: [MessageComponent]
    ) async throws {
        struct DataObj: Encodable { let custom_id: String; let title: String; let components: [MessageComponent] }
        struct Body: Encodable { let type: Int; let data: DataObj }
        struct Ack: Decodable {}
        let body = Body(type: InteractionResponseType.modal.rawValue, data: DataObj(custom_id: customId, title: title, components: components))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    public func shutdown() async {
        await gateway.close()
        eventContinuation?.finish()
    }

    // MARK: - Phase 4: Slash Commands (minimal)
    public struct ApplicationCommand: Codable {
        public let id: ApplicationCommandID
        public let application_id: ApplicationID
        public let name: String
        public let description: String
    }

    public struct ApplicationCommandOption: Codable {
        public enum ApplicationCommandOptionType: Int, Codable {
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
        public struct Choice: Codable { public let name: String; public let value: String }
        public let choices: [Choice]?
        public init(type: ApplicationCommandOptionType, name: String, description: String, required: Bool? = nil, choices: [Choice]? = nil) {
            self.type = type
            self.name = name
            self.description = description
            self.required = required
            self.choices = choices
        }
    }

    public struct ApplicationCommandCreate: Encodable {
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
        struct Body: Encodable { let name: String; let description: String }
        return try await http.post(path: "/applications/\(appId)/commands", body: Body(name: name, description: description))
    }

    public func createGuildCommand(guildId: GuildID, name: String, description: String) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable { let name: String; let description: String }
        return try await http.post(path: "/applications/\(appId)/guilds/\(guildId)/commands", body: Body(name: name, description: description))
    }

    public func createGlobalCommand(name: String, description: String, options: [ApplicationCommandOption]) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable { let name: String; let description: String; let options: [ApplicationCommandOption] }
        return try await http.post(path: "/applications/\(appId)/commands", body: Body(name: name, description: description, options: options))
    }

    public func createGuildCommand(guildId: GuildID, name: String, description: String, options: [ApplicationCommandOption]) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable { let name: String; let description: String; let options: [ApplicationCommandOption] }
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

    // MARK: - Phase 2 REST: Webhooks
    public func createWebhook(channelId: ChannelID, name: String) async throws -> Webhook {
        struct Body: Encodable { let name: String }
        return try await http.post(path: "/channels/\(channelId)/webhooks", body: Body(name: name))
    }

    public func executeWebhook(webhookId: WebhookID, token: String, content: String) async throws -> Message {
        struct Body: Encodable { let content: String }
        return try await http.post(path: "/webhooks/\(webhookId)/\(token)", body: Body(content: content))
    }

    public func createChannelInvite(channelId: ChannelID, maxAge: Int? = nil, maxUses: Int? = nil, temporary: Bool? = nil, unique: Bool? = nil) async throws -> Invite {
        struct Body: Encodable {
            let max_age: Int?
            let max_uses: Int?
            let temporary: Bool?
            let unique: Bool?
        }
        let body = Body(max_age: maxAge, max_uses: maxUses, temporary: temporary, unique: unique)
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

    public func getTemplate(code: String) async throws -> Template {
        try await http.get(path: "/guilds/templates/\(code)")
    }

    public func listGuildTemplates(guildId: GuildID) async throws -> [Template] {
        try await http.get(path: "/guilds/\(guildId)/templates")
    }

    public func createGuildTemplate(guildId: GuildID, name: String, description: String? = nil) async throws -> Template {
        struct Body: Encodable { let name: String; let description: String? }
        return try await http.post(path: "/guilds/\(guildId)/templates", body: Body(name: name, description: description))
    }

    public func modifyGuildTemplate(guildId: GuildID, code: String, name: String? = nil, description: String? = nil) async throws -> Template {
        struct Body: Encodable { let name: String?; let description: String? }
        return try await http.patch(path: "/guilds/\(guildId)/templates/\(code)", body: Body(name: name, description: description))
    }

    public func syncGuildTemplate(guildId: GuildID, code: String) async throws -> Template {
        struct Empty: Encodable {}
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
        struct Packs: Decodable { let sticker_packs: [StickerPack] }
        let resp: Packs = try await http.get(path: "/sticker-packs")
        return resp.sticker_packs
    }

    public func listGuildStickers(guildId: GuildID) async throws -> [Sticker] {
        try await http.get(path: "/guilds/\(guildId)/stickers")
    }

    public func getGuildSticker(guildId: GuildID, stickerId: StickerID) async throws -> Sticker {
        try await http.get(path: "/guilds/\(guildId)/stickers/\(stickerId)")
    }

    // MARK: - REST: Forum helpers
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
        struct Msg: Encodable { let content: String?; let embeds: [Embed]?; let components: [MessageComponent]? }
        struct Body: Encodable {
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
        var path = "/guilds/\(guildId)/audit-logs"
        var qs: [String] = []
        if let userId { qs.append("user_id=\(userId)") }
        if let actionType { qs.append("action_type=\(actionType)") }
        if let before { qs.append("before=\(before)") }
        if let limit { qs.append("limit=\(limit)") }
        if !qs.isEmpty { path += "?" + qs.joined(separator: "&") }
        return try await http.get(path: path)
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
        struct Body: Encodable {
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
        struct Body: Encodable {
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
        struct Body: Encodable {
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
        struct Body: Encodable {
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
        var path = "/guilds/\(guildId)/scheduled-events/\(eventId)/users"
        var qs: [String] = []
        if let limit { qs.append("limit=\(limit)") }
        if withMember { qs.append("with_member=true") }
        if let before { qs.append("before=\(before)") }
        if let after { qs.append("after=\(after)") }
        if !qs.isEmpty { path += "?" + qs.joined(separator: "&") }
        return try await http.get(path: path)
    }

    // MARK: - REST: Stage Instances
    public func createStageInstance(channelId: ChannelID, topic: String, privacyLevel: Int = 2, guildScheduledEventId: GuildScheduledEventID? = nil) async throws -> StageInstance {
        struct Body: Encodable {
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
        struct Body: Encodable { let topic: String?; let privacy_level: Int? }
        return try await http.patch(path: "/stage-instances/\(channelId)", body: Body(topic: topic, privacy_level: privacyLevel))
    }

    public func deleteStageInstance(channelId: ChannelID) async throws {
        try await http.delete(path: "/stage-instances/\(channelId)")
    }
}
