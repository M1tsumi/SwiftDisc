import Foundation

actor RateLimiter {
    private var lastRequestAt: Date?
    private let minInterval: TimeInterval = 0.1

    func waitTurn() async throws {
        if let last = lastRequestAt {
            let since = Date().timeIntervalSince(last)
            if since < minInterval {
                try await Task.sleep(nanoseconds: UInt64((minInterval - since) * 1_000_000_000))
            }
        }
        lastRequestAt = Date()
    }
}
