import Foundation

/// Base protocol for all action events
public protocol ActionEvent: Event {}

/// Agent action event
public struct AgentAction: ActionEvent {
    public let id: String
    public let timestamp: Date
    public let type: EventType = .agentAction
    public let action: AgentActionType
    public let data: String?
    
    public enum AgentActionType: String, Codable {
        case start
        case stop
        case reset
    }
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), action: AgentActionType, data: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.data = data
    }
}

/// Command action event
public struct CommandAction: ActionEvent {
    public let id: String
    public let timestamp: Date
    public let type: EventType = .commandAction
    public let command: String
    public let isInput: Bool
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), command: String, isInput: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.command = command
        self.isInput = isInput
    }
}

/// File action event
public struct FileAction: ActionEvent {
    public let id: String
    public let timestamp: Date
    public let type: EventType = .fileAction
    public let action: FileActionType
    public let path: String
    public let content: String?
    
    public enum FileActionType: String, Codable {
        case read
        case write
        case list
    }
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), action: FileActionType, path: String, content: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.path = path
        self.content = content
    }
}

/// Browse action event
public struct BrowseAction: ActionEvent {
    public let id: String
    public let timestamp: Date
    public let type: EventType = .browseAction
    public let url: String
    public let action: BrowseActionType
    public let code: String?
    
    public enum BrowseActionType: String, Codable {
        case navigate
        case interact
    }
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), url: String, action: BrowseActionType, code: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.url = url
        self.action = action
        self.code = code
    }
}

/// Message action event
public struct MessageAction: ActionEvent {
    public let id: String
    public let timestamp: Date
    public let type: EventType = .messageAction
    public let content: String
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), content: String) {
        self.id = id
        self.timestamp = timestamp
        self.content = content
    }
}

/// System action event
public struct SystemAction: ActionEvent {
    public let id: String
    public let timestamp: Date
    public let type: EventType = .systemAction
    public let action: SystemActionType
    
    public enum SystemActionType: String, Codable {
        case ping
        case authenticate
        case disconnect
    }
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), action: SystemActionType) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
    }
}