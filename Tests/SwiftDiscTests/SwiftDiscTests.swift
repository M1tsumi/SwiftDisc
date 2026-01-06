//
//  SwiftDiscTests.swift
//  SwiftDiscTests
//
//  Copyright © 2025 quefep. All rights reserved.
//

import XCTest
@testable import SwiftDisc

final class SwiftDiscTests: XCTestCase {
    func testInit() {
        let client = DiscordClient(token: "x")
        XCTAssertEqual(client.token, "x")
    }
}
