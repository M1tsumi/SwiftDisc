import Foundation

/// All errors thrown by SwiftDisc REST and gateway operations.
/// Declared `Sendable` so errors can be safely passed across actor/task boundaries.
public enum DiscordError: Error, Sendable, Equatable {
    /// A non-2xx HTTP response with status code and raw body.
    case http(Int, String, debugContext: String? = nil)
    /// A 4xx/5xx response whose body decoded to Discord's `{message, code}` error shape.
    case api(message: String, code: Int?, debugContext: String? = nil)
    /// JSON decoding failed for a successful HTTP response.
    case decoding(any Error, debugContext: String? = nil)
    /// JSON encoding failed before sending the request.
    case encoding(any Error, debugContext: String? = nil)
    /// A transport-level error (URLError, socket failure, etc.).
    case network(any Error, debugContext: String? = nil)
    /// A gateway-level protocol error.
    case gateway(String, debugContext: String? = nil)
    /// The task was cancelled before the request completed.
    case cancelled
    /// A value failed a precondition check (e.g. file too large).
    case validation(String, debugContext: String? = nil)
    /// HTTP is not available on this platform build.
    case unavailable
}

extension DiscordError: CustomStringConvertible, LocalizedError {
    public var description: String {
        switch self {
        case .http(let statusCode, let body, let debugContext):
            var desc: String
            if body.isEmpty { desc = "HTTP error \(statusCode)" }
            else { desc = "HTTP error \(statusCode): \(body)" }
            if let ctx = debugContext { desc += " - Context: \(ctx)" }
            return desc
        case .api(let message, let code, let debugContext):
            var desc: String
            if let code { desc = "Discord API error \(code): \(message)" }
            else { desc = "Discord API error: \(message)" }
            if let ctx = debugContext { desc += " - Context: \(ctx)" }
            return desc
        case .decoding(let error, let debugContext):
            var desc = "Decoding failed: \((error as NSError).localizedDescription)"
            if let ctx = debugContext { desc += " - Context: \(ctx)" }
            return desc
        case .encoding(let error, let debugContext):
            var desc = "Encoding failed: \((error as NSError).localizedDescription)"
            if let ctx = debugContext { desc += " - Context: \(ctx)" }
            return desc
        case .network(let error, let debugContext):
            var desc = "Network error: \((error as NSError).localizedDescription)"
            if let ctx = debugContext { desc += " - Context: \(ctx)" }
            return desc
        case .gateway(let message, let debugContext):
            var desc = "Gateway error: \(message)"
            if let ctx = debugContext { desc += " - Context: \(ctx)" }
            return desc
        case .cancelled:
            return "Operation cancelled"
        case .validation(let message, let debugContext):
            var desc = "Validation failed: \(message)"
            if let ctx = debugContext { desc += " - Context: \(ctx)" }
            return desc
        case .unavailable:
            return "HTTP is unavailable on this platform build"
        }
    }

    public var errorDescription: String? {
        description
    }

    public static func == (lhs: DiscordError, rhs: DiscordError) -> Bool {
        switch (lhs, rhs) {
        case (.http(let l1, let l2, let l3), .http(let r1, let r2, let r3)):
            return l1 == r1 && l2 == r2 && l3 == r3
        case (.api(let l1, let l2, let l3), .api(let r1, let r2, let r3)):
            return l1 == r1 && l2 == r2 && l3 == r3
        case (.decoding(let l1, let l2), .decoding(let r1, let r2)):
            return "\(l1)" == "\(r1)" && l2 == r2
        case (.encoding(let l1, let l2), .encoding(let r1, let r2)):
            return "\(l1)" == "\(r1)" && l2 == r2
        case (.network(let l1, let l2), .network(let r1, let r2)):
            return "\(l1)" == "\(r1)" && l2 == r2
        case (.gateway(let l1, let l2), .gateway(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.cancelled, .cancelled):
            return true
        case (.validation(let l1, let l2), .validation(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.unavailable, .unavailable):
            return true
        default:
            return false
        }
    }
}
