import Foundation

public enum PermissionsUtil {
    // Compute effective permissions for a user in a channel following Discord rules.
    // - Parameters:
    //   - userId: target user id
    //   - memberRoleIds: role IDs assigned to the member
    //   - guildRoles: all roles in the guild (include @everyone)
    //   - channel: channel with permission_overwrites
    //   - everyoneRoleId: guild ID is used as the @everyone role ID in Discord; pass that value here
    // - Returns: 64-bit bitset of permissions
    public static func effectivePermissions(userId: UserID,
                                            memberRoleIds: [RoleID],
                                            guildRoles: [Role],
                                            channel: Channel,
                                            everyoneRoleId: RoleID) -> UInt64 {
        func perms(_ s: String?) -> UInt64 { UInt64(s ?? "0") ?? 0 }

        // 1) Base = @everyone role perms
        let everyonePerms = perms(guildRoles.first(where: { $0.id == everyoneRoleId })?.permissions)
        var allow: UInt64 = everyonePerms

        // 2) Aggregate member roles (OR)
        let rolePerms = guildRoles.filter { memberRoleIds.contains($0.id) }.reduce(UInt64(0)) { $0 | perms($1.permissions) }
        allow |= rolePerms

        // 3) Apply channel overwrites (order is important)
        let overwrites = channel.permission_overwrites ?? []
        // 3a) @everyone overwrite
        if let everyoneOW = overwrites.first(where: { $0.type == 0 && $0.id.rawValue == everyoneRoleId.rawValue }) {
            let deny = perms(everyoneOW.deny)
            let add = perms(everyoneOW.allow)
            allow = (allow & ~deny) | add
        }
        // 3b) Role overwrites (all roles the member has). Collect denies and allows separately then apply: removes then adds
        let roleOW = overwrites.filter { ow in ow.type == 0 && memberRoleIds.contains(where: { $0.rawValue == ow.id.rawValue }) }
        if !roleOW.isEmpty {
            let deny = roleOW.reduce(UInt64(0)) { $0 | perms($1.deny) }
            let add = roleOW.reduce(UInt64(0)) { $0 | perms($1.allow) }
            allow = (allow & ~deny) | add
        }
        // 3c) Member overwrite
        if let memberOW = overwrites.first(where: { $0.type == 1 && $0.id.rawValue == userId.rawValue }) {
            let deny = perms(memberOW.deny)
            let add = perms(memberOW.allow)
            allow = (allow & ~deny) | add
        }
        return allow
    }

    // New method using cache for effective permissions
    public static func effectivePermissionsWithCache(cache: Cache, userId: UserID, guildId: GuildID, channelId: ChannelID) async -> PermissionBitset? {
        // Fetch guild and channel from cache
        guard let guild = await cache.getGuild(id: guildId),
              let channel = await cache.getChannel(id: channelId) else { return nil }
        
        // Fetch member roles from cache or assume they are provided; for simplicity, assume roles are cached or passed
        // In a real scenario, you'd need to handle member roles, perhaps by fetching from cache or DiscordClient
        let memberRoleIds = [RoleID]() // Placeholder; integrate with member cache if available
        let everyoneRoleId = guild.id // @everyone role ID is the guild ID
        
        // Convert string permissions to PermissionBitset (assuming guild roles have permissions)
        let guildRoles = guild.roles?.compactMap { role in
            PermissionBitset(rawValue: UInt64(role.permissions ?? "0") ?? 0)
        } ?? []
        
        // Compute effective permissions similar to existing logic but with PermissionBitset
        var allow = PermissionBitset(rawValue: 0)
        
        // 1) Base = @everyone role perms (find @everyone role)
        if let everyoneRole = guildRoles.first(where: { $0.id == everyoneRoleId }) {
            allow.insert(everyoneRole.permissionsBitset) // Assume roles have a permissionsBitset property or adapt
        }
        
        // 2) Aggregate member roles (OR operation)
        let rolePerms = memberRoleIds.compactMap { roleId in guildRoles.first { $0.id == roleId }?.permissionsBitset }.reduce(PermissionBitset(), { $0.union($1) })
        allow.formUnion(rolePerms)
        
        // 3) Apply channel overwrites (similar to existing logic)
        let overwrites = channel.permission_overwrites ?? []
        // Apply @everyone overwrite
        if let everyoneOW = overwrites.first(where: { $0.type == 0 && $0.id.rawValue == everyoneRoleId.rawValue }) {
            let deny = PermissionBitset(rawValue: UInt64(everyoneOW.deny ?? "0") ?? 0)
            let add = PermissionBitset(rawValue: UInt64(everyoneOW.allow ?? "0") ?? 0)
            allow.subtract(deny)
            allow.formUnion(add)
        }
        // Apply role overwrites
        let roleOW = overwrites.filter { ow in ow.type == 0 && memberRoleIds.contains(where: { $0.rawValue == ow.id.rawValue }) }
        let roleDeny = roleOW.reduce(PermissionBitset(), { $0.union(PermissionBitset(rawValue: UInt64($1.deny ?? "0") ?? 0)) })
        let roleAdd = roleOW.reduce(PermissionBitset(), { $0.union(PermissionBitset(rawValue: UInt64($1.allow ?? "0") ?? 0)) })
        allow.subtract(roleDeny)
        allow.formUnion(roleAdd)
        // Apply member overwrite
        if let memberOW = overwrites.first(where: { $0.type == 1 && $0.id.rawValue == userId.rawValue }) {
            let deny = PermissionBitset(rawValue: UInt64(memberOW.deny ?? "0") ?? 0)
            let add = PermissionBitset(rawValue: UInt64(memberOW.allow ?? "0") ?? 0)
            allow.subtract(deny)
            allow.formUnion(add)
        }
        
        return allow
    }
}
