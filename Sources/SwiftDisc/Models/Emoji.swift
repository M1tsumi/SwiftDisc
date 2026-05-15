import Foundation

/// Represents a Discord emoji.
///
/// Emojis can be custom (created in a guild) or Unicode. Custom emojis
/// have an ID and may be restricted to specific roles.
///
/// ## Example
///
/// ```swift
/// if let emojis = client.cache.getEmojis(guildId: guildId) {
///     for emoji in emojis {
///         if let id = emoji.id {
///             print("Custom emoji: \(emoji.name ?? "unknown") (ID: \(id))")
///         } else {
///             print("Unicode emoji: \(emoji.name ?? "unknown")")
///         }
///     }
/// }
/// ```
public struct Emoji: Codable, Hashable, Sendable {
    /// The emoji ID (nil for Unicode emojis).
    public let id: EmojiID?
    
    /// The emoji name.
    public let name: String?
    
    /// Roles that can use this emoji.
    public let roles: [RoleID]?
    
    /// The user who created this emoji (for custom emojis).
    public let user: User?
    
    /// Whether the emoji must be wrapped in colons.
    public let require_colons: Bool?
    
    /// Whether the emoji is managed.
    public let managed: Bool?
    
    /// Whether the emoji is animated.
    public let animated: Bool?
    
    /// Whether the emoji is available.
    public let available: Bool?
}
