import Foundation

public struct VanityURL: Codable, Hashable, Sendable {
    public let code: String?
    public let uses: Int
}
