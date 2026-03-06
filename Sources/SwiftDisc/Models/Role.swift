import Foundation

/// Represents a single stop in a gradient role color.
public struct RoleColorStop: Codable, Hashable, Sendable {
    public let color: Int
    public let position: Double?
    public init(color: Int, position: Double? = nil) {
        self.color = color
        self.position = position
    }
}

/// Gradient role colors object. Present when the guild has `ENHANCED_ROLE_COLORS` feature.
/// Added 2025-07-02 per Discord API changelog.
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

public struct Role: Codable, Hashable, Sendable {
    public let id: RoleID
    public let name: String
    /// Deprecated in favour of `colors`; still returned for backwards compatibility.
    public let color: Int?
    /// Gradient/multi-stop colors. Present when `ENHANCED_ROLE_COLORS` guild feature is enabled.
    /// Added 2025-07-02 per Discord API changelog.
    public let colors: RoleColors?
    public let hoist: Bool?
    public let position: Int?
    public let permissions: String?
    public let managed: Bool?
    public let mentionable: Bool?
    public let icon: String?
    public let unicode_emoji: String?
}
