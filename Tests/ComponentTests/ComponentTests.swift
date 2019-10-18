import XCTest
@testable import Component

final class ComponentTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Component().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
