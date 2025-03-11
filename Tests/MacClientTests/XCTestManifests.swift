import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SimpleTestTests.allTests),
        testCase(SocketExampleTests.allTests),
        testCase(ModelsTests.allTests),
        // Commented out tests that depend on SwiftUI
        // testCase(AppStateTests.allTests),
    ]
}
#endif