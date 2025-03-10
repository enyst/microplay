import Foundation

/// Base protocol for all observation events
public protocol ObservationEvent: Event {}

/// Command observation event
public struct CommandObservation: ObservationEvent {
    public let id: String
    public let timestamp: Date
    public let type: EventType = .commandObservation
    public let output: String
    public let exitCode: Int?
    public let isComplete: Bool
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), output: String, exitCode: Int? = nil, isComplete: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.output = output
        self.exitCode = exitCode
        self.isComplete = isComplete
    }
}

/// File observation event
public struct FileObservation: ObservationEvent {
    public let id: String
    public let timestamp: Date
    public let type: EventType = .fileObservation
    public let path: String
    public let content: String?
    public let fileList: [FileNode]?
    public let error: String?
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), path: String, content: String? = nil, fileList: [FileNode]? = nil, error: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.path = path
        self.content = content
        self.fileList = fileList
        self.error = error
    }
}

/// Browser observation event
public struct BrowserObservation: ObservationEvent {
    public let id: String
    public let timestamp: Date
    public let type: EventType = .browserObservation
    public let url: String
    public let content: String
    public let screenshot: String?
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), url: String, content: String, screenshot: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.url = url
        self.content = content
        self.screenshot = screenshot
    }
}

/// Agent observation event
public struct AgentObservation: ObservationEvent {
    public let id: String
    public let timestamp: Date
    public let type: EventType = .agentObservation
    public let content: String
    public let status: AgentStatus
    
    public enum AgentStatus: String, Codable {
        case thinking
        case responding
        case idle
        case error
    }
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), content: String, status: AgentStatus) {
        self.id = id
        self.timestamp = timestamp
        self.content = content
        self.status = status
    }
}

/// Status observation event
public struct StatusObservation: ObservationEvent {
    public let id: String
    public let timestamp: Date
    public let type: EventType = .statusObservation
    public let status: ConnectionStatus
    public let message: String?
    
    public enum ConnectionStatus: String, Codable {
        case connected
        case disconnected
        case error
    }
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), status: ConnectionStatus, message: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.status = status
        self.message = message
    }
}