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
            // Log the event for debugging
            print("Processing event: \(event.id) - \(event.source) - \(event.message)")
            
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
            } else {
                // Handle unknown event type
                print("Unknown event type: \(event)")
                
                // Add a message to the chat with the unknown event
                let resultMessage = "Unknown event: \(event.message)"
                let message = Message(text: resultMessage, sender: "system")
                if !appState.messages.contains(where: { $0.text == resultMessage }) {
                    appState.messages.append(message)
                }
            }
            
            // Notify the delegate that an event was processed
            self.delegate?.socketService(self, didProcessEvent: event)
        }
    }
    
    /// Processes an action event and updates the application state
    /// - Parameters:
    ///   - event: The action event to process
    ///   - appState: The application state to update
    private func processActionEvent(_ event: Event, appState: AppState) {
        guard let action = event.action else {
            print("Action event missing action type: \(event)")
            return
        }
        
        print("Processing action event: \(action) from \(event.source)")
        
        switch action {
        case "message":
            // Handle message action
            if event.source == "agent" {
                // Agent message
                if let waitForResponse = event.waitForResponse {
                    appState.isAwaitingUserConfirmation = waitForResponse
                }
                
                // Create message with all available data
                var message = Message(text: event.message, sender: event.source)
                
                // Add thought if available
                if let thought = event.thought {
                    print("Agent thought: \(thought)")
                    message.thought = thought
                }
                
                // Add image URLs if available
                if let imageUrls = event.imageUrls, !imageUrls.isEmpty {
                    print("Agent shared images: \(imageUrls)")
                    message.imageUrls = imageUrls
                }
                
                // Add the message to the messages array if it doesn't already exist
                if !appState.messages.contains(where: { $0.id == message.id }) {
                    appState.messages.append(message)
                }
            } else if event.source == "user" {
                // User message
                var message = Message(text: event.message, sender: event.source)
                
                // Add image URLs if available
                if let args = event.args, let imageUrls = args["image_urls"] as? [String], !imageUrls.isEmpty {
                    print("User shared images: \(imageUrls)")
                    message.imageUrls = imageUrls
                }
                
                // Add the message to the messages array if it doesn't already exist
                if !appState.messages.contains(where: { $0.id == message.id }) {
                    appState.messages.append(message)
                }
            }
            
        case "run":
            // Command execution request
            if let args = event.args, let command = args["command"] as? String {
                // Mark the command as running in the terminal commands
                let terminalCommand = TerminalCommand(
                    id: UUID(),
                    command: command,
                    output: "Running...",
                    exitCode: -1, // -1 indicates running
                    isRunning: true
                )
                
                // Add or update the command in the terminal commands
                if !appState.terminalCommands.contains(where: { $0.command == command }) {
                    appState.terminalCommands.append(terminalCommand)
                } else {
                    // Update the existing command
                    if let index = appState.terminalCommands.firstIndex(where: { $0.command == command }) {
                        appState.terminalCommands[index] = terminalCommand
                    }
                }
                
                // Add a message to the chat about the command execution
                let message = Message(text: "Executing command: \(command)", sender: "system")
                if !appState.messages.contains(where: { $0.text == message.text }) {
                    appState.messages.append(message)
                }
            }
            
        case "read":
            // File read request
            if let args = event.args, let path = args["path"] as? String {
                // Add a message to the chat about the file read
                let message = Message(text: "Reading file: \(path)", sender: "system")
                if !appState.messages.contains(where: { $0.text == message.text }) {
                    appState.messages.append(message)
                }
            }
            
        case "write":
            // File write request
            if let args = event.args, let path = args["path"] as? String {
                // Add a message to the chat about the file write
                let message = Message(text: "Writing to file: \(path)", sender: "system")
                if !appState.messages.contains(where: { $0.text == message.text }) {
                    appState.messages.append(message)
                }
            }
            
        case "edit":
            // File edit request
            if let args = event.args, let path = args["path"] as? String {
                // Add a message to the chat about the file edit
                let message = Message(text: "Editing file: \(path)", sender: "system")
                if !appState.messages.contains(where: { $0.text == message.text }) {
                    appState.messages.append(message)
                }
            }
            
        case "browse":
            // Browser navigation request
            if let args = event.args, let url = args["url"] as? String {
                // Add a message to the chat about the browser navigation
                let message = Message(text: "Navigating to: \(url)", sender: "system")
                if !appState.messages.contains(where: { $0.text == message.text }) {
                    appState.messages.append(message)
                }
            }
            
        case "browse_interactive":
            // Interactive browser request
            if let args = event.args, let code = args["code"] as? String {
                // Add a message to the chat about the interactive browser action
                let message = Message(text: "Executing browser interaction", sender: "system")
                if !appState.messages.contains(where: { $0.text == message.text }) {
                    appState.messages.append(message)
                }
            }
            
        default:
            // Handle unknown action type
            print("Unknown action type: \(action)")
            
            // Add a message to the chat with the unknown action
            let message = Message(text: "Unknown action: \(action)", sender: "system")
            if !appState.messages.contains(where: { $0.text == message.text }) {
                appState.messages.append(message)
            }
        }
    }
    
    /// Processes an observation event and updates the application state
    /// - Parameters:
    ///   - event: The observation event to process
    ///   - appState: The application state to update
    private func processObservationEvent(_ event: Event, appState: AppState) {
        guard let observation = event.observation else {
            print("Observation event missing observation type: \(event)")
            return
        }
        
        print("Processing observation event: \(observation) for event #\(event.cause ?? -1)")
        
        switch observation {
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
                
                // Check if we already have this command in the list
                if !appState.terminalCommands.contains(where: { $0.command == command }) {
                    appState.terminalCommands.append(terminalCommand)
                } else {
                    // Update the existing command with the new output
                    if let index = appState.terminalCommands.firstIndex(where: { $0.command == command }) {
                        appState.terminalCommands[index] = terminalCommand
                    }
                }
                
                // Add a message to the chat with the command result
                let resultMessage: String
                if exitCode == 0 {
                    resultMessage = "Command executed successfully: \(command)"
                } else {
                    resultMessage = "Command executed with error (exit code \(exitCode)): \(command)"
                }
                
                let message = Message(text: resultMessage, sender: "system")
                if !appState.messages.contains(where: { $0.text == resultMessage }) {
                    appState.messages.append(message)
                }
                
                // Update agent state
                appState.isAgentExecuting = false
            }
            
        case "read":
            // Handle file read result
            if let path = event.path {
                appState.selectedFilePath = path
                
                // Store the file content in the app state if available
                if let content = event.content {
                    // Add a message to the chat with the file read result
                    let resultMessage = "File read: \(path)"
                    let message = Message(text: resultMessage, sender: "system")
                    if !appState.messages.contains(where: { $0.text == resultMessage }) {
                        appState.messages.append(message)
                    }
                } else {
                    // Handle error case where content is missing
                    let errorMessage = "Error reading file: \(path)"
                    let message = Message(text: errorMessage, sender: "system")
                    if !appState.messages.contains(where: { $0.text == errorMessage }) {
                        appState.messages.append(message)
                    }
                }
            }
            
        case "write":
            // Handle file write result
            if let extras = event.extras, let path = extras["path"] as? String {
                // Refresh file explorer after file operations
                appState.refreshFileExplorer()
                
                // Add a message to the chat with the file write result
                let resultMessage = "File written: \(path)"
                let message = Message(text: resultMessage, sender: "system")
                if !appState.messages.contains(where: { $0.text == resultMessage }) {
                    appState.messages.append(message)
                }
            } else {
                // Handle error case where path is missing
                let errorMessage = "Error writing file: path not provided"
                let message = Message(text: errorMessage, sender: "system")
                if !appState.messages.contains(where: { $0.text == errorMessage }) {
                    appState.messages.append(message)
                }
            }
            
        case "edit":
            // Handle file edit result
            if let extras = event.extras, let path = extras["path"] as? String {
                // Refresh file explorer after file operations
                appState.refreshFileExplorer()
                
                // Get the diff if available
                let diff = extras["diff"] as? String ?? "No diff available"
                
                // Add a message to the chat with the file edit result
                let resultMessage = "File edited: \(path)"
                let message = Message(text: resultMessage, sender: "system")
                if !appState.messages.contains(where: { $0.text == resultMessage }) {
                    appState.messages.append(message)
                }
            } else {
                // Handle error case where path is missing
                let errorMessage = "Error editing file: path not provided"
                let message = Message(text: errorMessage, sender: "system")
                if !appState.messages.contains(where: { $0.text == errorMessage }) {
                    appState.messages.append(message)
                }
            }
            
        case "browse":
            // Handle browser output
            if let extras = event.extras, let url = extras["url"] as? String {
                // Add a message to the chat with the browser result
                let resultMessage = "Browsed URL: \(url)"
                let message = Message(text: resultMessage, sender: "system")
                if !appState.messages.contains(where: { $0.text == resultMessage }) {
                    appState.messages.append(message)
                }
                
                // Check for screenshot
                if let screenshot = extras["screenshot"] as? String {
                    print("Browser screenshot available")
                    // Create a message with the screenshot URL
                    let screenshotMessage = Message(
                        text: "Browser screenshot",
                        sender: "system",
                        imageUrls: [screenshot]
                    )
                    appState.messages.append(screenshotMessage)
                }
                
                // Check for DOM object
                if let domObject = extras["dom_object"] as? [String: Any] {
                    print("Browser DOM object available: \(domObject)")
                    // You might want to process the DOM object for UI display
                }
            } else {
                // Handle error case where URL is missing
                let errorMessage = "Error browsing: URL not provided"
                let message = Message(text: errorMessage, sender: "system")
                if !appState.messages.contains(where: { $0.text == errorMessage }) {
                    appState.messages.append(message)
                }
            }
            
        case "agent_state_changed":
            // Handle agent state change
            if let extras = event.extras, let agentState = extras["agent_state"] as? String {
                // Update agent state flags
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
                
                // Add a message to the chat with the agent state change
                let resultMessage = "Agent state changed to: \(agentState)"
                let message = Message(text: resultMessage, sender: "system")
                if !appState.messages.contains(where: { $0.text == resultMessage }) {
                    appState.messages.append(message)
                }
            } else {
                // Handle error case where agent state is missing
                let errorMessage = "Error: Agent state not provided"
                let message = Message(text: errorMessage, sender: "system")
                if !appState.messages.contains(where: { $0.text == errorMessage }) {
                    appState.messages.append(message)
                }
            }
            
        case "error":
            // Handle error observation
            let errorMessage: String
            if let extras = event.extras, let errorId = extras["error_id"] as? String {
                errorMessage = "Error: \(errorId) - \(event.message)"
            } else {
                errorMessage = "Error: \(event.message)"
            }
            
            // Update app state error property
            appState.error = errorMessage
            
            // Add a message to the chat with the error
            let message = Message(text: errorMessage, sender: "system")
            if !appState.messages.contains(where: { $0.text == errorMessage }) {
                appState.messages.append(message)
            }
            
        default:
            // Handle unknown observation type
            print("Unknown observation type: \(observation)")
            
            // Add a message to the chat with the unknown observation
            let resultMessage = "Unknown observation: \(observation)"
            let message = Message(text: resultMessage, sender: "system")
            if !appState.messages.contains(where: { $0.text == resultMessage }) {
                appState.messages.append(message)
            }
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