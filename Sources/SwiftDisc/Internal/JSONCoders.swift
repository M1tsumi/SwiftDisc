import Foundation

/// Shared, preconfigured `JSONEncoder` and `JSONDecoder` instances used across the
/// Internal, REST, and Gateway layers.
///
/// Reusing a single configured pair avoids the cost of constructing a new coder
/// per request (Foundation coders are non-trivially heavy to instantiate),
/// and gives the library one canonical place to evolve encoding behavior.
///
/// ## Key-strategy note
///
/// SwiftDisc's `Codable` models declare Discord's `snake_case` field names
/// literally (for example `channel_id`, `guild_id`). Therefore these coders do
/// **not** apply `.convertFromSnakeCase` / `.convertToSnakeCase` — doing so
/// would break decoding of the existing models. If models are ever migrated to
/// `camelCase` Swift properties, switch the strategies here once and the entire
/// codebase will follow.
public enum JSONCoders {
    /// Shared encoder. `JSONEncoder` is documented as thread-safe for encoding
    /// independent values once configured.
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        // Discord expects ISO-8601 dates in some payloads, but the wrapper currently
        // hand-formats them when needed. Leave the default strategy for now.
        return e
    }()

    /// Shared decoder. `JSONDecoder` is documented as thread-safe for decoding
    /// independent values once configured.
    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
}
