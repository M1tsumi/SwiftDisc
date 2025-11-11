import Foundation

public struct Interaction: Codable, Hashable {
    public let id: Snowflake
    public let application_id: Snowflake
    public let type: Int
    public let token: String
    public let channel_id: Snowflake?
}
