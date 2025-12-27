import XCTest
@testable import SwiftDisc

final class ComponentsV2Tests: XCTestCase {
    func testButtonBuilderEncodes() throws {
        var b = ButtonBuilder()
        b.style(.primary).label("Test").customId("btn_1")
        let comp = b.build()
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode([comp])
        XCTAssertFalse(data.isEmpty)
    }

    func testSelectMenuBuilderEncodes() throws {
        var s = SelectMenuBuilder()
        s.customId("menu_1").option(label: "A", value: "a")
        let comp = s.build()
        let data = try JSONEncoder().encode([comp])
        XCTAssertFalse(data.isEmpty)
    }

    func testEmbedBuilderProducesEmbed() {
        var eb = EmbedBuilder()
        eb.title("T").description("D").addField(name: "f", value: "v")
        let embed = eb.build()
        XCTAssertEqual(embed.title, "T")
    }
}
