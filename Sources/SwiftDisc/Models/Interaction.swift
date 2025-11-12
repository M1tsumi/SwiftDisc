import Foundation

public struct Interaction: Codable, Hashable {
    public let id: InteractionID
    public let application_id: ApplicationID
    public let type: Int
    public let token: String
    public let channel_id: ChannelID?
    public let guild_id: GuildID?

    public struct ApplicationCommandData: Codable, Hashable {
        public struct Option: Codable, Hashable {
            public let name: String
            public let type: Int?
            public let value: String?
            public let options: [Option]?
        }
        public let id: Snowflake<Interaction>?
        public let name: String
        public let type: Int?
        public let options: [Option]?
    }
    public let data: ApplicationCommandData?
}
