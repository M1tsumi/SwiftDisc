import Foundation

actor RateLimiter {
    typealias RateLimitHandler = @Sendable (RateLimitEvent) -> Void

    struct BucketState {
        var resetAt: Date?
        var remaining: Int?
        var limit: Int?
    }

    private var buckets: [String: BucketState] = [:]
    private var globalResetAt: Date?
    private let onRateLimit: RateLimitHandler?

    init(onRateLimit: RateLimitHandler? = nil) {
        self.onRateLimit = onRateLimit
    }

    func waitTurn(routeKey: String) async throws(DiscordError) {
        // Respect global rate limit if active
        if let greset = globalResetAt {
            let now = Date()
            if greset > now {
                let delay = greset.timeIntervalSince(now)
                onRateLimit?(RateLimitEvent(routeKey: routeKey, isGlobal: true, remaining: nil, limit: nil, resetAt: greset, waitedForSeconds: delay))
                try await backoff(after: delay)
            } else {
                globalResetAt = nil
            }
        }

        // Per-route bucket control
        if let state = buckets[routeKey], let resetAt = state.resetAt, let remaining = state.remaining, let limit = state.limit {
            if remaining <= 0 {
                let now = Date()
                if resetAt > now {
                    let delay = resetAt.timeIntervalSince(now)
                    onRateLimit?(RateLimitEvent(routeKey: routeKey, isGlobal: false, remaining: remaining, limit: limit, resetAt: resetAt, waitedForSeconds: delay))
                    try await backoff(after: delay)
                }
                // After reset, clear remaining; let next response headers set correct values
                buckets[routeKey]?.remaining = nil
            }
        }
    }

    func updateFromHeaders(routeKey: String, headers: [AnyHashable: Any]) {
        // Convert headers to lowercase dictionary for efficient lookup
        let lowercasedHeaders = Dictionary(uniqueKeysWithValues: headers.map { (String(describing: $0.key).lowercased(), $0.value) })
        
        func header(_ key: String) -> String? {
            lowercasedHeaders[key.lowercased()].map { String(describing: $0) }
        }

        // Global rate limit
        if let isGlobal = header("X-RateLimit-Global"), isGlobal.lowercased() == "true" {
            if let retry = header("Retry-After"), let secs = Double(retry) {
                globalResetAt = Date().addingTimeInterval(secs)
                onRateLimit?(RateLimitEvent(routeKey: routeKey, isGlobal: true, remaining: nil, limit: nil, resetAt: globalResetAt, waitedForSeconds: secs))
            }
        }

        var state = buckets[routeKey] ?? BucketState(resetAt: nil, remaining: nil, limit: nil)
        if let remaining = header("X-RateLimit-Remaining"), let rem = Int(remaining) {
            state.remaining = rem
        }
        if let limit = header("X-RateLimit-Limit"), let lim = Int(limit) {
            state.limit = lim
        }
        if let resetAfter = header("X-RateLimit-Reset-After"), let secs = Double(resetAfter) {
            state.resetAt = Date().addingTimeInterval(secs)
        }
        buckets[routeKey] = state
        onRateLimit?(RateLimitEvent(routeKey: routeKey, isGlobal: false, remaining: state.remaining, limit: state.limit, resetAt: state.resetAt))
    }

    func backoff(after seconds: TimeInterval) async throws(DiscordError) {
        do {
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        } catch {
            throw DiscordError.cancelled
        }
    }

    // MARK: - State monitoring
    func getBucketState(routeKey: String) -> BucketState? {
        buckets[routeKey]
    }

    func getAllBucketStates() -> [String: BucketState] {
        buckets
    }

    func getGlobalResetAt() -> Date? {
        globalResetAt
    }

    // MARK: - Reset/Clear methods
    func clearBucket(routeKey: String) {
        buckets.removeValue(forKey: routeKey)
    }

    func clearAllBuckets() {
        buckets.removeAll()
    }

    func resetGlobalRateLimit() {
        globalResetAt = nil
    }

    func resetAll() {
        buckets.removeAll()
        globalResetAt = nil
    }
}
