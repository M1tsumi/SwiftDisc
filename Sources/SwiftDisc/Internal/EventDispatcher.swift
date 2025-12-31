import Foundation

actor EventDispatcher {
    func process(event: DiscordEvent, client: DiscordClient) async {
        switch event {
        case .ready(let info):
            await client.cache.upsert(user: info.user)
            await client._internalSetCurrentUserId(info.user.id)
            if let onReady = client.onReady { await onReady(info) }
        case .messageCreate(let msg):
            await client.cache.upsert(user: msg.author)
            await client.cache.upsert(channel: Channel(id: msg.channel_id, type: 0, name: nil, topic: nil, nsfw: nil, position: nil, parent_id: nil, available_tags: nil, default_reaction_emoji: nil, default_sort_order: nil, default_forum_layout: nil, default_auto_archive_duration: nil, rate_limit_per_user: nil, permission_overwrites: nil))
            await client.cache.add(message: msg)
            if let onMessage = client.onMessage { await onMessage(msg) }
            if let router = client.commands { await router.handleIfCommand(message: msg, client: client) }
        case .messageUpdate(let msg):
            await client.cache.upsert(user: msg.author)
            await client.cache.add(message: msg)
            if let cb = client.onMessageUpdate { await cb(msg) }
        case .messageDelete(let del):
            await client.cache.removeMessage(id: del.id)
            if let cb = client.onMessageDelete { await cb(del) }
        case .messageDeleteBulk(_):
            break
        case .messageReactionAdd(let ev):
            if let cb = client.onReactionAdd { await cb(ev) }
        case .messageReactionRemove(let ev):
            if let cb = client.onReactionRemove { await cb(ev) }
        case .messageReactionRemoveAll(let ev):
            if let cb = client.onReactionRemoveAll { await cb(ev) }
        case .messageReactionRemoveEmoji(let ev):
            if let cb = client.onReactionRemoveEmoji { await cb(ev) }
        case .guildCreate(let guild):
            await client.cache.upsert(guild: guild)
            if let onGuildCreate = client.onGuildCreate { await onGuildCreate(guild) }
        case .guildUpdate(_):
            break
        case .guildDelete(_):
            break
        case .guildMemberAdd(_):
            break
        case .guildMemberRemove(_):
            break
        case .guildMemberUpdate(_):
            break
        case .guildRoleCreate(_):
            break
        case .guildRoleUpdate(_):
            break
        case .guildRoleDelete(_):
            break
        case .guildEmojisUpdate(_):
            break
        case .guildStickersUpdate(_):
            break
        case .guildMembersChunk(_):
            break
        case .channelCreate(let channel), .channelUpdate(let channel):
            await client.cache.upsert(channel: channel)
        case .channelDelete(let channel):
            await client.cache.removeChannel(id: channel.id)
        case .interactionCreate(let interaction):
            if let cid = interaction.channel_id {
                await client.cache.upsert(channel: Channel(id: cid, type: 0, name: nil, topic: nil, nsfw: nil, position: nil, parent_id: nil, available_tags: nil, default_reaction_emoji: nil, default_sort_order: nil, default_forum_layout: nil, default_auto_archive_duration: nil, rate_limit_per_user: nil, permission_overwrites: nil))
            }
            if interaction.type == 4, let ac = client.autocomplete {
                await ac.handle(interaction: interaction, client: client)
            } else if let s = client.slashCommands {
                await s.handle(interaction: interaction, client: client)
            }
        case .voiceStateUpdate(let state):
            await client._internalOnVoiceStateUpdate(state)
        case .voiceServerUpdate(let vsu):
            await client._internalOnVoiceServerUpdate(vsu)
        case .raw(_, _):
            break
        case .threadCreate(_):
            break
        case .threadUpdate(_):
            break
        case .threadDelete(_):
            break
        case .threadMemberUpdate(_):
            break
        case .threadMembersUpdate(_):
            break
        case .guildScheduledEventCreate(_):
            break
        case .guildScheduledEventUpdate(_):
            break
        case .guildScheduledEventDelete(_):
            break
        case .guildScheduledEventUserAdd(_):
            break
        case .guildScheduledEventUserRemove(_):
            break
        case .typingStart(_):
            break
        case .channelPinsUpdate(_):
            break
        case .presenceUpdate(_):
            break
        case .guildBanAdd(_):
            break
        case .guildBanRemove(_):
            break
        case .webhooksUpdate(_):
            break
        case .guildIntegrationsUpdate(_):
            break
        case .inviteCreate(_):
            break
        case .inviteDelete(_):
            break
        }
        client._internalEmitEvent(event)
    }
}
