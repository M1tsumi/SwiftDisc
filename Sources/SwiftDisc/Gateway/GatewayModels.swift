import Foundation

public struct GatewayHello: Codable {
    public let heartbeat_interval: Int
}

public enum GatewayOpcode: Int, Codable {
    case dispatch = 0
    case heartbeat = 1
    case identify = 2
    case resume = 6
    case reconnect = 7
    case invalidSession = 9
    case hello = 10
    case heartbeatAck = 11
}

public struct GatewayPayload<D: Codable>: Codable {
    public let op: GatewayOpcode
    public let d: D?
    public let s: Int?
    public let t: String?
}

public enum DiscordEvent: Hashable {
    case ready(ReadyEvent)
    case messageCreate(Message)
    case guildCreate(Guild)
    case channelCreate(Channel)
    case channelUpdate(Channel)
    case channelDelete(Channel)
    case interactionCreate(Interaction)
}

public struct ReadyEvent: Codable, Hashable {
    public let user: User
}

public struct Guild: Codable, Hashable {
    public let id: Snowflake
    public let name: String
}

public struct Interaction: Codable, Hashable {
    public let id: Snowflake
    public let type: Int
    public let guild_id: Snowflake?
    public let channel_id: Snowflake?
}

public struct IdentifyPayload: Codable {
    public let token: String
    public let intents: UInt64
    public let properties: IdentifyConnectionProperties
    public let compress: Bool?
    public let large_threshold: Int?

    public init(token: String, intents: UInt64, properties: IdentifyConnectionProperties = .default, compress: Bool? = nil, large_threshold: Int? = nil) {
        self.token = token
        self.intents = intents
        self.properties = properties
        self.compress = compress
        self.large_threshold = large_threshold
    }
}

public struct IdentifyConnectionProperties: Codable {
    public let os: String
    public let browser: String
    public let device: String

    public static var `default`: IdentifyConnectionProperties {
        #if os(iOS)
        let osName = "iOS"
        #elseif os(macOS)
        let osName = "macOS"
        #elseif os(Windows)
        let osName = "Windows"
        #elseif os(tvOS)
        let osName = "tvOS"
        #elseif os(watchOS)
        let osName = "watchOS"
        #else
        let osName = "SwiftOS"
        #endif
        return IdentifyConnectionProperties(os: osName, browser: "SwiftDisc", device: "SwiftDisc")
    }

    enum CodingKeys: String, CodingKey {
        case os = "$os"
        case browser = "$browser"
        case device = "$device"
    }
}

public struct HeartbeatPayload: Codable {
    public let heartbeat: Int?

    enum CodingKeys: String, CodingKey {
        case heartbeat = "d"
    }
}
