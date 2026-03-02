import Foundation

public struct Snowflake<T>: Hashable, Codable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(_ raw: String) { self.rawValue = raw }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

// Snowflake only stores a plain `String`; the phantom type parameter `T` is never
// stored at runtime, so this conformance is sound unconditionally.
extension Snowflake: @unchecked Sendable {}

public typealias UserID = Snowflake<User>
public typealias ChannelID = Snowflake<Channel>
public typealias MessageID = Snowflake<Message>
public typealias GuildID = Snowflake<Guild>
public typealias RoleID = Snowflake<Role>
public typealias EmojiID = Snowflake<Emoji>
public enum Application {}
public typealias ApplicationID = Snowflake<Application>
public enum AttachmentTag {}
public typealias AttachmentID = Snowflake<AttachmentTag>
public enum OverwriteTarget {}
public typealias OverwriteID = Snowflake<OverwriteTarget>
public enum InteractionTag {}
public typealias InteractionID = Snowflake<InteractionTag>
public enum ApplicationCommandTag {}
public typealias ApplicationCommandID = Snowflake<ApplicationCommandTag>

// Additional IDs
public typealias ForumTagID = Snowflake<ForumTag>
public enum GuildScheduledEventTag {}
public typealias GuildScheduledEventID = Snowflake<GuildScheduledEventTag>
public enum StageInstanceTag {}
public typealias StageInstanceID = Snowflake<StageInstanceTag>

public enum WebhookTag {}
public typealias WebhookID = Snowflake<WebhookTag>

public enum StickerTag {}
public typealias StickerID = Snowflake<StickerTag>
public enum StickerPackTag {}
public typealias StickerPackID = Snowflake<StickerPackTag>
public enum SKUTag {}
public typealias SKUID = Snowflake<SKUTag>
public enum BannerAssetTag {}
public typealias BannerAssetID = Snowflake<BannerAssetTag>
public enum SoundboardSoundTag {}
public typealias SoundboardSoundID = Snowflake<SoundboardSoundTag>
public enum EntitlementTag {}
public typealias EntitlementID = Snowflake<EntitlementTag>
public enum AppInstallationTag {}
public typealias AppInstallationID = Snowflake<AppInstallationTag>
public enum AppSubscriptionTag {}
public typealias AppSubscriptionID = Snowflake<AppSubscriptionTag>

public enum AuditLogEntryTag {}
public typealias AuditLogEntryID = Snowflake<AuditLogEntryTag>

public enum AutoModerationRuleTag {}
public typealias AutoModerationRuleID = Snowflake<AutoModerationRuleTag>
