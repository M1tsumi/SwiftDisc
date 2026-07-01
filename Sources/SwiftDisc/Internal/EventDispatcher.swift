import Foundation

/// Internal event dispatcher for Discord gateway events.
///
/// This actor processes incoming Discord events from the gateway,
/// updates the cache, and dispatches events to registered handlers.
/// It is an internal implementation detail and not part of the public API.
actor EventDispatcher {
    /// Processes a Discord event.
    ///
    /// This method handles the event by:
    /// 1. Updating the cache with relevant entities
    /// 2. Dispatching to registered event callbacks
    /// 3. Routing to command handlers if applicable
    ///
    /// - Parameters:
    ///   - event: The Discord event to process.
    ///   - client: The Discord client instance.
    func process(event: DiscordEvent, client: DiscordClient) async {
        await client._internalEmitEvent(event)
        switch event {

        // MARK: Ready
        case .ready(let info):
            await client.cache.upsert(user: info.user)
            await client._internalSetCurrentUserId(info.user.id)
            if let cb = await client.onReady { await cb(info) }

        // MARK: Messages
        case .messageCreate(let msg):
            await client.cache.upsert(user: msg.author)
            await client.cache.ensureChannelStub(id: msg.channel_id)
            await client.cache.add(message: msg)
            if let cb = await client.onMessage { await cb(msg) }
            if let router = await client.commands { await router.handle(msg, client: client) }

        case .messageUpdate(let msg):
            await client.cache.upsert(user: msg.author)
            await client.cache.add(message: msg)
            if let cb = await client.onMessageUpdate { await cb(msg) }

        case .messageDelete(let del):
            await client.cache.removeMessage(id: del.id)
            if let cb = await client.onMessageDelete { await cb(del) }

        case .messageDeleteBulk(let bulk):
            for id in bulk.ids { await client.cache.removeMessage(id: id) }
            if let cb = await client.onMessageDeleteBulk { await cb(bulk) }

        case .messageReactionAdd(let ev):
            if let cb = await client.onReactionAdd { await cb(ev) }

        case .messageReactionRemove(let ev):
            if let cb = await client.onReactionRemove { await cb(ev) }

        case .messageReactionRemoveAll(let ev):
            if let cb = await client.onReactionRemoveAll { await cb(ev) }

        case .messageReactionRemoveEmoji(let ev):
            if let cb = await client.onReactionRemoveEmoji { await cb(ev) }

        // MARK: Guilds
        case .guildCreate(let guild):
            await client.cache.upsert(guild: guild)
            // Eagerly seed channel and user caches from GUILD_CREATE payload
            for channel in guild.channels ?? [] { await client.cache.upsert(channel: channel) }
            for thread in guild.threads ?? []   { await client.cache.upsert(channel: thread) }
            for member in guild.members ?? [] { if let user = member.user { await client.cache.upsert(user: user) } }
            if let cb = await client.onGuildCreate { await cb(guild) }

        case .guildUpdate(let guild):
            await client.cache.upsert(guild: guild)
            if let cb = await client.onGuildUpdate { await cb(guild) }

        case .guildDelete(let ev):
            await client.cache.removeGuild(id: ev.id)
            if let cb = await client.onGuildDelete { await cb(ev) }

        // MARK: Members
        case .guildMemberAdd(let ev):
            await client.cache.upsert(user: ev.user)
            if let cb = await client.onGuildMemberAdd { await cb(ev) }

        case .guildMemberRemove(let ev):
            await client.cache.upsert(user: ev.user)
            if let cb = await client.onGuildMemberRemove { await cb(ev) }

        case .guildMemberUpdate(let ev):
            await client.cache.upsert(user: ev.user)
            if let cb = await client.onGuildMemberUpdate { await cb(ev) }

        case .guildMembersChunk(let ev):
            for member in ev.members { if let user = member.user { await client.cache.upsert(user: user) } }
            if let cb = await client.onGuildMembersChunk { await cb(ev) }

        // MARK: Roles
        case .guildRoleCreate(let ev):
            await client.cache.upsert(role: ev.role, guildId: ev.guild_id)
            if let cb = await client.onGuildRoleCreate { await cb(ev) }

        case .guildRoleUpdate(let ev):
            await client.cache.upsert(role: ev.role, guildId: ev.guild_id)
            if let cb = await client.onGuildRoleUpdate { await cb(ev) }

        case .guildRoleDelete(let ev):
            await client.cache.removeRole(id: ev.role_id, guildId: ev.guild_id)
            if let cb = await client.onGuildRoleDelete { await cb(ev) }

        // MARK: Emojis / Stickers
        case .guildEmojisUpdate(let ev):
            await client.cache.upsert(emojis: ev.emojis, guildId: ev.guild_id)
            if let cb = await client.onGuildEmojisUpdate { await cb(ev) }

        case .guildStickersUpdate(let ev):
            if let cb = await client.onGuildStickersUpdate { await cb(ev) }

        // MARK: Channels
        case .channelCreate(let channel):
            await client.cache.upsert(channel: channel)
            if let cb = await client.onChannelCreate { await cb(channel) }

        case .channelUpdate(let channel):
            await client.cache.upsert(channel: channel)
            if let cb = await client.onChannelUpdate { await cb(channel) }

        case .channelDelete(let channel):
            await client.cache.removeChannel(id: channel.id)
            if let cb = await client.onChannelDelete { await cb(channel) }

        // MARK: Voice Channel Status
        case .voiceChannelStatusUpdate(let ev):
            if let cb = await client.onVoiceChannelStatusUpdate { await cb(ev) }

        case .voiceChannelStartTimeUpdate(let ev):
            if let cb = await client.onVoiceChannelStartTimeUpdate { await cb(ev) }

        // MARK: Threads
        case .threadCreate(let ch):
            await client.cache.upsert(channel: ch)
            if let cb = await client.onThreadCreate { await cb(ch) }

        case .threadUpdate(let ch):
            await client.cache.upsert(channel: ch)
            if let cb = await client.onThreadUpdate { await cb(ch) }

        case .threadDelete(let ch):
            await client.cache.removeChannel(id: ch.id)
            if let cb = await client.onThreadDelete { await cb(ch) }

        case .threadMemberUpdate(let ev):
            if let cb = await client.onThreadMemberUpdate { await cb(ev) }

        case .threadMembersUpdate(let ev):
            if let cb = await client.onThreadMembersUpdate { await cb(ev) }

        case .threadListSync(let ev):
            for thread in ev.threads { await client.cache.upsert(channel: thread) }
            if let cb = await client.onThreadListSync { await cb(ev) }

        // MARK: Application Commands
        case .applicationCommandPermissionsUpdate(let ev):
            if let cb = await client.onApplicationCommandPermissionsUpdate { await cb(ev) }

        // MARK: Channel Info
        case .channelInfo(let channel):
            await client.cache.upsert(channel: channel)
            if let cb = await client.onChannelInfo { await cb(channel) }

        // MARK: Interactions
        case .interactionCreate(let interaction):
            if let cid = interaction.channel_id {
                await client.cache.ensureChannelStub(id: cid)
            }
            if let cb = await client.onInteractionCreate { await cb(interaction) }
            if interaction.type == .autocomplete, let ac = await client.autocomplete {
                await ac.handle(interaction: interaction, client: client)
            } else if let s = await client.slashCommands {
                await s.handle(interaction: interaction, client: client)
            }


        // MARK: Presence & Typing
        case .typingStart(let ev):
            if let cb = await client.onTypingStart { await cb(ev) }

        case .presenceUpdate(let ev):
            await client.cache.upsert(user: ev.user)
            if let cb = await client.onPresenceUpdate { await cb(ev) }

        case .channelPinsUpdate(let ev):
            if let cb = await client.onChannelPinsUpdate { await cb(ev) }

        // MARK: Bans
        case .guildBanAdd(let ev):
            if let cb = await client.onGuildBanAdd { await cb(ev) }

        case .guildBanRemove(let ev):
            if let cb = await client.onGuildBanRemove { await cb(ev) }

        // MARK: Webhooks / Integrations / Invites
        case .webhooksUpdate(let ev):
            if let cb = await client.onWebhooksUpdate { await cb(ev) }

        case .guildIntegrationsUpdate(let ev):
            if let cb = await client.onGuildIntegrationsUpdate { await cb(ev) }

        case .inviteCreate(let ev):
            if let cb = await client.onInviteCreate { await cb(ev) }

        case .inviteDelete(let ev):
            if let cb = await client.onInviteDelete { await cb(ev) }

        // MARK: AutoMod
        case .autoModerationRuleCreate(let ev):
            if let cb = await client.onAutoModerationRuleCreate { await cb(ev) }

        case .autoModerationRuleUpdate(let ev):
            if let cb = await client.onAutoModerationRuleUpdate { await cb(ev) }

        case .autoModerationRuleDelete(let ev):
            if let cb = await client.onAutoModerationRuleDelete { await cb(ev) }

        case .autoModerationActionExecution(let ev):
            if let cb = await client.onAutoModerationActionExecution { await cb(ev) }

        // MARK: Audit Log
        case .guildAuditLogEntryCreate(let ev):
            if let cb = await client.onGuildAuditLogEntryCreate { await cb(ev) }

        // MARK: Scheduled Events
        case .guildScheduledEventCreate(let ev):
            if let cb = await client.onGuildScheduledEventCreate { await cb(ev) }

        case .guildScheduledEventUpdate(let ev):
            if let cb = await client.onGuildScheduledEventUpdate { await cb(ev) }

        case .guildScheduledEventDelete(let ev):
            if let cb = await client.onGuildScheduledEventDelete { await cb(ev) }

        case .guildScheduledEventUserAdd(let ev):
            if let cb = await client.onGuildScheduledEventUserAdd { await cb(ev) }

        case .guildScheduledEventUserRemove(let ev):
            if let cb = await client.onGuildScheduledEventUserRemove { await cb(ev) }

        // MARK: Polls
        case .pollVoteAdd(let ev):
            if let cb = await client.onPollVoteAdd { await cb(ev) }

        case .pollVoteRemove(let ev):
            if let cb = await client.onPollVoteRemove { await cb(ev) }

        // MARK: Soundboard
        case .soundboardSoundCreate(let ev):
            if let cb = await client.onSoundboardSoundCreate { await cb(ev) }

        case .soundboardSoundUpdate(let ev):
            if let cb = await client.onSoundboardSoundUpdate { await cb(ev) }

        case .soundboardSoundDelete(let ev):
            if let cb = await client.onSoundboardSoundDelete { await cb(ev) }

        // MARK: Entitlements
        case .entitlementCreate(let ev):
            if let cb = await client.onEntitlementCreate { await cb(ev) }

        case .entitlementUpdate(let ev):
            if let cb = await client.onEntitlementUpdate { await cb(ev) }

        case .entitlementDelete(let ev):
            if let cb = await client.onEntitlementDelete { await cb(ev) }

        case .userUpdate(let ev):
            if let cb = await client.onUserUpdate { await cb(ev) }

        // MARK: Raw / Other
        case .raw:
            break
        // MARK: Session events
        case .sessionInvalidated:
            if let cb = await client.onSessionInvalidated { await cb() }
        case .disconnected(let reason):
            if let cb = await client.onDisconnected { await cb(reason) }
        case .resumed:
            if let cb = await client.onResumed { await cb() }
        }
    }
}
