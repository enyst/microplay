import Foundation
import SocketIO

/// SocketService is responsible for managing the WebSocket connection to the OpenHands server.
/// It handles connection, disconnection, and event handling for the socket.io connection.
class SocketService {
    // MARK: - Properties
    
    /// The SocketIO manager instance
    private let manager: SocketManager
    
    /// The default socket instance
    private let socket: SocketIOClient
    
    /// Flag indicating whether the socket is connected
    private(set) var isConnected = false
    
    /// The ID of the latest event received
    private(set) var latestEventId: Int?
    
    /// The ID of the current conversation
    private(set) var conversationId: String?
    
    /// Delegate for handling socket events
    weak var delegate: SocketServiceDelegate?
    
    /// The application state
    private let appState: AppState?
    
    // MARK: - Initialization
    
    /// Initializes a new SocketService with the specified server URL
    /// - Parameters:
    ///   - serverUrl: The URL of the OpenHands server. Defaults to "http://openhands-server:3000"
    ///   - appState: The application state to update. Defaults to nil
    init(serverUrl: URL = URL(string: "http://openhands-server:3000")!, appState: AppState? = nil) {
        self.manager = SocketManager(socketURL: serverUrl, config: [
            .log(true),
            .compress,
            .reconnects(true),
            .reconnectAttempts(10),
            .reconnectWait(5)
        ])
        
        self.socket = manager.defaultSocket
        self.appState = appState
        setupEventListeners()
    }
    
    // MARK: - Public Methods
    
    /// Connects to the OpenHands server with the specified conversation ID and latest event ID
    /// - Parameters:
    ///   - conversationId: The ID of the conversation to join
    ///   - latestEventId: The ID of the latest event received by the client. Defaults to nil
    func connect(conversationId: String, latestEventId: Int? = nil) {
        self.conversationId = conversationId
        self.latestEventId = latestEventId
        
        // Add query parameters for connection
        var params: [String: Any] = ["conversation_id": conversationId]
        if let latestEventId = latestEventId {
            params["latest_event_id"] = latestEventId
        }
        
        socket.connect(withPayload: params)
    }
    
    /// Disconnects from the OpenHands server
    func disconnect() {
        socket.disconnect()
    }
    
    /// Sends an action to the server
    /// - Parameters:
    ///   - action: The type of action to send
    ///   - args: The arguments for the action
    func sendAction(action: String, args: [String: Any]) {
        let data: [String: Any] = [
            "action": action,
            "args": args
        ]
        
        socket.emit("oh_action", data)
    }
    
    /// Sends a user message to the server
    /// - Parameters:
    ///   - content: The content of the message
    ///   - imageUrls: Optional array of image URLs to include with the message
    func sendMessage(content: String, imageUrls: [String]? = nil) {
        var args: [String: Any] = [
            "content": content,
            "source": "user"
        ]
        
        if let imageUrls = imageUrls {
            args["image_urls"] = imageUrls
        }
        
        sendAction(action: "message", args: args)
    }
    
    /// Executes a command on the server
    /// - Parameters:
    ///   - command: The command to execute
    ///   - securityRisk: Whether the command poses a security risk
    ///   - confirmationState: The confirmation state for the command
    ///   - thought: The thought process behind the command
    func executeCommand(command: String, securityRisk: Bool = false, confirmationState: String? = nil, thought: String? = nil) {
        var args: [String: Any] = [
            "command": command,
            "security_risk": securityRisk
        ]
        
        if let confirmationState = confirmationState {
            args["confirmation_state"] = confirmationState
        }
        
        if let thought = thought {
            args["thought"] = thought
        }
        
        sendAction(action: "run", args: args)
    }
    
    /// Reads a file from the server
    /// - Parameter path: The path of the file to read
    func readFile(path: String) {
        let args: [String: Any] = [
            "path": path
        ]
        
        sendAction(action: "read", args: args)
    }
    
    /// Writes to a file on the server
    /// - Parameters:
    ///   - path: The path of the file to write
    ///   - content: The content to write to the file
    func writeFile(path: String, content: String) {
        let args: [String: Any] = [
            "path": path,
            "content": content
        ]
        
        sendAction(action: "write", args: args)
    }
    
    /// Edits a file on the server
    /// - Parameters:
    ///   - path: The path of the file to edit
    ///   - oldContent: The old content of the file
    ///   - newContent: The new content of the file
    func editFile(path: String, oldContent: String, newContent: String) {
        let args: [String: Any] = [
            "path": path,
            "old_content": oldContent,
            "new_content": newContent
        ]
        
        sendAction(action: "edit", args: args)
    }
    
    /// Navigates to a URL in the browser
    /// - Parameter url: The URL to navigate to
    func browseUrl(url: String) {
        let args: [String: Any] = [
            "url": url
        ]
        
        sendAction(action: "browse", args: args)
    }
    
    /// Interacts with the browser
    /// - Parameter code: The code to execute in the browser
    func browseInteractive(code: String) {
        let args: [String: Any] = [
            "code": code
        ]
        
        sendAction(action: "browse_interactive", args: args)
    }
    
    // MARK: - Private Methods
    
    /// Sets up the event listeners for the socket
    private func setupEventListeners() {
        // Handle connection event
        socket.on(clientEvent: .connect) { [weak self] data, _ in
            guard let self = self else { return }
            print("Socket connected")
            self.isConnected = true
            
            // Update app state
            DispatchQueue.main.async {
                self.appState?.isConnected = true
            }
            
            // Notify the delegate
            self.delegate?.socketServiceDidConnect(self)
        }
        
        // Handle disconnection event
        socket.on(clientEvent: .disconnect) { [weak self] data, _ in
            guard let self = self else { return }
            print("Socket disconnected")
            self.isConnected = false
            
            // Update app state
            DispatchQueue.main.async {
                self.appState?.isConnected = false
            }
            
            // Notify the delegate
            self.delegate?.socketServiceDidDisconnect(self)
        }
        
        // Handle error event
        socket.on(clientEvent: .error) { [weak self] data, _ in
            guard let self = self else { return }
            
            var errorMessage: String = "Unknown socket error"
            
            if let errorString = data[0] as? String {
                print("Socket error: \(errorString)")
                errorMessage = errorString
            } else if let error = data[0] as? Error {
                print("Socket error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            } else {
                print("Socket error occurred")
            }
            
            let error = NSError(domain: "SocketIOError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            
            // Update app state
            DispatchQueue.main.async {
                self.appState?.error = errorMessage
            }
            
            // Notify the delegate
            self.delegate?.socketService(self, didEncounterError: error)
        }
        
        // Handle reconnection event
        socket.on(clientEvent: .reconnect) { [weak self] data, _ in
            guard let self = self else { return }
            print("Socket reconnected")
            self.isConnected = true
            
            // Update app state
            DispatchQueue.main.async {
                self.appState?.isConnected = true
            }
            
            // Notify the delegate
            self.delegate?.socketServiceDidConnect(self)
        }
        
        // Handle oh_event from server
        socket.on("oh_event") { [weak self] data, _ in
            guard let self = self else { return }
            
            guard let eventData = data[0] as? [String: Any] else {
                print("Invalid event data received")
                let error = NSError(domain: "SocketIOError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid event data received"])
                
                // Update app state
                DispatchQueue.main.async {
                    self.appState?.error = "Invalid event data received"
                }
                
                // Notify the delegate
                self.delegate?.socketService(self, didEncounterError: error)
                return
            }
            
            // Process the event data
            self.processEvent(eventData)
        }
    }
    
    /// Processes an event received from the server
    /// - Parameter eventData: The event data to process
    private func processEvent(_ eventData: [String: Any]) {
        // Convert the event data to an Event object
        guard let event = Event.from(dict: eventData) else {
            print("Failed to parse event data")
            return
        }
        
        // Update latest event ID
        if event.id > (latestEventId ?? 0) {
            latestEventId = event.id
        }
        
        // Print event information
        print("Received event #\(event.id) from \(event.source): \(event.message)")
        
        // Update app state based on event type
        updateAppState(with: event)
        
        // Notify the delegate
        delegate?.socketService(self, didReceiveEvent: event)
    }
    
    /// Updates the application state based on the received event
    /// - Parameter event: The event to process
    private func updateAppState(with event: Event) {
        guard let appState = appState else { return }
        
        DispatchQueue.main.async {
            // Add the event to the events array
            if !appState.events.contains(where: { $0.id == event.id }) {
                appState.events.append(event)
                // Sort events by ID in descending order
                appState.events.sort(by: { $0.id > $1.id })
            }
            
            // Process different event types
            if event.isAction {
                self.processActionEvent(event, appState: appState)
            } else if event.isObservation {
                self.processObservationEvent(event, appState: appState)
            }
        }
    }
    
    /// Processes an action event and updates the application state
    /// - Parameters:
    ///   - event: The action event to process
    ///   - appState: The application state to update
    private func processActionEvent(_ event: Event, appState: AppState) {
        // Handle specific action types
        if event.isMessage {
            // Handle message action
            if event.source == "agent" {
                // Agent message
                if let waitForResponse = event.waitForResponse {
                    appState.isAwaitingUserConfirmation = waitForResponse
                }
            }
        }
    }
    
    /// Processes an observation event and updates the application state
    /// - Parameters:
    ///   - event: The observation event to process
    ///   - appState: The application state to update
    private func processObservationEvent(_ event: Event, appState: AppState) {
        // Handle specific observation types
        switch event.observation {
        case "run":
            // Handle command execution result
            if let command = event.command, let exitCode = event.exitCode {
                let terminalCommand = TerminalCommand(
                    id: UUID(),
                    command: command,
                    output: event.content ?? "",
                    exitCode: exitCode,
                    isRunning: false
                )
                appState.terminalCommands.append(terminalCommand)
            }
            
        case "read":
            // Handle file read result
            if let path = event.path {
                appState.selectedFilePath = path
                // You might want to store the file content in the app state as well
            }
            
        case "write", "edit":
            // Handle file write/edit result
            if let path = event.path {
                // Refresh file explorer after file operations
                appState.refreshFileExplorer()
            }
            
        case "browse":
            // Handle browser output
            if let url = event.url {
                // Update browser state
            }
            
        case "agent_state_changed":
            // Handle agent state change
            if let agentState = event.agentState {
                appState.isAgentThinking = agentState == "thinking"
                appState.isAgentExecuting = agentState == "executing"
                
                // Update other agent state properties as needed
                switch agentState {
                case "idle":
                    appState.isAwaitingUserConfirmation = false
                case "waiting_for_user_input":
                    appState.isAwaitingUserConfirmation = true
                default:
                    break
                }
            }
            
        case "error":
            // Handle error observation
            if let errorId = event.errorId {
                appState.error = "Error: \(errorId) - \(event.message)"
            } else {
                appState.error = "Error: \(event.message)"
            }
            
        default:
            break
        }
    }
}

/// Represents a terminal command with its output and status
struct TerminalCommand: Identifiable {
    let id: UUID
    let command: String
    let output: String
    let exitCode: Int
    let isRunning: Bool
}