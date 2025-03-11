import Foundation
import SwiftUI

/// AppState is responsible for managing the state of the application.
/// It acts as a central store for all application data and coordinates
/// between the UI and the socket service.
class AppState: ObservableObject {
    // MARK: - Properties
    
    /// The socket service instance
    private let socketService: SocketService
    
    /// Flag indicating whether the socket is connected
    @Published var isConnected = false
    
    /// The current conversation ID
    @Published var conversationId: String = ""
    
    /// The events received from the server
    @Published var events: [Event] = []
    
    /// The messages in the chat interface
    @Published var messages: [Message] = []
    
    /// The latest error message
    @Published var error: String?
    
    /// The current user message
    @Published var userMessage: String = ""
    
    /// Flag indicating whether the agent is thinking
    @Published var isAgentThinking = false
    
    /// Flag indicating whether the agent is executing a command
    @Published var isAgentExecuting = false
    
    /// Flag indicating whether the agent is awaiting user confirmation
    @Published var isAwaitingUserConfirmation = false
    
    /// The currently selected file path
    @Published var selectedFilePath: String? = nil
    
    /// The terminal commands executed
    @Published var terminalCommands: [TerminalCommand] = []
    
    /// The file structure for the file explorer
    @Published var fileStructure: [FileNode] = []
    
    /// The contents of files that have been read
    @Published var fileContents: [String: String] = [:]
    
    /// The DOM objects from browser operations
    @Published var domObjects: [String: [String: Any]] = [:]
    
    /// The HTML content from browser operations
    @Published var htmlContents: [String: String] = [:]
    
    // MARK: - Initialization
    
    /// Initializes a new AppState with the specified server URL
    /// - Parameter serverUrl: The URL of the OpenHands server. Defaults to "http://openhands-server:3000"
    init(serverUrl: URL = URL(string: "http://openhands-server:3000")!) {
        // Create socket service with reference to this AppState
        self.socketService = SocketService(serverUrl: serverUrl, appState: self)
        self.socketService.delegate = self
    }
    
    // MARK: - Public Methods
    
    /// Connects to the OpenHands server with the specified conversation ID
    /// - Parameter conversationId: The ID of the conversation to join
    func connect(conversationId: String) {
        guard !conversationId.isEmpty else { return }
        
        self.conversationId = conversationId
        socketService.connect(conversationId: conversationId)
    }
    
    /// Disconnects from the OpenHands server
    func disconnect() {
        socketService.disconnect()
    }
    
    /// Sends a message to the OpenHands server
    /// - Parameter content: The content of the message
    func sendMessage(content: String) {
        guard !content.isEmpty, isConnected else { return }
        
        socketService.sendMessage(content: content)
        userMessage = ""
    }
    
    /// Executes a command on the OpenHands server
    /// - Parameter command: The command to execute
    func executeCommand(command: String) {
        guard !command.isEmpty, isConnected else { return }
        
        socketService.executeCommand(command: command)
    }
    
    /// Reads a file from the OpenHands server
    /// - Parameter path: The path of the file to read
    func readFile(path: String) {
        guard !path.isEmpty, isConnected else { return }
        
        socketService.readFile(path: path)
    }
    
    /// Writes to a file on the OpenHands server
    /// - Parameters:
    ///   - path: The path of the file to write
    ///   - content: The content to write to the file
    func writeFile(path: String, content: String) {
        guard !path.isEmpty, !content.isEmpty, isConnected else { return }
        
        socketService.writeFile(path: path, content: content)
    }
    
    /// Edits a file on the OpenHands server
    /// - Parameters:
    ///   - path: The path of the file to edit
    ///   - oldContent: The old content of the file
    ///   - newContent: The new content of the file
    func editFile(path: String, oldContent: String, newContent: String) {
        guard !path.isEmpty, !oldContent.isEmpty, !newContent.isEmpty, isConnected else { return }
        
        socketService.editFile(path: path, oldContent: oldContent, newContent: newContent)
    }
    
    /// Navigates to a URL in the browser
    /// - Parameter url: The URL to navigate to
    func browseUrl(url: String) {
        guard !url.isEmpty, isConnected else { return }
        
        socketService.browseUrl(url: url)
    }
    
    /// Interacts with the browser
    /// - Parameter code: The code to execute in the browser
    func browseInteractive(code: String) {
        guard !code.isEmpty, isConnected else { return }
        
        socketService.browseInteractive(code: code)
    }
    
    /// Refreshes the file explorer
    func refreshFileExplorer() {
        // This would typically involve a server request to get the file structure
        // For now, we'll just log that it was called
        print("Refreshing file explorer")
        
        // In a real implementation, you would:
        // 1. Request the file structure from the server
        // 2. Parse the response
        // 3. Update the fileStructure property
    }
}

// MARK: - SocketServiceDelegate

extension AppState: SocketServiceDelegate {
    func socketService(_ service: SocketService, didReceiveEvent event: Event) {
        DispatchQueue.main.async {
            // Add the event to the events array if it doesn't already exist
            if !self.events.contains(where: { $0.id == event.id }) {
                self.events.insert(event, at: 0)
            }
            
            // Clear any error
            self.error = nil
        }
    }
    
    func socketService(_ service: SocketService, didProcessEvent event: Event) {
        DispatchQueue.main.async {
            // Log that the event was processed
            print("Event processed: \(event.id) - \(event.source) - \(event.message)")
            
            // Update the UI based on the processed event
            // This is handled by the SocketService's updateAppState method
        }
    }
    
    func socketServiceDidConnect(_ service: SocketService) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.error = nil
        }
    }
    
    func socketServiceDidDisconnect(_ service: SocketService) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    func socketService(_ service: SocketService, didEncounterError error: Error) {
        DispatchQueue.main.async {
            self.error = error.localizedDescription
        }
    }
}

/// Represents a file node in the file explorer
struct FileNode: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    var children: [FileNode]?
    var isExpanded: Bool = false
}