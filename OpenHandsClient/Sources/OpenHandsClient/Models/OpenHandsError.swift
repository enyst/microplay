import Foundation

/// Represents errors that can occur in the OpenHands client
public enum OpenHandsError: Error, Equatable {
    /// Connection errors
    case connectionFailed(String)
    case socketDisconnected
    case socketTimeout
    
    /// API errors
    case invalidURL
    case requestFailed(Int, String)
    case decodingFailed(String)
    case encodingFailed(String)
    
    /// File errors
    case fileNotFound(String)
    case fileAccessDenied(String)
    case invalidFilePath(String)
    
    /// Event errors
    case invalidEventType(String)
    case eventRoutingFailed(String)
    
    /// General errors
    case unknown(String)
    
    public var localizedDescription: String {
        switch self {
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .socketDisconnected:
            return "Socket disconnected unexpectedly"
        case .socketTimeout:
            return "Socket connection timed out"
            
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed(let statusCode, let message):
            return "Request failed with status code \(statusCode): \(message)"
        case .decodingFailed(let message):
            return "Failed to decode response: \(message)"
        case .encodingFailed(let message):
            return "Failed to encode request: \(message)"
            
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileAccessDenied(let path):
            return "Access denied to file: \(path)"
        case .invalidFilePath(let path):
            return "Invalid file path: \(path)"
            
        case .invalidEventType(let type):
            return "Invalid event type: \(type)"
        case .eventRoutingFailed(let reason):
            return "Event routing failed: \(reason)"
            
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
    
    public static func == (lhs: OpenHandsError, rhs: OpenHandsError) -> Bool {
        switch (lhs, rhs) {
        case (.connectionFailed(let lhsReason), .connectionFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.socketDisconnected, .socketDisconnected):
            return true
        case (.socketTimeout, .socketTimeout):
            return true
            
        case (.invalidURL, .invalidURL):
            return true
        case (.requestFailed(let lhsCode, let lhsMessage), .requestFailed(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case (.decodingFailed(let lhsMessage), .decodingFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.encodingFailed(let lhsMessage), .encodingFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
            
        case (.fileNotFound(let lhsPath), .fileNotFound(let rhsPath)):
            return lhsPath == rhsPath
        case (.fileAccessDenied(let lhsPath), .fileAccessDenied(let rhsPath)):
            return lhsPath == rhsPath
        case (.invalidFilePath(let lhsPath), .invalidFilePath(let rhsPath)):
            return lhsPath == rhsPath
            
        case (.invalidEventType(let lhsType), .invalidEventType(let rhsType)):
            return lhsType == rhsType
        case (.eventRoutingFailed(let lhsReason), .eventRoutingFailed(let rhsReason)):
            return lhsReason == rhsReason
            
        case (.unknown(let lhsMessage), .unknown(let rhsMessage)):
            return lhsMessage == rhsMessage
            
        default:
            return false
        }
    }
}