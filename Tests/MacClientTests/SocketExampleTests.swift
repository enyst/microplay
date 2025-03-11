import XCTest
@testable import MacClient

final class SocketExampleTests: XCTestCase {
    // These tests are designed to demonstrate the API rather than actually connect
    // to a real Socket.IO server, as that would require a running server
    
    func testSocketExampleInitialization() {
        let url = URL(string: "http://localhost:8080")!
        let socketExample = SocketExample(url: url)
        
        // This test just verifies that initialization doesn't crash
        XCTAssertNotNil(socketExample)
    }
    
    static var allTests = [
        ("testSocketExampleInitialization", testSocketExampleInitialization),
    ]
}