import XCTest
@testable import MacClient

final class SimpleTestTests: XCTestCase {
    func testHello() {
        XCTAssertEqual(SimpleTest.hello(), "Hello, Swift on Linux!")
    }
    
    func testAdd() {
        XCTAssertEqual(SimpleTest.add(2, 3), 5)
    }
    
    static var allTests = [
        ("testHello", testHello),
        ("testAdd", testAdd),
    ]
}