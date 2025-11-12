import Foundation

public struct Snowflake<T>: Hashable, Codable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(_ raw: String) { self.rawValue = raw }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

public typealias UserID = Snowflake<User>
public typealias ChannelID = Snowflake<Channel>
public typealias MessageID = Snowflake<Message>
public typealias GuildID = Snowflake<Guild>
public typealias RoleID = Snowflake<Role>
public typealias EmojiID = Snowflake<Emoji>
public enum Application {}
public typealias ApplicationID = Snowflake<Application>
public enum Attachment {}
public typealias AttachmentID = Snowflake<Attachment>
public enum OverwriteTarget {}
public typealias OverwriteID = Snowflake<OverwriteTarget>
public enum Interaction {}
public typealias InteractionID = Snowflake<Interaction>
public enum ApplicationCommandTag {}
public typealias ApplicationCommandID = Snowflake<ApplicationCommandTag>
