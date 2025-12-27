import Foundation

public struct PermissionBitset: OptionSet, Codable, Hashable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    
    // Common Discord permission flags (based on API documentation)
    public static let createInstantInvite = PermissionBitset(rawValue: 1 << 0)
    public static let kickMembers = PermissionBitset(rawValue: 1 << 1)
    public static let banMembers = PermissionBitset(rawValue: 1 << 2)
    public static let administrator = PermissionBitset(rawValue: 1 << 3)
    public static let manageChannels = PermissionBitset(rawValue: 1 << 4)
    public static let manageGuild = PermissionBitset(rawValue: 1 << 5)
    public static let addReactions = PermissionBitset(rawValue: 1 << 6)
    public static let viewAuditLog = PermissionBitset(rawValue: 1 << 7)
    public static let prioritySpeaker = PermissionBitset(rawValue: 1 << 8)
    public static let stream = PermissionBitset(rawValue: 1 << 9)
    public static let viewChannel = PermissionBitset(rawValue: 1 << 10)
    public static let sendMessages = PermissionBitset(rawValue: 1 << 11)
    public static let sendTTSMessages = PermissionBitset(rawValue: 1 << 12)
    public static let manageMessages = PermissionBitset(rawValue: 1 << 13)
    public static let embedLinks = PermissionBitset(rawValue: 1 << 14)
    public static let attachFiles = PermissionBitset(rawValue: 1 << 15)
    public static let readMessageHistory = PermissionBitset(rawValue: 1 << 16)
    public static let mentionEveryone = PermissionBitset(rawValue: 1 << 17)
    public static let useExternalEmojis = PermissionBitset(rawValue: 1 << 18)
    public static let viewGuildInsights = PermissionBitset(rawValue: 1 << 19)
    public static let connect = PermissionBitset(rawValue: 1 << 20)
    public static let speak = PermissionBitset(rawValue: 1 << 21)
    public static let muteMembers = PermissionBitset(rawValue: 1 << 22)
    public static let deafenMembers = PermissionBitset(rawValue: 1 << 23)
    public static let moveMembers = PermissionBitset(rawValue: 1 << 24)
    public static let useVAD = PermissionBitset(rawValue: 1 << 25)
    public static let changeNickname = PermissionBitset(rawValue: 1 << 26)
    public static let manageNicknames = PermissionBitset(rawValue: 1 << 27)
    public static let manageRoles = PermissionBitset(rawValue: 1 << 28)
    public static let manageWebhooks = PermissionBitset(rawValue: 1 << 29)
    public static let manageEmojisAndStickers = PermissionBitset(rawValue: 1 << 30)
    public static let useApplicationCommands = PermissionBitset(rawValue: 1 << 31)
    public static let requestToSpeak = PermissionBitset(rawValue: 1 << 32)
    public static let manageEvents = PermissionBitset(rawValue: 1 << 33)
    public static let manageThreads = PermissionBitset(rawValue: 1 << 34)
    public static let createPublicThreads = PermissionBitset(rawValue: 1 << 35)
    public static let createPrivateThreads = PermissionBitset(rawValue: 1 << 36)
    public static let useExternalStickers = PermissionBitset(rawValue: 1 << 37)
    public static let sendMessagesInThreads = PermissionBitset(rawValue: 1 << 38)
    public static let useEmbeddedActivities = PermissionBitset(rawValue: 1 << 39)
    public static let moderateMembers = PermissionBitset(rawValue: 1 << 40)
    // New permission flags added to match Discord platform changes (2024-2025)
    public static let createGuildExpressions = PermissionBitset(rawValue: 1 << 43)
    public static let createEvents = PermissionBitset(rawValue: 1 << 44)
    public static let useExternalApps = PermissionBitset(rawValue: 1 << 50)
    public static let pinMessages = PermissionBitset(rawValue: 1 << 51)
    public static let bypassSlowmode = PermissionBitset(rawValue: 1 << 52)
    
    // Codable conformance for serialization
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(UInt64.self)
        self.rawValue = rawValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
