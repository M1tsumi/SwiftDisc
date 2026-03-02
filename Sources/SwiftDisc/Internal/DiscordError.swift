import Foundation

/// All errors thrown by SwiftDisc REST and gateway operations.
/// Declared `Sendable` so errors can be safely passed across actor/task boundaries.
public enum DiscordError: Error, Sendable {
    /// A non-2xx HTTP response with status code and raw body.
    case http(Int, String)
    /// A 4xx/5xx response whose body decoded to Discord's `{message, code}` error shape.
    case api(message: String, code: Int?)
    /// JSON decoding failed for a successful HTTP response.
    case decoding(any Error)
    /// JSON encoding failed before sending the request.
    case encoding(any Error)
    /// A transport-level error (URLError, socket failure, etc.).
    case network(any Error)
    /// A gateway-level protocol error.
    case gateway(String)
    /// The task was cancelled before the request completed.
    case cancelled
    /// A value failed a precondition check (e.g. file too large).
    case validation(String)
    /// HTTP is not available on this platform build.
    case unavailable
}
