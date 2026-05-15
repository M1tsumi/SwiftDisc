import Foundation

/// Configuration for transient-failure retry behavior in the REST layer.
///
/// `RetryPolicy` provides a single source of truth for retry attempts and
/// exponential backoff. The HTTP layer applies this policy to network errors
/// and 5xx responses. 429 responses are handled separately by the rate
/// limiter, which honours `Retry-After`.
///
/// ## Example
/// ```swift
/// let policy = RetryPolicy(maxAttempts: 4, baseDelay: 0.5, maxDelay: 4.0)
/// let delay = policy.backoffDelay(forAttempt: 2) // 1.0s
/// ```
public struct RetryPolicy: Sendable, Hashable {
    /// Maximum number of attempts including the initial request. Must be >= 1.
    public let maxAttempts: Int

    /// Base delay in seconds for the first backoff. Subsequent attempts double
    /// this delay until `maxDelay` is reached.
    public let baseDelay: TimeInterval

    /// Hard ceiling on backoff delay in seconds.
    public let maxDelay: TimeInterval

    public init(maxAttempts: Int = 4, baseDelay: TimeInterval = 0.5, maxDelay: TimeInterval = 4.0) {
        precondition(maxAttempts >= 1, "RetryPolicy.maxAttempts must be >= 1")
        precondition(baseDelay >= 0, "RetryPolicy.baseDelay must be >= 0")
        precondition(maxDelay >= baseDelay, "RetryPolicy.maxDelay must be >= baseDelay")
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    /// Exponential backoff delay for the given attempt number (1-indexed).
    /// Attempt 1 returns `baseDelay`, attempt 2 returns `baseDelay * 2`, etc., capped at `maxDelay`.
    public func backoffDelay(forAttempt attempt: Int) -> TimeInterval {
        let n = max(1, attempt)
        let raw = baseDelay * pow(2.0, Double(n - 1))
        return min(raw, maxDelay)
    }

    /// Default policy for general transient failures.
    public static let `default` = RetryPolicy()

    /// Default policy for 5xx server errors (slightly more patient).
    public static let serverError = RetryPolicy(maxAttempts: 4, baseDelay: 2.0, maxDelay: 8.0)
}
