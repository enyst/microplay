import Foundation

/// Configuration for connecting to the backend
public struct BackendSettings: Codable, Equatable {
    public let backendHost: String
    public let backendPort: Int
    public let useTLS: Bool
    
    public init(backendHost: String, backendPort: Int, useTLS: Bool) {
        self.backendHost = backendHost
        self.backendPort = backendPort
        self.useTLS = useTLS
    }
    
    public var baseURL: URL? {
        let scheme = useTLS ? "https" : "http"
        return URL(string: "\(scheme)://\(backendHost):\(backendPort)")
    }
    
    public var socketURL: URL? {
        let scheme = useTLS ? "wss" : "ws"
        return URL(string: "\(scheme)://\(backendHost):\(backendPort)")
    }
}