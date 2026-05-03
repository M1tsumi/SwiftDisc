import Foundation

public enum PermissionsUtil {
    // MARK: - Permission Flag Constants
    
    /// Create instant invite
    public static let createInstantInvite: UInt64 = 1 << 0
    /// Kick members
    public static let kickMembers: UInt64 = 1 << 1
    /// Ban members
    public static let banMembers: UInt64 = 1 << 2
    /// Administrator (all permissions and bypasses channel overwrites)
    public static let administrator: UInt64 = 1 << 3
    /// Manage channels
    public static let manageChannels: UInt64 = 1 << 4
    /// Manage guild
    public static let manageGuild: UInt64 = 1 << 5
    /// Add reactions
    public static let addReactions: UInt64 = 1 << 6
    /// View audit log
    public static let viewAuditLog: UInt64 = 1 << 7
    /// Priority speaker
    public static let prioritySpeaker: UInt64 = 1 << 8
    /// Stream
    public static let stream: UInt64 = 1 << 9
    /// Read messages
    public static let readMessages: UInt64 = 1 << 10
    /// Send messages
    public static let sendMessage: UInt64 = 1 << 11
    /// Send TTS messages
    public static let sendTtsMessages: UInt64 = 1 << 12
    /// Manage messages
    public static let manageMessages: UInt64 = 1 << 13
    /// Embed links
    public static let embedLinks: UInt64 = 1 << 14
    /// Attach files
    public static let attachFiles: UInt64 = 1 << 15
    /// Read message history
    public static let readMessageHistory: UInt64 = 1 << 16
    /// Mention everyone
    public static let mentionEveryone: UInt64 = 1 << 17
    /// Use external emojis
    public static let useExternalEmojis: UInt64 = 1 << 18
    /// View guild insights
    public static let viewGuildInsights: UInt64 = 1 << 19
    /// Connect to voice
    public static let connect: UInt64 = 1 << 20
    /// Speak in voice
    public static let speak: UInt64 = 1 << 21
    /// Mute members
    public static let muteMembers: UInt64 = 1 << 22
    /// Deafen members
    public static let deafenMembers: UInt64 = 1 << 23
    /// Move members
    public static let moveMembers: UInt64 = 1 << 24
    /// Use voice activity
    public static let useVoiceActivation: UInt64 = 1 << 25
    /// Change nickname
    public static let changeNickname: UInt64 = 1 << 26
    /// Manage nicknames
    public static let manageNicknames: UInt64 = 1 << 27
    /// Manage roles
    public static let manageRoles: UInt64 = 1 << 28
    /// Manage webhooks
    public static let manageWebhooks: UInt64 = 1 << 29
    /// Manage emojis and stickers
    public static let manageEmojisAndStickers: UInt64 = 1 << 30
    /// Use application commands
    public static let useApplicationCommands: UInt64 = 1 << 31
    /// Request to speak in stage channels
    public static let requestToSpeak: UInt64 = 1 << 32
    /// Manage events
    public static let manageEvents: UInt64 = 1 << 33
    /// Manage threads
    public static let manageThreads: UInt64 = 1 << 34
    /// Create public threads
    public static let createPublicThreads: UInt64 = 1 << 35
    /// Create private threads
    public static let createPrivateThreads: UInt64 = 1 << 36
    /// Use external stickers
    public static let useExternalStickers: UInt64 = 1 << 37
    /// Send messages in threads
    public static let sendMessagesInThreads: UInt64 = 1 << 38
    /// Use embedded activities
    public static let useEmbeddedActivities: UInt64 = 1 << 39
    /// Moderate members
    public static let moderateMembers: UInt64 = 1 << 40
    /// View creator monetization analytics
    public static let viewCreatorMonetizationAnalytics: UInt64 = 1 << 41
    /// Use soundboard
    public static let useSoundboard: UInt64 = 1 << 42
    /// Create expressions
    public static let createExpressions: UInt64 = 1 << 43
    /// Create events
    public static let createEvents: UInt64 = 1 << 44
    /// Use external sounds
    public static let useExternalSounds: UInt64 = 1 << 45
    /// Send voice messages
    public static let sendVoiceMessages: UInt64 = 1 << 46
    
    /// All permissions combined (useful for checking if someone has all permissions)
    public static let all: UInt64 = (1 << 47) - 1
    
    // MARK: - Permission Helpers
    
    /// Check if a permission bitset contains a specific permission
    public static func hasPermission(_ permissions: UInt64, _ permission: UInt64) -> Bool {
        return (permissions & permission) != 0
    }
    
    /// Check if a permission bitset contains all the specified permissions
    public static func hasAllPermissions(_ permissions: UInt64, _ requiredPermissions: UInt64) -> Bool {
        return (permissions & requiredPermissions) == requiredPermissions
    }
    
    /// Check if a permission bitset contains any of the specified permissions
    public static func hasAnyPermission(_ permissions: UInt64, _ requiredPermissions: UInt64) -> Bool {
        return (permissions & requiredPermissions) != 0
    }
    
    /// Check if the user has administrator permission (bypasses all channel overwrites)
    public static func isAdministrator(_ permissions: UInt64) -> Bool {
        return hasPermission(permissions, administrator)
    }
    
    /// Check if the user can manage messages (delete, pin, etc.)
    public static func canManageMessages(_ permissions: UInt64) -> Bool {
        return isAdministrator(permissions) || hasPermission(permissions, manageMessages)
    }
    
    /// Check if the user can moderate members (timeout, ban, kick)
    public static func canModerateMembers(_ permissions: UInt64) -> Bool {
        return isAdministrator(permissions) || 
               hasPermission(permissions, moderateMembers) ||
               hasPermission(permissions, kickMembers) ||
               hasPermission(permissions, banMembers)
    }
    
    // MARK: - Effective Permissions Calculation
    
    /// Compute effective permissions for a user in a channel following Discord rules.
    /// - Parameters:
    ///   - userId: target user id
    ///   - memberRoleIds: role IDs assigned to the member
    ///   - guildRoles: all roles in the guild (include @everyone)
    ///   - channel: channel with permission_overwrites
    ///   - everyoneRoleId: guild ID is used as the @everyone role ID in Discord; pass that value here
    /// - Returns: 64-bit bitset of permissions
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
}
