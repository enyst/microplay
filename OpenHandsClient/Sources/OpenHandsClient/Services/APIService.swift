import Foundation
import Combine

/// Service for handling REST API requests
public class APIService {
    private let settings: BackendSettings
    private let session: URLSession
    
    public init(settings: BackendSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }
    
    /// Perform a GET request
    public func get<T: Decodable>(endpoint: String) -> AnyPublisher<T, OpenHandsError> {
        guard let baseURL = settings.baseURL else {
            return Fail(error: OpenHandsError.invalidURL(message: "Invalid base URL")).eraseToAnyPublisher()
        }
        
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return performRequest(request)
    }
    
    /// Perform a POST request
    public func post<T: Decodable, E: Encodable>(endpoint: String, body: E) -> AnyPublisher<T, OpenHandsError> {
        guard let baseURL = settings.baseURL else {
            return Fail(error: OpenHandsError.invalidURL(message: "Invalid base URL")).eraseToAnyPublisher()
        }
        
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        } catch {
            return Fail(error: OpenHandsError.encodingFailed(message: "Failed to encode request body: \(error.localizedDescription)")).eraseToAnyPublisher()
        }
        
        return performRequest(request)
    }
    
    /// Perform a PUT request
    public func put<T: Decodable, E: Encodable>(endpoint: String, body: E) -> AnyPublisher<T, OpenHandsError> {
        guard let baseURL = settings.baseURL else {
            return Fail(error: OpenHandsError.invalidURL(message: "Invalid base URL")).eraseToAnyPublisher()
        }
        
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        } catch {
            return Fail(error: OpenHandsError.encodingFailed(message: "Failed to encode request body: \(error.localizedDescription)")).eraseToAnyPublisher()
        }
        
        return performRequest(request)
    }
    
    /// Perform a DELETE request
    public func delete<T: Decodable>(endpoint: String) -> AnyPublisher<T, OpenHandsError> {
        guard let baseURL = settings.baseURL else {
            return Fail(error: OpenHandsError.invalidURL(message: "Invalid base URL")).eraseToAnyPublisher()
        }
        
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        return performRequest(request)
    }
    
    /// Perform the actual request and handle the response
    private func performRequest<T: Decodable>(_ request: URLRequest) -> AnyPublisher<T, OpenHandsError> {
        return session.dataTaskPublisher(for: request)
            .mapError { error in
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        return OpenHandsError.networkUnavailable(message: "No network connection available: \(error.localizedDescription)")
                    case .timedOut:
                        return OpenHandsError.socketTimeout(message: "Request timed out: \(error.localizedDescription)")
                    case .serverCertificateUntrusted, .serverCertificateHasUnknownRoot:
                        return OpenHandsError.sslCertificateInvalid(message: "SSL certificate validation failed: \(error.localizedDescription)")
                    default:
                        return OpenHandsError.connectionFailed(message: "Connection failed: \(error.localizedDescription)")
                    }
                }
                return OpenHandsError.connectionFailed(message: "Connection failed: \(error.localizedDescription)")
            }
            .flatMap { data, response -> AnyPublisher<T, OpenHandsError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: OpenHandsError.invalidResponse(message: "Invalid HTTP response")).eraseToAnyPublisher()
                }
                
                // Handle different HTTP status codes
                switch httpResponse.statusCode {
                case 200...299:
                    // Success
                    break
                case 400:
                    return Fail(error: OpenHandsError.invalidRequest(message: "Bad request")).eraseToAnyPublisher()
                case 401:
                    return Fail(error: OpenHandsError.unauthorizedAccess(message: "Authentication required")).eraseToAnyPublisher()
                case 403:
                    return Fail(error: OpenHandsError.unauthorizedAccess(message: "Access forbidden")).eraseToAnyPublisher()
                case 404:
                    return Fail(error: OpenHandsError.resourceNotFound(message: "Resource not found")).eraseToAnyPublisher()
                case 429:
                    return Fail(error: OpenHandsError.rateLimitExceeded(message: "Too many requests")).eraseToAnyPublisher()
                case 500...599:
                    return Fail(error: OpenHandsError.serverError(code: httpResponse.statusCode, message: "Server error")).eraseToAnyPublisher()
                default:
                    return Fail(error: OpenHandsError.requestFailed(code: httpResponse.statusCode, message: "Request failed with status code \(httpResponse.statusCode)")).eraseToAnyPublisher()
                }
                
                do {
                    let decoder = JSONDecoder()
                    let value = try decoder.decode(T.self, from: data)
                    return Just(value)
                        .setFailureType(to: OpenHandsError.self)
                        .eraseToAnyPublisher()
                } catch {
                    return Fail(error: OpenHandsError.decodingFailed(message: "Failed to decode response: \(error.localizedDescription)")).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
}