import Foundation

/// Represents the content of a file
public struct FileContent: Codable, Equatable {
    public let code: String
    
    public init(code: String) {
        self.code = code
    }
}