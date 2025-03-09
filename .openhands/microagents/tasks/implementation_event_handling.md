# Event Handling Architecture for Mac Client

This document outlines the implementation details for event handling in the Mac client, including processing and routing events from the backend, event prioritization, and queueing mechanisms.

## 1. Event System Architecture

### 1.1 Event Types and Definitions

```swift
// MARK: - Event Types

// Base protocol for all events
protocol Event {
    var id: String { get }
    var timestamp: Date { get }
    var type: EventType { get }
}

// Event types enum
enum EventType: String, Codable {
    // System events
    case connectionEstablished = "connection_established"
    case connectionLost = "connection_lost"
    case connectionError = "connection_error"
    case authRequired = "auth_required"
    case authSuccess = "auth_success"
    case authFailure = "auth_failure"
    
    // Agent events
    case agentThinking = "agent_thinking"
    case agentResponse = "agent_response"
    case agentError = "agent_error"
    case agentComplete = "agent_complete"
    
    // Conversation events
    case conversationCreated = "conversation_created"
    case conversationUpdated = "conversation_updated"
    case conversationDeleted = "conversation_deleted"
    case messageReceived = "message_received"
    case messageUpdated = "message_updated"
    
    // File system events
    case fileCreated = "file_created"
    case fileUpdated = "file_updated"
    case fileDeleted = "file_deleted"
    case fileContentChanged = "file_content_changed"
    
    // User events
    case userJoined = "user_joined"
    case userLeft = "user_left"
    case userActivity = "user_activity"
    
    // Custom events
    case custom = "custom"
}

// Base event implementation
struct BaseEvent: Event, Codable {
    let id: String
    let timestamp: Date
    let type: EventType
    let payload: [String: AnyCodable]?
    
    init(id: String = UUID().uuidString, type: EventType, payload: [String: Any]? = nil) {
        self.id = id
        self.timestamp = Date()
        self.type = type
        self.payload = payload?.mapValues { AnyCodable($0) }
    }
}

// Specialized event types
struct AgentResponseEvent: Event, Codable {
    let id: String
    let timestamp: Date
    let type: EventType = .agentResponse
    let conversationId: String
    let messageId: String
    let content: String
    let isComplete: Bool
    let metadata: [String: AnyCodable]?
    
    init(id: String = UUID().uuidString, conversationId: String, messageId: String, content: String, isComplete: Bool, metadata: [String: Any]? = nil) {
        self.id = id
        self.timestamp = Date()
        self.conversationId = conversationId
        self.messageId = messageId
        self.content = content
        self.isComplete = isComplete
        self.metadata = metadata?.mapValues { AnyCodable($0) }
    }
}

struct MessageReceivedEvent: Event, Codable {
    let id: String
    let timestamp: Date
    let type: EventType = .messageReceived
    let conversationId: String
    let message: Message
    
    init(id: String = UUID().uuidString, conversationId: String, message: Message) {
        self.id = id
        self.timestamp = Date()
        self.conversationId = conversationId
        self.message = message
    }
}

struct ConnectionEvent: Event, Codable {
    let id: String
    let timestamp: Date
    let type: EventType
    let status: ConnectionStatus
    let error: String?
    
    init(id: String = UUID().uuidString, type: EventType, status: ConnectionStatus, error: String? = nil) {
        self.id = id
        self.timestamp = Date()
        self.type = type
        self.status = status
        self.error = error
    }
}

// Connection status enum
enum ConnectionStatus: String, Codable {
    case connecting
    case connected
    case disconnected
    case reconnecting
    case error
}

// Helper for encoding/decoding Any values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable value cannot be encoded"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}
```

### 1.2 Event Bus Implementation

```swift
// MARK: - Event Bus

class EventBus {
    // Singleton instance
    static let shared = EventBus()
    
    // Event handlers by type
    private var handlers: [EventType: [(Event) -> Void]] = [:]
    
    // Event history for debugging and recovery
    private var eventHistory: [Event] = []
    private let maxHistorySize = 100
    
    // Serial queue for thread safety
    private let queue = DispatchQueue(label: "com.openhands.mac.eventBus", qos: .userInitiated)
    
    private init() {}
    
    // Register handler for specific event type
    func register(for eventType: EventType, handler: @escaping (Event) -> Void) -> EventSubscription {
        let subscription = EventSubscription(eventBus: self, eventType: eventType, handler: handler)
        
        queue.sync {
            if handlers[eventType] == nil {
                handlers[eventType] = []
            }
            
            handlers[eventType]?.append(handler)
        }
        
        return subscription
    }
    
    // Register handler for multiple event types
    func register(for eventTypes: [EventType], handler: @escaping (Event) -> Void) -> [EventSubscription] {
        return eventTypes.map { register(for: $0, handler: handler) }
    }
    
    // Unregister handler
    func unregister(for eventType: EventType, handler: @escaping (Event) -> Void) {
        queue.sync {
            handlers[eventType]?.removeAll { $0 as AnyObject === handler as AnyObject }
        }
    }
    
    // Post event to bus
    func post(_ event: Event) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Add to history
            self.eventHistory.append(event)
            if self.eventHistory.count > self.maxHistorySize {
                self.eventHistory.removeFirst()
            }
            
            // Notify handlers
            let eventHandlers = self.handlers[event.type] ?? []
            
            // Dispatch to main queue for UI updates
            DispatchQueue.main.async {
                for handler in eventHandlers {
                    handler(event)
                }
            }
        }
    }
    
    // Get event history
    func getEventHistory() -> [Event] {
        return queue.sync { eventHistory }
    }
    
    // Clear event history
    func clearEventHistory() {
        queue.sync { eventHistory.removeAll() }
    }
}

// Event subscription for cleanup
class EventSubscription {
    private weak var eventBus: EventBus?
    private let eventType: EventType
    private let handler: (Event) -> Void
    
    init(eventBus: EventBus, eventType: EventType, handler: @escaping (Event) -> Void) {
        self.eventBus = eventBus
        self.eventType = eventType
        self.handler = handler
    }
    
    func cancel() {
        eventBus?.unregister(for: eventType, handler: handler)
    }
    
    deinit {
        cancel()
    }
}
```

### 1.3 Socket.IO Event Adapter

```swift
// MARK: - Socket.IO Event Adapter

class SocketEventAdapter {
    private let socketManager: SocketManager
    private let eventBus: EventBus
    private var subscriptions: [EventSubscription] = []
    
    init(socketManager: SocketManager, eventBus: EventBus = .shared) {
        self.socketManager = socketManager
        self.eventBus = eventBus
        
        setupSocketHandlers()
        setupEventBusHandlers()
    }
    
    // Set up Socket.IO event handlers
    private func setupSocketHandlers() {
        // Handle connection events
        socketManager.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self = self else { return }
            
            let event = ConnectionEvent(
                type: .connectionEstablished,
                status: .connected
            )
            
            self.eventBus.post(event)
        }
        
        socketManager.on(clientEvent: .disconnect) { [weak self] _, _ in
            guard let self = self else { return }
            
            let event = ConnectionEvent(
                type: .connectionLost,
                status: .disconnected
            )
            
            self.eventBus.post(event)
        }
        
        socketManager.on(clientEvent: .error) { [weak self] _, data in
            guard let self = self else { return }
            
            let errorMessage = data.first as? String ?? "Unknown error"
            
            let event = ConnectionEvent(
                type: .connectionError,
                status: .error,
                error: errorMessage
            )
            
            self.eventBus.post(event)
        }
        
        socketManager.on(clientEvent: .reconnect) { [weak self] _, _ in
            guard let self = self else { return }
            
            let event = ConnectionEvent(
                type: .connectionEstablished,
                status: .connected
            )
            
            self.eventBus.post(event)
        }
        
        socketManager.on(clientEvent: .reconnectAttempt) { [weak self] _, _ in
            guard let self = self else { return }
            
            let event = ConnectionEvent(
                type: .connectionLost,
                status: .reconnecting
            )
            
            self.eventBus.post(event)
        }
        
        // Handle agent events
        socketManager.on("oh_event") { [weak self] data in
            guard let self = self,
                  let eventData = data.first as? [String: Any],
                  let eventType = eventData["type"] as? String else {
                return
            }
            
            // Convert Socket.IO event to app event
            if let event = self.convertSocketEventToAppEvent(eventType: eventType, data: eventData) {
                self.eventBus.post(event)
            }
        }
    }
    
    // Set up event bus handlers for outgoing events
    private func setupEventBusHandlers() {
        // Register for outgoing events that need to be sent to the server
        let outgoingEventTypes: [EventType] = [
            .messageReceived,
            .conversationCreated,
            .conversationUpdated,
            .fileCreated,
            .fileUpdated,
            .fileDeleted
        ]
        
        for eventType in outgoingEventTypes {
            let subscription = eventBus.register(for: eventType) { [weak self] event in
                guard let self = self else { return }
                
                // Convert app event to Socket.IO event
                if let socketEvent = self.convertAppEventToSocketEvent(event) {
                    self.socketManager.emit(socketEvent.name, socketEvent.data)
                }
            }
            
            subscriptions.append(subscription)
        }
    }
    
    // Convert Socket.IO event to app event
    private func convertSocketEventToAppEvent(eventType: String, data: [String: Any]) -> Event? {
        // Map Socket.IO event type to app event type
        guard let appEventType = mapSocketEventTypeToAppEventType(eventType) else {
            return nil
        }
        
        // Create appropriate event based on type
        switch appEventType {
        case .agentResponse:
            guard let conversationId = data["conversation_id"] as? String,
                  let messageId = data["message_id"] as? String,
                  let content = data["content"] as? String,
                  let isComplete = data["is_complete"] as? Bool else {
                return nil
            }
            
            return AgentResponseEvent(
                conversationId: conversationId,
                messageId: messageId,
                content: content,
                isComplete: isComplete,
                metadata: data["metadata"] as? [String: Any]
            )
            
        case .messageReceived:
            guard let conversationId = data["conversation_id"] as? String,
                  let messageData = data["message"] as? [String: Any],
                  let message = try? decodeMessage(from: messageData) else {
                return nil
            }
            
            return MessageReceivedEvent(
                conversationId: conversationId,
                message: message
            )
            
        default:
            // For other event types, create a generic BaseEvent
            return BaseEvent(
                id: data["id"] as? String ?? UUID().uuidString,
                type: appEventType,
                payload: data
            )
        }
    }
    
    // Convert app event to Socket.IO event
    private func convertAppEventToSocketEvent(event: Event) -> (name: String, data: [String: Any])? {
        // Create Socket.IO event based on app event type
        switch event.type {
        case .messageReceived:
            guard let messageEvent = event as? MessageReceivedEvent else {
                return nil
            }
            
            return ("oh_action", [
                "type": "send_message",
                "conversation_id": messageEvent.conversationId,
                "message": try? encodeToJSON(messageEvent.message)
            ])
            
        case .conversationCreated, .conversationUpdated:
            // Extract conversation data from event
            guard let payload = (event as? BaseEvent)?.payload else {
                return nil
            }
            
            return ("oh_action", [
                "type": mapAppEventTypeToSocketEventType(event.type),
                "conversation": payload.mapValues { $0.value }
            ])
            
        case .fileCreated, .fileUpdated, .fileDeleted:
            // Extract file data from event
            guard let payload = (event as? BaseEvent)?.payload else {
                return nil
            }
            
            return ("oh_action", [
                "type": mapAppEventTypeToSocketEventType(event.type),
                "file": payload.mapValues { $0.value }
            ])
            
        default:
            return nil
        }
    }
    
    // Map Socket.IO event type to app event type
    private func mapSocketEventTypeToAppEventType(_ socketEventType: String) -> EventType? {
        switch socketEventType {
        case "agent_thinking":
            return .agentThinking
        case "agent_response":
            return .agentResponse
        case "agent_error":
            return .agentError
        case "agent_complete":
            return .agentComplete
        case "conversation_created":
            return .conversationCreated
        case "conversation_updated":
            return .conversationUpdated
        case "conversation_deleted":
            return .conversationDeleted
        case "message_received":
            return .messageReceived
        case "message_updated":
            return .messageUpdated
        case "file_created":
            return .fileCreated
        case "file_updated":
            return .fileUpdated
        case "file_deleted":
            return .fileDeleted
        case "file_content_changed":
            return .fileContentChanged
        case "user_joined":
            return .userJoined
        case "user_left":
            return .userLeft
        case "user_activity":
            return .userActivity
        case "auth_required":
            return .authRequired
        case "auth_success":
            return .authSuccess
        case "auth_failure":
            return .authFailure
        default:
            if socketEventType.hasPrefix("custom_") {
                return .custom
            }
            return nil
        }
    }
    
    // Map app event type to Socket.IO event type
    private func mapAppEventTypeToSocketEventType(_ appEventType: EventType) -> String {
        switch appEventType {
        case .agentThinking:
            return "agent_thinking"
        case .agentResponse:
            return "agent_response"
        case .agentError:
            return "agent_error"
        case .agentComplete:
            return "agent_complete"
        case .conversationCreated:
            return "conversation_created"
        case .conversationUpdated:
            return "conversation_updated"
        case .conversationDeleted:
            return "conversation_deleted"
        case .messageReceived:
            return "message_received"
        case .messageUpdated:
            return "message_updated"
        case .fileCreated:
            return "file_created"
        case .fileUpdated:
            return "file_updated"
        case .fileDeleted:
            return "file_deleted"
        case .fileContentChanged:
            return "file_content_changed"
        case .userJoined:
            return "user_joined"
        case .userLeft:
            return "user_left"
        case .userActivity:
            return "user_activity"
        case .authRequired:
            return "auth_required"
        case .authSuccess:
            return "auth_success"
        case .authFailure:
            return "auth_failure"
        case .connectionEstablished:
            return "connection_established"
        case .connectionLost:
            return "connection_lost"
        case .connectionError:
            return "connection_error"
        case .custom:
            return "custom"
        }
    }
    
    // Helper to decode message from JSON
    private func decodeMessage(from data: [String: Any]) throws -> Message {
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        return try JSONDecoder().decode(Message.self, from: jsonData)
    }
    
    // Helper to encode object to JSON
    private func encodeToJSON<T: Encodable>(_ object: T) throws -> [String: Any] {
        let jsonData = try JSONEncoder().encode(object)
        guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw EncodingError.invalidValue(object, EncodingError.Context(
                codingPath: [],
                debugDescription: "Failed to convert encoded data to JSON object"
            ))
        }
        return jsonObject
    }
}
```

## 2. Event Processing and Routing

### 2.1 Event Processor

```swift
// MARK: - Event Processor

class EventProcessor {
    private let eventBus: EventBus
    private let eventQueue: EventQueue
    private var subscriptions: [EventSubscription] = []
    
    // Event handlers by type
    private var processors: [EventType: (Event) -> Void] = [:]
    
    init(eventBus: EventBus = .shared, eventQueue: EventQueue = EventQueue()) {
        self.eventBus = eventBus
        self.eventQueue = eventQueue
        
        registerProcessors()
        subscribeToEvents()
    }
    
    // Register event processors
    private func registerProcessors() {
        // Agent response processor
        processors[.agentResponse] = { [weak self] event in
            guard let self = self,
                  let responseEvent = event as? AgentResponseEvent else {
                return
            }
            
            // Process agent response
            self.processAgentResponse(responseEvent)
        }
        
        // Message received processor
        processors[.messageReceived] = { [weak self] event in
            guard let self = self,
                  let messageEvent = event as? MessageReceivedEvent else {
                return
            }
            
            // Process message
            self.processMessage(messageEvent)
        }
        
        // Connection event processor
        processors[.connectionEstablished] = { [weak self] event in
            guard let self = self,
                  let connectionEvent = event as? ConnectionEvent else {
                return
            }
            
            // Process connection established
            self.processConnectionEstablished(connectionEvent)
        }
        
        processors[.connectionLost] = { [weak self] event in
            guard let self = self,
                  let connectionEvent = event as? ConnectionEvent else {
                return
            }
            
            // Process connection lost
            self.processConnectionLost(connectionEvent)
        }
        
        // Add more processors for other event types...
    }
    
    // Subscribe to events
    private func subscribeToEvents() {
        // Subscribe to all event types with processors
        for eventType in processors.keys {
            let subscription = eventBus.register(for: eventType) { [weak self] event in
                guard let self = self else { return }
                
                // Queue event for processing
                self.eventQueue.enqueue(event: event)
            }
            
            subscriptions.append(subscription)
        }
        
        // Start processing events from queue
        eventQueue.startProcessing { [weak self] event in
            guard let self = self else { return }
            
            // Process event
            if let processor = self.processors[event.type] {
                processor(event)
            }
        }
    }
    
    // Process agent response
    private func processAgentResponse(_ event: AgentResponseEvent) {
        // Update conversation with response
        NotificationCenter.default.post(
            name: .agentResponseReceived,
            object: event
        )
        
        // If response is complete, notify completion
        if event.isComplete {
            NotificationCenter.default.post(
                name: .agentResponseComplete,
                object: event
            )
        }
    }
    
    // Process message
    private func processMessage(_ event: MessageReceivedEvent) {
        // Update conversation with message
        NotificationCenter.default.post(
            name: .messageReceived,
            object: event
        )
    }
    
    // Process connection established
    private func processConnectionEstablished(_ event: ConnectionEvent) {
        // Update connection status
        NotificationCenter.default.post(
            name: .connectionStatusChanged,
            object: event
        )
        
        // Sync state with server
        NotificationCenter.default.post(
            name: .syncStateWithServer,
            object: nil
        )
    }
    
    // Process connection lost
    private func processConnectionLost(_ event: ConnectionEvent) {
        // Update connection status
        NotificationCenter.default.post(
            name: .connectionStatusChanged,
            object: event
        )
        
        // Enable offline mode if needed
        if event.status == .disconnected {
            NotificationCenter.default.post(
                name: .enableOfflineMode,
                object: nil
            )
        }
    }
}

// Notification names
extension Notification.Name {
    static let agentResponseReceived = Notification.Name("com.openhands.mac.agentResponseReceived")
    static let agentResponseComplete = Notification.Name("com.openhands.mac.agentResponseComplete")
    static let messageReceived = Notification.Name("com.openhands.mac.messageReceived")
    static let connectionStatusChanged = Notification.Name("com.openhands.mac.connectionStatusChanged")
    static let syncStateWithServer = Notification.Name("com.openhands.mac.syncStateWithServer")
}
```

### 2.2 Event Router

```swift
// MARK: - Event Router

class EventRouter {
    private let eventBus: EventBus
    private var subscriptions: [EventSubscription] = []
    
    // Component registrations
    private var componentRegistrations: [String: [EventType]] = [:]
    
    init(eventBus: EventBus = .shared) {
        self.eventBus = eventBus
    }
    
    // Register component for event types
    func registerComponent(_ component: AnyObject, id: String, for eventTypes: [EventType], handler: @escaping (Event) -> Void) {
        // Store registration
        componentRegistrations[id] = eventTypes
        
        // Subscribe to events
        for eventType in eventTypes {
            let subscription = eventBus.register(for: eventType) { event in
                handler(event)
            }
            
            subscriptions.append(subscription)
        }
    }
    
    // Unregister component
    func unregisterComponent(id: String) {
        guard let eventTypes = componentRegistrations[id] else {
            return
        }
        
        // Remove registrations
        componentRegistrations.removeValue(forKey: id)
        
        // Remove subscriptions for this component
        subscriptions = subscriptions.filter { subscription in
            // This is a simplification - in a real implementation,
            // we would need to track which subscription belongs to which component
            return true
        }
    }
    
    // Route event to specific component
    func routeEvent(_ event: Event, to componentId: String) {
        guard let eventTypes = componentRegistrations[componentId],
              eventTypes.contains(event.type) else {
            return
        }
        
        // Post event to bus - it will be routed to the component's handler
        eventBus.post(event)
    }
    
    // Get components registered for event type
    func getComponentsForEventType(_ eventType: EventType) -> [String] {
        return componentRegistrations.compactMap { id, types in
            types.contains(eventType) ? id : nil
        }
    }
}
```

### 2.3 Component Event Handling

```swift
// MARK: - Component Event Handling

// Protocol for components that handle events
protocol EventHandler: AnyObject {
    var componentId: String { get }
    func handleEvent(_ event: Event)
    func registerForEvents()
    func unregisterFromEvents()
}

// Base class for view models that handle events
class EventHandlingViewModel: ObservableObject, EventHandler {
    let componentId: String
    private let eventRouter: EventRouter
    private let eventTypes: [EventType]
    
    init(componentId: String, eventRouter: EventRouter, eventTypes: [EventType]) {
        self.componentId = componentId
        self.eventRouter = eventRouter
        self.eventTypes = eventTypes
        
        registerForEvents()
    }
    
    deinit {
        unregisterFromEvents()
    }
    
    func handleEvent(_ event: Event) {
        // Override in subclasses
    }
    
    func registerForEvents() {
        eventRouter.registerComponent(self, id: componentId, for: eventTypes) { [weak self] event in
            self?.handleEvent(event)
        }
    }
    
    func unregisterFromEvents() {
        eventRouter.unregisterComponent(id: componentId)
    }
}

// Example conversation view model
class ConversationViewModel: EventHandlingViewModel {
    @Published var conversation: Conversation
    @Published var messages: [Message] = []
    @Published var isAgentResponding = false
    @Published var agentResponseProgress = 0.0
    
    init(conversation: Conversation, eventRouter: EventRouter) {
        self.conversation = conversation
        
        // Register for conversation-specific events
        super.init(
            componentId: "conversation_\(conversation.id)",
            eventRouter: eventRouter,
            eventTypes: [
                .agentThinking,
                .agentResponse,
                .agentComplete,
                .messageReceived,
                .messageUpdated
            ]
        )
        
        // Initialize messages
        messages = conversation.messages
    }
    
    override func handleEvent(_ event: Event) {
        // Handle events based on type
        switch event.type {
        case .agentThinking:
            handleAgentThinking(event)
        case .agentResponse:
            handleAgentResponse(event)
        case .agentComplete:
            handleAgentComplete(event)
        case .messageReceived:
            handleMessageReceived(event)
        case .messageUpdated:
            handleMessageUpdated(event)
        default:
            break
        }
    }
    
    private func handleAgentThinking(_ event: Event) {
        DispatchQueue.main.async {
            self.isAgentResponding = true
            self.agentResponseProgress = 0.0
        }
    }
    
    private func handleAgentResponse(_ event: Event) {
        guard let responseEvent = event as? AgentResponseEvent,
              responseEvent.conversationId == conversation.id else {
            return
        }
        
        DispatchQueue.main.async {
            self.isAgentResponding = true
            
            // Find existing message or create new one
            if let index = self.messages.firstIndex(where: { $0.id == responseEvent.messageId }) {
                // Update existing message
                var updatedMessage = self.messages[index]
                updatedMessage.content = responseEvent.content
                self.messages[index] = updatedMessage
            } else {
                // Create new message
                let newMessage = Message(
                    id: responseEvent.messageId,
                    source: .agent,
                    content: responseEvent.content,
                    timestamp: responseEvent.timestamp,
                    metadata: responseEvent.metadata?.mapValues { $0.value },
                    sequence: self.messages.count,
                    isAcknowledged: true
                )
                
                self.messages.append(newMessage)
            }
            
            // Update progress
            self.agentResponseProgress = responseEvent.isComplete ? 1.0 : 0.5
        }
    }
    
    private func handleAgentComplete(_ event: Event) {
        DispatchQueue.main.async {
            self.isAgentResponding = false
            self.agentResponseProgress = 1.0
        }
    }
    
    private func handleMessageReceived(_ event: Event) {
        guard let messageEvent = event as? MessageReceivedEvent,
              messageEvent.conversationId == conversation.id else {
            return
        }
        
        DispatchQueue.main.async {
            // Add message if it doesn't exist
            if !self.messages.contains(where: { $0.id == messageEvent.message.id }) {
                self.messages.append(messageEvent.message)
                
                // Sort messages by sequence
                self.messages.sort { $0.sequence < $1.sequence }
            }
        }
    }
    
    private func handleMessageUpdated(_ event: Event) {
        guard let baseEvent = event as? BaseEvent,
              let payload = baseEvent.payload,
              let conversationId = payload["conversation_id"]?.value as? String,
              conversationId == conversation.id,
              let messageData = payload["message"]?.value as? [String: Any],
              let messageId = messageData["id"] as? String else {
            return
        }
        
        DispatchQueue.main.async {
            // Find and update message
            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: messageData)
                    if let updatedMessage = try? JSONDecoder().decode(Message.self, from: jsonData) {
                        self.messages[index] = updatedMessage
                    }
                } catch {
                    print("Error decoding updated message: \(error)")
                }
            }
        }
    }
    
    // Send message
    func sendMessage(_ content: String) {
        // Create message
        let message = Message(
            id: UUID().uuidString,
            source: .user,
            content: content,
            timestamp: Date(),
            metadata: nil,
            sequence: messages.count,
            isAcknowledged: false
        )
        
        // Add to local messages
        DispatchQueue.main.async {
            self.messages.append(message)
        }
        
        // Create event
        let event = MessageReceivedEvent(
            conversationId: conversation.id,
            message: message
        )
        
        // Post to event bus
        EventBus.shared.post(event)
    }
}
```

## 3. Event Prioritization and Queueing

### 3.1 Event Queue Implementation

```swift
// MARK: - Event Queue

class EventQueue {
    // Event priority
    enum EventPriority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3
        
        static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    // Queued event with priority
    private struct QueuedEvent {
        let event: Event
        let priority: EventPriority
        let timestamp: Date
        
        init(event: Event, priority: EventPriority) {
            self.event = event
            self.priority = priority
            self.timestamp = Date()
        }
    }
    
    // Queue of events
    private var queue: [QueuedEvent] = []
    
    // Processing state
    private var isProcessing = false
    private var processingHandler: ((Event) -> Void)?
    
    // Serial queue for thread safety
    private let serialQueue = DispatchQueue(label: "com.openhands.mac.eventQueue", qos: .userInitiated)
    
    // Enqueue event with priority
    func enqueue(event: Event, priority: EventPriority = .normal) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Create queued event
            let queuedEvent = QueuedEvent(event: event, priority: priority)
            
            // Add to queue
            self.queue.append(queuedEvent)
            
            // Sort queue by priority and timestamp
            self.sortQueue()
            
            // Start processing if not already processing
            if !self.isProcessing {
                self.processNextEvent()
            }
        }
    }
    
    // Start processing events
    func startProcessing(handler: @escaping (Event) -> Void) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.processingHandler = handler
            
            // Start processing if queue has events
            if !self.queue.isEmpty && !self.isProcessing {
                self.processNextEvent()
            }
        }
    }
    
    // Stop processing events
    func stopProcessing() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.isProcessing = false
            self.processingHandler = nil
        }
    }
    
    // Process next event in queue
    private func processNextEvent() {
        serialQueue.async { [weak self] in
            guard let self = self,
                  !self.queue.isEmpty,
                  let handler = self.processingHandler else {
                self?.isProcessing = false
                return
            }
            
            self.isProcessing = true
            
            // Get next event
            let queuedEvent = self.queue.removeFirst()
            
            // Process event on main queue
            DispatchQueue.main.async {
                handler(queuedEvent.event)
                
                // Process next event
                self.serialQueue.async {
                    if !self.queue.isEmpty {
                        self.processNextEvent()
                    } else {
                        self.isProcessing = false
                    }
                }
            }
        }
    }
    
    // Sort queue by priority and timestamp
    private func sortQueue() {
        queue.sort { first, second in
            if first.priority == second.priority {
                return first.timestamp < second.timestamp
            }
            return first.priority > second.priority
        }
    }
    
    // Get event priority based on type
    static func priorityForEventType(_ eventType: EventType) -> EventPriority {
        switch eventType {
        case .connectionEstablished, .connectionLost, .connectionError, .authRequired:
            return .critical
        case .agentResponse, .agentComplete, .messageReceived:
            return .high
        case .conversationCreated, .conversationUpdated, .conversationDeleted:
            return .normal
        default:
            return .low
        }
    }
    
    // Clear queue
    func clearQueue() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.queue.removeAll()
        }
    }
    
    // Get queue size
    func getQueueSize() -> Int {
        return serialQueue.sync { queue.count }
    }
    
    // Get queued events
    func getQueuedEvents() -> [Event] {
        return serialQueue.sync { queue.map { $0.event } }
    }
}
```

### 3.2 Priority-Based Event Processing

```swift
// MARK: - Priority-Based Event Processor

class PriorityEventProcessor {
    private let eventBus: EventBus
    private let eventQueue: EventQueue
    private var subscriptions: [EventSubscription] = []
    
    init(eventBus: EventBus = .shared, eventQueue: EventQueue = EventQueue()) {
        self.eventBus = eventBus
        self.eventQueue = eventQueue
        
        subscribeToEvents()
    }
    
    // Subscribe to all events
    private func subscribeToEvents() {
        // Get all event types
        let allEventTypes = getAllEventTypes()
        
        // Subscribe to each event type
        for eventType in allEventTypes {
            let subscription = eventBus.register(for: eventType) { [weak self] event in
                guard let self = self else { return }
                
                // Get priority for event type
                let priority = EventQueue.priorityForEventType(event.type)
                
                // Enqueue event with priority
                self.eventQueue.enqueue(event: event, priority: priority)
            }
            
            subscriptions.append(subscription)
        }
        
        // Start processing events
        eventQueue.startProcessing { [weak self] event in
            guard let self = self else { return }
            
            // Process event based on type
            self.processEvent(event)
        }
    }
    
    // Get all event types
    private func getAllEventTypes() -> [EventType] {
        return [
            .connectionEstablished,
            .connectionLost,
            .connectionError,
            .authRequired,
            .authSuccess,
            .authFailure,
            .agentThinking,
            .agentResponse,
            .agentError,
            .agentComplete,
            .conversationCreated,
            .conversationUpdated,
            .conversationDeleted,
            .messageReceived,
            .messageUpdated,
            .fileCreated,
            .fileUpdated,
            .fileDeleted,
            .fileContentChanged,
            .userJoined,
            .userLeft,
            .userActivity,
            .custom
        ]
    }
    
    // Process event based on type
    private func processEvent(_ event: Event) {
        switch event.type {
        case .connectionEstablished, .connectionLost, .connectionError:
            processConnectionEvent(event)
        case .authRequired, .authSuccess, .authFailure:
            processAuthEvent(event)
        case .agentThinking, .agentResponse, .agentError, .agentComplete:
            processAgentEvent(event)
        case .conversationCreated, .conversationUpdated, .conversationDeleted:
            processConversationEvent(event)
        case .messageReceived, .messageUpdated:
            processMessageEvent(event)
        case .fileCreated, .fileUpdated, .fileDeleted, .fileContentChanged:
            processFileEvent(event)
        case .userJoined, .userLeft, .userActivity:
            processUserEvent(event)
        case .custom:
            processCustomEvent(event)
        }
    }
    
    // Process connection event
    private func processConnectionEvent(_ event: Event) {
        // Notify connection manager
        NotificationCenter.default.post(
            name: .connectionEventReceived,
            object: event
        )
    }
    
    // Process auth event
    private func processAuthEvent(_ event: Event) {
        // Notify auth manager
        NotificationCenter.default.post(
            name: .authEventReceived,
            object: event
        )
    }
    
    // Process agent event
    private func processAgentEvent(_ event: Event) {
        // Notify agent manager
        NotificationCenter.default.post(
            name: .agentEventReceived,
            object: event
        )
    }
    
    // Process conversation event
    private func processConversationEvent(_ event: Event) {
        // Notify conversation manager
        NotificationCenter.default.post(
            name: .conversationEventReceived,
            object: event
        )
    }
    
    // Process message event
    private func processMessageEvent(_ event: Event) {
        // Notify message manager
        NotificationCenter.default.post(
            name: .messageEventReceived,
            object: event
        )
    }
    
    // Process file event
    private func processFileEvent(_ event: Event) {
        // Notify file manager
        NotificationCenter.default.post(
            name: .fileEventReceived,
            object: event
        )
    }
    
    // Process user event
    private func processUserEvent(_ event: Event) {
        // Notify user manager
        NotificationCenter.default.post(
            name: .userEventReceived,
            object: event
        )
    }
    
    // Process custom event
    private func processCustomEvent(_ event: Event) {
        // Notify custom event handler
        NotificationCenter.default.post(
            name: .customEventReceived,
            object: event
        )
    }
}

// Notification names
extension Notification.Name {
    static let connectionEventReceived = Notification.Name("com.openhands.mac.connectionEventReceived")
    static let authEventReceived = Notification.Name("com.openhands.mac.authEventReceived")
    static let agentEventReceived = Notification.Name("com.openhands.mac.agentEventReceived")
    static let conversationEventReceived = Notification.Name("com.openhands.mac.conversationEventReceived")
    static let messageEventReceived = Notification.Name("com.openhands.mac.messageEventReceived")
    static let fileEventReceived = Notification.Name("com.openhands.mac.fileEventReceived")
    static let userEventReceived = Notification.Name("com.openhands.mac.userEventReceived")
    static let customEventReceived = Notification.Name("com.openhands.mac.customEventReceived")
}
```

### 3.3 Event Batching and Throttling

```swift
// MARK: - Event Batcher

class EventBatcher {
    // Batch configuration
    private struct BatchConfig {
        let maxBatchSize: Int
        let maxWaitTime: TimeInterval
    }
    
    // Batched events by type
    private var batches: [EventType: [Event]] = [:]
    
    // Batch configurations by type
    private var batchConfigs: [EventType: BatchConfig] = [:]
    
    // Batch timers by type
    private var batchTimers: [EventType: Timer] = [:]
    
    // Serial queue for thread safety
    private let serialQueue = DispatchQueue(label: "com.openhands.mac.eventBatcher", qos: .userInitiated)
    
    // Event bus
    private let eventBus: EventBus
    
    init(eventBus: EventBus = .shared) {
        self.eventBus = eventBus
        
        // Set up default batch configurations
        setupDefaultBatchConfigs()
    }
    
    // Set up default batch configurations
    private func setupDefaultBatchConfigs() {
        // File events can be batched
        batchConfigs[.fileCreated] = BatchConfig(maxBatchSize: 10, maxWaitTime: 0.5)
        batchConfigs[.fileUpdated] = BatchConfig(maxBatchSize: 10, maxWaitTime: 0.5)
        batchConfigs[.fileDeleted] = BatchConfig(maxBatchSize: 10, maxWaitTime: 0.5)
        
        // User activity events can be batched
        batchConfigs[.userActivity] = BatchConfig(maxBatchSize: 5, maxWaitTime: 0.2)
    }
    
    // Add event to batch
    func addToBatch(_ event: Event) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if event type supports batching
            guard let config = self.batchConfigs[event.type] else {
                // If not, post event directly
                self.eventBus.post(event)
                return
            }
            
            // Add to batch
            if self.batches[event.type] == nil {
                self.batches[event.type] = []
            }
            
            self.batches[event.type]?.append(event)
            
            // Check if batch is full
            if let batch = self.batches[event.type], batch.count >= config.maxBatchSize {
                self.flushBatch(eventType: event.type)
                return
            }
            
            // Start timer if not already running
            if self.batchTimers[event.type] == nil {
                let timer = Timer.scheduledTimer(
                    withTimeInterval: config.maxWaitTime,
                    repeats: false
                ) { [weak self] _ in
                    self?.serialQueue.async {
                        self?.flushBatch(eventType: event.type)
                    }
                }
                
                self.batchTimers[event.type] = timer
            }
        }
    }
    
    // Flush batch for event type
    private func flushBatch(eventType: EventType) {
        // Cancel timer
        batchTimers[eventType]?.invalidate()
        batchTimers[eventType] = nil
        
        // Get batch
        guard let batch = batches[eventType], !batch.isEmpty else {
            return
        }
        
        // Create batch event
        let batchEvent = createBatchEvent(eventType: eventType, events: batch)
        
        // Post batch event
        eventBus.post(batchEvent)
        
        // Clear batch
        batches[eventType] = []
    }
    
    // Create batch event
    private func createBatchEvent(eventType: EventType, events: [Event]) -> Event {
        // For file events, create a batch event
        if eventType == .fileCreated || eventType == .fileUpdated || eventType == .fileDeleted {
            return createFileBatchEvent(eventType: eventType, events: events)
        }
        
        // For user activity events, create a batch event
        if eventType == .userActivity {
            return createUserActivityBatchEvent(events: events)
        }
        
        // Default: return first event
        return events.first!
    }
    
    // Create file batch event
    private func createFileBatchEvent(eventType: EventType, events: [Event]) -> Event {
        // Extract file paths from events
        let filePaths = events.compactMap { event -> String? in
            guard let baseEvent = event as? BaseEvent,
                  let payload = baseEvent.payload,
                  let path = payload["path"]?.value as? String else {
                return nil
            }
            return path
        }
        
        // Create batch event
        return BaseEvent(
            type: eventType,
            payload: [
                "paths": filePaths,
                "count": filePaths.count,
                "isBatch": true
            ]
        )
    }
    
    // Create user activity batch event
    private func createUserActivityBatchEvent(events: [Event]) -> Event {
        // Extract user IDs and activities from events
        let activities = events.compactMap { event -> [String: Any]? in
            guard let baseEvent = event as? BaseEvent,
                  let payload = baseEvent.payload,
                  let userId = payload["user_id"]?.value as? String,
                  let activity = payload["activity"]?.value as? String else {
                return nil
            }
            return ["user_id": userId, "activity": activity, "timestamp": baseEvent.timestamp]
        }
        
        // Create batch event
        return BaseEvent(
            type: .userActivity,
            payload: [
                "activities": activities,
                "count": activities.count,
                "isBatch": true
            ]
        )
    }
    
    // Flush all batches
    func flushAllBatches() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Flush each batch
            for eventType in self.batches.keys {
                self.flushBatch(eventType: eventType)
            }
        }
    }
}

// MARK: - Event Throttler

class EventThrottler {
    // Throttle configuration
    private struct ThrottleConfig {
        let interval: TimeInterval
        let dropIntermediate: Bool
    }
    
    // Last event time by type
    private var lastEventTimes: [EventType: Date] = [:]
    
    // Pending events by type
    private var pendingEvents: [EventType: Event] = [:]
    
    // Throttle configurations by type
    private var throttleConfigs: [EventType: ThrottleConfig] = [:]
    
    // Serial queue for thread safety
    private let serialQueue = DispatchQueue(label: "com.openhands.mac.eventThrottler", qos: .userInitiated)
    
    // Event bus
    private let eventBus: EventBus
    
    init(eventBus: EventBus = .shared) {
        self.eventBus = eventBus
        
        // Set up default throttle configurations
        setupDefaultThrottleConfigs()
    }
    
    // Set up default throttle configurations
    private func setupDefaultThrottleConfigs() {
        // Throttle file content changed events
        throttleConfigs[.fileContentChanged] = ThrottleConfig(interval: 0.5, dropIntermediate: true)
        
        // Throttle user activity events
        throttleConfigs[.userActivity] = ThrottleConfig(interval: 0.2, dropIntermediate: true)
    }
    
    // Throttle event
    func throttle(_ event: Event) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if event type supports throttling
            guard let config = self.throttleConfigs[event.type] else {
                // If not, post event directly
                self.eventBus.post(event)
                return
            }
            
            let now = Date()
            
            // Check if we should throttle
            if let lastTime = self.lastEventTimes[event.type],
               now.timeIntervalSince(lastTime) < config.interval {
                
                // If we drop intermediate events, just update the pending event
                if config.dropIntermediate {
                    self.pendingEvents[event.type] = event
                } else {
                    // Otherwise, post event after delay
                    let delay = config.interval - now.timeIntervalSince(lastTime)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.eventBus.post(event)
                    }
                }
                
                return
            }
            
            // Update last event time
            self.lastEventTimes[event.type] = now
            
            // Post event
            self.eventBus.post(event)
            
            // Schedule processing of pending event
            if config.dropIntermediate {
                DispatchQueue.main.asyncAfter(deadline: .now() + config.interval) { [weak self] in
                    self?.serialQueue.async {
                        if let pendingEvent = self?.pendingEvents[event.type] {
                            self?.lastEventTimes[event.type] = Date()
                            self?.eventBus.post(pendingEvent)
                            self?.pendingEvents[event.type] = nil
                        }
                    }
                }
            }
        }
    }
}
```

## 4. Integration with App Components

### 4.1 View Model Integration

```swift
// MARK: - View Model Integration

// Protocol for view models that handle events
protocol EventHandlingViewModel: ObservableObject {
    var eventSubscriptions: [EventSubscription] { get set }
    func registerForEvents()
    func unregisterFromEvents()
    func handleEvent(_ event: Event)
}

// Extension with default implementation
extension EventHandlingViewModel {
    func registerForEvents() {
        // Override in subclasses
    }
    
    func unregisterFromEvents() {
        for subscription in eventSubscriptions {
            subscription.cancel()
        }
        eventSubscriptions = []
    }
    
    func handleEvent(_ event: Event) {
        // Override in subclasses
    }
}

// Example conversation list view model
class ConversationListViewModel: ObservableObject, EventHandlingViewModel {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    var eventSubscriptions: [EventSubscription] = []
    private let eventBus: EventBus
    
    init(eventBus: EventBus = .shared) {
        self.eventBus = eventBus
        
        registerForEvents()
        loadConversations()
    }
    
    deinit {
        unregisterFromEvents()
    }
    
    func registerForEvents() {
        // Register for conversation events
        let conversationEventTypes: [EventType] = [
            .conversationCreated,
            .conversationUpdated,
            .conversationDeleted
        ]
        
        for eventType in conversationEventTypes {
            let subscription = eventBus.register(for: eventType) { [weak self] event in
                self?.handleEvent(event)
            }
            
            eventSubscriptions.append(subscription)
        }
    }
    
    func handleEvent(_ event: Event) {
        DispatchQueue.main.async {
            switch event.type {
            case .conversationCreated:
                self.handleConversationCreated(event)
            case .conversationUpdated:
                self.handleConversationUpdated(event)
            case .conversationDeleted:
                self.handleConversationDeleted(event)
            default:
                break
            }
        }
    }
    
    private func handleConversationCreated(_ event: Event) {
        guard let baseEvent = event as? BaseEvent,
              let payload = baseEvent.payload,
              let conversationData = payload["conversation"]?.value as? [String: Any] else {
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: conversationData)
            let conversation = try JSONDecoder().decode(Conversation.self, from: jsonData)
            
            // Add conversation if it doesn't exist
            if !conversations.contains(where: { $0.id == conversation.id }) {
                conversations.append(conversation)
                
                // Sort conversations by last updated
                conversations.sort { $0.lastUpdated > $1.lastUpdated }
            }
        } catch {
            print("Error decoding conversation: \(error)")
        }
    }
    
    private func handleConversationUpdated(_ event: Event) {
        guard let baseEvent = event as? BaseEvent,
              let payload = baseEvent.payload,
              let conversationData = payload["conversation"]?.value as? [String: Any],
              let conversationId = conversationData["id"] as? String else {
            return
        }
        
        // Find conversation index
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else {
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: conversationData)
            let updatedConversation = try JSONDecoder().decode(Conversation.self, from: jsonData)
            
            // Update conversation
            conversations[index] = updatedConversation
            
            // Sort conversations by last updated
            conversations.sort { $0.lastUpdated > $1.lastUpdated }
        } catch {
            print("Error decoding updated conversation: \(error)")
        }
    }
    
    private func handleConversationDeleted(_ event: Event) {
        guard let baseEvent = event as? BaseEvent,
              let payload = baseEvent.payload,
              let conversationId = payload["conversation_id"]?.value as? String else {
            return
        }
        
        // Remove conversation
        conversations.removeAll { $0.id == conversationId }
    }
    
    private func loadConversations() {
        isLoading = true
        error = nil
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.conversations = [
                Conversation(
                    id: "1",
                    title: "First Conversation",
                    messages: [],
                    status: .active,
                    lastUpdated: Date(),
                    isArchived: false,
                    localDraft: nil,
                    unreadCount: 0,
                    version: 1
                ),
                Conversation(
                    id: "2",
                    title: "Second Conversation",
                    messages: [],
                    status: .active,
                    lastUpdated: Date().addingTimeInterval(-3600),
                    isArchived: false,
                    localDraft: nil,
                    unreadCount: 0,
                    version: 1
                )
            ]
            
            self.isLoading = false
        }
    }
    
    // Create new conversation
    func createConversation(title: String) {
        // Create conversation
        let conversation = Conversation(
            id: UUID().uuidString,
            title: title,
            messages: [],
            status: .active,
            lastUpdated: Date(),
            isArchived: false,
            localDraft: nil,
            unreadCount: 0,
            version: 1
        )
        
        // Create event
        let event = BaseEvent(
            type: .conversationCreated,
            payload: [
                "conversation": [
                    "id": conversation.id,
                    "title": conversation.title,
                    "status": conversation.status.rawValue,
                    "lastUpdated": conversation.lastUpdated,
                    "isArchived": conversation.isArchived,
                    "version": conversation.version
                ]
            ]
        )
        
        // Post to event bus
        eventBus.post(event)
    }
}
```

### 4.2 View Integration

```swift
// MARK: - View Integration

// SwiftUI view that observes events
struct EventObservingView<Content: View>: View {
    @StateObject private var viewModel: EventObservingViewModel
    private let content: (EventObservingViewModel) -> Content
    
    init(eventTypes: [EventType], @ViewBuilder content: @escaping (EventObservingViewModel) -> Content) {
        _viewModel = StateObject(wrappedValue: EventObservingViewModel(eventTypes: eventTypes))
        self.content = content
    }
    
    var body: some View {
        content(viewModel)
            .onDisappear {
                viewModel.unregisterFromEvents()
            }
    }
}

// View model for event observing view
class EventObservingViewModel: ObservableObject {
    @Published private(set) var lastEvent: Event?
    @Published private(set) var eventCount: [EventType: Int] = [:]
    
    private let eventBus: EventBus
    private var subscriptions: [EventSubscription] = []
    private let eventTypes: [EventType]
    
    init(eventTypes: [EventType], eventBus: EventBus = .shared) {
        self.eventTypes = eventTypes
        self.eventBus = eventBus
        
        registerForEvents()
    }
    
    deinit {
        unregisterFromEvents()
    }
    
    func registerForEvents() {
        for eventType in eventTypes {
            let subscription = eventBus.register(for: eventType) { [weak self] event in
                DispatchQueue.main.async {
                    self?.lastEvent = event
                    self?.eventCount[event.type, default: 0] += 1
                }
            }
            
            subscriptions.append(subscription)
        }
    }
    
    func unregisterFromEvents() {
        for subscription in subscriptions {
            subscription.cancel()
        }
        subscriptions = []
    }
    
    func resetCounts() {
        eventCount = [:]
    }
}

// Example usage in a view
struct ConnectionStatusView: View {
    var body: some View {
        EventObservingView(eventTypes: [
            .connectionEstablished,
            .connectionLost,
            .connectionError
        ]) { viewModel in
            HStack {
                // Connection status indicator
                Circle()
                    .fill(statusColor(for: viewModel.lastEvent))
                    .frame(width: 10, height: 10)
                
                // Status text
                Text(statusText(for: viewModel.lastEvent))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private func statusColor(for event: Event?) -> Color {
        guard let event = event as? ConnectionEvent else {
            return .gray
        }
        
        switch event.status {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .yellow
        case .disconnected, .error:
            return .red
        }
    }
    
    private func statusText(for event: Event?) -> String {
        guard let event = event as? ConnectionEvent else {
            return "Unknown"
        }
        
        switch event.status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .reconnecting:
            return "Reconnecting..."
        case .disconnected:
            return "Disconnected"
        case .error:
            return "Error: \(event.error ?? "Unknown error")"
        }
    }
}
```

### 4.3 Service Integration

```swift
// MARK: - Service Integration

// Protocol for services that handle events
protocol EventHandlingService: AnyObject {
    var eventSubscriptions: [EventSubscription] { get set }
    func registerForEvents()
    func unregisterFromEvents()
    func handleEvent(_ event: Event)
}

// Extension with default implementation
extension EventHandlingService {
    func registerForEvents() {
        // Override in subclasses
    }
    
    func unregisterFromEvents() {
        for subscription in eventSubscriptions {
            subscription.cancel()
        }
        eventSubscriptions = []
    }
    
    func handleEvent(_ event: Event) {
        // Override in subclasses
    }
}

// Example file sync service
class FileSyncService: EventHandlingService {
    var eventSubscriptions: [EventSubscription] = []
    private let eventBus: EventBus
    
    init(eventBus: EventBus = .shared) {
        self.eventBus = eventBus
        
        registerForEvents()
    }
    
    deinit {
        unregisterFromEvents()
    }
    
    func registerForEvents() {
        // Register for file events
        let fileEventTypes: [EventType] = [
            .fileCreated,
            .fileUpdated,
            .fileDeleted,
            .fileContentChanged
        ]
        
        for eventType in fileEventTypes {
            let subscription = eventBus.register(for: eventType) { [weak self] event in
                self?.handleEvent(event)
            }
            
            eventSubscriptions.append(subscription)
        }
    }
    
    func handleEvent(_ event: Event) {
        switch event.type {
        case .fileCreated:
            handleFileCreated(event)
        case .fileUpdated:
            handleFileUpdated(event)
        case .fileDeleted:
            handleFileDeleted(event)
        case .fileContentChanged:
            handleFileContentChanged(event)
        default:
            break
        }
    }
    
    private func handleFileCreated(_ event: Event) {
        guard let baseEvent = event as? BaseEvent,
              let payload = baseEvent.payload else {
            return
        }
        
        // Check if it's a batch event
        if let isBatch = payload["isBatch"]?.value as? Bool, isBatch,
           let paths = payload["paths"]?.value as? [String] {
            // Handle batch file creation
            for path in paths {
                syncFileCreation(path: path)
            }
        } else if let path = payload["path"]?.value as? String {
            // Handle single file creation
            syncFileCreation(path: path)
        }
    }
    
    private func handleFileUpdated(_ event: Event) {
        guard let baseEvent = event as? BaseEvent,
              let payload = baseEvent.payload else {
            return
        }
        
        // Check if it's a batch event
        if let isBatch = payload["isBatch"]?.value as? Bool, isBatch,
           let paths = payload["paths"]?.value as? [String] {
            // Handle batch file update
            for path in paths {
                syncFileUpdate(path: path)
            }
        } else if let path = payload["path"]?.value as? String {
            // Handle single file update
            syncFileUpdate(path: path)
        }
    }
    
    private func handleFileDeleted(_ event: Event) {
        guard let baseEvent = event as? BaseEvent,
              let payload = baseEvent.payload else {
            return
        }
        
        // Check if it's a batch event
        if let isBatch = payload["isBatch"]?.value as? Bool, isBatch,
           let paths = payload["paths"]?.value as? [String] {
            // Handle batch file deletion
            for path in paths {
                syncFileDeletion(path: path)
            }
        } else if let path = payload["path"]?.value as? String {
            // Handle single file deletion
            syncFileDeletion(path: path)
        }
    }
    
    private func handleFileContentChanged(_ event: Event) {
        guard let baseEvent = event as? BaseEvent,
              let payload = baseEvent.payload,
              let path = payload["path"]?.value as? String else {
            return
        }
        
        // Sync file content change
        syncFileContentChange(path: path)
    }
    
    // Sync file creation with server
    private func syncFileCreation(path: String) {
        print("Syncing file creation: \(path)")
        // Implementation...
    }
    
    // Sync file update with server
    private func syncFileUpdate(path: String) {
        print("Syncing file update: \(path)")
        // Implementation...
    }
    
    // Sync file deletion with server
    private func syncFileDeletion(path: String) {
        print("Syncing file deletion: \(path)")
        // Implementation...
    }
    
    // Sync file content change with server
    private func syncFileContentChange(path: String) {
        print("Syncing file content change: \(path)")
        // Implementation...
    }
}
```

This implementation guide provides a comprehensive approach to event handling in the Mac client, covering event types, processing, routing, prioritization, and integration with app components.