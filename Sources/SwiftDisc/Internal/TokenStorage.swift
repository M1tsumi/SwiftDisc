import Foundation

/// A wrapper around a bot token that prevents accidental leakage in logs and errors.
///
/// `RedactedToken` stores the raw token but its `description`, `debugDescription`,
/// and `CustomStringConvertible` conformances return a redacted placeholder.
/// The raw value is only exposed via `rawValue` (intended for the single
/// `Authorization` header construction site) and via `authorizationHeaderValue`,
/// which applies the required `Bot ` prefix exactly once.
///
/// ## Example
/// ```swift
/// let token = RedactedToken("abc.def.ghi")
/// print(token)                          // "RedactedToken(***)"
/// request.setValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
/// ```
public struct RedactedToken: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The raw token string. Avoid logging this directly.
    public let rawValue: String

    /// Creates a new redacted token wrapper.
    /// - Parameter rawValue: The raw bot token (no `Bot ` prefix).
    public init(_ rawValue: String) {
        // Defensively strip a leading "Bot " prefix if a caller accidentally
        // passes a prefixed token, so the prefix is never applied twice.
        if rawValue.hasPrefix("Bot ") {
            self.rawValue = String(rawValue.dropFirst("Bot ".count))
        } else {
            self.rawValue = rawValue
        }
    }

    /// The full value to assign to the `Authorization` header.
    public var authorizationHeaderValue: String { "Bot \(rawValue)" }

    public var description: String { "RedactedToken(***)" }
    public var debugDescription: String { "RedactedToken(***)" }
}
