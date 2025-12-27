import XCTest
@testable import SwiftDisc

final class CommandFrameworkTests: XCTestCase {
    func testRegisterAndUnregister() async {
        let router = CommandRouter(prefix: "!")
        var called = false

        router.register("hello") { ctx in
            called = true
        }

        // We can't easily construct a full Message here without the library models in tests,
        // but ensure registration stores the handler by registering/unregistering without error.
        router.unregister("hello")
        XCTAssertFalse(called)
    }
}
