import Foundation

/// Specific error codes for the OpenHands client
public enum ErrorCode: Int, Codable {
    // Connection error codes (1000-1999)
    case connectionFailed = 1000
    case socketDisconnected = 1001
    case socketTimeout = 1002
    case invalidURL = 1003
    case sslCertificateInvalid = 1004
    case networkUnavailable = 1005
    case connectionRefused = 1006
    case hostUnreachable = 1007
    
    // API error codes (2000-2999)
    case requestFailed = 2000
    case unauthorizedAccess = 2001
    case resourceNotFound = 2002
    case serverError = 2003
    case rateLimitExceeded = 2004
    case invalidRequest = 2005
    case invalidResponse = 2006
    case requestTimeout = 2007
    case badGateway = 2008
    case serviceUnavailable = 2009
    
    // Data error codes (3000-3999)
    case decodingFailed = 3000
    case encodingFailed = 3001
    case invalidData = 3002
    case dataCorrupted = 3003
    case typeCastFailed = 3004
    case dataMissing = 3005
    case dataIncomplete = 3006
    
    // File error codes (4000-4999)
    case fileNotFound = 4000
    case fileAccessDenied = 4001
    case invalidFilePath = 4002
    case fileOperationFailed = 4003
    case directoryCreationFailed = 4004
    
    // Event error codes (5000-5999)
    case invalidEventType = 5000
    case eventRoutingFailed = 5001
    case eventHandlingFailed = 5002
    case eventTimeout = 5003
    
    // General error codes (9000-9999)
    case unknown = 9000
    case internalError = 9001
    case notImplemented = 9002
    
    /// Returns a human-readable description of the error code
    public var description: String {
        switch self {
        // Connection errors
        case .connectionFailed:
            return "Connection failed"
        case .socketDisconnected:
            return "Socket disconnected unexpectedly"
        case .socketTimeout:
            return "Socket connection timed out"
        case .invalidURL:
            return "Invalid URL"
        case .sslCertificateInvalid:
            return "SSL certificate validation failed"
        case .networkUnavailable:
            return "Network is unavailable"
        case .connectionRefused:
            return "Connection refused"
        case .hostUnreachable:
            return "Host unreachable"
            
        // API errors
        case .requestFailed:
            return "Request failed"
        case .unauthorizedAccess:
            return "Unauthorized access"
        case .resourceNotFound:
            return "Resource not found"
        case .serverError:
            return "Server error"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .invalidRequest:
            return "Invalid request"
        case .invalidResponse:
            return "Invalid response"
        case .requestTimeout:
            return "Request timeout"
        case .badGateway:
            return "Bad gateway"
        case .serviceUnavailable:
            return "Service unavailable"
            
        // Data errors
        case .decodingFailed:
            return "Failed to decode data"
        case .encodingFailed:
            return "Failed to encode data"
        case .invalidData:
            return "Invalid data format"
        case .dataCorrupted:
            return "Data is corrupted"
        case .typeCastFailed:
            return "Type cast failed"
        case .dataMissing:
            return "Data is missing"
        case .dataIncomplete:
            return "Data is incomplete"
            
        // File errors
        case .fileNotFound:
            return "File not found"
        case .fileAccessDenied:
            return "Access denied to file"
        case .invalidFilePath:
            return "Invalid file path"
        case .fileOperationFailed:
            return "File operation failed"
        case .directoryCreationFailed:
            return "Failed to create directory"
            
        // Event errors
        case .invalidEventType:
            return "Invalid event type"
        case .eventRoutingFailed:
            return "Event routing failed"
        case .eventHandlingFailed:
            return "Event handling failed"
        case .eventTimeout:
            return "Event timed out"
            
        // General errors
        case .unknown:
            return "Unknown error"
        case .internalError:
            return "Internal error"
        case .notImplemented:
            return "Feature not implemented"
        }
    }
    
    /// Returns suggested recovery actions for the error
    public var recoverySuggestion: String {
        switch self {
        // Connection errors
        case .connectionFailed:
            return "Check your internet connection and verify the backend server is running."
        case .socketDisconnected:
            return "The connection was lost. The app will automatically attempt to reconnect."
        case .socketTimeout:
            return "The connection timed out. Check your network and try again."
        case .invalidURL:
            return "The server URL is invalid. Check your settings and try again."
        case .sslCertificateInvalid:
            return "The server's SSL certificate is invalid. Check your security settings or contact your administrator."
        case .networkUnavailable:
            return "No network connection is available. Connect to a network and try again."
        case .connectionRefused:
            return "The server refused the connection. Verify the server is running and accepting connections."
        case .hostUnreachable:
            return "The host could not be reached. Check your network connection and server address."
            
        // API errors
        case .requestFailed:
            return "The request to the server failed. Try again later."
        case .unauthorizedAccess:
            return "You don't have permission to access this resource. Check your credentials."
        case .resourceNotFound:
            return "The requested resource was not found on the server."
        case .serverError:
            return "The server encountered an error. Please try again later or contact support."
        case .rateLimitExceeded:
            return "You've exceeded the rate limit. Please wait before making more requests."
        case .invalidRequest:
            return "The request was invalid. Check your input and try again."
        case .invalidResponse:
            return "The server response was invalid. This may indicate a version mismatch with the server."
        case .requestTimeout:
            return "The request timed out. Check your network connection and try again."
        case .badGateway:
            return "The server received an invalid response from an upstream server. Try again later."
        case .serviceUnavailable:
            return "The service is temporarily unavailable. Please try again later."
            
        // Data errors
        case .decodingFailed:
            return "Failed to decode the response from the server. This may indicate a version mismatch."
        case .encodingFailed:
            return "Failed to encode the request. Check your input data."
        case .invalidData:
            return "The data format is invalid. Check your input."
        case .dataCorrupted:
            return "The data is corrupted. Try refreshing or restarting the application."
        case .typeCastFailed:
            return "Failed to convert data to the expected type. This may indicate a version mismatch with the server."
        case .dataMissing:
            return "Required data is missing. Check that all required fields are provided."
        case .dataIncomplete:
            return "The data is incomplete. Check that all required fields are provided and try again."
            
        // File errors
        case .fileNotFound:
            return "The file was not found. Check the file path and try again."
        case .fileAccessDenied:
            return "You don't have permission to access this file. Check your file permissions."
        case .invalidFilePath:
            return "The file path is invalid. Check the path and try again."
        case .fileOperationFailed:
            return "The file operation failed. Check file permissions and try again."
        case .directoryCreationFailed:
            return "Failed to create the directory. Check permissions and available disk space."
            
        // Event errors
        case .invalidEventType:
            return "The event type is invalid. This may indicate a version mismatch with the server."
        case .eventRoutingFailed:
            return "Failed to route the event. Check your event handlers."
        case .eventHandlingFailed:
            return "Failed to handle the event. Check your event handlers."
        case .eventTimeout:
            return "The event timed out. Try again or check your connection."
            
        // General errors
        case .unknown:
            return "An unknown error occurred. Try restarting the application."
        case .internalError:
            return "An internal error occurred. Please report this issue to support."
        case .notImplemented:
            return "This feature is not yet implemented. Check for updates or contact support."
        }
    }
}