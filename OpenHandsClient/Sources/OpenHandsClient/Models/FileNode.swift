import Foundation

/// Represents a file or directory in the workspace
public struct FileNode: Codable, Identifiable, Equatable {
    public var id: String { path }
    public let path: String
    public let name: String
    public let type: FileType
    public let size: Int?
    public let children: [FileNode]?
    
    public enum FileType: String, Codable {
        case file
        case directory
    }
    
    public init(path: String, name: String, type: FileType, size: Int? = nil, children: [FileNode]? = nil) {
        self.path = path
        self.name = name
        self.type = type
        self.size = size
        self.children = children
    }
    
    public static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        return lhs.path == rhs.path
    }
}