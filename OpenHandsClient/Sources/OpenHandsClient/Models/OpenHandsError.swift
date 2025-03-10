import Foundation

/// Represents errors that can occur in the OpenHands client
public enum OpenHandsError: Error, Equatable {
    // Connection errors
    case connectionFailed(String)
    case socketDisconnected(String)
    case socketTimeout(String)
    case networkUnavailable(String)
    case sslCertificateInvalid(String)
    case connectionRefused(String)
    case hostUnreachable(String)
    
    // API errors
    case invalidURL(String)
    case requestFailed(Int, String)
    case unauthorizedAccess(String)
    case resourceNotFound(String)
    case serverError(Int, String)
    case rateLimitExceeded(String)
    case invalidRequest(String)
    case invalidResponse(String)
    case requestTimeout(String)
    case badGateway(String)
    case serviceUnavailable(String)
    
    // Data errors
    case decodingFailed(String)
    case encodingFailed(String)
    case invalidData(String)
    case dataCorrupted(String)
    case typeCastFailed(String)
    case dataMissing(String)
    case dataIncomplete(String)
    
    // File errors
    case fileNotFound(String)
    case fileAccessDenied(String)
    case invalidFilePath(String)
    case fileOperationFailed(String)
    case directoryCreationFailed(String)
    
    // Event errors
    case invalidEventType(String)
    case eventRoutingFailed(String)
    case eventHandlingFailed(String)
    case eventTimeout(String)
    
    // General errors
    case unknown(String)
    case internalError(String)
    case notImplemented(String)
    
    /// Returns the error code associated with this error
    public var errorCode: ErrorCode {
        switch self {
        // Connection errors
        case .connectionFailed: return .connectionFailed
        case .socketDisconnected: return .socketDisconnected
        case .socketTimeout: return .socketTimeout
        case .networkUnavailable: return .networkUnavailable
        case .sslCertificateInvalid: return .sslCertificateInvalid
        case .connectionRefused: return .connectionRefused
        case .hostUnreachable: return .hostUnreachable
            
        // API errors
        case .invalidURL: return .invalidURL
        case .requestFailed: return .requestFailed
        case .unauthorizedAccess: return .unauthorizedAccess
        case .resourceNotFound: return .resourceNotFound
        case .serverError: return .serverError
        case .rateLimitExceeded: return .rateLimitExceeded
        case .invalidRequest: return .invalidRequest
        case .invalidResponse: return .invalidResponse
        case .requestTimeout: return .requestTimeout
        case .badGateway: return .badGateway
        case .serviceUnavailable: return .serviceUnavailable
            
        // Data errors
        case .decodingFailed: return .decodingFailed
        case .encodingFailed: return .encodingFailed
        case .invalidData: return .invalidData
        case .dataCorrupted: return .dataCorrupted
        case .typeCastFailed: return .typeCastFailed
        case .dataMissing: return .dataMissing
        case .dataIncomplete: return .dataIncomplete
            
        // File errors
        case .fileNotFound: return .fileNotFound
        case .fileAccessDenied: return .fileAccessDenied
        case .invalidFilePath: return .invalidFilePath
        case .fileOperationFailed: return .fileOperationFailed
        case .directoryCreationFailed: return .directoryCreationFailed
            
        // Event errors
        case .invalidEventType: return .invalidEventType
        case .eventRoutingFailed: return .eventRoutingFailed
        case .eventHandlingFailed: return .eventHandlingFailed
        case .eventTimeout: return .eventTimeout
            
        // General errors
        case .unknown: return .unknown
        case .internalError: return .internalError
        case .notImplemented: return .notImplemented
        }
    }
    
    public var localizedDescription: String {
        switch self {
        // Connection errors
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .socketDisconnected(let reason):
            return "Socket disconnected unexpectedly: \(reason)"
        case .socketTimeout(let reason):
            return "Socket connection timed out: \(reason)"
        case .networkUnavailable(let reason):
            return "Network is unavailable: \(reason)"
        case .sslCertificateInvalid(let reason):
            return "SSL certificate validation failed: \(reason)"
            
        // API errors
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .requestFailed(let statusCode, let message):
            return "Request failed with status code \(statusCode): \(message)"
        case .unauthorizedAccess(let resource):
            return "Unauthorized access to resource: \(resource)"
        case .resourceNotFound(let resource):
            return "Resource not found: \(resource)"
        case .serverError(let statusCode, let message):
            return "Server error with status code \(statusCode): \(message)"
        case .rateLimitExceeded(let message):
            return "Rate limit exceeded: \(message)"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
            
        // Data errors
        case .decodingFailed(let message):
            return "Failed to decode response: \(message)"
        case .encodingFailed(let message):
            return "Failed to encode request: \(message)"
        case .invalidData(let message):
            return "Invalid data format: \(message)"
        case .dataCorrupted(let message):
            return "Data is corrupted: \(message)"
        case .typeCastFailed(let message):
            return "Type cast failed: \(message)"
            
        // File errors
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileAccessDenied(let path):
            return "Access denied to file: \(path)"
        case .invalidFilePath(let path):
            return "Invalid file path: \(path)"
        case .fileOperationFailed(let message):
            return "File operation failed: \(message)"
        case .directoryCreationFailed(let path):
            return "Failed to create directory: \(path)"
            
        // Event errors
        case .invalidEventType(let type):
            return "Invalid event type: \(type)"
        case .eventRoutingFailed(let reason):
            return "Event routing failed: \(reason)"
        case .eventHandlingFailed(let reason):
            return "Event handling failed: \(reason)"
        case .eventTimeout(let message):
            return "Event timed out: \(message)"
            
        // General errors
        case .unknown(let message):
            return "Unknown error: \(message)"
        case .internalError(let message):
            return "Internal error: \(message)"
        case .notImplemented(let feature):
            return "Feature not implemented: \(feature)"
        }
    }
    
    /// Returns suggested recovery actions for the error
    public var recoverySuggestion: String {
        return self.errorCode.recoverySuggestion
    }
    
    public static func == (lhs: OpenHandsError, rhs: OpenHandsError) -> Bool {
        switch (lhs, rhs) {
        // Connection errors
        case (.connectionFailed(let lhsReason), .connectionFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.socketDisconnected(let lhsReason), .socketDisconnected(let rhsReason)):
            return lhsReason == rhsReason
        case (.socketTimeout(let lhsReason), .socketTimeout(let rhsReason)):
            return lhsReason == rhsReason
        case (.networkUnavailable(let lhsReason), .networkUnavailable(let rhsReason)):
            return lhsReason == rhsReason
        case (.sslCertificateInvalid(let lhsReason), .sslCertificateInvalid(let rhsReason)):
            return lhsReason == rhsReason
            
        // API errors
        case (.invalidURL(let lhsURL), .invalidURL(let rhsURL)):
            return lhsURL == rhsURL
        case (.requestFailed(let lhsCode, let lhsMessage), .requestFailed(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case (.unauthorizedAccess(let lhsResource), .unauthorizedAccess(let rhsResource)):
            return lhsResource == rhsResource
        case (.resourceNotFound(let lhsResource), .resourceNotFound(let rhsResource)):
            return lhsResource == rhsResource
        case (.serverError(let lhsCode, let lhsMessage), .serverError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case (.rateLimitExceeded(let lhsMessage), .rateLimitExceeded(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.invalidRequest(let lhsMessage), .invalidRequest(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.invalidResponse(let lhsMessage), .invalidResponse(let rhsMessage)):
            return lhsMessage == rhsMessage
            
        // Data errors
        case (.decodingFailed(let lhsMessage), .decodingFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.encodingFailed(let lhsMessage), .encodingFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.invalidData(let lhsMessage), .invalidData(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.dataCorrupted(let lhsMessage), .dataCorrupted(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.typeCastFailed(let lhsMessage), .typeCastFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
            
        // File errors
        case (.fileNotFound(let lhsPath), .fileNotFound(let rhsPath)):
            return lhsPath == rhsPath
        case (.fileAccessDenied(let lhsPath), .fileAccessDenied(let rhsPath)):
            return lhsPath == rhsPath
        case (.invalidFilePath(let lhsPath), .invalidFilePath(let rhsPath)):
            return lhsPath == rhsPath
        case (.fileOperationFailed(let lhsMessage), .fileOperationFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.directoryCreationFailed(let lhsPath), .directoryCreationFailed(let rhsPath)):
            return lhsPath == rhsPath
            
        // Event errors
        case (.invalidEventType(let lhsType), .invalidEventType(let rhsType)):
            return lhsType == rhsType
        case (.eventRoutingFailed(let lhsReason), .eventRoutingFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.eventHandlingFailed(let lhsReason), .eventHandlingFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.eventTimeout(let lhsMessage), .eventTimeout(let rhsMessage)):
            return lhsMessage == rhsMessage
            
        // General errors
        case (.unknown(let lhsMessage), .unknown(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.internalError(let lhsMessage), .internalError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.notImplemented(let lhsFeature), .notImplemented(let rhsFeature)):
            return lhsFeature == rhsFeature
            
        default:
            return false
        }
    }
}