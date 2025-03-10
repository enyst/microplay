import Foundation
import Combine

/// Service for handling and routing events
public class EventService {
    private let socketService: SocketIOService
    private var cancellables = Set<AnyCancellable>()
    
    // Event publishers for specific event types
    private let commandSubject = PassthroughSubject<CommandObservation, Never>()
    private let fileSubject = PassthroughSubject<FileObservation, Never>()
    private let browserSubject = PassthroughSubject<BrowserObservation, Never>()
    private let agentSubject = PassthroughSubject<AgentObservation, Never>()
    private let errorSubject = PassthroughSubject<OpenHandsError, Never>()
    
    // Public publishers
    public var commandPublisher: AnyPublisher<CommandObservation, Never> {
        return commandSubject.eraseToAnyPublisher()
    }
    
    public var filePublisher: AnyPublisher<FileObservation, Never> {
        return fileSubject.eraseToAnyPublisher()
    }
    
    public var browserPublisher: AnyPublisher<BrowserObservation, Never> {
        return browserSubject.eraseToAnyPublisher()
    }
    
    public var agentPublisher: AnyPublisher<AgentObservation, Never> {
        return agentSubject.eraseToAnyPublisher()
    }
    
    public var errorPublisher: AnyPublisher<OpenHandsError, Never> {
        return errorSubject.eraseToAnyPublisher()
    }
    
    public var statusPublisher: AnyPublisher<StatusObservation, Never> {
        return socketService.statusPublisher
    }
    
    public init(socketService: SocketIOService) {
        self.socketService = socketService
        setupEventRouting()
    }
    
    private func setupEventRouting() {
        socketService.eventPublisher
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorSubject.send(error)
                        print("Event error: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] event in
                    self?.routeEvent(event)
                }
            )
            .store(in: &cancellables)
    }
    
    private func routeEvent(_ event: Event) {
        switch event.type {
        case .commandObservation:
            if let commandEvent = event as? CommandObservation {
                commandSubject.send(commandEvent)
            } else {
                errorSubject.send(.typeCastFailed(message: "Failed to cast event to CommandObservation"))
            }
        case .fileObservation:
            if let fileEvent = event as? FileObservation {
                fileSubject.send(fileEvent)
            } else {
                errorSubject.send(.typeCastFailed(message: "Failed to cast event to FileObservation"))
            }
        case .browserObservation:
            if let browserEvent = event as? BrowserObservation {
                browserSubject.send(browserEvent)
            } else {
                errorSubject.send(.typeCastFailed(message: "Failed to cast event to BrowserObservation"))
            }
        case .agentObservation:
            if let agentEvent = event as? AgentObservation {
                agentSubject.send(agentEvent)
            } else {
                errorSubject.send(.typeCastFailed(message: "Failed to cast event to AgentObservation"))
            }
        case .statusObservation:
            // Status observations are handled directly by the SocketIOService
            break
        default:
            errorSubject.send(.invalidEventType(message: "Unhandled event type: \(event.type)"))
        }
    }
    
    // Methods for sending action events
    
    public func sendAgentAction(_ action: AgentAction) -> AnyPublisher<Void, OpenHandsError> {
        // Validate connection before sending
        guard socketService.isConnected else {
            return Fail(error: OpenHandsError.socketDisconnected(message: "Cannot send agent action: Socket is not connected")).eraseToAnyPublisher()
        }
        return socketService.sendEvent(action)
    }
    
    public func sendCommandAction(_ action: CommandAction) -> AnyPublisher<Void, OpenHandsError> {
        // Validate connection before sending
        guard socketService.isConnected else {
            return Fail(error: OpenHandsError.socketDisconnected(message: "Cannot send command action: Socket is not connected")).eraseToAnyPublisher()
        }
        return socketService.sendEvent(action)
    }
    
    public func sendFileAction(_ action: FileAction) -> AnyPublisher<Void, OpenHandsError> {
        // Validate connection before sending
        guard socketService.isConnected else {
            return Fail(error: OpenHandsError.socketDisconnected(message: "Cannot send file action: Socket is not connected")).eraseToAnyPublisher()
        }
        
        // Validate path
        if action.path.isEmpty {
            return Fail(error: OpenHandsError.invalidRequest(message: "File path cannot be empty")).eraseToAnyPublisher()
        }
        
        // For write actions, validate content
        if action.action == .write && (action.content == nil || action.content?.isEmpty == true) {
            return Fail(error: OpenHandsError.invalidRequest(message: "File content cannot be empty for write action")).eraseToAnyPublisher()
        }
        
        return socketService.sendEvent(action)
    }
    
    public func sendBrowseAction(_ action: BrowseAction) -> AnyPublisher<Void, OpenHandsError> {
        // Validate connection before sending
        guard socketService.isConnected else {
            return Fail(error: OpenHandsError.socketDisconnected(message: "Cannot send browse action: Socket is not connected")).eraseToAnyPublisher()
        }
        
        // Validate URL
        if action.url.isEmpty {
            return Fail(error: OpenHandsError.invalidURL(message: "Browser URL cannot be empty")).eraseToAnyPublisher()
        }
        
        // For interact actions, validate code
        if action.action == .interact && (action.code == nil || action.code?.isEmpty == true) {
            return Fail(error: OpenHandsError.invalidRequest(message: "Browser interaction code cannot be empty")).eraseToAnyPublisher()
        }
        
        return socketService.sendEvent(action)
    }
    
    public func sendMessageAction(_ action: MessageAction) -> AnyPublisher<Void, OpenHandsError> {
        // Validate connection before sending
        guard socketService.isConnected else {
            return Fail(error: OpenHandsError.socketDisconnected(message: "Cannot send message action: Socket is not connected")).eraseToAnyPublisher()
        }
        
        // Validate message content
        if action.content.isEmpty {
            return Fail(error: OpenHandsError.invalidRequest(message: "Message content cannot be empty")).eraseToAnyPublisher()
        }
        
        return socketService.sendEvent(action)
    }
    
    public func sendSystemAction(_ action: SystemAction) -> AnyPublisher<Void, OpenHandsError> {
        // Validate connection before sending
        guard socketService.isConnected else {
            return Fail(error: OpenHandsError.socketDisconnected(message: "Cannot send system action: Socket is not connected")).eraseToAnyPublisher()
        }
        return socketService.sendEvent(action)
    }
    
    // Convenience methods for common actions
    
    public func executeCommand(_ command: String) -> AnyPublisher<Void, OpenHandsError> {
        if command.isEmpty {
            return Fail(error: OpenHandsError.invalidRequest(message: "Command cannot be empty")).eraseToAnyPublisher()
        }
        let action = CommandAction(command: command)
        return sendCommandAction(action)
    }
    
    public func readFile(path: String) -> AnyPublisher<Void, OpenHandsError> {
        if path.isEmpty {
            return Fail(error: OpenHandsError.invalidRequest(message: "File path cannot be empty")).eraseToAnyPublisher()
        }
        let action = FileAction(action: .read, path: path)
        return sendFileAction(action)
    }
    
    public func writeFile(path: String, content: String) -> AnyPublisher<Void, OpenHandsError> {
        if path.isEmpty {
            return Fail(error: OpenHandsError.invalidRequest(message: "File path cannot be empty")).eraseToAnyPublisher()
        }
        if content.isEmpty {
            return Fail(error: OpenHandsError.invalidRequest(message: "File content cannot be empty")).eraseToAnyPublisher()
        }
        let action = FileAction(action: .write, path: path, content: content)
        return sendFileAction(action)
    }
    
    public func listFiles(path: String) -> AnyPublisher<Void, OpenHandsError> {
        if path.isEmpty {
            return Fail(error: OpenHandsError.invalidRequest(message: "Directory path cannot be empty")).eraseToAnyPublisher()
        }
        let action = FileAction(action: .list, path: path)
        return sendFileAction(action)
    }
    
    public func navigateBrowser(url: String) -> AnyPublisher<Void, OpenHandsError> {
        if url.isEmpty {
            return Fail(error: OpenHandsError.invalidURL(message: "Browser URL cannot be empty")).eraseToAnyPublisher()
        }
        let action = BrowseAction(url: url, action: .navigate)
        return sendBrowseAction(action)
    }
    
    public func interactBrowser(url: String, code: String) -> AnyPublisher<Void, OpenHandsError> {
        if url.isEmpty {
            return Fail(error: OpenHandsError.invalidURL(message: "Browser URL cannot be empty")).eraseToAnyPublisher()
        }
        if code.isEmpty {
            return Fail(error: OpenHandsError.invalidRequest(message: "Browser interaction code cannot be empty")).eraseToAnyPublisher()
        }
        let action = BrowseAction(url: url, action: .interact, code: code)
        return sendBrowseAction(action)
    }
    
    public func sendMessage(content: String) -> AnyPublisher<Void, OpenHandsError> {
        if content.isEmpty {
            return Fail(error: OpenHandsError.invalidRequest(message: "Message content cannot be empty")).eraseToAnyPublisher()
        }
        let action = MessageAction(content: content)
        return sendMessageAction(action)
    }
    
    public func startAgent() -> AnyPublisher<Void, OpenHandsError> {
        let action = AgentAction(action: .start)
        return sendAgentAction(action)
    }
    
    public func stopAgent() -> AnyPublisher<Void, OpenHandsError> {
        let action = AgentAction(action: .stop)
        return sendAgentAction(action)
    }
    
    public func resetAgent() -> AnyPublisher<Void, OpenHandsError> {
        let action = AgentAction(action: .reset)
        return sendAgentAction(action)
    }
    
    public func ping() -> AnyPublisher<Void, OpenHandsError> {
        let action = SystemAction(action: .ping)
        return sendSystemAction(action)
    }
    
    /// Checks if the socket connection is active
    public var isConnected: Bool {
        return socketService.isConnected
    }
    
    /// Connects to the socket server
    public func connect() {
        socketService.connect()
    }
    
    /// Disconnects from the socket server
    public func disconnect() {
        socketService.disconnect()
    }
}