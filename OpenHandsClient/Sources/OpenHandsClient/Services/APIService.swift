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
            return Fail(error: OpenHandsError.connectionFailed("Invalid base URL")).eraseToAnyPublisher()
        }
        
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return performRequest(request)
    }
    
    /// Perform a POST request
    public func post<T: Decodable, E: Encodable>(endpoint: String, body: E) -> AnyPublisher<T, OpenHandsError> {
        guard let baseURL = settings.baseURL else {
            return Fail(error: OpenHandsError.connectionFailed("Invalid base URL")).eraseToAnyPublisher()
        }
        
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        } catch {
            return Fail(error: OpenHandsError.requestFailed("Failed to encode request body: \(error.localizedDescription)")).eraseToAnyPublisher()
        }
        
        return performRequest(request)
    }
    
    /// Perform a PUT request
    public func put<T: Decodable, E: Encodable>(endpoint: String, body: E) -> AnyPublisher<T, OpenHandsError> {
        guard let baseURL = settings.baseURL else {
            return Fail(error: OpenHandsError.connectionFailed("Invalid base URL")).eraseToAnyPublisher()
        }
        
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        } catch {
            return Fail(error: OpenHandsError.requestFailed("Failed to encode request body: \(error.localizedDescription)")).eraseToAnyPublisher()
        }
        
        return performRequest(request)
    }
    
    /// Perform a DELETE request
    public func delete<T: Decodable>(endpoint: String) -> AnyPublisher<T, OpenHandsError> {
        guard let baseURL = settings.baseURL else {
            return Fail(error: OpenHandsError.connectionFailed("Invalid base URL")).eraseToAnyPublisher()
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
                return OpenHandsError.requestFailed(error.localizedDescription)
            }
            .flatMap { data, response -> AnyPublisher<T, OpenHandsError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: OpenHandsError.invalidResponse(-1)).eraseToAnyPublisher()
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    return Fail(error: OpenHandsError.invalidResponse(httpResponse.statusCode)).eraseToAnyPublisher()
                }
                
                do {
                    let decoder = JSONDecoder()
                    let value = try decoder.decode(T.self, from: data)
                    return Just(value)
                        .setFailureType(to: OpenHandsError.self)
                        .eraseToAnyPublisher()
                } catch {
                    return Fail(error: OpenHandsError.decodingFailed(error.localizedDescription)).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
}