import Foundation

/// A lightweight diagnostic snapshot for REST rate-limit behavior.
public struct RateLimitEvent: Sendable {
    public let routeKey: String
    public let isGlobal: Bool
    public let remaining: Int?
    public let limit: Int?
    public let resetAt: Date?
    public let waitedForSeconds: TimeInterval?

    public init(routeKey: String, isGlobal: Bool, remaining: Int?, limit: Int?, resetAt: Date?, waitedForSeconds: TimeInterval? = nil) {
        self.routeKey = routeKey
        self.isGlobal = isGlobal
        self.remaining = remaining
        self.limit = limit
        self.resetAt = resetAt
        self.waitedForSeconds = waitedForSeconds
    }
}