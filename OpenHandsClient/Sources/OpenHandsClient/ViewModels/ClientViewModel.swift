import Foundation
import Combine

/// Main view model for the OpenHands client
public class ClientViewModel: ObservableObject {
    private let socketService: SocketIOService
    private let apiService: APIService
    private let eventService: EventService
    private var cancellables = Set<AnyCancellable>()
    
    // Published properties for UI updates
    @Published public var isConnected = false
    @Published public var connectionStatus = "Disconnected"
    @Published public var commandOutput = ""
    @Published public var agentOutput = ""
    @Published public var agentStatus: AgentObservation.AgentStatus = .idle
    @Published public var fileContent: String?
    @Published public var fileList: [FileNode] = []
    @Published public var currentPath = "/"
    @Published public var errorMessage: String?
    
    public init(settings: BackendSettings) {
        self.socketService = SocketIOService(settings: settings)
        self.apiService = APIService(settings: settings)
        self.eventService = EventService(socketService: socketService)
        
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Status updates
        eventService.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                
                switch status.status {
                case .connected:
                    self.isConnected = true
                    self.connectionStatus = "Connected"
                case .disconnected:
                    self.isConnected = false
                    self.connectionStatus = "Disconnected"
                case .error:
                    self.isConnected = false
                    self.connectionStatus = "Error: \(status.message ?? "Unknown error")"
                    self.errorMessage = status.message
                }
            }
            .store(in: &cancellables)
        
        // Command observations
        eventService.commandPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] observation in
                guard let self = self else { return }
                
                if observation.isComplete {
                    self.commandOutput += "\n[Exit code: \(observation.exitCode ?? 0)]\n"
                } else {
                    self.commandOutput += observation.output
                }
            }
            .store(in: &cancellables)
        
        // Agent observations
        eventService.agentPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] observation in
                guard let self = self else { return }
                
                self.agentStatus = observation.status
                self.agentOutput += observation.content
            }
            .store(in: &cancellables)
        
        // File observations
        eventService.filePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] observation in
                guard let self = self else { return }
                
                if let content = observation.content {
                    self.fileContent = content
                }
                
                if let fileList = observation.fileList {
                    self.fileList = fileList
                    if !observation.path.isEmpty {
                        self.currentPath = observation.path
                    }
                }
                
                if let error = observation.error {
                    self.errorMessage = error
                }
            }
            .store(in: &cancellables)
    }
    
    // Connection management
    
    public func connect() {
        socketService.connect()
    }
    
    public func disconnect() {
        socketService.disconnect()
    }
    
    // Command execution
    
    public func executeCommand(_ command: String) {
        eventService.executeCommand(command)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    // File operations
    
    public func readFile(path: String) {
        eventService.readFile(path: path)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    public func writeFile(path: String, content: String) {
        eventService.writeFile(path: path, content: content)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    public func listFiles(path: String) {
        eventService.listFiles(path: path)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    // Agent control
    
    public func startAgent() {
        eventService.startAgent()
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    public func stopAgent() {
        eventService.stopAgent()
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    public func resetAgent() {
        eventService.resetAgent()
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    public func sendMessage(content: String) {
        eventService.sendMessage(content: content)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    // Error handling
    
    public func clearError() {
        errorMessage = nil
    }
}