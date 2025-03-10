import XCTest
import Combine
@testable import OpenHandsClient

final class EventManagerTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()
    
    func testEventRouting() {
        // Create mock settings
        let settings = BackendSettings(backendHost: "localhost", backendPort: 8000)
        
        // Create socket service
        let socketService = SocketIOService(settings: settings)
        
        // Create event manager
        let eventManager = EventManager(socketService: socketService)
        
        // Set up expectations
        let commandExpectation = expectation(description: "Command observation received")
        let fileExpectation = expectation(description: "File observation received")
        let agentExpectation = expectation(description: "Agent observation received")
        
        // Subscribe to command observations
        eventManager.commandPublisher
            .sink { observation in
                XCTAssertEqual(observation.output, "Test output")
                XCTAssertEqual(observation.exitCode, 0)
                XCTAssertTrue(observation.isComplete)
                commandExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Subscribe to file observations
        eventManager.filePublisher
            .sink { observation in
                XCTAssertEqual(observation.path, "/test/path")
                XCTAssertEqual(observation.content, "Test content")
                fileExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Subscribe to agent observations
        eventManager.agentPublisher
            .sink { observation in
                XCTAssertEqual(observation.content, "Agent response")
                XCTAssertEqual(observation.status, .responding)
                agentExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Manually trigger events (in a real scenario, these would come from the socket)
        // This is a simplified test that doesn't actually test the socket communication
        
        // Create and route a command observation
        let commandObservation = CommandObservation(
            output: "Test output",
            exitCode: 0,
            isComplete: true
        )
        
        // Create and route a file observation
        let fileObservation = FileObservation(
            path: "/test/path",
            content: "Test content"
        )
        
        // Create and route an agent observation
        let agentObservation = AgentObservation(
            content: "Agent response",
            status: .responding
        )
        
        // In a real test, we would mock the socket service to emit these events
        // For now, we'll just call the private method directly for testing
        // This is not ideal but works for demonstration purposes
        eventManager.perform(#selector(NSSelectorFromString("routeEvent:")), with: commandObservation)
        eventManager.perform(#selector(NSSelectorFromString("routeEvent:")), with: fileObservation)
        eventManager.perform(#selector(NSSelectorFromString("routeEvent:")), with: agentObservation)
        
        // Wait for expectations
        wait(for: [commandExpectation, fileExpectation, agentExpectation], timeout: 1.0)
    }
}