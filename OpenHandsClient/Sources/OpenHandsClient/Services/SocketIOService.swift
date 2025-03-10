import Foundation
import SocketIO
import Combine

/// Service for handling Socket.IO connections and events
public class SocketIOService {
    private let manager: SocketManager
    private let socket: SocketIOClient
    private let settings: BackendSettings
    
    private let eventSubject = PassthroughSubject<Event, OpenHandsError>()
    private let statusSubject = PassthroughSubject<StatusObservation, Never>()
    
    public var eventPublisher: AnyPublisher<Event, OpenHandsError> {
        return eventSubject.eraseToAnyPublisher()
    }
    
    public var statusPublisher: AnyPublisher<StatusObservation, Never> {
        return statusSubject.eraseToAnyPublisher()
    }
    
    public init(settings: BackendSettings) {
        self.settings = settings
        
        guard let socketURL = settings.socketURL else {
            fatalError("Invalid socket URL")
        }
        
        self.manager = SocketManager(socketURL: socketURL, config: [.log(true), .compress])
        self.socket = manager.defaultSocket
        
        setupSocketHandlers()
    }
    
    private func setupSocketHandlers() {
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            guard let self = self else { return }
            let statusEvent = StatusObservation(status: .connected, message: "Connected to server")
            self.statusSubject.send(statusEvent)
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            guard let self = self else { return }
            let statusEvent = StatusObservation(status: .disconnected, message: "Disconnected from server")
            self.statusSubject.send(statusEvent)
        }
        
        socket.on(clientEvent: .error) { [weak self] data, ack in
            guard let self = self else { return }
            let errorMessage = data.first as? String ?? "Unknown error"
            let statusEvent = StatusObservation(status: .error, message: errorMessage)
            self.statusSubject.send(statusEvent)
        }
        
        // Handle incoming events from the server
        socket.on("oh_event") { [weak self] data, ack in
            guard let self = self else { return }
            self.handleIncomingEvent(data: data)
        }
    }
    
    private func handleIncomingEvent(data: [Any]) {
        guard let eventData = data.first as? [String: Any],
              let eventTypeRaw = eventData["type"] as? String,
              let eventType = EventType(rawValue: eventTypeRaw) else {
            eventSubject.send(completion: .failure(.invalidEventType("Invalid event data")))
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: eventData)
            
            switch eventType {
            case .commandObservation:
                let event = try JSONDecoder().decode(CommandObservation.self, from: jsonData)
                eventSubject.send(event)
            case .fileObservation:
                let event = try JSONDecoder().decode(FileObservation.self, from: jsonData)
                eventSubject.send(event)
            case .browserObservation:
                let event = try JSONDecoder().decode(BrowserObservation.self, from: jsonData)
                eventSubject.send(event)
            case .agentObservation:
                let event = try JSONDecoder().decode(AgentObservation.self, from: jsonData)
                eventSubject.send(event)
            case .statusObservation:
                let event = try JSONDecoder().decode(StatusObservation.self, from: jsonData)
                eventSubject.send(event)
                statusSubject.send(event)
            default:
                eventSubject.send(completion: .failure(.invalidEventType("Unexpected event type: \(eventType)")))
            }
        } catch {
            eventSubject.send(completion: .failure(.decodingFailed(error.localizedDescription)))
        }
    }
    
    public func connect() {
        socket.connect()
    }
    
    public func disconnect() {
        socket.disconnect()
    }
    
    public func sendEvent<T: ActionEvent>(_ event: T) -> AnyPublisher<Void, OpenHandsError> {
        return Future<Void, OpenHandsError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown("SocketIOService instance is nil")))
                return
            }
            
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(event)
                
                guard let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    promise(.failure(.eventHandlingFailed("Failed to convert event to JSON dictionary")))
                    return
                }
                
                self.socket.emit("oh_action", jsonDict) {
                    promise(.success(()))
                }
            } catch {
                promise(.failure(.eventHandlingFailed("Failed to encode event: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
}