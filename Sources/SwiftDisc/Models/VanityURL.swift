import Foundation

/// A guild's vanity invite URL settings.
public struct VanityURL: Codable, Hashable, Sendable {
    public let code: String?
    public let uses: Int
}
