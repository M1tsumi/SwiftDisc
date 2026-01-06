//
//  ComponentCollectorTests.swift
//  SwiftDiscTests
//
//  Copyright © 2025 quefep. All rights reserved.
//

import XCTest
@testable import SwiftDisc

final class ComponentCollectorTests: XCTestCase {
    func testCreateComponentCollectorReturnsStream() async {
        let client = DiscordClient(token: "")
        let stream = client.createComponentCollector(customId: nil)
        var iter = stream.makeAsyncIterator()
        XCTAssertNotNil(iter)
    }
}
