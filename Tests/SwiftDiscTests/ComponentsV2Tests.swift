//
//  ComponentsV2Tests.swift
//  SwiftDiscTests
//
//  Copyright © 2025 quefep. All rights reserved.
//

import XCTest
@testable import SwiftDisc

final class ComponentsV2Tests: XCTestCase {
    func testButtonBuilderEncodes() throws {
        let b = ButtonBuilder()
            .style(.primary)
            .label("Test")
            .customId("btn_1")
        let comp = b.build()
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode([comp])
        XCTAssertFalse(data.isEmpty)
    }

    func testSelectMenuBuilderEncodes() throws {
        let s = SelectMenuBuilder()
            .customId("menu_1")
            .option(label: "A", value: "a")
        let comp = s.build()
        let data = try JSONEncoder().encode([comp])
        XCTAssertFalse(data.isEmpty)
    }

    func testEmbedBuilderProducesEmbed() {
        let eb = EmbedBuilder()
            .title("T")
            .description("D")
            .addField(name: "f", value: "v")
        let embed = eb.build()
        XCTAssertEqual(embed.title, "T")
    }
}
