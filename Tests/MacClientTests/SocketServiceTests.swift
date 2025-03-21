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
    struct EmittedEvent {
        let name: String
        let items: [Any]
    }
    
    var emitCalls: [(String, [Any])] = []
    var emittedEvents: [EmittedEvent] = []
    var onHandlers: [String: ([Any], SocketAckEmitter?) -> Void] = [:]
    
    func emit(_ event: String, _ items: Any...) {
        emitCalls.append((event, items))
        emittedEvents.append(EmittedEvent(name: event, items: items))
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
        ("testDelegateNotification", testDelegateNotification),
        
        // Event emission tests
        ("testSendAction", testSendAction),
        ("testSendMessage", testSendMessage),
        ("testExecuteCommand", testExecuteCommand),
        ("testReadFile", testReadFile),
        ("testWriteFile", testWriteFile),
        ("testEditFile", testEditFile),
        ("testBrowseUrl", testBrowseUrl),
        ("testBrowseInteractive", testBrowseInteractive)
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
                "path": "/path/to/file.txt",
                "impl_source": "local"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify the file path was selected in the app state
        XCTAssertEqual(mockAppState.selectedFilePath, "/path/to/file.txt")
        XCTAssertEqual(mockAppState.messages.count, 1)
        XCTAssertEqual(mockAppState.messages[0].text, "File read: /path/to/file.txt")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
        
        // Reset mock state
        mockAppState.messages = []
        mockAppState.selectedFilePath = nil
        
        // Test with an image file
        let imageEventData: [String: Any] = [
            "id": 9,
            "timestamp": "2023-03-11T10:08:00Z",
            "source": "system",
            "message": "Image file read",
            "cause": 4,
            "observation": "read",
            "content": "binary image data",
            "extras": [
                "path": "/path/to/image.jpg",
                "impl_source": "local",
                "image_url": "https://example.com/image.jpg"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [imageEventData])
        
        // Verify the file path was selected in the app state
        XCTAssertEqual(mockAppState.selectedFilePath, "/path/to/image.jpg")
        XCTAssertEqual(mockAppState.messages.count, 2)
        XCTAssertEqual(mockAppState.messages[0].text, "File read: /path/to/image.jpg")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
        XCTAssertEqual(mockAppState.messages[1].text, "Image from file: /path/to/image.jpg")
        XCTAssertEqual(mockAppState.messages[1].sender, "system")
        XCTAssertEqual(mockAppState.messages[1].imageUrls, ["https://example.com/image.jpg"])
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
                "screenshot": "https://example.com/screenshot.jpg",
                "dom_object": [
                    "title": "Example Domain",
                    "text_content": "This domain is for use in illustrative examples in documents.",
                    "links": [
                        ["href": "https://www.iana.org/domains/example", "text": "More information"],
                        ["href": "https://example.org", "text": "Example.org"]
                    ]
                ] as [String: Any],
                "html": "<html><body>Example content</body></html>"
            ] as [String : Any]
        ]
        
        // Trigger the event
        mockSocket.triggerEvent("event", with: [eventData])
        
        // Verify messages were added to the chat
        XCTAssertEqual(mockAppState.messages.count, 5)
        
        // Check the URL message
        XCTAssertEqual(mockAppState.messages[0].text, "Browsed URL: https://example.com")
        XCTAssertEqual(mockAppState.messages[0].sender, "system")
        
        // Check the screenshot message
        XCTAssertEqual(mockAppState.messages[1].text, "Browser screenshot")
        XCTAssertEqual(mockAppState.messages[1].sender, "system")
        XCTAssertEqual(mockAppState.messages[1].imageUrls, ["https://example.com/screenshot.jpg"])
        
        // Check the title message
        XCTAssertEqual(mockAppState.messages[2].text, "Page title: Example Domain")
        XCTAssertEqual(mockAppState.messages[2].sender, "system")
        
        // Check the content message
        XCTAssertEqual(mockAppState.messages[3].text, "Page content: This domain is for use in illustrative examples in documents.")
        XCTAssertEqual(mockAppState.messages[3].sender, "system")
        
        // Check the links message
        XCTAssertEqual(mockAppState.messages[4].text, "Page links:\n1. [More information](https://www.iana.org/domains/example)\n2. [Example.org](https://example.org)\n")
        XCTAssertEqual(mockAppState.messages[4].sender, "system")
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
    
    // MARK: - Event Emission Tests
    
    func testSendAction() {
        // Call the method
        socketService.sendAction(action: "testAction", args: ["key": "value"])
        
        // Verify the socket emitted the correct event
        XCTAssertEqual(mockSocket.emittedEvents.count, 1)
        XCTAssertEqual(mockSocket.emittedEvents[0].name, "action")
        
        // Verify the data structure
        if let data = mockSocket.emittedEvents[0].items[0] as? [String: Any],
           let action = data["action"] as? String,
           let args = data["args"] as? [String: Any] {
            XCTAssertEqual(action, "testAction")
            XCTAssertEqual(args["key"] as? String, "value")
        } else {
            XCTFail("Emitted data structure is incorrect")
        }
    }
    
    func testSendMessage() {
        // Test with text only
        socketService.sendMessage(content: "Hello server")
        
        // Verify the socket emitted the correct event
        XCTAssertEqual(mockSocket.emittedEvents.count, 1)
        XCTAssertEqual(mockSocket.emittedEvents[0].name, "action")
        
        // Verify the data structure
        if let data = mockSocket.emittedEvents[0].items[0] as? [String: Any],
           let action = data["action"] as? String,
           let args = data["args"] as? [String: Any],
           let content = args["content"] as? String {
            XCTAssertEqual(action, "message")
            XCTAssertEqual(content, "Hello server")
            XCTAssertNil(args["imageUrls"])
        } else {
            XCTFail("Emitted data structure is incorrect")
        }
        
        // Reset mock
        mockSocket.emittedEvents = []
        
        // Test with text and images
        let imageUrls = ["image1.jpg", "image2.jpg"]
        socketService.sendMessage(content: "Hello with images", imageUrls: imageUrls)
        
        // Verify the socket emitted the correct event
        XCTAssertEqual(mockSocket.emittedEvents.count, 1)
        XCTAssertEqual(mockSocket.emittedEvents[0].name, "action")
        
        // Verify the data structure
        if let data = mockSocket.emittedEvents[0].items[0] as? [String: Any],
           let action = data["action"] as? String,
           let args = data["args"] as? [String: Any],
           let content = args["content"] as? String,
           let urls = args["imageUrls"] as? [String] {
            XCTAssertEqual(action, "message")
            XCTAssertEqual(content, "Hello with images")
            XCTAssertEqual(urls, imageUrls)
        } else {
            XCTFail("Emitted data structure is incorrect")
        }
    }
    
    func testExecuteCommand() {
        // Test basic command
        socketService.executeCommand(command: "ls -la")
        
        // Verify the socket emitted the correct event
        XCTAssertEqual(mockSocket.emittedEvents.count, 1)
        XCTAssertEqual(mockSocket.emittedEvents[0].name, "action")
        
        // Verify the data structure
        if let data = mockSocket.emittedEvents[0].items[0] as? [String: Any],
           let action = data["action"] as? String,
           let args = data["args"] as? [String: Any],
           let command = args["command"] as? String {
            XCTAssertEqual(action, "run")
            XCTAssertEqual(command, "ls -la")
            XCTAssertEqual(args["securityRisk"] as? Bool, false)
            XCTAssertNil(args["confirmationState"])
            XCTAssertNil(args["thought"])
        } else {
            XCTFail("Emitted data structure is incorrect")
        }
        
        // Reset mock
        mockSocket.emittedEvents = []
        
        // Test with all parameters
        socketService.executeCommand(
            command: "rm -rf /",
            securityRisk: true,
            confirmationState: "confirmed",
            thought: "This is a dangerous command"
        )
        
        // Verify the socket emitted the correct event
        XCTAssertEqual(mockSocket.emittedEvents.count, 1)
        XCTAssertEqual(mockSocket.emittedEvents[0].name, "action")
        
        // Verify the data structure
        if let data = mockSocket.emittedEvents[0].items[0] as? [String: Any],
           let action = data["action"] as? String,
           let args = data["args"] as? [String: Any],
           let command = args["command"] as? String,
           let securityRisk = args["securityRisk"] as? Bool,
           let confirmationState = args["confirmationState"] as? String,
           let thought = args["thought"] as? String {
            XCTAssertEqual(action, "run")
            XCTAssertEqual(command, "rm -rf /")
            XCTAssertEqual(securityRisk, true)
            XCTAssertEqual(confirmationState, "confirmed")
            XCTAssertEqual(thought, "This is a dangerous command")
        } else {
            XCTFail("Emitted data structure is incorrect")
        }
    }
    
    func testReadFile() {
        // Call the method
        socketService.readFile(path: "/path/to/file.txt")
        
        // Verify the socket emitted the correct event
        XCTAssertEqual(mockSocket.emittedEvents.count, 1)
        XCTAssertEqual(mockSocket.emittedEvents[0].name, "action")
        
        // Verify the data structure
        if let data = mockSocket.emittedEvents[0].items[0] as? [String: Any],
           let action = data["action"] as? String,
           let args = data["args"] as? [String: Any],
           let path = args["path"] as? String {
            XCTAssertEqual(action, "read")
            XCTAssertEqual(path, "/path/to/file.txt")
        } else {
            XCTFail("Emitted data structure is incorrect")
        }
    }
    
    func testWriteFile() {
        // Call the method
        socketService.writeFile(path: "/path/to/file.txt", content: "Hello, world!")
        
        // Verify the socket emitted the correct event
        XCTAssertEqual(mockSocket.emittedEvents.count, 1)
        XCTAssertEqual(mockSocket.emittedEvents[0].name, "action")
        
        // Verify the data structure
        if let data = mockSocket.emittedEvents[0].items[0] as? [String: Any],
           let action = data["action"] as? String,
           let args = data["args"] as? [String: Any],
           let path = args["path"] as? String,
           let content = args["content"] as? String {
            XCTAssertEqual(action, "write")
            XCTAssertEqual(path, "/path/to/file.txt")
            XCTAssertEqual(content, "Hello, world!")
        } else {
            XCTFail("Emitted data structure is incorrect")
        }
    }
    
    func testEditFile() {
        // Call the method
        socketService.editFile(path: "/path/to/file.txt", oldContent: "Hello", newContent: "Hello, world!")
        
        // Verify the socket emitted the correct event
        XCTAssertEqual(mockSocket.emittedEvents.count, 1)
        XCTAssertEqual(mockSocket.emittedEvents[0].name, "action")
        
        // Verify the data structure
        if let data = mockSocket.emittedEvents[0].items[0] as? [String: Any],
           let action = data["action"] as? String,
           let args = data["args"] as? [String: Any],
           let path = args["path"] as? String,
           let oldContent = args["oldContent"] as? String,
           let newContent = args["newContent"] as? String {
            XCTAssertEqual(action, "edit")
            XCTAssertEqual(path, "/path/to/file.txt")
            XCTAssertEqual(oldContent, "Hello")
            XCTAssertEqual(newContent, "Hello, world!")
        } else {
            XCTFail("Emitted data structure is incorrect")
        }
    }
    
    func testBrowseUrl() {
        // Call the method
        socketService.browseUrl(url: "https://example.com")
        
        // Verify the socket emitted the correct event
        XCTAssertEqual(mockSocket.emittedEvents.count, 1)
        XCTAssertEqual(mockSocket.emittedEvents[0].name, "action")
        
        // Verify the data structure
        if let data = mockSocket.emittedEvents[0].items[0] as? [String: Any],
           let action = data["action"] as? String,
           let args = data["args"] as? [String: Any],
           let url = args["url"] as? String {
            XCTAssertEqual(action, "browse")
            XCTAssertEqual(url, "https://example.com")
        } else {
            XCTFail("Emitted data structure is incorrect")
        }
    }
    
    func testBrowseInteractive() {
        // Call the method
        socketService.browseInteractive(code: "click('button')")
        
        // Verify the socket emitted the correct event
        XCTAssertEqual(mockSocket.emittedEvents.count, 1)
        XCTAssertEqual(mockSocket.emittedEvents[0].name, "action")
        
        // Verify the data structure
        if let data = mockSocket.emittedEvents[0].items[0] as? [String: Any],
           let action = data["action"] as? String,
           let args = data["args"] as? [String: Any],
           let code = args["code"] as? String {
            XCTAssertEqual(action, "browse_interactive")
            XCTAssertEqual(code, "click('button')")
        } else {
            XCTFail("Emitted data structure is incorrect")
        }
    }
}