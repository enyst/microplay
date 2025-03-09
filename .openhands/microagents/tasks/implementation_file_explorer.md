---
name: implementation_file_explorer
type: task
agent: CodeActAgent
version: 1.0.0
triggers:
- file explorer
- file browser
---

# File Explorer Implementation

The File Explorer provides a read-only view of the workspace file system, allowing users to navigate directories and view file contents. All file operations are performed through the backend API.

## 1. Data Models

```swift
// Model representing a file or directory in the workspace
struct FileNode: Identifiable, Codable {
    var id: String { path }
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int?
    let lastModified: Date?
    var children: [FileNode]?
    var isExpanded: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case name, path, isDirectory, size, lastModified, children
    }
}

// Model representing file content
struct FileContent: Codable {
    let path: String
    let content: String
    let encoding: String?
    let language: String?
}
```

## 2. API Client Methods

```swift
protocol FileExplorerService {
    func listFiles(conversationId: String, path: String?) async throws -> [FileNode]
    func getFileContent(conversationId: String, path: String) async throws -> FileContent
}

class FileExplorerServiceImpl: FileExplorerService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func listFiles(conversationId: String, path: String? = nil) async throws -> [FileNode] {
        var queryItems: [URLQueryItem] = []
        if let path = path {
            queryItems.append(URLQueryItem(name: "path", value: path))
        }
        
        return try await apiClient.get(
            endpoint: "api/conversations/\(conversationId)/list-files",
            queryItems: queryItems
        )
    }
    
    func getFileContent(conversationId: String, path: String) async throws -> FileContent {
        let queryItems = [URLQueryItem(name: "file", value: path)]
        
        let response: [String: String] = try await apiClient.get(
            endpoint: "api/conversations/\(conversationId)/select-file",
            queryItems: queryItems
        )
        
        // Backend returns {"code": "file_content"}
        guard let content = response["code"] else {
            throw APIError.invalidResponse
        }
        
        // Determine language from file extension
        let language = path.components(separatedBy: ".").last
        
        return FileContent(
            path: path,
            content: content,
            encoding: "utf-8",
            language: language
        )
    }
}
```

## 3. View Models

```swift
class FileExplorerViewModel: ObservableObject {
    @Published var rootNodes: [FileNode] = []
    @Published var selectedFilePath: String?
    @Published var selectedFileContent: FileContent?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let fileService: FileExplorerService
    private let conversationId: String
    
    // Cache for file content to avoid unnecessary API calls
    private var fileContentCache: [String: FileContent] = [:]
    
    init(fileService: FileExplorerService, conversationId: String) {
        self.fileService = fileService
        self.conversationId = conversationId
    }
    
    func loadRootDirectory() async {
        await loadDirectory(path: nil)
    }
    
    func loadDirectory(path: String?) async {
        do {
            isLoading = true
            errorMessage = nil
            
            let files = try await fileService.listFiles(
                conversationId: conversationId,
                path: path
            )
            
            await MainActor.run {
                if path == nil {
                    // Root directory
                    self.rootNodes = files
                } else {
                    // Update children of a specific directory
                    self.updateDirectoryChildren(path: path!, children: files)
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load directory: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func selectFile(path: String) async {
        await MainActor.run {
            self.selectedFilePath = path
            
            // Check if content is already cached
            if let cachedContent = fileContentCache[path] {
                self.selectedFileContent = cachedContent
                return
            }
            
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let content = try await fileService.getFileContent(
                conversationId: conversationId,
                path: path
            )
            
            // Cache the content
            fileContentCache[path] = content
            
            await MainActor.run {
                self.selectedFileContent = content
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load file: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func toggleDirectory(path: String) async {
        // Find the directory node
        guard var node = findNode(path: path, in: rootNodes) else {
            return
        }
        
        // Toggle expansion state
        node.isExpanded = !node.isExpanded
        
        // If expanding and no children loaded yet, load them
        if node.isExpanded && (node.children == nil || node.children!.isEmpty) {
            await loadDirectory(path: path)
        }
        
        // Update the node in the tree
        updateNode(node, in: &rootNodes)
    }
    
    // Helper methods for tree manipulation
    private func updateDirectoryChildren(path: String, children: [FileNode]) {
        guard var node = findNode(path: path, in: rootNodes) else {
            return
        }
        
        node.children = children
        node.isExpanded = true
        
        updateNode(node, in: &rootNodes)
    }
    
    private func findNode(path: String, in nodes: [FileNode]) -> FileNode? {
        for var node in nodes {
            if node.path == path {
                return node
            }
            
            if node.isDirectory, let children = node.children {
                if let foundNode = findNode(path: path, in: children) {
                    return foundNode
                }
            }
        }
        
        return nil
    }
    
    private func updateNode(_ targetNode: FileNode, in nodes: inout [FileNode]) {
        for i in 0..<nodes.count {
            if nodes[i].path == targetNode.path {
                nodes[i] = targetNode
                return
            }
            
            if nodes[i].isDirectory, var children = nodes[i].children {
                updateNode(targetNode, in: &children)
                nodes[i].children = children
            }
        }
    }
}
```

## 4. UI Components

```swift
struct FileExplorerView: View {
    @ObservedObject var viewModel: FileExplorerViewModel
    
    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.rootNodes.isEmpty {
                ProgressView("Loading files...")
            } else if let errorMessage = viewModel.errorMessage, viewModel.rootNodes.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                Button("Retry") {
                    Task {
                        await viewModel.loadRootDirectory()
                    }
                }
            } else {
                HSplitView {
                    // File tree view
                    List {
                        ForEach(viewModel.rootNodes) { node in
                            FileNodeView(
                                node: node,
                                selectedPath: viewModel.selectedFilePath,
                                onSelectFile: { path in
                                    Task {
                                        await viewModel.selectFile(path: path)
                                    }
                                },
                                onToggleDirectory: { path in
                                    Task {
                                        await viewModel.toggleDirectory(path: path)
                                    }
                                }
                            )
                        }
                    }
                    .frame(minWidth: 200)
                    
                    // File content view
                    if let selectedFileContent = viewModel.selectedFileContent {
                        FileContentView(fileContent: selectedFileContent)
                    } else {
                        Text("Select a file to view its contents")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.textBackgroundColor))
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadRootDirectory()
            }
        }
    }
}

struct FileNodeView: View {
    let node: FileNode
    let selectedPath: String?
    let onSelectFile: (String) -> Void
    let onToggleDirectory: (String) -> Void
    
    var body: some View {
        if node.isDirectory {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { node.isExpanded },
                    set: { _ in onToggleDirectory(node.path) }
                )
            ) {
                if let children = node.children {
                    ForEach(children) { child in
                        FileNodeView(
                            node: child,
                            selectedPath: selectedPath,
                            onSelectFile: onSelectFile,
                            onToggleDirectory: onToggleDirectory
                        )
                        .padding(.leading, 10)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                    Text(node.name)
                }
            }
        } else {
            HStack {
                Image(systemName: "doc")
                    .foregroundColor(.gray)
                Text(node.name)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelectFile(node.path)
            }
            .background(
                selectedPath == node.path ? Color.accentColor.opacity(0.2) : Color.clear
            )
        }
    }
}

struct FileContentView: View {
    let fileContent: FileContent
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(fileContent.content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.textBackgroundColor))
    }
}
```

## 5. Integration with Backend

The File Explorer integrates with the backend through:

1. **REST API calls** for listing files and retrieving file content
2. **SocketIO events** for real-time updates when files change

```swift
// Example of handling file change events from SocketIO
func setupFileChangeListeners() {
    socketManager.on("oh_event") { [weak self] data in
        guard let self = self,
              let eventData = data as? [String: Any],
              let observation = eventData["observation"] as? [String: Any],
              let observationType = observation["observation"] as? String,
              observationType == "FileObservation" else {
            return
        }
        
        // File has changed, refresh if it's the currently selected file
        if let path = eventData["path"] as? String,
           path == self.selectedFilePath {
            Task {
                await self.viewModel.selectFile(path: path)
            }
        }
    }
}
```

## 6. Caching and Performance

To optimize performance, the File Explorer implementation includes:

1. **File content caching**: Store retrieved file contents to avoid redundant API calls
2. **Lazy loading**: Only load directory contents when expanded
3. **Pagination**: Support for handling large directories (to be implemented if needed)

```swift
// Example pagination implementation (if needed for large directories)
func loadDirectoryPage(path: String, page: Int, pageSize: Int) async throws -> [FileNode] {
    let queryItems = [
        URLQueryItem(name: "path", value: path),
        URLQueryItem(name: "page", value: String(page)),
        URLQueryItem(name: "pageSize", value: String(pageSize))
    ]
    
    return try await apiClient.get(
        endpoint: "api/conversations/\(conversationId)/list-files",
        queryItems: queryItems
    )
}
```