import Foundation

/// The MFA (multi-factor authentication) level for a guild.
public struct MFALevel: Codable, Hashable, Sendable {
    /// 0 = disabled, 1 = enabled.
    public let level: Int
}
