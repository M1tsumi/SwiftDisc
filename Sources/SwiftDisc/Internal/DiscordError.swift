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

extension DiscordError: CustomStringConvertible, LocalizedError {
    public var description: String {
        switch self {
        case .http(let statusCode, let body):
            if body.isEmpty { return "HTTP error \(statusCode)" }
            return "HTTP error \(statusCode): \(body)"
        case .api(let message, let code):
            if let code { return "Discord API error \(code): \(message)" }
            return "Discord API error: \(message)"
        case .decoding(let error):
            return "Decoding failed: \((error as NSError).localizedDescription)"
        case .encoding(let error):
            return "Encoding failed: \((error as NSError).localizedDescription)"
        case .network(let error):
            return "Network error: \((error as NSError).localizedDescription)"
        case .gateway(let message):
            return "Gateway error: \(message)"
        case .cancelled:
            return "Operation cancelled"
        case .validation(let message):
            return "Validation failed: \(message)"
        case .unavailable:
            return "HTTP is unavailable on this platform build"
        }
    }

    public var errorDescription: String? {
        description
    }
}
