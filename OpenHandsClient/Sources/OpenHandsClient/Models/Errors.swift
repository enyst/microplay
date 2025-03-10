import Foundation

/// Errors that can occur in the OpenHands client
public enum OpenHandsError: Error, Equatable {
    // Connection errors
    case connectionFailed(String)
    case socketDisconnected(String)
    case socketTimeout(String)
    
    // API errors
    case invalidResponse(Int)
    case decodingFailed(String)
    case requestFailed(String)
    
    // File errors
    case fileNotFound(String)
    case fileAccessDenied(String)
    case fileOperationFailed(String)
    
    // Event errors
    case invalidEventType(String)
    case eventHandlingFailed(String)
    
    // General errors
    case unknown(String)
    
    public var localizedDescription: String {
        switch self {
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .socketDisconnected(let message):
            return "Socket disconnected: \(message)"
        case .socketTimeout(let message):
            return "Socket timeout: \(message)"
        case .invalidResponse(let statusCode):
            return "Invalid response with status code: \(statusCode)"
        case .decodingFailed(let message):
            return "Decoding failed: \(message)"
        case .requestFailed(let message):
            return "Request failed: \(message)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileAccessDenied(let path):
            return "File access denied: \(path)"
        case .fileOperationFailed(let message):
            return "File operation failed: \(message)"
        case .invalidEventType(let type):
            return "Invalid event type: \(type)"
        case .eventHandlingFailed(let message):
            return "Event handling failed: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
    
    public static func == (lhs: OpenHandsError, rhs: OpenHandsError) -> Bool {
        switch (lhs, rhs) {
        case (.connectionFailed(let lhsMsg), .connectionFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.socketDisconnected(let lhsMsg), .socketDisconnected(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.socketTimeout(let lhsMsg), .socketTimeout(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.invalidResponse(let lhsCode), .invalidResponse(let rhsCode)):
            return lhsCode == rhsCode
        case (.decodingFailed(let lhsMsg), .decodingFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.requestFailed(let lhsMsg), .requestFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.fileNotFound(let lhsPath), .fileNotFound(let rhsPath)):
            return lhsPath == rhsPath
        case (.fileAccessDenied(let lhsPath), .fileAccessDenied(let rhsPath)):
            return lhsPath == rhsPath
        case (.fileOperationFailed(let lhsMsg), .fileOperationFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.invalidEventType(let lhsType), .invalidEventType(let rhsType)):
            return lhsType == rhsType
        case (.eventHandlingFailed(let lhsMsg), .eventHandlingFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.unknown(let lhsMsg), .unknown(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}