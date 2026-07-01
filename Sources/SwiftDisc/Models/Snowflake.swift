import Foundation

/// A Discord snowflake ID.
///
/// Snowflakes are unique identifiers used throughout Discord's API.
/// They are represented as strings but can be decoded from integers as well.
/// The phantom type parameter `T` provides type safety for different ID types.
///
/// ## Example
///
/// ```swift
/// let userId: UserID = "123456789012345678"
/// let channelId: ChannelID = "987654321098765432"
/// print("User ID: \(userId)")
/// ```
public struct Snowflake<T>: Hashable, Codable, CustomStringConvertible, ExpressibleByStringLiteral {
    /// The raw string value of the snowflake.
    public let rawValue: String
    
    public init(_ raw: String) { self.rawValue = raw }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let raw = try? container.decode(String.self) {
            self.rawValue = raw
            return
        }

        if let raw = try? container.decode(UInt64.self) {
            self.rawValue = String(raw)
            return
        }

        if let raw = try? container.decode(Int64.self), raw >= 0 {
            self.rawValue = String(raw)
            return
        }

        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Expected snowflake to be a string or integer"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// Snowflake only stores a plain `String`; the phantom type parameter `T` is never
// stored at runtime, so this conformance is sound unconditionally.
extension Snowflake: @unchecked Sendable {}

/// A user ID.
public typealias UserID = Snowflake<User>

/// A channel ID.
public typealias ChannelID = Snowflake<Channel>

/// A message ID.
public typealias MessageID = Snowflake<Message>

/// A guild ID.
public typealias GuildID = Snowflake<Guild>

/// A role ID.
public typealias RoleID = Snowflake<Role>

/// An emoji ID.
public typealias EmojiID = Snowflake<Emoji>

/// An application ID.
public enum ApplicationTag {}
public typealias ApplicationID = Snowflake<ApplicationTag>

/// An attachment ID.
public enum AttachmentTag {}
public typealias AttachmentID = Snowflake<AttachmentTag>

/// A permission overwrite target ID.
public enum OverwriteTarget {}
public typealias OverwriteID = Snowflake<OverwriteTarget>

/// An interaction ID.
public enum InteractionTag {}
public typealias InteractionID = Snowflake<InteractionTag>

/// An application command ID.
public enum ApplicationCommandTag {}
public typealias ApplicationCommandID = Snowflake<ApplicationCommandTag>

// Additional IDs

/// A forum tag ID.
public typealias ForumTagID = Snowflake<ForumTag>

/// A guild scheduled event ID.
public enum GuildScheduledEventTag {}
public typealias GuildScheduledEventID = Snowflake<GuildScheduledEventTag>

/// A stage instance ID.
public enum StageInstanceTag {}
public typealias StageInstanceID = Snowflake<StageInstanceTag>

/// A webhook ID.
public enum WebhookTag {}
public typealias WebhookID = Snowflake<WebhookTag>

/// A sticker ID.
public enum StickerTag {}
public typealias StickerID = Snowflake<StickerTag>

/// A sticker pack ID.
public enum StickerPackTag {}
public typealias StickerPackID = Snowflake<StickerPackTag>

/// A SKU (stock keeping unit) ID.
public enum SKUTag {}
public typealias SKUID = Snowflake<SKUTag>

/// A banner asset ID.
public enum BannerAssetTag {}
public typealias BannerAssetID = Snowflake<BannerAssetTag>

/// A soundboard sound ID.
public enum SoundboardSoundTag {}
public typealias SoundboardSoundID = Snowflake<SoundboardSoundTag>

/// An entitlement ID.
public enum EntitlementTag {}
public typealias EntitlementID = Snowflake<EntitlementTag>

/// An app installation ID.
public enum AppInstallationTag {}
public typealias AppInstallationID = Snowflake<AppInstallationTag>

/// An app subscription ID.
public enum AppSubscriptionTag {}
public typealias AppSubscriptionID = Snowflake<AppSubscriptionTag>

/// An audit log entry ID.
public enum AuditLogEntryTag {}
public typealias AuditLogEntryID = Snowflake<AuditLogEntryTag>

/// An auto moderation rule ID.
public enum AutoModerationRuleTag {}
public typealias AutoModerationRuleID = Snowflake<AutoModerationRuleTag>

/// A team ID.
public enum TeamTag {}
public typealias TeamID = Snowflake<TeamTag>
