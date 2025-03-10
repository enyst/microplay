import XCTest
import Combine
@testable import OpenHandsClient

final class ClientViewModelTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()
    
    func testConnectionStatusUpdates() {
        // Create mock settings
        let settings = BackendSettings(backendHost: "localhost", backendPort: 8000)
        
        // Create view model
        let viewModel = ClientViewModel(settings: settings)
        
        // Set up expectations
        let connectionExpectation = expectation(description: "Connection status updated")
        
        // Subscribe to connection status changes
        viewModel.$isConnected
            .dropFirst() // Skip initial value
            .sink { isConnected in
                XCTAssertTrue(isConnected)
                connectionExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Connect to server
        viewModel.connect()
        
        // In a real test, we would mock the socket connection
        // For now, we'll just wait for a short time
        // This is not ideal but works for demonstration purposes
        
        // Wait for expectations with a short timeout
        wait(for: [connectionExpectation], timeout: 0.1)
    }
    
    func testCommandExecution() {
        // Create mock settings
        let settings = BackendSettings(backendHost: "localhost", backendPort: 8000)
        
        // Create view model
        let viewModel = ClientViewModel(settings: settings)
        
        // Set up expectations
        let commandExpectation = expectation(description: "Command output updated")
        
        // Subscribe to command output changes
        viewModel.$commandOutput
            .dropFirst() // Skip initial value
            .sink { output in
                XCTAssertFalse(output.isEmpty)
                commandExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Execute command
        viewModel.executeCommand("ls -la")
        
        // In a real test, we would mock the event manager and socket service
        // For now, we'll just wait for a short time
        // This is not ideal but works for demonstration purposes
        
        // Wait for expectations with a short timeout
        wait(for: [commandExpectation], timeout: 0.1)
    }
    
    func testFileOperations() {
        // Create mock settings
        let settings = BackendSettings(backendHost: "localhost", backendPort: 8000)
        
        // Create view model
        let viewModel = ClientViewModel(settings: settings)
        
        // Set up expectations
        let fileContentExpectation = expectation(description: "File content updated")
        
        // Subscribe to file content changes
        viewModel.$fileContent
            .dropFirst() // Skip initial value
            .sink { content in
                XCTAssertNotNil(content)
                fileContentExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Read file
        viewModel.readFile(path: "/test/file.txt")
        
        // In a real test, we would mock the event manager and socket service
        // For now, we'll just wait for a short time
        // This is not ideal but works for demonstration purposes
        
        // Wait for expectations with a short timeout
        wait(for: [fileContentExpectation], timeout: 0.1)
    }
    
    func testAgentControl() {
        // Create mock settings
        let settings = BackendSettings(backendHost: "localhost", backendPort: 8000)
        
        // Create view model
        let viewModel = ClientViewModel(settings: settings)
        
        // Set up expectations
        let agentStatusExpectation = expectation(description: "Agent status updated")
        
        // Subscribe to agent status changes
        viewModel.$agentStatus
            .dropFirst() // Skip initial value
            .sink { status in
                XCTAssertEqual(status, .thinking)
                agentStatusExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Start agent
        viewModel.startAgent()
        
        // In a real test, we would mock the event manager and socket service
        // For now, we'll just wait for a short time
        // This is not ideal but works for demonstration purposes
        
        // Wait for expectations with a short timeout
        wait(for: [agentStatusExpectation], timeout: 0.1)
    }
}