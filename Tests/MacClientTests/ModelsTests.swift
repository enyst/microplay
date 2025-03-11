import XCTest
@testable import MacClient

class ModelsTests: XCTestCase {
    
    static var allTests = [
        ("testMessageModel", testMessageModel),
        ("testTerminalCommandModel", testTerminalCommandModel),
        ("testFileNodeModel", testFileNodeModel),
        ("testFileNodeWithChildren", testFileNodeWithChildren)
    ]
    // Test Message model
    func testMessageModel() {
        let message = Message(text: "Hello, world!", sender: "agent")
        
        XCTAssertEqual(message.text, "Hello, world!")
        XCTAssertEqual(message.sender, "agent")
        XCTAssertNotNil(message.id)
    }
    
    // Test TerminalCommand model
    func testTerminalCommandModel() {
        let command = TerminalCommand(command: "ls -la", output: "file1.txt\nfile2.txt")
        
        XCTAssertEqual(command.command, "ls -la")
        XCTAssertEqual(command.output, "file1.txt\nfile2.txt")
        XCTAssertNotNil(command.id)
    }
    
    // Test FileNode model
    func testFileNodeModel() {
        let fileNode = FileNode(name: "file.txt", path: "/path/to/file.txt", isDirectory: false)
        
        XCTAssertEqual(fileNode.name, "file.txt")
        XCTAssertEqual(fileNode.path, "/path/to/file.txt")
        XCTAssertFalse(fileNode.isDirectory)
        XCTAssertNotNil(fileNode.id)
    }
    
    // Test FileNode with children
    func testFileNodeWithChildren() {
        let childNode1 = FileNode(name: "child1.txt", path: "/path/to/directory/child1.txt", isDirectory: false)
        let childNode2 = FileNode(name: "child2.txt", path: "/path/to/directory/child2.txt", isDirectory: false)
        let directoryNode = FileNode(
            name: "directory",
            path: "/path/to/directory",
            isDirectory: true,
            children: [childNode1, childNode2]
        )
        
        XCTAssertEqual(directoryNode.name, "directory")
        XCTAssertEqual(directoryNode.path, "/path/to/directory")
        XCTAssertTrue(directoryNode.isDirectory)
        XCTAssertEqual(directoryNode.children.count, 2)
        XCTAssertEqual(directoryNode.children[0].name, "child1.txt")
        XCTAssertEqual(directoryNode.children[1].name, "child2.txt")
    }
}