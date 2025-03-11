import XCTest
@testable import MacClient

class AppStateTests: XCTestCase {
    
    static var allTests = [
        ("testAddMessage", testAddMessage),
        ("testAddTerminalCommand", testAddTerminalCommand),
        ("testSetSelectedFilePath", testSetSelectedFilePath),
        ("testSetAwaitingUserConfirmation", testSetAwaitingUserConfirmation),
        ("testAddFileNodes", testAddFileNodes)
    ]
    var appState: AppState!
    
    override func setUp() {
        super.setUp()
        appState = AppState()
    }
    
    override func tearDown() {
        appState = nil
        super.tearDown()
    }
    
    // Test adding a message to the app state
    func testAddMessage() {
        // Initial state
        XCTAssertEqual(appState.messages.count, 0)
        
        // Add a message
        let message = Message(text: "Test message", sender: "user")
        appState.messages.append(message)
        
        // Verify the message was added
        XCTAssertEqual(appState.messages.count, 1)
        XCTAssertEqual(appState.messages[0].text, "Test message")
        XCTAssertEqual(appState.messages[0].sender, "user")
    }
    
    // Test adding a terminal command to the app state
    func testAddTerminalCommand() {
        // Initial state
        XCTAssertEqual(appState.terminalCommands.count, 0)
        
        // Add a terminal command
        let command = TerminalCommand(command: "ls -la", output: "file1.txt\nfile2.txt")
        appState.terminalCommands.append(command)
        
        // Verify the terminal command was added
        XCTAssertEqual(appState.terminalCommands.count, 1)
        XCTAssertEqual(appState.terminalCommands[0].command, "ls -la")
        XCTAssertEqual(appState.terminalCommands[0].output, "file1.txt\nfile2.txt")
    }
    
    // Test setting the selected file path
    func testSetSelectedFilePath() {
        // Initial state
        XCTAssertNil(appState.selectedFilePath)
        
        // Set the selected file path
        appState.selectedFilePath = "/path/to/file.txt"
        
        // Verify the selected file path was set
        XCTAssertEqual(appState.selectedFilePath, "/path/to/file.txt")
    }
    
    // Test setting the awaiting user confirmation flag
    func testSetAwaitingUserConfirmation() {
        // Initial state
        XCTAssertFalse(appState.isAwaitingUserConfirmation)
        
        // Set the awaiting user confirmation flag
        appState.isAwaitingUserConfirmation = true
        
        // Verify the awaiting user confirmation flag was set
        XCTAssertTrue(appState.isAwaitingUserConfirmation)
    }
    
    // Test adding file nodes to the file structure
    func testAddFileNodes() {
        // Initial state
        XCTAssertEqual(appState.fileStructure.count, 0)
        
        // Add file nodes
        let fileNode1 = FileNode(name: "file1.txt", path: "/path/to/file1.txt", isDirectory: false)
        let fileNode2 = FileNode(name: "directory", path: "/path/to/directory", isDirectory: true)
        appState.fileStructure = [fileNode1, fileNode2]
        
        // Verify the file nodes were added
        XCTAssertEqual(appState.fileStructure.count, 2)
        XCTAssertEqual(appState.fileStructure[0].name, "file1.txt")
        XCTAssertEqual(appState.fileStructure[0].path, "/path/to/file1.txt")
        XCTAssertFalse(appState.fileStructure[0].isDirectory)
        XCTAssertEqual(appState.fileStructure[1].name, "directory")
        XCTAssertEqual(appState.fileStructure[1].path, "/path/to/directory")
        XCTAssertTrue(appState.fileStructure[1].isDirectory)
    }
}