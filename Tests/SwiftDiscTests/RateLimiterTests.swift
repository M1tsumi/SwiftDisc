import XCTest
@testable import SwiftDisc

final class RateLimiterTests: XCTestCase {
    func testWaitTurnAllowsRequestsUnderLimit() async throws {
        let limiter = RateLimiter()
        for _ in 0..<50 {
            try await limiter.waitTurn(routeKey: "test/route")
        }
        let state = await limiter.getBucketState(routeKey: "test/route")
        XCTAssertNil(state)
    }

    func testWaitTurnBlocksWhenOverLimit() async throws {
        let limiter = RateLimiter()
        for _ in 0..<50 {
            try await limiter.waitTurn(routeKey: "test/route")
        }
        let start = Date()
        try await limiter.waitTurn(routeKey: "test/route")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(elapsed, 0.5)
    }

    func testUpdateFromHeadersTracksRemainingAndLimit() async throws {
        let limiter = RateLimiter()
        await limiter.updateFromHeaders(routeKey: "channels/123", headers: [
            "X-RateLimit-Remaining": "9",
            "X-RateLimit-Limit": "10",
            "X-RateLimit-Reset-After": "1.0"
        ])
        let state = await limiter.getBucketState(routeKey: "channels/123")
        XCTAssertEqual(state?.remaining, 9)
        XCTAssertEqual(state?.limit, 10)
    }

    func testUpdateFromHeadersTracksReset() async throws {
        let limiter = RateLimiter()
        await limiter.updateFromHeaders(routeKey: "test/route", headers: [
            "X-RateLimit-Remaining": "0",
            "X-RateLimit-Reset-After": "0.5"
        ])
        let state = await limiter.getBucketState(routeKey: "test/route")
        XCTAssertEqual(state?.remaining, 0)
        let resetAt = try XCTUnwrap(state?.resetAt)
        XCTAssertLessThan(resetAt.timeIntervalSinceNow, 0.6)
        XCTAssertGreaterThan(resetAt.timeIntervalSinceNow, 0)
    }

    func testBucketKeyResolution() async throws {
        let limiter = RateLimiter()
        await limiter.updateFromHeaders(routeKey: "channels/123", headers: [
            "X-RateLimit-Bucket": "abc123",
            "X-RateLimit-Remaining": "4",
            "X-RateLimit-Reset-After": "1.0"
        ])
        let state = await limiter.getBucketState(routeKey: "channels/123")
        XCTAssertEqual(state?.remaining, 4)
        let allStates = await limiter.getAllBucketStates()
        XCTAssertNotNil(allStates["abc123"])
    }

    func testClearBucket() async throws {
        let limiter = RateLimiter()
        await limiter.updateFromHeaders(routeKey: "test/route", headers: [
            "X-RateLimit-Remaining": "5",
            "X-RateLimit-Reset-After": "2.0"
        ])
        var state = await limiter.getBucketState(routeKey: "test/route")
        XCTAssertNotNil(state)
        await limiter.clearBucket(routeKey: "test/route")
        state = await limiter.getBucketState(routeKey: "test/route")
        XCTAssertNil(state)
    }

    func testClearAllBuckets() async throws {
        let limiter = RateLimiter()
        await limiter.updateFromHeaders(routeKey: "route/a", headers: [
            "X-RateLimit-Remaining": "1",
            "X-RateLimit-Reset-After": "1.0"
        ])
        await limiter.updateFromHeaders(routeKey: "route/b", headers: [
            "X-RateLimit-Remaining": "2",
            "X-RateLimit-Reset-After": "2.0"
        ])
        var allStates = await limiter.getAllBucketStates()
        XCTAssertEqual(allStates.count, 2)
        await limiter.clearAllBuckets()
        allStates = await limiter.getAllBucketStates()
        XCTAssertTrue(allStates.isEmpty)
    }
}
