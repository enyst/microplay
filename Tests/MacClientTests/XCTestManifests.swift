import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SocketServiceTests.allTests),
        testCase(AppStateTests.allTests),
        testCase(ModelsTests.allTests),
    ]
}
#endif