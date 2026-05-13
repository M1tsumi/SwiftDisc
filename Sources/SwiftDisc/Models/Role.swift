import Foundation

/// Represents a single stop in a gradient role color.
///
/// Used in gradient role colors to define color transitions.
///
/// - Parameter color: The color value (RGB integer).
/// - Parameter position: The position of the color stop (0.0 to 1.0).
public struct RoleColorStop: Codable, Hashable, Sendable {
    /// The color value as an RGB integer.
    public let color: Int
    
    /// The position of the color stop (0.0 to 1.0).
    public let position: Double?
    
    public init(color: Int, position: Double? = nil) {
        self.color = color
        self.position = position
    }
}

/// Gradient role colors object.
///
/// Present when the guild has the `ENHANCED_ROLE_COLORS` feature.
/// Added 2025-07-02 per Discord API changelog.
///
/// ## Example
///
/// ```swift
/// let colors = RoleColors(
///     primary_color: 0x5865F2,
///     gradient_stops: [
///         RoleColorStop(color: 0x5865F2, position: 0.0),
///         RoleColorStop(color: 0x57F287, position: 1.0)
///     ]
/// )
/// ```
public struct RoleColors: Codable, Hashable, Sendable {
    /// Primary (single) color as an integer, for backwards compatibility.
    public let primary_color: Int?
    
    /// Gradient color stops. When present the role displays a gradient.
    public let gradient_stops: [RoleColorStop]?
    
    public init(primary_color: Int? = nil, gradient_stops: [RoleColorStop]? = nil) {
        self.primary_color = primary_color
        self.gradient_stops = gradient_stops
    }
}

/// Represents a Discord role.
///
/// Roles are used to group users together and grant them permissions.
///
/// ## Example
///
/// ```swift
/// if let roles = client.cache.getRoles(guildId: guildId) {
///     for role in roles {
///         print("Role: \(role.name)")
///         print("ID: \(role.id)")
///         if role.hoist {
///             print("  (displayed separately)")
///         }
///     }
/// }
/// ```
public struct Role: Codable, Hashable, Sendable {
    /// The role ID.
    public let id: RoleID
    
    /// The role name.
    public let name
    
    /// Deprecated in favour of `colors`; still returned for backwards compatibility.
    public let color: Int?
    
    /// Gradient/multi-stop colors. Present when `ENHANCED_ROLE_COLORS` guild feature is enabled.
    /// Added 2025-07-02 per Discord API changelog.
    public let colors: RoleColors?
    
    /// Whether the role is displayed separately in the member list.
    public let hoist: Bool?
    
    /// The position of the role in the role hierarchy.
    public let position: Int?
    
    /// The permission bitset for the role.
    public let permissions: String?
    
    /// Whether the role is managed by an integration or bot.
    public let managed: Bool?
    
    /// Whether the role can be mentioned.
    public let mentionable: Bool?
    
    /// The role icon hash.
    public let icon: String?
    
    /// The role unicode emoji.
    public let unicode_emoji: String?
}
