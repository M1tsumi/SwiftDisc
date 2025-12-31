import Foundation

public struct VanityURL: Codable, Hashable {
    public let code: String?
    public let uses: Int
}
