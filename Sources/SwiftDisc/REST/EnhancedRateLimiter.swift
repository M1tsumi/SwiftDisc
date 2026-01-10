//
//  EnhancedRateLimiter.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Enhanced rate limiter with advanced features and metrics
public actor EnhancedRateLimiter {
    private var rateLimiter: RateLimiter
    private var metrics: RateLimitMetrics
    private var requestQueue: [RateLimitRequest] = []
    private var isProcessingQueue = false

    /// Rate limit metrics
    public struct RateLimitMetrics {
        public let requestsTotal: Int
        public let requestsThrottled: Int
        public let averageRequestTime: TimeInterval
        public let bucketsActive: Int
        public let globalRateLimitsHit: Int

        public init(
            requestsTotal: Int = 0,
            requestsThrottled: Int = 0,
            averageRequestTime: TimeInterval = 0,
            bucketsActive: Int = 0,
            globalRateLimitsHit: Int = 0
        ) {
            self.requestsTotal = requestsTotal
            self.requestsThrottled = requestsThrottled
            self.averageRequestTime = averageRequestTime
            self.bucketsActive = bucketsActive
            self.globalRateLimitsHit = globalRateLimitsHit
        }
    }

    /// Rate limit request with priority
    private struct RateLimitRequest {
        let routeKey: String
        let priority: RequestPriority
        let continuation: CheckedContinuation<Void, Error>

        enum RequestPriority: Int {
            case low = 0
            case normal = 1
            case high = 2
            case critical = 3
        }
    }

    /// Initialize enhanced rate limiter
    public init() {
        self.rateLimiter = RateLimiter()
        self.metrics = RateLimitMetrics()
    }

    /// Wait for rate limit turn with priority queuing
    /// - Parameters:
    ///   - routeKey: Route key for rate limiting
    ///   - priority: Request priority
    public func waitTurn(routeKey: String, priority: RateLimitRequest.RequestPriority = .normal) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let request = RateLimitRequest(routeKey: routeKey, priority: priority, continuation: continuation)
            requestQueue.append(request)
            requestQueue.sort { $0.priority.rawValue > $1.priority.rawValue } // Higher priority first

            Task {
                await processQueue()
            }
        }
    }

    /// Update rate limit state from headers
    /// - Parameters:
    ///   - routeKey: Route key
    ///   - headers: HTTP headers
    public func updateFromHeaders(routeKey: String, headers: [AnyHashable: Any]) async {
        await rateLimiter.updateFromHeaders(routeKey: routeKey, headers: headers)

        // Update metrics
        let wasThrottled = headers["X-RateLimit-Global"] as? String == "true"
        let newMetrics = RateLimitMetrics(
            requestsTotal: metrics.requestsTotal + 1,
            requestsThrottled: metrics.requestsThrottled + (wasThrottled ? 1 : 0),
            averageRequestTime: metrics.averageRequestTime,
            bucketsActive: metrics.bucketsActive,
            globalRateLimitsHit: metrics.globalRateLimitsHit + (wasThrottled ? 1 : 0)
        )
        metrics = newMetrics
    }

    /// Get current metrics
    /// - Returns: Rate limit metrics
    public func getMetrics() -> RateLimitMetrics {
        metrics
    }

    /// Check if route is currently rate limited
    /// - Parameter routeKey: Route key to check
    /// - Returns: True if rate limited
    public func isRateLimited(routeKey: String) async -> Bool {
        // This would need access to internal bucket state
        // For now, return false as a placeholder
        false
    }

    /// Get estimated wait time for route
    /// - Parameter routeKey: Route key
    /// - Returns: Estimated wait time in seconds
    public func estimatedWaitTime(routeKey: String) async -> TimeInterval {
        // Placeholder - would calculate based on bucket state
        0
    }

    /// Reset metrics
    public func resetMetrics() {
        metrics = RateLimitMetrics()
    }

    private func processQueue() async {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true

        while !requestQueue.isEmpty {
            let request = requestQueue.removeFirst()

            do {
                try await rateLimiter.waitTurn(routeKey: request.routeKey)
                request.continuation.resume()
            } catch {
                request.continuation.resume(throwing: error)
            }
        }

        isProcessingQueue = false
    }
}

/// Request priority levels
public enum RequestPriority {
    case low
    case normal
    case high
    case critical

    var rawValue: Int {
        switch self {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/REST/EnhancedRateLimiter.swift