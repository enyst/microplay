import XCTest
@testable import MacClient

// Mock AppState for testing
class MockAppState: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isAwaitingUserConfirmation: Bool = false
    @Published var selectedFilePath: String? = nil
    @Published var terminalCommands: [TerminalCommand] = []
    @Published var fileStructure: [FileNode] = []
    
    func refreshFileExplorer() {
        // Mock implementation
    }
}

// Mock SocketIOClient for testing
class MockSocketIOClient {
    var emitCalls: [(String, [Any])] = []
    var onHandlers: [String: ([Any], SocketAckEmitter?) -> Void] = [:]
    
    func emit(_ event: String, _ items: Any...) {
        emitCalls.append((event, items))
    }
    
    func on(_ event: String, callback: @escaping ([Any], SocketAckEmitter?) -> Void) {
        onHandlers[event] = callback
    }
    
    func triggerEvent(_ event: String, with data: [Any]) {
        onHandlers[event]?(data, nil)
    }
}

class SocketServiceTests: XCTestCase {
    
    static var allTests = [
        ("testProcessMessageEvent", testProcessMessageEvent),
        ("testProcessRunObservationEvent", testProcessRunObservationEvent),
        ("testProcessReadObservationEvent", testProcessReadObservationEvent),
        ("testProcessAgentStateChangedEvent", testProcessAgentStateChangedEvent),
        ("testProcessActionEvent", testProcessActionEvent)
    ]
    var socketService: SocketService!
    var mockAppState: MockAppState!
    var mockSocket: MockSocketIOClient!
    
    override func setUp() {
        super.setUp()
        mockAppState = MockAppState()
        mockSocket = MockSocketIOClient()
        socketService = SocketService(appState: mockAppState)
        // Replace the real socket with our mock
        socketService.socket = mockSocket as! SocketIOClient
    }
    
    override func tearDown() {
        socketService = nil
        mockAppState = nil
        mockSocket = nil
        super.tearDown()
    }
    
    // Test processing a message event
    func testProcessMessageEvent() {
        // Prepare test data
        let messageData: [String: Any] = [
            "text": "Hello, world!",
            "sender": "agent"
        ]
        
        // Trigger the message event
        mockSocket.triggerEvent("message", with: [messageData])
        
        // Verify the message was added to the app state
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "Hello, world!")
        XCTAssertEqual(mockAppState.messages[0].sender, "agent")
    }
    
    // Test processing a run observation event
    func testProcessRunObservationEvent() {
        // Prepare test data
        let observationData: [String: Any] = [
            "type": "run",
            "command": "ls -la",
            "output": "total 0\ndrwxr-xr-x  2 user  staff   64 Mar 11 10:00 .\ndrwxr-xr-x  3 user  staff   96 Mar 11 10:00 .."
        ]
        
        // Trigger the observation event
        mockSocket.triggerEvent("observation", with: [observationData])
        
        // Verify the terminal command was added to the app state
        XCTAssertEqual(mockAppState.terminalCommands.count, 1)
        XCTAssertEqual(mockAppState.terminalCommands[0].command, "ls -la")
        XCTAssertEqual(mockAppState.terminalCommands[0].output, "total 0\ndrwxr-xr-x  2 user  staff   64 Mar 11 10:00 .\ndrwxr-xr-x  3 user  staff   96 Mar 11 10:00 ..")
    }
    
    // Test processing a read observation event
    func testProcessReadObservationEvent() {
        // Prepare test data
        let observationData: [String: Any] = [
            "type": "read",
            "path": "/path/to/file.txt",
            "content": "This is the content of the file."
        ]
        
        // Trigger the observation event
        mockSocket.triggerEvent("observation", with: [observationData])
        
        // Verify the file path was selected in the app state
        XCTAssertEqual(mockAppState.selectedFilePath, "/path/to/file.txt")
    }
    
    // Test processing an agent_state_changed observation event
    func testProcessAgentStateChangedEvent() {
        // Prepare test data
        let observationData: [String: Any] = [
            "type": "agent_state_changed",
            "state": "awaiting_user_confirmation"
        ]
        
        // Trigger the observation event
        mockSocket.triggerEvent("observation", with: [observationData])
        
        // Verify the app state was updated
        XCTAssertTrue(mockAppState.isAwaitingUserConfirmation)
    }
    
    // Test processing an action event
    func testProcessActionEvent() {
        // Prepare test data
        let actionData: [String: Any] = [
            "type": "confirm",
            "message": "Do you want to proceed?"
        ]
        
        // Trigger the action event
        mockSocket.triggerEvent("action", with: [actionData])
        
        // Verify the app state was updated
        XCTAssertTrue(mockAppState.isAwaitingUserConfirmation)
    }
}