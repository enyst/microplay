import Foundation

/// Base protocol for all events
public protocol Event: Codable {
    var id: String { get }
    var timestamp: Date { get }
    var type: EventType { get }
}

/// Types of events in the OpenHands system
public enum EventType: String, Codable {
    // Action events (client to server)
    case agentAction = "agent_action"
    case commandAction = "command_action"
    case fileAction = "file_action"
    case browseAction = "browse_action"
    case messageAction = "message_action"
    case systemAction = "system_action"
    
    // Observation events (server to client)
    case commandObservation = "command_observation"
    case fileObservation = "file_observation"
    case browserObservation = "browser_observation"
    case agentObservation = "agent_observation"
    case statusObservation = "status_observation"
}

/// Base struct for all events with common properties
public struct BaseEvent: Event {
    public let id: String
    public let timestamp: Date
    public let type: EventType
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), type: EventType) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
    }
}