import Foundation
import SocketIO

/// SocketManager is responsible for managing the WebSocket connection to the OpenHands server.
/// It handles connection, disconnection, and event handling for the socket.io connection.
class SocketManager {
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
    weak var delegate: SocketManagerDelegate?
    
    // MARK: - Initialization
    
    /// Initializes a new SocketManager with the specified server URL
    /// - Parameter serverUrl: The URL of the OpenHands server. Defaults to "http://openhands-server:3000"
    init(serverUrl: URL = URL(string: "http://openhands-server:3000")!) {
        self.manager = SocketManager(socketURL: serverUrl, config: [
            .log(true),
            .compress,
            .reconnects(true),
            .reconnectAttempts(10),
            .reconnectWait(5)
        ])
        
        self.socket = manager.defaultSocket
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
            
            // Notify the delegate
            self.delegate?.socketManagerDidConnect(self)
        }
        
        // Handle disconnection event
        socket.on(clientEvent: .disconnect) { [weak self] data, _ in
            guard let self = self else { return }
            print("Socket disconnected")
            self.isConnected = false
            
            // Notify the delegate
            self.delegate?.socketManagerDidDisconnect(self)
        }
        
        // Handle error event
        socket.on(clientEvent: .error) { [weak self] data, _ in
            guard let self = self else { return }
            
            if let errorString = data[0] as? String {
                print("Socket error: \(errorString)")
                let error = NSError(domain: "SocketIOError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorString])
                self.delegate?.socketManager(self, didEncounterError: error)
            } else if let error = data[0] as? Error {
                print("Socket error: \(error.localizedDescription)")
                self.delegate?.socketManager(self, didEncounterError: error)
            } else {
                print("Socket error occurred")
                let error = NSError(domain: "SocketIOError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown socket error"])
                self.delegate?.socketManager(self, didEncounterError: error)
            }
        }
        
        // Handle reconnection event
        socket.on(clientEvent: .reconnect) { [weak self] data, _ in
            guard let self = self else { return }
            print("Socket reconnected")
            self.isConnected = true
            
            // Notify the delegate
            self.delegate?.socketManagerDidConnect(self)
        }
        
        // Handle oh_event from server
        socket.on("oh_event") { [weak self] data, _ in
            guard let self = self else { return }
            
            guard let eventData = data[0] as? [String: Any] else {
                print("Invalid event data received")
                let error = NSError(domain: "SocketIOError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid event data received"])
                self.delegate?.socketManager(self, didEncounterError: error)
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
        
        // Process different event types
        if event.isAction {
            // Handle action events
            print("Action: \(event.action ?? "unknown")")
            if let args = event.args {
                print("Args: \(args)")
            }
            
            // Handle specific action types
            if event.isMessage {
                if let thought = event.thought {
                    print("Thought: \(thought)")
                }
                if let imageUrls = event.imageUrls {
                    print("Image URLs: \(imageUrls)")
                }
                if let waitForResponse = event.waitForResponse {
                    print("Wait for response: \(waitForResponse)")
                }
            }
        } else if event.isObservation {
            // Handle observation events
            print("Observation: \(event.observation ?? "unknown")")
            if let content = event.content {
                print("Content: \(content)")
            }
            if let extras = event.extras {
                print("Extras: \(extras)")
            }
            
            // Handle specific observation types
            switch event.observation {
            case "run":
                if let command = event.command {
                    print("Command: \(command)")
                }
                if let exitCode = event.exitCode {
                    print("Exit code: \(exitCode)")
                }
            case "read", "write", "edit":
                if let path = event.path {
                    print("Path: \(path)")
                }
            case "browse":
                if let url = event.url {
                    print("URL: \(url)")
                }
            case "agent_state_changed":
                if let agentState = event.agentState {
                    print("Agent state: \(agentState)")
                }
            case "error":
                if let errorId = event.errorId {
                    print("Error ID: \(errorId)")
                }
            default:
                break
            }
            
            // Check for cause
            if let cause = event.cause {
                print("Caused by event #\(cause)")
            }
        }
        
        // Notify the delegate
        delegate?.socketManager(self, didReceiveEvent: event)
    }
}