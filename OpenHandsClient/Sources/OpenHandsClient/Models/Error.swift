import Foundation

/// Represents errors that can occur in the OpenHands client
public enum OpenHandsError: Error, Equatable {
    // Connection errors (1000-1999)
    case connectionFailed(code: Int = 1000, message: String)
    case socketDisconnected(code: Int = 1001, message: String)
    case socketTimeout(code: Int = 1002, message: String)
    case invalidURL(code: Int = 1003, message: String)
    case sslCertificateInvalid(code: Int = 1004, message: String)
    case networkUnavailable(code: Int = 1005, message: String)
    case connectionRefused(code: Int = 1006, message: String)
    case hostUnreachable(code: Int = 1007, message: String)
    
    // API errors (2000-2999)
    case requestFailed(code: Int = 2000, statusCode: Int, message: String)
    case unauthorizedAccess(code: Int = 2001, message: String)
    case resourceNotFound(code: Int = 2002, message: String)
    case serverError(code: Int = 2003, statusCode: Int, message: String)
    case rateLimitExceeded(code: Int = 2004, message: String)
    case invalidRequest(code: Int = 2005, message: String)
    case invalidResponse(code: Int = 2006, message: String)
    case requestTimeout(code: Int = 2007, message: String)
    case badGateway(code: Int = 2008, message: String)
    case serviceUnavailable(code: Int = 2009, message: String)
    
    // Data errors (3000-3999)
    case decodingFailed(code: Int = 3000, message: String)
    case encodingFailed(code: Int = 3001, message: String)
    case invalidData(code: Int = 3002, message: String)
    case dataCorrupted(code: Int = 3003, message: String)
    case typeCastFailed(code: Int = 3004, message: String)
    case dataMissing(code: Int = 3005, message: String)
    case dataIncomplete(code: Int = 3006, message: String)
    
    // File errors (4000-4999)
    case fileNotFound(code: Int = 4000, message: String)
    case fileAccessDenied(code: Int = 4001, message: String)
    case invalidFilePath(code: Int = 4002, message: String)
    case fileOperationFailed(code: Int = 4003, message: String)
    case directoryCreationFailed(code: Int = 4004, message: String)
    
    // Event errors (5000-5999)
    case invalidEventType(code: Int = 5000, message: String)
    case eventRoutingFailed(code: Int = 5001, message: String)
    case eventHandlingFailed(code: Int = 5002, message: String)
    case eventTimeout(code: Int = 5003, message: String)
    
    // General errors (9000-9999)
    case unknown(code: Int = 9000, message: String)
    case internalError(code: Int = 9001, message: String)
    case notImplemented(code: Int = 9002, message: String)
    
    /// Returns the numeric error code
    public var code: Int {
        switch self {
        // Connection errors
        case .connectionFailed(let code, _): return code
        case .socketDisconnected(let code, _): return code
        case .socketTimeout(let code, _): return code
        case .invalidURL(let code, _): return code
        case .sslCertificateInvalid(let code, _): return code
        case .networkUnavailable(let code, _): return code
        case .connectionRefused(let code, _): return code
        case .hostUnreachable(let code, _): return code
            
        // API errors
        case .requestFailed(let code, _, _): return code
        case .unauthorizedAccess(let code, _): return code
        case .resourceNotFound(let code, _): return code
        case .serverError(let code, _, _): return code
        case .rateLimitExceeded(let code, _): return code
        case .invalidRequest(let code, _): return code
        case .invalidResponse(let code, _): return code
        case .requestTimeout(let code, _): return code
        case .badGateway(let code, _): return code
        case .serviceUnavailable(let code, _): return code
            
        // Data errors
        case .decodingFailed(let code, _): return code
        case .encodingFailed(let code, _): return code
        case .invalidData(let code, _): return code
        case .dataCorrupted(let code, _): return code
        case .typeCastFailed(let code, _): return code
        case .dataMissing(let code, _): return code
        case .dataIncomplete(let code, _): return code
            
        // File errors
        case .fileNotFound(let code, _): return code
        case .fileAccessDenied(let code, _): return code
        case .invalidFilePath(let code, _): return code
        case .fileOperationFailed(let code, _): return code
        case .directoryCreationFailed(let code, _): return code
            
        // Event errors
        case .invalidEventType(let code, _): return code
        case .eventRoutingFailed(let code, _): return code
        case .eventHandlingFailed(let code, _): return code
        case .eventTimeout(let code, _): return code
            
        // General errors
        case .unknown(let code, _): return code
        case .internalError(let code, _): return code
        case .notImplemented(let code, _): return code
        }
    }
    
    /// Returns a human-readable description of the error
    public var localizedDescription: String {
        switch self {
        // Connection errors
        case .connectionFailed(_, let message):
            return "Connection failed: \(message)"
        case .socketDisconnected(_, let message):
            return "Socket disconnected unexpectedly: \(message)"
        case .socketTimeout(_, let message):
            return "Socket connection timed out: \(message)"
        case .invalidURL(_, let message):
            return "Invalid URL: \(message)"
        case .sslCertificateInvalid(_, let message):
            return "SSL certificate validation failed: \(message)"
        case .networkUnavailable(_, let message):
            return "Network is unavailable: \(message)"
        case .connectionRefused(_, let message):
            return "Connection refused: \(message)"
        case .hostUnreachable(_, let message):
            return "Host unreachable: \(message)"
            
        // API errors
        case .requestFailed(_, let statusCode, let message):
            return "Request failed with status code \(statusCode): \(message)"
        case .unauthorizedAccess(_, let message):
            return "Unauthorized access to resource: \(message)"
        case .resourceNotFound(_, let message):
            return "Resource not found: \(message)"
        case .serverError(_, let statusCode, let message):
            return "Server error with status code \(statusCode): \(message)"
        case .rateLimitExceeded(_, let message):
            return "Rate limit exceeded: \(message)"
        case .invalidRequest(_, let message):
            return "Invalid request: \(message)"
        case .invalidResponse(_, let message):
            return "Invalid response: \(message)"
        case .requestTimeout(_, let message):
            return "Request timeout: \(message)"
        case .badGateway(_, let message):
            return "Bad gateway: \(message)"
        case .serviceUnavailable(_, let message):
            return "Service unavailable: \(message)"
            
        // Data errors
        case .decodingFailed(_, let message):
            return "Failed to decode response: \(message)"
        case .encodingFailed(_, let message):
            return "Failed to encode request: \(message)"
        case .invalidData(_, let message):
            return "Invalid data format: \(message)"
        case .dataCorrupted(_, let message):
            return "Data is corrupted: \(message)"
        case .typeCastFailed(_, let message):
            return "Type cast failed: \(message)"
        case .dataMissing(_, let message):
            return "Data is missing: \(message)"
        case .dataIncomplete(_, let message):
            return "Data is incomplete: \(message)"
            
        // File errors
        case .fileNotFound(_, let message):
            return "File not found: \(message)"
        case .fileAccessDenied(_, let message):
            return "Access denied to file: \(message)"
        case .invalidFilePath(_, let message):
            return "Invalid file path: \(message)"
        case .fileOperationFailed(_, let message):
            return "File operation failed: \(message)"
        case .directoryCreationFailed(_, let message):
            return "Failed to create directory: \(message)"
            
        // Event errors
        case .invalidEventType(_, let message):
            return "Invalid event type: \(message)"
        case .eventRoutingFailed(_, let message):
            return "Event routing failed: \(message)"
        case .eventHandlingFailed(_, let message):
            return "Event handling failed: \(message)"
        case .eventTimeout(_, let message):
            return "Event timed out: \(message)"
            
        // General errors
        case .unknown(_, let message):
            return "Unknown error: \(message)"
        case .internalError(_, let message):
            return "Internal error: \(message)"
        case .notImplemented(_, let message):
            return "Feature not implemented: \(message)"
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
    
    /// Returns a dictionary representation of the error for logging or analytics
    public var dictionaryRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "code": code,
            "description": localizedDescription,
            "recoverySuggestion": recoverySuggestion
        ]
        
        // Add HTTP status code for API errors if available
        switch self {
        case .requestFailed(_, let statusCode, _):
            dict["statusCode"] = statusCode
        case .serverError(_, let statusCode, _):
            dict["statusCode"] = statusCode
        default:
            break
        }
        
        return dict
    }
    
    /// Equality check for OpenHandsError
    public static func == (lhs: OpenHandsError, rhs: OpenHandsError) -> Bool {
        // Compare by error type and code
        switch (lhs, rhs) {
        // Connection errors
        case (.connectionFailed(let lhsCode, _), .connectionFailed(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.socketDisconnected(let lhsCode, _), .socketDisconnected(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.socketTimeout(let lhsCode, _), .socketTimeout(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.invalidURL(let lhsCode, _), .invalidURL(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.sslCertificateInvalid(let lhsCode, _), .sslCertificateInvalid(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.networkUnavailable(let lhsCode, _), .networkUnavailable(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.connectionRefused(let lhsCode, _), .connectionRefused(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.hostUnreachable(let lhsCode, _), .hostUnreachable(let rhsCode, _)):
            return lhsCode == rhsCode
            
        // API errors
        case (.requestFailed(let lhsCode, _, _), .requestFailed(let rhsCode, _, _)):
            return lhsCode == rhsCode
        case (.unauthorizedAccess(let lhsCode, _), .unauthorizedAccess(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.resourceNotFound(let lhsCode, _), .resourceNotFound(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.serverError(let lhsCode, _, _), .serverError(let rhsCode, _, _)):
            return lhsCode == rhsCode
        case (.rateLimitExceeded(let lhsCode, _), .rateLimitExceeded(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.invalidRequest(let lhsCode, _), .invalidRequest(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.invalidResponse(let lhsCode, _), .invalidResponse(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.requestTimeout(let lhsCode, _), .requestTimeout(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.badGateway(let lhsCode, _), .badGateway(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.serviceUnavailable(let lhsCode, _), .serviceUnavailable(let rhsCode, _)):
            return lhsCode == rhsCode
            
        // Data errors
        case (.decodingFailed(let lhsCode, _), .decodingFailed(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.encodingFailed(let lhsCode, _), .encodingFailed(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.invalidData(let lhsCode, _), .invalidData(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.dataCorrupted(let lhsCode, _), .dataCorrupted(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.typeCastFailed(let lhsCode, _), .typeCastFailed(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.dataMissing(let lhsCode, _), .dataMissing(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.dataIncomplete(let lhsCode, _), .dataIncomplete(let rhsCode, _)):
            return lhsCode == rhsCode
            
        // File errors
        case (.fileNotFound(let lhsCode, _), .fileNotFound(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.fileAccessDenied(let lhsCode, _), .fileAccessDenied(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.invalidFilePath(let lhsCode, _), .invalidFilePath(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.fileOperationFailed(let lhsCode, _), .fileOperationFailed(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.directoryCreationFailed(let lhsCode, _), .directoryCreationFailed(let rhsCode, _)):
            return lhsCode == rhsCode
            
        // Event errors
        case (.invalidEventType(let lhsCode, _), .invalidEventType(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.eventRoutingFailed(let lhsCode, _), .eventRoutingFailed(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.eventHandlingFailed(let lhsCode, _), .eventHandlingFailed(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.eventTimeout(let lhsCode, _), .eventTimeout(let rhsCode, _)):
            return lhsCode == rhsCode
            
        // General errors
        case (.unknown(let lhsCode, _), .unknown(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.internalError(let lhsCode, _), .internalError(let rhsCode, _)):
            return lhsCode == rhsCode
        case (.notImplemented(let lhsCode, _), .notImplemented(let rhsCode, _)):
            return lhsCode == rhsCode
            
        default:
            return false
        }
    }
}

// MARK: - Convenience Initializers

extension OpenHandsError {
    /// Create a server error from an HTTP status code
    public static func fromHTTPStatus(_ statusCode: Int, message: String = "") -> OpenHandsError {
        switch statusCode {
        case 400:
            return .invalidRequest(message: message.isEmpty ? "Bad request" : message)
        case 401:
            return .unauthorizedAccess(message: message.isEmpty ? "Unauthorized" : message)
        case 403:
            return .unauthorizedAccess(message: message.isEmpty ? "Forbidden" : message)
        case 404:
            return .resourceNotFound(message: message.isEmpty ? "Resource not found" : message)
        case 408:
            return .requestTimeout(message: message.isEmpty ? "Request timeout" : message)
        case 429:
            return .rateLimitExceeded(message: message.isEmpty ? "Too many requests" : message)
        case 500:
            return .serverError(statusCode: statusCode, message: message.isEmpty ? "Internal server error" : message)
        case 502:
            return .badGateway(message: message.isEmpty ? "Bad gateway" : message)
        case 503:
            return .serviceUnavailable(message: message.isEmpty ? "Service unavailable" : message)
        case 504:
            return .requestTimeout(message: message.isEmpty ? "Gateway timeout" : message)
        case 400...499:
            return .requestFailed(statusCode: statusCode, message: message.isEmpty ? "Client error" : message)
        case 500...599:
            return .serverError(statusCode: statusCode, message: message.isEmpty ? "Server error" : message)
        default:
            return .unknown(message: message.isEmpty ? "Unknown HTTP status: \(statusCode)" : message)
        }
    }
    
    /// Create an error from a network error
    public static func fromNetworkError(_ error: Error) -> OpenHandsError {
        let nsError = error as NSError
        
        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return .networkUnavailable(message: "Not connected to the internet")
            case NSURLErrorTimedOut:
                return .socketTimeout(message: "Connection timed out")
            case NSURLErrorCannotFindHost:
                return .hostUnreachable(message: "Cannot find host")
            case NSURLErrorCannotConnectToHost:
                return .connectionRefused(message: "Cannot connect to host")
            case NSURLErrorNetworkConnectionLost:
                return .socketDisconnected(message: "Network connection lost")
            case NSURLErrorDNSLookupFailed:
                return .hostUnreachable(message: "DNS lookup failed")
            case NSURLErrorBadURL:
                return .invalidURL(message: "Bad URL")
            case NSURLErrorSecureConnectionFailed:
                return .sslCertificateInvalid(message: "Secure connection failed")
            case NSURLErrorServerCertificateHasBadDate, 
                 NSURLErrorServerCertificateUntrusted,
                 NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid:
                return .sslCertificateInvalid(message: "SSL certificate validation failed")
            default:
                return .connectionFailed(message: "Network error: \(nsError.localizedDescription)")
            }
        default:
            return .unknown(message: "Unknown error: \(nsError.localizedDescription)")
        }
    }
}