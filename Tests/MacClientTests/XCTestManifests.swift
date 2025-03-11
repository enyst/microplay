import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SimpleTestTests.allTests),
        // Commented out tests that depend on SwiftUI and SocketIO
        // testCase(SocketServiceTests.allTests),
        // testCase(AppStateTests.allTests),
        // testCase(ModelsTests.allTests),
    ]
}
#endif