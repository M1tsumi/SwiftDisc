import XCTest
@testable import SwiftDisc

final class HTTPClientTests: XCTestCase {
    private struct TestResponse: Codable, Sendable {
        let id: String
        let value: String
    }

    func testBasicGETRequest() async throws {
        let transport = MockHTTPTransport()
        let config = DiscordConfiguration()
        let client = HTTPClient(token: "test_token", configuration: config, transport: transport)

        let responseData = try JSONEncoder().encode(TestResponse(id: "42", value: "hello"))
        let path = "/v10/test/endpoint"
        await transport.addResponse(for: path, data: responseData)

        let result: TestResponse = try await client.get(path: "test/endpoint")
        XCTAssertEqual(result.id, "42")
        XCTAssertEqual(result.value, "hello")
    }

    func testRateLimitHeaderParsing() async throws {
        var capturedEvent: RateLimitEvent?
        let config = DiscordConfiguration(onRateLimit: { event in
            capturedEvent = event
        })
        let transport = MockHTTPTransport()
        let client = HTTPClient(token: "test_token", configuration: config, transport: transport)

        let responseData = try JSONEncoder().encode(["ok": true])
        let path = "/v10/channels/123/messages"
        await transport.addResponse(
            for: path,
            data: responseData,
            headers: [
                "X-RateLimit-Remaining": "4",
                "X-RateLimit-Reset-After": "0.5",
                "X-RateLimit-Limit": "5"
            ]
        )

        let result: [String: Bool] = try await client.get(path: "channels/123/messages")
        XCTAssertEqual(result["ok"], true)

        let event = try XCTUnwrap(capturedEvent)
        XCTAssertEqual(event.remaining, 4)
        XCTAssertEqual(event.limit, 5)
        XCTAssertFalse(event.isGlobal)
    }

    func test429RetryWithBackoff() async throws {
        let transport = MockHTTPTransport()
        let config = DiscordConfiguration()
        let client = HTTPClient(token: "test_token", configuration: config, transport: transport)

        let successData = try JSONEncoder().encode(TestResponse(id: "1", value: "ok"))
        let path = "/v10/guilds/111/channels"

        // First call returns 429 with minimal retry-after
        await transport.addResponse(
            for: path,
            data: Data("\"rate limited\"".utf8),
            statusCode: 429,
            headers: ["Retry-After": "0.001"]
        )
        // Second call (retry) returns success
        await transport.addResponse(
            for: path,
            data: successData,
            statusCode: 200
        )

        let result: TestResponse = try await client.get(path: "guilds/111/channels")
        XCTAssertEqual(result.id, "1")
        XCTAssertEqual(result.value, "ok")
    }

    func testMakeRouteKeySimplePath() throws {
        let client = HTTPClient(token: "t", configuration: DiscordConfiguration())

        let key = client.makeRouteKey(method: "GET", path: "channels/123/messages")
        XCTAssertEqual(key, "GET:channels/123/messages|major=123")
    }

    func testMakeRouteKeyWithSnowflakes() throws {
        let client = HTTPClient(token: "t", configuration: DiscordConfiguration())

        let noMajor = client.makeRouteKey(method: "POST", path: "some/endpoint")
        XCTAssertEqual(noMajor, "POST:some/endpoint|major=global")

        let channelId = client.makeRouteKey(method: "GET", path: "channels/987654321098765432/messages/12345")
        XCTAssertEqual(channelId, "GET:channels/987654321098765432/messages/:id|major=987654321098765432")

        let guildId = client.makeRouteKey(method: "GET", path: "guilds/111111111111111111/channels")
        XCTAssertEqual(guildId, "GET:guilds/111111111111111111/channels|major=111111111111111111")

        let webhook = client.makeRouteKey(method: "POST", path: "webhooks/555555555555555555/abcdef123")
        XCTAssertEqual(webhook, "POST:webhooks/555555555555555555/abcdef123|major=555555555555555555")
    }
}
