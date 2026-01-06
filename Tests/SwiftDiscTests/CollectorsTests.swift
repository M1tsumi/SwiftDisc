//
//  CollectorsTests.swift
//  SwiftDiscTests
//
//  Copyright © 2025 quefep. All rights reserved.
//

import XCTest
@testable import SwiftDisc

final class CollectorsTests: XCTestCase {
    func testCreateMessageCollectorReturnsStream() async {
        let client = DiscordClient(token: "")
        let stream = client.createMessageCollector()
        // Ensure the returned type is an AsyncStream<Message> by obtaining it and then cancelling.
        var iter = stream.makeAsyncIterator()
        _ = try? await Task.checkCancellation()
        // We don't iterate (no network) — this test ensures the API exists and compiles.
        XCTAssertNotNil(iter)
    }

    func testStreamGuildMembersReturnsStream() async {
        let client = DiscordClient(token: "")
        let stream = client.streamGuildMembers(guildId: "0")
        var iter = stream.makeAsyncIterator()
        XCTAssertNotNil(iter)
    }
}
