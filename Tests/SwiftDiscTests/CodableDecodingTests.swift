import XCTest
@testable import SwiftDisc

final class CodableDecodingTests: XCTestCase {
    private struct UserContainer: Codable, Sendable {
        let id: UserID
    }

    private struct PermissionContainer: Codable, Sendable {
        let permissions: PermissionBitset
    }

    func testSnowflakeDecodesFromString() throws {
        let data = Data("{\"id\":\"123456789012345678\"}".utf8)
        let decoded = try JSONDecoder().decode(UserContainer.self, from: data)
        XCTAssertEqual(decoded.id.rawValue, "123456789012345678")
    }

    func testSnowflakeDecodesFromInteger() throws {
        let data = Data("{\"id\":123456789012345678}".utf8)
        let decoded = try JSONDecoder().decode(UserContainer.self, from: data)
        XCTAssertEqual(decoded.id.rawValue, "123456789012345678")
    }

    func testSnowflakeEncodesAsString() throws {
        let payload = UserContainer(id: UserID("42"))
        let encoded = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        XCTAssertEqual(json?["id"] as? String, "42")
    }

    func testPermissionBitsetDecodesFromString() throws {
        let data = Data("{\"permissions\":\"1024\"}".utf8)
        let decoded = try JSONDecoder().decode(PermissionContainer.self, from: data)
        XCTAssertEqual(decoded.permissions.rawValue, 1024)
    }

    func testPermissionBitsetDecodesFromInteger() throws {
        let data = Data("{\"permissions\":1024}".utf8)
        let decoded = try JSONDecoder().decode(PermissionContainer.self, from: data)
        XCTAssertEqual(decoded.permissions.rawValue, 1024)
    }

    func testPermissionBitsetEncodesAsString() throws {
        let payload = PermissionContainer(permissions: PermissionBitset(rawValue: 2048))
        let encoded = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        XCTAssertEqual(json?["permissions"] as? String, "2048")
    }
}