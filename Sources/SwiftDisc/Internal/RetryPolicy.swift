import Foundation

/// Configuration for transient-failure retry behavior in the REST layer.
///
/// `RetryPolicy` provides a single source of truth for retry attempts and
/// exponential backoff with jitter. The HTTP layer applies this policy to network errors
/// and 5xx responses. 429 responses are handled separately by the rate
/// limiter, which honours `Retry-After`.
///
/// ## Example
/// ```swift
/// let policy = RetryPolicy(maxAttempts: 4, baseDelay: 0.5, maxDelay: 4.0)
/// let delay = policy.backoffDelay(forAttempt: 2) // ~1.0s with jitter
/// ```
public struct RetryPolicy: Sendable, Hashable {
    /// Maximum number of attempts including the initial request. Must be >= 1.
    public let maxAttempts: Int

    /// Base delay in seconds for the first backoff. Subsequent attempts double
    /// this delay until `maxDelay` is reached.
    public let baseDelay: TimeInterval

    /// Hard ceiling on backoff delay in seconds.
    public let maxDelay: TimeInterval

    /// Jitter factor (0.0 = no jitter, 0.1 = ±10%, 1.0 = ±100%). Applied as random
    /// uniform scaling to the backoff delay to prevent thundering herd.
    public let jitter: Double

    public init(maxAttempts: Int = 4, baseDelay: TimeInterval = 0.5, maxDelay: TimeInterval = 4.0, jitter: Double = 0.1) {
        precondition(maxAttempts >= 1, "RetryPolicy.maxAttempts must be >= 1")
        precondition(baseDelay >= 0, "RetryPolicy.baseDelay must be >= 0")
        precondition(maxDelay >= baseDelay, "RetryPolicy.maxDelay must be >= baseDelay")
        precondition(jitter >= 0 && jitter <= 1, "RetryPolicy.jitter must be in 0...1")
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitter = jitter
    }

    /// Exponential backoff delay for the given attempt number (1-indexed).
    /// Attempt 1 returns `baseDelay`, attempt 2 returns `baseDelay * 2`, etc., capped at `maxDelay`,
    /// with jitter applied to spread retries across multiple clients.
    public func backoffDelay(forAttempt attempt: Int) -> TimeInterval {
        let n = max(1, attempt)
        let raw = baseDelay * pow(2.0, Double(n - 1))
        let clamped = min(raw, maxDelay)
        let jitterRange = clamped * jitter
        let offset = Double.random(in: -jitterRange...jitterRange)
        return max(0, clamped + offset)
    }

    /// No retry policy (single attempt, no backoff).
    public static let noRetry = RetryPolicy(maxAttempts: 1, jitter: 0)

    /// Default policy for general transient failures.
    public static let `default` = RetryPolicy()

    /// Default policy for 5xx server errors (slightly more patient).
    public static let serverError = RetryPolicy(maxAttempts: 4, baseDelay: 2.0, maxDelay: 8.0)
}
