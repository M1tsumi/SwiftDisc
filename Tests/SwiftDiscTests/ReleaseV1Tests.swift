//
//  ReleaseV1Tests.swift
//  SwiftDiscTests
//
//  Copyright © 2025 quefep. All rights reserved.
//

import XCTest
@testable import SwiftDisc

final class ReleaseV1Tests: XCTestCase {
    func testPermissionFlagsPresent() {
        // Verify new permission flags exist and map to expected bit positions
        XCTAssertEqual(PermissionBitset.pinMessages.rawValue, 1 << 51)
        XCTAssertEqual(PermissionBitset.bypassSlowmode.rawValue, 1 << 52)
        XCTAssertEqual(PermissionBitset.useExternalApps.rawValue, 1 << 50)
        XCTAssertEqual(PermissionBitset.createGuildExpressions.rawValue, 1 << 43)
        XCTAssertEqual(PermissionBitset.createEvents.rawValue, 1 << 44)
    }

    func testPinsStreamType() async {
        // Ensure the client provides a streaming API for pins (no network call here — just type check)
        let client = DiscordClient(token: "", configuration: .init())
        let stream = client.streamChannelPins(channelId: "0")
        var iter = stream.makeAsyncIterator()
        // The iterator should conform; we won't await a value since there's no network in tests here
        _ = iter
        XCTAssertNotNil(stream)
    }
}
