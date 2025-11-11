import Foundation

public struct Channel: Codable, Hashable {
    public let id: Snowflake
    public let type: Int
    public let name: String?
}
