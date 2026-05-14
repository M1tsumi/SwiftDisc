import Foundation

/// Errors thrown by SwiftDisc REST and gateway operations.
///
/// This enum represents all possible errors that can occur when interacting with
/// the Discord API through SwiftDisc.
///
/// Declared `Sendable` so errors can be safely passed across actor/task boundaries.
///
/// ## Example
///
/// ```swift
/// do {
///     try await client.sendMessage(channelId: channelId, content: "Hello")
/// } catch let error as DiscordError {
///     switch error {
///     case .http(let code, let body, _):
///         print("HTTP error \(code): \(body)")
///     case .api(let message, let code, _):
///         print("API error \(code ?? 0): \(message)")
///     case .network(let error, _):
///         print("Network error: \(error)")
///     default:
///         print("Error: \(error)")
///     }
/// }
/// ```
public enum DiscordError: Error, Sendable {
    /// A non-2xx HTTP response with status code and raw body.
    ///
    /// - `Int`: The HTTP status code.
    /// - `String`: The response body.
    /// - `debugContext`: Optional debug context for troubleshooting.
    case http(Int, String, debugContext: String? = nil)
    
    /// A 4xx/5xx response whose body decoded to Discord's `{message, code}` error shape.
    ///
    /// Use ``apiValidation(message:code:errors:debugContext:)`` instead when
    /// the response body contains a structured `errors` tree (typical for
    /// `Invalid Form Body` responses).
    ///
    /// - `message`: The error message from Discord.
    /// - `code`: The Discord error code (if available).
    /// - `debugContext`: Optional debug context for troubleshooting.
    case api(message: String, code: Int?, debugContext: String? = nil)

    /// A 4xx response whose body contained Discord's nested `errors` validation
    /// tree (HTTP 400 with `Invalid Form Body`, `Invalid OAuth2 redirect`, etc.).
    ///
    /// The `errors` array is a flat list of leaf validation failures, each
    /// with a dotted path (for example `embeds.0.fields.1.name`) so callers
    /// can pinpoint the offending field without traversing the nested JSON.
    ///
    /// - `message`: The top-level error message, e.g. `"Invalid Form Body"`.
    /// - `code`: The Discord error code (e.g. `50035`).
    /// - `errors`: Flattened list of per-field validation failures.
    /// - `debugContext`: Optional debug context for troubleshooting.
    case apiValidation(message: String, code: Int?, errors: [DiscordAPIErrorBody.ValidationError], debugContext: String? = nil)
    
    /// JSON decoding failed for a successful HTTP response.
    ///
    /// - `any Error`: The underlying decoding error.
    /// - `debugContext`: Optional debug context for troubleshooting.
    case decoding(any Error, debugContext: String? = nil)
    
    /// JSON encoding failed before sending the request.
    ///
    /// - `any Error`: The underlying encoding error.
    /// - `debugContext`: Optional debug context for troubleshooting.
    case encoding(any Error, debugContext: String? = nil)
    
    /// A transport-level error (URLError, socket failure, etc.).
    ///
    /// - `any Error`: The underlying network error.
    /// - `debugContext`: Optional debug context for troubleshooting.
    case network(any Error, debugContext: String? = nil)
    
    /// A gateway-level protocol error.
    ///
    /// - `String`: The error message.
    /// - `debugContext`: Optional debug context for troubleshooting.
    case gateway(String, debugContext: String? = nil)

    /// The bot token was rejected by Discord (close code 4004).
    ///
    /// This occurs when the token is missing, malformed, or does not belong to a valid bot.
    /// Verify your token in the Discord Developer Portal.
    case authenticationFailed

    /// The task was cancelled before the request completed.
    case cancelled
    
    /// A value failed a precondition check (e.g. file too large).
    ///
    /// - `String`: The validation error message.
    /// - `debugContext`: Optional debug context for troubleshooting.
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
        case .apiValidation(let message, let code, let errors, let debugContext):
            var desc: String
            if let code { desc = "Discord API validation error \(code): \(message)" }
            else { desc = "Discord API validation error: \(message)" }
            if !errors.isEmpty {
                let lines = errors.map { "  - \($0.path) [\($0.code)]: \($0.message)" }
                desc += "\n" + lines.joined(separator: "\n")
            }
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
        case .authenticationFailed:
            return "Authentication failed: invalid or missing bot token (close code 4004)"
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
}

// MARK: - Convenience accessors

public extension DiscordError {
    /// The HTTP status code for ``http(_:_:debugContext:)`` errors, otherwise `nil`.
    var httpStatusCode: Int? {
        if case .http(let code, _, _) = self { return code }
        return nil
    }

    /// The Discord API error code for ``api(message:code:debugContext:)`` and
    /// ``apiValidation(message:code:errors:debugContext:)`` errors, otherwise
    /// `nil`. See <https://discord.com/developers/docs/topics/opcodes-and-status-codes#json>
    /// for the full list.
    var apiErrorCode: Int? {
        switch self {
        case .api(_, let code, _): return code
        case .apiValidation(_, let code, _, _): return code
        default: return nil
        }
    }

    /// Flattened list of per-field validation failures parsed from Discord's
    /// `errors` tree, or `[]` for non-validation errors.
    var validationErrors: [DiscordAPIErrorBody.ValidationError] {
        if case .apiValidation(_, _, let errors, _) = self { return errors }
        return []
    }

    /// `true` for rate-limit responses (HTTP 429).
    var isRateLimited: Bool {
        httpStatusCode == 429
    }

    /// `true` for authentication failures (HTTP 401, gateway close 4004,
    /// Discord error code 0).
    var isAuthenticationFailure: Bool {
        if case .authenticationFailed = self { return true }
        if httpStatusCode == 401 { return true }
        return false
    }

    /// `true` for the operation-cancelled case.
    var isCancelled: Bool {
        if case .cancelled = self { return true }
        return false
    }

    /// `true` for errors that are typically worth retrying after a delay
    /// (network blips, 5xx server errors, rate limits, gateway disconnects). Excludes deterministic
    /// failures like 4xx client errors and validation failures.
    var isTransient: Bool {
        if case .network = self { return true }
        if case .gateway = self { return true }
        if case .cancelled = self { return false }
        if let code = httpStatusCode {
            return code == 429 || (500..<600).contains(code)
        }
        return false
    }
}
