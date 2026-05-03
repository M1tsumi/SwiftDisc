import Foundation

actor EventDispatcher {
    func process(event: DiscordEvent, client: DiscordClient) async {
        switch event {

        // MARK: Ready
        case .ready(let info):
            await client.cache.upsert(user: info.user)
            await client._internalSetCurrentUserId(info.user.id)
            if let cb = await client.onReady { await cb(info) }

        // MARK: Messages
        case .messageCreate(let msg):
            await client.cache.upsert(user: msg.author)
            await client.cache.upsert(channel: Channel(id: msg.channel_id, type: 0))
            await client.cache.add(message: msg)
            if let cb = await client.onMessage { await cb(msg) }
            if let router = await client.commands { await router.handleIfCommand(message: msg, client: client) }

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

        case .guildMembersChunk(let chunk):
            for member in chunk.members { if let user = member.user { await client.cache.upsert(user: user) } }

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

        // MARK: Emojis / Stickers (no callback – stream-only)
        case .guildEmojisUpdate(let ev):
            await client.cache.upsert(emojis: ev.emojis, guildId: ev.guild_id)

        case .guildStickersUpdate:
            break

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

        case .threadMemberUpdate:
            break

        case .threadMembersUpdate(let ev):
            for thread in ev.threads { await client.cache.upsert(channel: thread) }
            if let cb = await client.onThreadMembersUpdate { await cb(ev) }

        case .threadListSync(let ev):
            for thread in ev.threads { await client.cache.upsert(channel: thread) }

        // MARK: Application Commands
        case .applicationCommandPermissionsUpdate(let ev):
            if let cb = await client.onApplicationCommandPermissionsUpdate { await cb(ev) }

        // MARK: Channel Info
        case .channelInfo(let channel):
            await client.cache.upsert(channel: channel)

        // MARK: Interactions
        case .interactionCreate(let interaction):
            if let cid = interaction.channel_id {
                await client.cache.upsert(channel: Channel(id: cid, type: 0))
            }
            if let cb = await client.onInteractionCreate { await cb(interaction) }
            if interaction.type == 4, let ac = await client.autocomplete {
                await ac.handle(interaction: interaction, client: client)
            } else if let s = await client.slashCommands {
                await s.handle(interaction: interaction, client: client)
            }

        // MARK: Voice
        case .voiceStateUpdate(let state):
            await client._internalOnVoiceStateUpdate(state)
            if let cb = await client.onVoiceStateUpdate { await cb(state) }

        case .voiceServerUpdate(let vsu):
            await client._internalOnVoiceServerUpdate(vsu)

        // MARK: Presence & Typing
        case .typingStart(let ev):
            if let cb = await client.onTypingStart { await cb(ev) }

        case .presenceUpdate(let ev):
            await client.cache.upsert(user: ev.user)
            if let cb = await client.onPresenceUpdate { await cb(ev) }

        case .channelPinsUpdate:
            break

        // MARK: Bans
        case .guildBanAdd(let ev):
            if let cb = await client.onGuildBanAdd { await cb(ev) }

        case .guildBanRemove(let ev):
            if let cb = await client.onGuildBanRemove { await cb(ev) }

        // MARK: Webhooks / Integrations / Invites (stream-only)
        case .webhooksUpdate, .guildIntegrationsUpdate, .inviteCreate, .inviteDelete:
            break

        // MARK: AutoMod
        case .autoModerationRuleCreate, .autoModerationRuleUpdate, .autoModerationRuleDelete:
            break

        case .autoModerationActionExecution(let ev):
            if let cb = await client.onAutoModerationActionExecution { await cb(ev) }

        // MARK: Audit Log (stream-only)
        case .guildAuditLogEntryCreate:
            break

        // MARK: Scheduled Events
        case .guildScheduledEventCreate(let ev):
            if let cb = await client.onGuildScheduledEventCreate { await cb(ev) }

        case .guildScheduledEventUpdate(let ev):
            if let cb = await client.onGuildScheduledEventUpdate { await cb(ev) }

        case .guildScheduledEventDelete(let ev):
            if let cb = await client.onGuildScheduledEventDelete { await cb(ev) }

        case .guildScheduledEventUserAdd, .guildScheduledEventUserRemove:
            break

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

        // MARK: Raw / Other
        case .raw:
            break
        }

        await client._internalEmitEvent(event)
    }
}


