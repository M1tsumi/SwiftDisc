import Foundation

actor RateLimiter {
    struct BucketState {
        var resetAt: Date?
        var remaining: Int?
        var limit: Int?
    }

    private var buckets: [String: BucketState] = [:]
    private var globalResetAt: Date?

    func waitTurn(routeKey: String) async throws {
        // Respect global rate limit if active
        if let greset = globalResetAt {
            let now = Date()
            if greset > now {
                let delay = greset.timeIntervalSince(now)
                try await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
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
                    try await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
                }
                // After reset, clear remaining so next request can proceed
                buckets[routeKey]?.remaining = limit
            }
        }
    }

    func updateFromHeaders(routeKey: String, headers: [AnyHashable: Any]) {
        func header(_ key: String) -> String? {
            for (k, v) in headers {
                if String(describing: k).lowercased() == key.lowercased() {
                    return String(describing: v)
                }
            }
            return nil
        }

        // Global rate limit
        if let isGlobal = header("X-RateLimit-Global"), isGlobal.lowercased() == "true" {
            if let retry = header("Retry-After"), let secs = Double(retry) {
                globalResetAt = Date().addingTimeInterval(secs)
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
    }

    func backoff(after seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }
}
