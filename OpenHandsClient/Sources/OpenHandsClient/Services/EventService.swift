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
            }
        case .fileObservation:
            if let fileEvent = event as? FileObservation {
                fileSubject.send(fileEvent)
            }
        case .browserObservation:
            if let browserEvent = event as? BrowserObservation {
                browserSubject.send(browserEvent)
            }
        case .agentObservation:
            if let agentEvent = event as? AgentObservation {
                agentSubject.send(agentEvent)
            }
        default:
            break
        }
    }
    
    // Methods for sending action events
    
    public func sendAgentAction(_ action: AgentAction) -> AnyPublisher<Void, OpenHandsError> {
        return socketService.sendEvent(action)
    }
    
    public func sendCommandAction(_ action: CommandAction) -> AnyPublisher<Void, OpenHandsError> {
        return socketService.sendEvent(action)
    }
    
    public func sendFileAction(_ action: FileAction) -> AnyPublisher<Void, OpenHandsError> {
        return socketService.sendEvent(action)
    }
    
    public func sendBrowseAction(_ action: BrowseAction) -> AnyPublisher<Void, OpenHandsError> {
        return socketService.sendEvent(action)
    }
    
    public func sendMessageAction(_ action: MessageAction) -> AnyPublisher<Void, OpenHandsError> {
        return socketService.sendEvent(action)
    }
    
    public func sendSystemAction(_ action: SystemAction) -> AnyPublisher<Void, OpenHandsError> {
        return socketService.sendEvent(action)
    }
    
    // Convenience methods for common actions
    
    public func executeCommand(_ command: String) -> AnyPublisher<Void, OpenHandsError> {
        let action = CommandAction(command: command)
        return sendCommandAction(action)
    }
    
    public func readFile(path: String) -> AnyPublisher<Void, OpenHandsError> {
        let action = FileAction(action: .read, path: path)
        return sendFileAction(action)
    }
    
    public func writeFile(path: String, content: String) -> AnyPublisher<Void, OpenHandsError> {
        let action = FileAction(action: .write, path: path, content: content)
        return sendFileAction(action)
    }
    
    public func listFiles(path: String) -> AnyPublisher<Void, OpenHandsError> {
        let action = FileAction(action: .list, path: path)
        return sendFileAction(action)
    }
    
    public func navigateBrowser(url: String) -> AnyPublisher<Void, OpenHandsError> {
        let action = BrowseAction(url: url, action: .navigate)
        return sendBrowseAction(action)
    }
    
    public func interactBrowser(url: String, code: String) -> AnyPublisher<Void, OpenHandsError> {
        let action = BrowseAction(url: url, action: .interact, code: code)
        return sendBrowseAction(action)
    }
    
    public func sendMessage(content: String) -> AnyPublisher<Void, OpenHandsError> {
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
}