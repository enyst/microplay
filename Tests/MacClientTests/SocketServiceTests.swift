import XCTest
@testable import MacClient

// Mock AppState for testing
class MockAppState: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isAwaitingUserConfirmation: Bool = false
    @Published var isAgentThinking: Bool = false
    @Published var isAgentExecuting: Bool = false
    @Published var selectedFilePath: String? = nil
    @Published var terminalCommands: [TerminalCommand] = []
    @Published var fileStructure: [FileNode] = []
    @Published var error: String? = nil
    
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

// Mock SocketServiceDelegate for testing
class MockSocketServiceDelegate: SocketServiceDelegate {
    var processedEvents: [Event] = []
    
    func socketService(_ socketService: SocketService, didProcessEvent event: Event) {
        processedEvents.append(event)
    }
}

class SocketServiceTests: XCTestCase {
    
    static var allTests = [
        ("testProcessActionMessageEvent", testProcessActionMessageEvent),
        ("testProcessActionRunEvent", testProcessActionRunEvent),
        ("testProcessActionReadEvent", testProcessActionReadEvent),
        ("testProcessActionWriteEvent", testProcessActionWriteEvent),
        ("testProcessActionEditEvent", testProcessActionEditEvent),
        ("testProcessActionBrowseEvent", testProcessActionBrowseEvent),
        ("testProcessObservationRunEvent", testProcessObservationRunEvent),
        ("testProcessObservationReadEvent", testProcessObservationReadEvent),
        ("testProcessObservationWriteEvent", testProcessObservationWriteEvent),
        ("testProcessObservationEditEvent", testProcessObservationEditEvent),
        ("testProcessObservationBrowseEvent", testProcessObservationBrowseEvent),
        ("testProcessObservationAgentStateChangedEvent", testProcessObservationAgentStateChangedEvent),
        ("testProcessObservationErrorEvent", testProcessObservationErrorEvent),
        ("testProcessUnknownEvent", testProcessUnknownEvent),
        ("testDelegateNotification", testDelegateNotification)
    ]
    
    var socketService: SocketService!
    var mockAppState: MockAppState!
    var mockSocket: MockSocketIOClient!
    var mockDelegate: MockSocketServiceDelegate!
    
    override func setUp() {
        super.setUp()
        mockAppState = MockAppState()
        mockSocket = MockSocketIOClient()
        mockDelegate = MockSocketServiceDelegate()
        socketService = SocketService(appState: mockAppState)
        socketService.delegate = mockDelegate
        // Replace the real socket with our mock
        socketService.socket = mockSocket as! SocketIOClient
    }
    
    override func tearDown() {
        socketService = nil
        mockAppState = nil
        mockSocket = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    // MARK: - Action Event Tests
    
    // Test processing a message action event from agent
    func testProcessActionMessageEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 1,
            "timestamp": "2023-03-11T10:00:00Z",
            "source": "agent",
            "message": "Hello, world!",
            "action": "message",
            "args": [
                "thought": "I should greet the user",
                "image_urls": ["https://example.com/image.jpg"],
                "wait_for_response": true
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify the message was added to the app state
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "Hello, world!")
        XCTAssertEqual(mockAppState.messages[0].sender, "agent")
        XCTAssertEqual(mockAppState.messages[0].thought, "I should greet the user")
        XCTAssertEqual(mockAppState.messages[0].imageUrls, ["https://example.com/image.jpg"])
        XCTAssertTrue(mockAppState.isAwaitingUserConfirmation)
    }
    
    // Test processing a run action event
    func testProcessActionRunEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 2,
            "timestamp": "2023-03-11T10:01:00Z",
            "source": "agent",
            "message": "Running command",
            "action": "run",
            "args": [
                "command": "ls -la"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify the terminal command was added to the app state
        XCTAssertEqual(mockAppState.terminalCommands.count, 1)
        XCTAssertEqual(mockAppState.terminalCommands[0].command, "ls -la")
        XCTAssertEqual(mockAppState.terminalCommands[0].output, "Running...")
        XCTAssertEqual(mockAppState.terminalCommands[0].exitCode, -1)
        XCTAssertTrue(mockAppState.terminalCommands[0].isRunning)
        
        // Verify a message was added to the chat
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "Executing command: ls -la")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
    }
    
    // Test processing a read action event
    func testProcessActionReadEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 3,
            "timestamp": "2023-03-11T10:02:00Z",
            "source": "agent",
            "message": "Reading file",
            "action": "read",
            "args": [
                "path": "/path/to/file.txt"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify a message was added to the chat
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "Reading file: /path/to/file.txt")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
    }
    
    // Test processing a write action event
    func testProcessActionWriteEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 4,
            "timestamp": "2023-03-11T10:03:00Z",
            "source": "agent",
            "message": "Writing file",
            "action": "write",
            "args": [
                "path": "/path/to/file.txt",
                "content": "Hello, world!"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify a message was added to the chat
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "Writing to file: /path/to/file.txt")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
    }
    
    // Test processing an edit action event
    func testProcessActionEditEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 5,
            "timestamp": "2023-03-11T10:04:00Z",
            "source": "agent",
            "message": "Editing file",
            "action": "edit",
            "args": [
                "path": "/path/to/file.txt",
                "old_str": "Hello",
                "new_str": "Hello, world!"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify a message was added to the chat
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "Editing file: /path/to/file.txt")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
    }
    
    // Test processing a browse action event
    func testProcessActionBrowseEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 6,
            "timestamp": "2023-03-11T10:05:00Z",
            "source": "agent",
            "message": "Browsing URL",
            "action": "browse",
            "args": [
                "url": "https://example.com"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify a message was added to the chat
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "Navigating to: https://example.com")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
    }
    
    // MARK: - Observation Event Tests
    
    // Test processing a run observation event
    func testProcessObservationRunEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 7,
            "timestamp": "2023-03-11T10:06:00Z",
            "source": "system",
            "message": "Command executed",
            "cause": 2,
            "observation": "run",
            "content": "total 0\ndrwxr-xr-x  2 user  staff   64 Mar 11 10:00 .\ndrwxr-xr-x  3 user  staff   96 Mar 11 10:00 ..",
            "extras": [
                "command": "ls -la",
                "metadata": [
                    "exit_code": 0
                ] as [String : Any]
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify the terminal command was updated in the app state
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "Command executed successfully: ls -la")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
        XCTAssertFalse(mockAppState.isAgentExecuting)
    }
    
    // Test processing a read observation event
    func testProcessObservationReadEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 8,
            "timestamp": "2023-03-11T10:07:00Z",
            "source": "system",
            "message": "File read",
            "cause": 3,
            "observation": "read",
            "content": "Hello, world!",
            "extras": [
                "path": "/path/to/file.txt"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify the file path was selected in the app state
        XCTAssertEqual(mockAppState.selectedFilePath, "/path/to/file.txt")
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "File read: /path/to/file.txt")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
    }
    
    // Test processing a write observation event
    func testProcessObservationWriteEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 9,
            "timestamp": "2023-03-11T10:08:00Z",
            "source": "system",
            "message": "File written",
            "cause": 4,
            "observation": "write",
            "extras": [
                "path": "/path/to/file.txt"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify a message was added to the chat
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "File written: /path/to/file.txt")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
    }
    
    // Test processing an edit observation event
    func testProcessObservationEditEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 10,
            "timestamp": "2023-03-11T10:09:00Z",
            "source": "system",
            "message": "File edited",
            "cause": 5,
            "observation": "edit",
            "extras": [
                "path": "/path/to/file.txt",
                "diff": "- Hello\n+ Hello, world!"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify a message was added to the chat
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "File edited: /path/to/file.txt")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
    }
    
    // Test processing a browse observation event
    func testProcessObservationBrowseEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 11,
            "timestamp": "2023-03-11T10:10:00Z",
            "source": "system",
            "message": "URL browsed",
            "cause": 6,
            "observation": "browse",
            "extras": [
                "url": "https://example.com",
                "screenshot": "https://example.com/screenshot.jpg"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify messages were added to the chat
        XCTAssertEqual(mockAppState.messages.count, 2)
        XCTAssertEqual(mockAppState.messages[0].text, "Browsed URL: https://example.com")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
        XCTAssertEqual(mockAppState.messages[1].text, "Browser screenshot")
        XCTAssertEqual(mockAppState.messages[1].sender, "system")
        XCTAssertEqual(mockAppState.messages[1].imageUrls, ["https://example.com/screenshot.jpg"])
    }
    
    // Test processing an agent_state_changed observation event
    func testProcessObservationAgentStateChangedEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 12,
            "timestamp": "2023-03-11T10:11:00Z",
            "source": "system",
            "message": "Agent state changed",
            "observation": "agent_state_changed",
            "extras": [
                "agent_state": "thinking"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify the app state was updated
        XCTAssertTrue(mockAppState.isAgentThinking)
        XCTAssertFalse(mockAppState.isAgentExecuting)
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "Agent state changed to: thinking")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
    }
    
    // Test processing an error observation event
    func testProcessObservationErrorEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 13,
            "timestamp": "2023-03-11T10:12:00Z",
            "source": "system",
            "message": "An error occurred",
            "observation": "error",
            "extras": [
                "error_id": "file_not_found"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify the app state was updated
        XCTAssertEqual(mockAppState.error, "Error: file_not_found - An error occurred")
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "Error: file_not_found - An error occurred")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
        XCTAssertTrue(mockAppState.messages[0].isError)
    }
    
    // Test processing an unknown event
    func testProcessUnknownEvent() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 14,
            "timestamp": "2023-03-11T10:13:00Z",
            "source": "system",
            "message": "Unknown event",
            "action": "unknown_action"
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify a message was added to the chat
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "Unknown action: unknown_action")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
    }
    
    // Test delegate notification
    func testDelegateNotification() {
        // Prepare test data
        let eventData: [String: Any] = [
            "id": 15,
            "timestamp": "2023-03-11T10:14:00Z",
            "source": "agent",
            "message": "Hello, world!",
            "action": "message"
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify the delegate was notified
        XCTAssertEqual(mockDelegate.processedEvents.count, 1)
        XCTAssertEqual(mockDelegate.processedEvents[0].id, 15)
        XCTAssertEqual(mockDelegate.processedEvents[0].message, "Hello, world!")
    }
}