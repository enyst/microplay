# Socket.IO Implementation Guide for Mac Client

This document outlines the implementation details for Socket.IO in the Mac client, including connection management, error handling, and event processing.

## 1. Socket.IO Connection Setup

### 1.1 Basic Connection Configuration

```swift
import SocketIO

class SocketManager {
    private let manager: SocketManager
    private var socket: SocketIOClient
    private var lastEventId: Int = -1
    private var conversationId: String
    
    init(conversationId: String) {
        self.conversationId = conversationId
        
        // Configure the Socket.IO manager
        let url = URL(string: AppConfig.backendBaseURL)!
        manager = SocketManager(socketURL: url, config: [
            .log(true),
            .compress,
            .forceWebsockets(true),
            .reconnects(true),
            .reconnectAttempts(10),
            .reconnectWait(5),
            .connectParams(["conversation_id": conversationId, 
                           "latest_event_id": lastEventId])
        ])
        
        socket = manager.defaultSocket
        setupSocketHandlers()
    }
    
    private func setupSocketHandlers() {
        // Connection handlers
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            self?.handleConnect()
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] data, _ in
            self?.handleDisconnect(data: data)
        }
        
        socket.on(clientEvent: .error) { [weak self] data, _ in
            self?.handleError(data: data)
        }
        
        // Event handlers
        socket.on("oh_event") { [weak self] data, _ in
            self?.handleEvent(data: data)
        }
    }
    
    func connect() {
        socket.connect()
    }
    
    func disconnect() {
        socket.disconnect()
    }
}
```

### 1.2 Connection Status Management

```swift
enum ConnectionStatus {
    case connected
    case disconnected
    case connecting
    case error(String)
}

class SocketManager {
    // ... previous code ...
    
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected
    
    private func handleConnect() {
        connectionStatus = .connected
        NotificationCenter.default.post(name: .socketConnected, object: nil)
    }
    
    private func handleDisconnect(data: [Any]) {
        connectionStatus = .disconnected
        
        // Update connection params with the latest event ID for reconnection
        if let lastId = lastEventId {
            socket.setConnectionParameters(["latest_event_id": lastId])
        }
        
        NotificationCenter.default.post(name: .socketDisconnected, object: nil)
    }
    
    private func handleError(data: [Any]) {
        let errorMessage = extractErrorMessage(from: data)
        connectionStatus = .error(errorMessage)
        NotificationCenter.default.post(name: .socketError, object: errorMessage)
    }
}
```

## 2. Reconnection Strategy

The Mac client implements a robust reconnection strategy to handle network interruptions:

### 2.1 Automatic Reconnection

```swift
// In SocketManager initialization
manager = SocketManager(socketURL: url, config: [
    .reconnects(true),
    .reconnectAttempts(10),  // Try to reconnect up to 10 times
    .reconnectWait(5),       // Wait 5 seconds between attempts
    .randomizationFactor(0.5) // Add randomization to prevent thundering herd
])
```

### 2.2 Exponential Backoff

For more advanced reconnection handling, implement an exponential backoff strategy:

```swift
class ReconnectionManager {
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private var timer: Timer?
    
    func attemptReconnect(socketManager: SocketManager) {
        guard reconnectAttempts < maxReconnectAttempts else {
            // Max attempts reached, notify user
            NotificationCenter.default.post(
                name: .reconnectionFailed, 
                object: "Failed to reconnect after \(maxReconnectAttempts) attempts"
            )
            return
        }
        
        // Calculate delay with exponential backoff
        let delay = min(30, pow(2.0, Double(reconnectAttempts)))
        reconnectAttempts += 1
        
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            socketManager.connect()
        }
    }
    
    func resetAttempts() {
        reconnectAttempts = 0
        timer?.invalidate()
        timer = nil
    }
}
```

## 3. Error Handling

### 3.1 Error Types and Handling

```swift
enum SocketError: Error {
    case connectionFailed(String)
    case messageError(String, metadata: [String: Any]?)
    case disconnected
    case timeout
}

extension SocketManager {
    private func extractErrorMessage(from data: [Any]) -> String {
        // Extract error message from Socket.IO error data
        if let errorData = data.first as? [String: Any],
           let message = errorData["message"] as? String {
            return message
        }
        return "Unknown error occurred"
    }
    
    private func handleError(data: [Any]) {
        let errorMessage = extractErrorMessage(from: data)
        var metadata: [String: Any]? = nil
        
        // Extract additional error metadata if available
        if let errorData = data.first as? [String: Any],
           let dataDict = errorData["data"] as? [String: Any] {
            metadata = dataDict
        }
        
        // Create appropriate error type
        let error = SocketError.messageError(errorMessage, metadata: metadata)
        
        // Update UI and notify observers
        connectionStatus = .error(errorMessage)
        NotificationCenter.default.post(name: .socketError, object: error)
        
        // Log error for debugging
        Logger.error("Socket error: \(errorMessage)", metadata: metadata)
    }
}
```

### 3.2 User Feedback for Errors

```swift
class ConnectionStatusView: View {
    @ObservedObject var socketManager: SocketManager
    
    var body: some View {
        switch socketManager.connectionStatus {
        case .connected:
            Label("Connected", systemImage: "wifi")
                .foregroundColor(.green)
        case .connecting:
            Label("Connecting...", systemImage: "wifi.exclamationmark")
                .foregroundColor(.yellow)
        case .disconnected:
            Label("Disconnected", systemImage: "wifi.slash")
                .foregroundColor(.red)
        case .error(let message):
            VStack {
                Label("Connection Error", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                Button("Retry") {
                    socketManager.connect()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
```

## 4. Event Queuing During Disconnections

### 4.1 Outgoing Event Queue

```swift
class SocketManager {
    // ... previous code ...
    
    private var outgoingEventQueue: [SocketEvent] = []
    private var isProcessingQueue = false
    
    struct SocketEvent {
        let eventName: String
        let payload: [String: Any]
        let timestamp: Date
    }
    
    func sendUserAction(type: String, args: [String: Any]) {
        let payload: [String: Any] = [
            "type": type,
            "args": args,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // If connected, send immediately
        if connectionStatus == .connected {
            socket.emit("oh_action", payload)
        } else {
            // Otherwise, queue for later
            let event = SocketEvent(
                eventName: "oh_action", 
                payload: payload,
                timestamp: Date()
            )
            outgoingEventQueue.append(event)
            
            // Attempt to connect if disconnected
            if connectionStatus == .disconnected {
                connect()
            }
        }
    }
    
    private func processEventQueue() {
        guard !isProcessingQueue && !outgoingEventQueue.isEmpty else {
            return
        }
        
        isProcessingQueue = true
        
        // Process events in order
        while !outgoingEventQueue.isEmpty && connectionStatus == .connected {
            let event = outgoingEventQueue.removeFirst()
            socket.emit(event.eventName, event.payload)
        }
        
        isProcessingQueue = false
    }
    
    private func handleConnect() {
        connectionStatus = .connected
        NotificationCenter.default.post(name: .socketConnected, object: nil)
        
        // Process queued events when connection is established
        processEventQueue()
    }
}
```

### 4.2 Event Persistence

For critical events that must survive app restarts:

```swift
extension SocketManager {
    // Save queued events to persistent storage
    private func persistEventQueue() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(outgoingEventQueue) {
            UserDefaults.standard.set(encoded, forKey: "queued_events")
        }
    }
    
    // Load queued events from persistent storage
    private func loadPersistedEvents() {
        if let data = UserDefaults.standard.data(forKey: "queued_events"),
           let events = try? JSONDecoder().decode([SocketEvent].self, from: data) {
            // Filter out events older than 24 hours
            let cutoffDate = Date().addingTimeInterval(-86400)
            outgoingEventQueue = events.filter { $0.timestamp > cutoffDate }
        }
    }
}
```

## 5. Integration with SwiftUI

### 5.1 Socket Manager as Observable Object

```swift
class SocketManager: ObservableObject {
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected
    @Published private(set) var events: [OpenHandsEvent] = []
    @Published private(set) var isLoadingMessages = false
    
    // ... rest of implementation ...
}
```

### 5.2 Using in SwiftUI Views

```swift
struct ConversationView: View {
    @StateObject private var socketManager: SocketManager
    
    init(conversationId: String) {
        _socketManager = StateObject(wrappedValue: SocketManager(conversationId: conversationId))
    }
    
    var body: some View {
        VStack {
            ConnectionStatusView(socketManager: socketManager)
            
            MessageList(events: socketManager.events)
            
            MessageInputField(onSend: { message in
                socketManager.sendUserAction(type: "message", args: ["content": message])
            })
        }
        .onAppear {
            socketManager.connect()
        }
        .onDisappear {
            socketManager.disconnect()
        }
    }
}
```

## 6. Testing Socket.IO Implementation

### 6.1 Mock Socket for Testing

```swift
class MockSocketManager: SocketManager {
    override func connect() {
        // Simulate connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.connectionStatus = .connected
            NotificationCenter.default.post(name: .socketConnected, object: nil)
        }
    }
    
    override func sendUserAction(type: String, args: [String: Any]) {
        // Simulate sending and receiving a response
        let payload: [String: Any] = [
            "type": type,
            "args": args,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Simulate response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let responseEvent = OpenHandsEvent(
                id: UUID().uuidString,
                source: "agent",
                type: "message",
                message: "This is a mock response",
                timestamp: Date()
            )
            self.events.append(responseEvent)
        }
    }
}
```

This implementation guide provides a comprehensive approach to Socket.IO integration in the Mac client, covering connection management, error handling, event queuing, and SwiftUI integration.