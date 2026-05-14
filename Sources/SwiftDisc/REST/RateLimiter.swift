import Foundation

actor RateLimiter {
    typealias RateLimitHandler = @Sendable (RateLimitEvent) -> Void

    struct BucketState: Sendable {
        var resetAt: Date?
        var remaining: Int?
        var limit: Int?
    }

    /// Bucket state keyed by Discord bucket ID (or routeKey before the first response).
    private var bucketStates: [String: BucketState] = [:]
    /// Maps routeKey → Discord bucket ID. Once a bucket ID is known, all requests
    /// for that route share the same `BucketState` entry.
    private var routeKeyToBucket: [String: String] = [:]
    /// Reactive global reset set by Discord 429 responses.
    private var globalResetAt: Date?
    /// Proactive global rate limit: timestamps of the last requests, sliding 1-second window.
    private var globalRequestTimestamps: [Date] = []
    private let onRateLimit: RateLimitHandler?

    init(onRateLimit: RateLimitHandler? = nil) {
        self.onRateLimit = onRateLimit
    }

    func waitTurn(routeKey: String) async throws(DiscordError) {
        // Proactive global rate limit: 50 requests per second sliding window.
        // This prevents unnecessary 429s during cross-route bursts.
        let now = Date()
        globalRequestTimestamps.removeAll { now.timeIntervalSince($0) >= 1.0 }
        if globalRequestTimestamps.count >= 50, let oldest = globalRequestTimestamps.first {
            let delay = 1.0 - now.timeIntervalSince(oldest)
            if delay > 0 {
                try await backoff(after: delay)
            }
        }
        globalRequestTimestamps.append(Date())

        // Respect reactive global rate limit if Discord returned a 429 global.
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

        // Per-route bucket control (resolved to Discord bucket ID if known).
        let bucketKey = routeKeyToBucket[routeKey] ?? routeKey
        if let state = bucketStates[bucketKey], let resetAt = state.resetAt, let remaining = state.remaining, let limit = state.limit {
            if remaining <= 0 {
                let now = Date()
                if resetAt > now {
                    let delay = resetAt.timeIntervalSince(now)
                    onRateLimit?(RateLimitEvent(routeKey: routeKey, isGlobal: false, remaining: remaining, limit: limit, resetAt: resetAt, waitedForSeconds: delay))
                    try await backoff(after: delay)
                }
                // After reset, clear remaining; let next response headers set correct values
                bucketStates[bucketKey]?.remaining = nil
            }
        }
    }

    func updateFromHeaders(routeKey: String, headers: [String: String]) {
        // Convert headers to lowercase dictionary for efficient lookup
        let lowercasedHeaders = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })

        func header(_ key: String) -> String? {
            lowercasedHeaders[key.lowercased()]
        }

        // Determine rate-limit scope. Discord sends `X-RateLimit-Scope` on 429s with
        // one of: `user` (per-bot, per-route), `global` (per-bot, all routes), or
        // `shared` (per-resource limit that does NOT count against the bot's global
        // budget). Shared-scope limits must not promote to the global reset.
        let scope = header("X-RateLimit-Scope")?.lowercased()

        // Global rate limit (only when scope is truly global, not shared).
        if let isGlobal = header("X-RateLimit-Global"),
           isGlobal.lowercased() == "true",
           scope != "shared" {
            if let retry = header("Retry-After"), let secs = Double(retry) {
                globalResetAt = Date().addingTimeInterval(secs)
                onRateLimit?(RateLimitEvent(routeKey: routeKey, isGlobal: true, remaining: nil, limit: nil, resetAt: globalResetAt, waitedForSeconds: secs))
            }
        }

        // Resolve the bucket key using Discord's `X-RateLimit-Bucket` header.
        let bucketKey = resolveBucketKey(routeKey: routeKey, bucketId: header("X-RateLimit-Bucket"))

        var state = bucketStates[bucketKey] ?? BucketState(resetAt: nil, remaining: nil, limit: nil)
        if let remaining = header("X-RateLimit-Remaining"), let rem = Int(remaining) {
            state.remaining = rem
        }
        if let limit = header("X-RateLimit-Limit"), let lim = Int(limit) {
            state.limit = lim
        }
        if let resetAfter = header("X-RateLimit-Reset-After"), let secs = Double(resetAfter) {
            state.resetAt = Date().addingTimeInterval(secs)
        } else if let resetEpoch = header("X-RateLimit-Reset"), let epoch = Double(resetEpoch) {
            // Fallback: absolute unix timestamp (seconds, possibly fractional).
            state.resetAt = Date(timeIntervalSince1970: epoch)
        }
        bucketStates[bucketKey] = state
        onRateLimit?(RateLimitEvent(routeKey: routeKey, isGlobal: false, remaining: state.remaining, limit: state.limit, resetAt: state.resetAt))
    }

    /// Maps a routeKey to its Discord bucket ID. If a bucket ID is provided and
    /// differs from the current mapping, existing state is migrated so concurrent
    /// routes that share a bucket use a single `BucketState` entry.
    private func resolveBucketKey(routeKey: String, bucketId: String?) -> String {
        guard let bucketId = bucketId else {
            return routeKeyToBucket[routeKey] ?? routeKey
        }
        let oldKey = routeKeyToBucket[routeKey] ?? routeKey
        if oldKey != bucketId {
            // Migrate state from the old key (routeKey or prior bucket) to the
            // canonical bucket ID, but only if the bucket doesn't already have
            // state from another route that discovered it first.
            if let oldState = bucketStates[oldKey], bucketStates[bucketId] == nil {
                bucketStates[bucketId] = oldState
            }
            routeKeyToBucket[routeKey] = bucketId
        }
        return bucketId
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
        let bucketKey = routeKeyToBucket[routeKey] ?? routeKey
        return bucketStates[bucketKey]
    }

    func getAllBucketStates() -> [String: BucketState] {
        bucketStates
    }

    func getGlobalResetAt() -> Date? {
        globalResetAt
    }

    // MARK: - Reset/Clear methods
    func clearBucket(routeKey: String) {
        let bucketKey = routeKeyToBucket[routeKey] ?? routeKey
        bucketStates.removeValue(forKey: bucketKey)
    }

    func clearAllBuckets() {
        bucketStates.removeAll()
        routeKeyToBucket.removeAll()
    }

    func resetGlobalRateLimit() {
        globalResetAt = nil
        globalRequestTimestamps.removeAll()
    }

    func resetAll() {
        bucketStates.removeAll()
        routeKeyToBucket.removeAll()
        globalResetAt = nil
        globalRequestTimestamps.removeAll()
    }
}
