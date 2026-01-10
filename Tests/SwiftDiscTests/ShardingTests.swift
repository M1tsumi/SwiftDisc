//
//  ShardingTests.swift
//  SwiftDiscTests
//
//  Copyright © 2025 quefep. All rights reserved.
//

import XCTest
@testable import SwiftDisc

final class ShardingTests: XCTestCase {

    func testShardingConfigurationDefaults() {
        let config = ShardingGatewayManager.Configuration()
        // shardCount defaults to .automatic
        switch config.shardCount {
        case .automatic: break
        default: XCTFail("Expected shardCount .automatic by default")
        }
        // connectionDelay defaults to .none
        switch config.connectionDelay {
        case .none: break
        default: XCTFail("Expected connectionDelay .none by default")
        }
        XCTAssertNil(config.makeIntents)
        XCTAssertNil(config.makePresence)
    }

    func testStaggeredConnectionDelay() {
        let config = ShardingGatewayManager.Configuration(connectionDelay: .staggered(interval: 1.5))
        if case .staggered(let interval) = config.connectionDelay {
            XCTAssertEqual(interval, 1.5, accuracy: 0.0001)
        } else {
            XCTFail("Expected staggered connection delay")
        }
    }

    func testGuildShardCalculation() {
        let totalShards = 4
        let guildId1: UInt64 = 123_456_789
        let expected1 = Int(guildId1 % UInt64(totalShards))
        XCTAssertTrue((0..<totalShards).contains(expected1))

        let guildId2: UInt64 = 987_654_321
        let expected2 = Int(guildId2 % UInt64(totalShards))
        XCTAssertTrue((0..<totalShards).contains(expected2))
    }

    func testShardedEventWrapper() {
        let guild = Guild(id: GuildID("123"), name: "Test Guild", owner_id: nil, member_count: nil)
        let se = ShardedEvent(shardId: 2, event: .guildCreate(guild), receivedAt: Date(), shardLatency: 0.030)
        XCTAssertEqual(se.shardId, 2)
        XCTAssertEqual(se.shardLatency ?? 0.0, 0.030, accuracy: 0.0001)
        if case let .guildCreate(g) = se.event {
            XCTAssertEqual(g.id.rawValue, "123")
        } else {
            XCTFail("Expected guildCreate event")
        }
    }
}
