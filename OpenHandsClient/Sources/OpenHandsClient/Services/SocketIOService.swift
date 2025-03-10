import Foundation
import SocketIO
import Combine
import os.log

/// Service for handling Socket.IO connections and events
public class SocketIOService {
    private let manager: SocketManager
    private let socket: SocketIOClient
    private let settings: BackendSettings
    private let logger = Logger(subsystem: "dev.all-hands.OpenHandsClient", category: "SocketIOService")
    
    private let eventSubject = PassthroughSubject<Event, OpenHandsError>()
    private let statusSubject = PassthroughSubject<StatusObservation, Never>()
    private let reconnectTimer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()
    private var reconnectCancellable: AnyCancellable?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    
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
        
        // Configure socket with more robust settings
        let config: SocketIOClientConfiguration = [
            .log(true),
            .compress,
            .reconnects(true),
            .reconnectAttempts(5),
            .reconnectWait(3000),
            .forceNew(true),
            .secure(settings.useTLS)
        ]
        
        self.manager = SocketManager(socketURL: socketURL, config: config)
        self.socket = manager.defaultSocket
        
        setupSocketHandlers()
        setupReconnectHandler()
    }
    
    private func setupSocketHandlers() {
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            guard let self = self else { return }
            self.reconnectAttempts = 0
            let statusEvent = StatusObservation(status: .connected, message: "Connected to server")
            self.statusSubject.send(statusEvent)
            self.logger.info("Socket connected successfully")
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            guard let self = self else { return }
            let reason = data.first as? String ?? "Unknown reason"
            let statusEvent = StatusObservation(status: .disconnected, message: "Disconnected from server: \(reason)")
            self.statusSubject.send(statusEvent)
            self.logger.warning("Socket disconnected: \(reason)")
            
            // Don't send completion if we're intentionally disconnecting
            if reason != "io client disconnect" {
                // Notify event subscribers about the disconnection
                self.eventSubject.send(completion: .failure(.socketDisconnected(message: "Socket disconnected from server: \(reason)")))
            }
        }
        
        socket.on(clientEvent: .error) { [weak self] data, ack in
            guard let self = self else { return }
            let errorMessage = data.first as? String ?? "Unknown error"
            let statusEvent = StatusObservation(status: .error, message: "Socket error: \(errorMessage)")
            self.statusSubject.send(statusEvent)
            self.logger.error("Socket error: \(errorMessage)")
            
            // Notify event subscribers about the error
            self.eventSubject.send(completion: .failure(.connectionFailed(message: "Socket error: \(errorMessage)")))
        }
        
        socket.on(clientEvent: .reconnect) { [weak self] data, ack in
            guard let self = self else { return }
            self.reconnectAttempts += 1
            let statusEvent = StatusObservation(status: .connecting, message: "Reconnecting to server (attempt \(self.reconnectAttempts))")
            self.statusSubject.send(statusEvent)
            self.logger.info("Socket reconnecting, attempt \(self.reconnectAttempts)")
        }
        
        socket.on(clientEvent: .reconnectAttempt) { [weak self] data, ack in
            guard let self = self else { return }
            let attempt = data.first as? Int ?? self.reconnectAttempts
            let statusEvent = StatusObservation(status: .connecting, message: "Reconnection attempt \(attempt)")
            self.statusSubject.send(statusEvent)
            self.logger.info("Socket reconnection attempt \(attempt)")
        }
        
        socket.on(clientEvent: .ping) { [weak self] _, _ in
            self?.logger.debug("Socket ping")
        }
        
        socket.on(clientEvent: .pong) { [weak self] _, _ in
            self?.logger.debug("Socket pong")
        }
        
        // Handle incoming events from the server
        socket.on("oh_event") { [weak self] data, ack in
            guard let self = self else { return }
            self.handleIncomingEvent(data: data)
        }
    }
    
    private func setupReconnectHandler() {
        reconnectCancellable = reconnectTimer.sink { [weak self] _ in
            guard let self = self else { return }
            
            // Only attempt to reconnect if we're disconnected and not already trying to connect
            if !self.isConnected && self.socket.status != .connecting && self.reconnectAttempts < self.maxReconnectAttempts {
                self.logger.info("Auto-reconnect attempt \(self.reconnectAttempts + 1) of \(self.maxReconnectAttempts)")
                self.connect()
            }
        }
    }
    
    private func handleIncomingEvent(data: [Any]) {
        guard let eventData = data.first as? [String: Any] else {
            let error = OpenHandsError.invalidData(message: "Invalid event data format")
            logger.error("Event error: \(error.localizedDescription)")
            eventSubject.send(completion: .failure(error))
            return
        }
        
        guard let eventTypeRaw = eventData["type"] as? String else {
            let error = OpenHandsError.invalidData(message: "Missing event type")
            logger.error("Event error: \(error.localizedDescription)")
            eventSubject.send(completion: .failure(error))
            return
        }
        
        guard let eventType = EventType(rawValue: eventTypeRaw) else {
            let error = OpenHandsError.invalidEventType(message: "Unknown event type: \(eventTypeRaw)")
            logger.error("Event error: \(error.localizedDescription)")
            eventSubject.send(completion: .failure(error))
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: eventData)
            logger.debug("Received event of type: \(eventTypeRaw)")
            
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
                let error = OpenHandsError.invalidEventType(message: "Unexpected event type: \(eventType)")
                logger.error("Event error: \(error.localizedDescription)")
                eventSubject.send(completion: .failure(error))
            }
        } catch {
            let decodingError = OpenHandsError.decodingFailed(message: "Failed to decode event: \(error.localizedDescription)")
            logger.error("Event decoding error: \(error.localizedDescription)")
            eventSubject.send(completion: .failure(decodingError))
        }
    }
    
    public func connect() {
        if socket.status == .connected {
            logger.info("Socket already connected, ignoring connect request")
            return
        }
        
        if socket.status == .connecting {
            logger.info("Socket already connecting, ignoring connect request")
            return
        }
        
        logger.info("Connecting to socket at \(settings.socketURL?.absoluteString ?? "unknown URL")")
        let statusEvent = StatusObservation(status: .connecting, message: "Connecting to server...")
        statusSubject.send(statusEvent)
        socket.connect()
    }
    
    public func disconnect() {
        if socket.status == .disconnected {
            logger.info("Socket already disconnected, ignoring disconnect request")
            return
        }
        
        logger.info("Disconnecting from socket")
        let statusEvent = StatusObservation(status: .disconnecting, message: "Disconnecting from server...")
        statusSubject.send(statusEvent)
        socket.disconnect()
    }
    
    public func sendEvent<T: ActionEvent>(_ event: T) -> AnyPublisher<Void, OpenHandsError> {
        return Future<Void, OpenHandsError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.internalError(message: "SocketIOService instance is nil")))
                return
            }
            
            // Check if socket is connected
            guard self.socket.status == .connected else {
                let error = OpenHandsError.socketDisconnected(message: "Socket is not connected. Current status: \(self.socket.status)")
                self.logger.error("Send event error: \(error.localizedDescription)")
                promise(.failure(error))
                return
            }
            
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(event)
                
                guard let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    let error = OpenHandsError.encodingFailed(message: "Failed to convert event to JSON dictionary")
                    self.logger.error("Send event error: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                self.logger.debug("Sending event of type: \(event.type.rawValue)")
                self.socket.emit("oh_action", jsonDict) {
                    self.logger.debug("Event sent successfully: \(event.type.rawValue)")
                    promise(.success(()))
                }
            } catch {
                let encodingError = OpenHandsError.encodingFailed(message: "Failed to encode event: \(error.localizedDescription)")
                self.logger.error("Send event error: \(encodingError.localizedDescription)")
                promise(.failure(encodingError))
            }
        }.eraseToAnyPublisher()
    }
    
    /// Checks if the socket is currently connected
    public var isConnected: Bool {
        return socket.status == .connected
    }
    
    /// Returns the current connection status
    public var connectionStatus: SocketIOStatus {
        return socket.status
    }
    
    /// Sends a ping to the server to check connection
    public func ping() -> AnyPublisher<Void, OpenHandsError> {
        return Future<Void, OpenHandsError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.internalError(message: "SocketIOService instance is nil")))
                return
            }
            
            guard self.isConnected else {
                promise(.failure(.socketDisconnected(message: "Cannot ping: Socket is not connected")))
                return
            }
            
            self.logger.debug("Sending ping to server")
            self.socket.emit("ping") {
                self.logger.debug("Ping acknowledged by server")
                promise(.success(()))
            }
        }.eraseToAnyPublisher()
    }
    
    deinit {
        reconnectCancellable?.cancel()
        socket.disconnect()
        logger.debug("SocketIOService deinit")
    }
}