---
name  :  mac_client_api_integration
type  :  task
agent  :  CodeActAgent
---

# OpenHands Mac Client API Integration Specification

This document provides detailed specifications for integrating the Mac client with the OpenHands backend API, including both Socket.IO real-time communication and REST API endpoints.

## 1. Socket.IO Integration

### 1.1 Connection Setup

```swift
// Example Socket.IO connection setup
class SocketIOManager {
    private var socket: SocketIOClient?
    private let manager: SocketManager
    
    init(serverURL: URL, conversationId: String, authToken: String? = nil) {
        var config: SocketIOClientConfiguration = [
            .log(true),
            .compress,
            .forceWebsockets(true),
            .reconnects(true),
            .reconnectAttempts(10),
            .reconnectWait(5),
            .path("/socket.io")
        ]
        
        if let authToken = authToken {
            config.insert(.extraHeaders(["Authorization": "Bearer \(authToken)"]))
        }
        
        manager = SocketManager(socketURL: serverURL, config: config)
        socket = manager.defaultSocket
        
        setupEventHandlers()
    }
    
    private func setupEventHandlers() {
        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            self?.handleConnect()
        }
        
        socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
            self?.handleDisconnect()
        }
        
        socket?.on("oh_event") { [weak self] data, ack in
            self?.handleEvent(data: data, ack: ack)
        }
    }
    
    func connect() {
        socket?.connect()
    }
    
    func disconnect() {
        socket?.disconnect()
    }
    
    func sendAction(action: String, args: [String: Any], timeout: Int? = nil) {
        var payload: [String: Any] = [
            "action": action,
            "args": args
        ]
        
        if let timeout = timeout {
            payload["timeout"] = timeout
        }
        
        socket?.emit("oh_action", payload)
    }
}
```

### 1.2 Event Types and Handling

The Mac client must handle the following event types from the `oh_event` Socket.IO event:

#### Agent State Events

```swift
// Example handling of agent state events
func handleAgentStateEvent(data: [String: Any]) {
    guard let state = data["agent_state"] as? String else { return }
    
    let agentState: AgentState
    switch state {
        case "RUNNING": agentState = .running
        case "PAUSED": agentState = .paused
        case "STOPPED": agentState = .stopped
        case "AWAITING_USER_INPUT": agentState = .awaitingUserInput
        case "FINISHED": agentState = .finished
        case "ERROR": agentState = .error
        default: agentState = .unknown
    }
    
    // Update UI with new agent state
    DispatchQueue.main.async {
        self.updateAgentStateUI(agentState)
    }
}
```

#### Command Execution Events

```swift
// Example handling of command execution events
func handleCommandEvent(data: [String: Any]) {
    guard let observation = data["observation"] as? [String: Any],
          observation["observation"] as? String == "CmdOutputObservation",
          let content = data["content"] as? String,
          let extras = data["extras"] as? [String: Any],
          let command = extras["command"] as? String,
          let exitCode = extras["exit_code"] as? Int else {
        return
    }
    
    let commandOutput = CommandOutput(
        command: command,
        output: content,
        exitCode: exitCode,
        timestamp: Date()
    )
    
    // Update UI with command output
    DispatchQueue.main.async {
        self.appendCommandOutput(commandOutput)
    }
}
```

#### File Operation Events

```swift
// Example handling of file operation events
func handleFileEvent(data: [String: Any]) {
    guard let observation = data["observation"] as? [String: Any],
          let observationType = observation["observation"] as? String,
          observationType == "FileObservation",
          let path = data["path"] as? String else {
        return
    }
    
    // Handle different file operations
    if let content = data["content"] as? String {
        // File read operation
        let fileContent = FileContent(
            path: path,
            content: content,
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            self.updateFileContent(fileContent)
        }
    } else if let success = data["success"] as? Bool {
        // File write/edit operation
        DispatchQueue.main.async {
            if success {
                self.refreshFileExplorer(path: path)
            } else {
                self.showFileOperationError(path: path)
            }
        }
    }
}
```

#### Message Events

```swift
// Example handling of message events
func handleMessageEvent(data: [String: Any]) {
    guard let content = data["content"] as? String else { return }
    
    let message = Message(
        content: content,
        source: data["source"] as? String ?? "AGENT",
        timestamp: Date()
    )
    
    // Update UI with new message
    DispatchQueue.main.async {
        self.appendMessage(message)
    }
}
```

#### Error Events

```swift
// Example handling of error events
func handleErrorEvent(data: [String: Any]) {
    guard let message = data["message"] as? String else { return }
    
    let errorEvent = ErrorEvent(
        message: message,
        code: data["code"] as? Int,
        details: data["details"] as? [String: Any],
        timestamp: Date()
    )
    
    // Update UI with error
    DispatchQueue.main.async {
        self.showError(errorEvent)
    }
}
```

### 1.3 Sending Actions

The Mac client must be able to send the following actions via the `oh_action` Socket.IO event:

#### Send Message Action

```swift
// Example of sending a message action
func sendMessage(content: String, imageURLs: [URL]? = nil) {
    var args: [String: Any] = [
        "content": content
    ]
    
    if let imageURLs = imageURLs, !imageURLs.isEmpty {
        args["image_urls"] = imageURLs.map { $0.absoluteString }
    }
    
    socketManager.sendAction(
        action: "message",
        args: args
    )
}
```

#### Run Command Action

```swift
// Example of sending a run command action
func runCommand(command: String, hidden: Bool = false) {
    let args: [String: Any] = [
        "command": command,
        "hidden": hidden
    ]
    
    socketManager.sendAction(
        action: "run",
        args: args
    )
}
```

#### Change Agent State Action

```swift
// Example of sending a change agent state action
func changeAgentState(state: AgentState) {
    let stateString: String
    switch state {
        case .running: stateString = "RUNNING"
        case .paused: stateString = "PAUSED"
        case .stopped: stateString = "STOPPED"
        default: return // Invalid state transition
    }
    
    let args: [String: Any] = [
        "agent_state": stateString
    ]
    
    socketManager.sendAction(
        action: "change_agent_state",
        args: args
    )
}
```

#### Read File Action

```swift
// Example of sending a read file action
func readFile(path: String, startLine: Int = 0, endLine: Int = -1) {
    let args: [String: Any] = [
        "path": path,
        "start": startLine,
        "end": endLine
    ]
    
    socketManager.sendAction(
        action: "read",
        args: args
    )
}
```

#### Write File Action (Optional for MVP)

```swift
// Example of sending a write file action
func writeFile(path: String, content: String) {
    let args: [String: Any] = [
        "path": path,
        "content": content
    ]
    
    socketManager.sendAction(
        action: "write",
        args: args
    )
}
```

## 2. REST API Integration

### 2.1 API Client Setup

```swift
// Example API client setup
class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private var authToken: String?
    
    init(baseURL: URL, authToken: String? = nil) {
        self.baseURL = baseURL
        self.authToken = authToken
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        self.session = URLSession(configuration: config)
    }
    
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }
    
    func get<T: Decodable>(endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let request = try createRequest(
            method: "GET",
            endpoint: endpoint,
            queryItems: queryItems
        )
        
        return try await performRequest(request)
    }
    
    func post<T: Decodable, U: Encodable>(endpoint: String, body: U) async throws -> T {
        let request = try createRequest(
            method: "POST",
            endpoint: endpoint,
            body: body
        )
        
        return try await performRequest(request)
    }
    
    // Additional methods for PUT, PATCH, DELETE...
    
    private func createRequest(
        method: String,
        endpoint: String,
        queryItems: [URLQueryItem]? = nil,
        body: Encodable? = nil
    ) throws -> URLRequest {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let authToken = authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        }
        
        return request
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingError(Error)
}
```

### 2.2 Conversation Management

```swift
// Example conversation management API calls
class ConversationService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func createConversation(
        selectedRepository: String? = nil,
        initialUserMessage: String,
        imageURLs: [URL]? = nil
    ) async throws -> String {
        struct CreateConversationRequest: Codable {
            let selected_repository: String?
            let initial_user_msg: String
            let image_urls: [String]?
        }
        
        struct CreateConversationResponse: Codable {
            let conversation_id: String
        }
        
        let request = CreateConversationRequest(
            selected_repository: selectedRepository,
            initial_user_msg: initialUserMessage,
            image_urls: imageURLs?.map { $0.absoluteString }
        )
        
        let response: CreateConversationResponse = try await apiClient.post(
            endpoint: "api/conversations",
            body: request
        )
        
        return response.conversation_id
    }
    
    func listConversations(page: Int = 0, limit: Int = 20) async throws -> [ConversationInfo] {
        struct ConversationResultSet: Codable {
            let conversations: [ConversationInfo]
            let total: Int
            let page: Int
        }
        
        let queryItems = [
            URLQueryItem(name: "page_id", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        let resultSet: ConversationResultSet = try await apiClient.get(
            endpoint: "api/conversations",
            queryItems: queryItems
        )
        
        return resultSet.conversations
    }
    
    func getConversation(id: String) async throws -> ConversationInfo? {
        try await apiClient.get(endpoint: "api/conversations/\(id)")
    }
    
    func updateConversationTitle(id: String, title: String) async throws -> Bool {
        struct UpdateTitleRequest: Codable {
            let title: String
        }
        
        let request = UpdateTitleRequest(title: title)
        
        return try await apiClient.post(
            endpoint: "api/conversations/\(id)",
            body: request
        )
    }
    
    func deleteConversation(id: String) async throws -> Bool {
        try await apiClient.delete(endpoint: "api/conversations/\(id)")
    }
}
```

### 2.3 File Operations

```swift
// Example file operations API calls
class FileService {
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
    
    func getFileContent(conversationId: String, path: String) async throws -> String {
        struct FileContentResponse: Codable {
            let code: String
        }
        
        let queryItems = [URLQueryItem(name: "file", value: path)]
        
        let response: FileContentResponse = try await apiClient.get(
            endpoint: "api/conversations/\(conversationId)/select-file",
            queryItems: queryItems
        )
        
        return response.code
    }
    
    func saveFile(conversationId: String, path: String, content: String) async throws -> Bool {
        struct SaveFileRequest: Codable {
            let filePath: String
            let content: String
        }
        
        struct SaveFileResponse: Codable {
            let message: String
        }
        
        let request = SaveFileRequest(
            filePath: path,
            content: content
        )
        
        let _: SaveFileResponse = try await apiClient.post(
            endpoint: "api/conversations/\(conversationId)/save-file",
            body: request
        )
        
        return true
    }
    
    func downloadWorkspace(conversationId: String) async throws -> URL {
        // Implementation for downloading workspace as zip
        // This would use URLSession.downloadTask instead of the APIClient
        // and return a local file URL
        fatalError("Not implemented")
    }
}
```

### 2.4 Settings Management

```swift
// Example settings management API calls
class SettingsService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func getSettings() async throws -> Settings? {
        try await apiClient.get(endpoint: "api/settings")
    }
    
    func saveSettings(settings: Settings) async throws -> Bool {
        struct SaveSettingsResponse: Codable {
            let message: String
        }
        
        let _: SaveSettingsResponse = try await apiClient.post(
            endpoint: "api/settings",
            body: settings
        )
        
        return true
    }
    
    func getAvailableModels() async throws -> [String] {
        try await apiClient.get(endpoint: "api/options/models")
    }
    
    func getAvailableAgents() async throws -> [String] {
        try await apiClient.get(endpoint: "api/options/agents")
    }
    
    func getServerConfig() async throws -> ServerConfig {
        try await apiClient.get(endpoint: "api/options/config")
    }
}
```

## 3. Data Models

### 3.1 Conversation Models

```swift
struct ConversationInfo: Codable, Identifiable {
    let id: String
    let title: String
    let created: Date
    let updated: Date
    let repository: String?
    let isArchived: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "conversation_id"
        case title
        case created = "created_at"
        case updated = "updated_at"
        case repository = "repository"
        case isArchived = "is_archived"
    }
}

struct Message: Codable, Identifiable {
    var id: UUID = UUID()
    let content: String
    let source: String
    let timestamp: Date
    let imageURLs: [URL]?
    
    enum CodingKeys: String, CodingKey {
        case content
        case source
        case timestamp
        case imageURLs = "image_urls"
    }
}
```

### 3.2 File Models

```swift
struct FileNode: Codable, Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int?
    let lastModified: Date?
    var children: [FileNode]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case path
        case isDirectory = "is_directory"
        case size
        case lastModified = "last_modified"
        case children
    }
}

struct FileContent: Codable {
    let path: String
    let content: String
    let timestamp: Date
}
```

### 3.3 Settings Models

```swift
struct Settings: Codable {
    var backendURL: URL
    var apiKeys: [String: String]
    var uiPreferences: UIPreferences
    
    struct UIPreferences: Codable {
        var theme: String
        var fontSize: Int
        var showLineNumbers: Bool
    }
}

struct ServerConfig: Codable {
    let version: String
    let features: [String]
    let maxFileSize: Int
    
    enum CodingKeys: String, CodingKey {
        case version
        case features
        case maxFileSize = "max_file_size"
    }
}
```

### 3.4 Event and Action Models

```swift
enum AgentState {
    case unknown
    case loading
    case running
    case paused
    case stopped
    case awaitingUserInput
    case finished
    case error
}

struct CommandOutput {
    let command: String
    let output: String
    let exitCode: Int
    let timestamp: Date
}

struct ErrorEvent {
    let message: String
    let code: Int?
    let details: [String: Any]?
    let timestamp: Date
}
```

## 4. Integration Testing

### 4.1 Socket.IO Connection Testing

```swift
func testSocketIOConnection() async throws {
    // Create a test connection
    let socketManager = SocketIOManager(
        serverURL: URL(string: "http://localhost:8000")!,
        conversationId: "test-conversation"
    )
    
    // Set up expectations
    let connectExpectation = XCTestExpectation(description: "Socket connected")
    let eventExpectation = XCTestExpectation(description: "Received event")
    
    // Override handlers for testing
    socketManager.onConnect = {
        connectExpectation.fulfill()
    }
    
    socketManager.onEvent = { data in
        eventExpectation.fulfill()
    }
    
    // Connect and wait for connection
    socketManager.connect()
    
    // Wait for expectations with timeout
    await fulfillment(of: [connectExpectation], timeout: 5.0)
    
    // Send a test action
    socketManager.sendAction(
        action: "message",
        args: ["content": "Test message"]
    )
    
    // Wait for response event
    await fulfillment(of: [eventExpectation], timeout: 5.0)
    
    // Disconnect
    socketManager.disconnect()
}
```

### 4.2 REST API Testing

```swift
func testConversationCreation() async throws {
    // Create API client
    let apiClient = APIClient(baseURL: URL(string: "http://localhost:8000")!)
    let conversationService = ConversationService(apiClient: apiClient)
    
    // Create a test conversation
    let conversationId = try await conversationService.createConversation(
        initialUserMessage: "Test conversation"
    )
    
    // Verify conversation exists
    let conversation = try await conversationService.getConversation(id: conversationId)
    XCTAssertNotNil(conversation)
    XCTAssertEqual(conversation?.id, conversationId)
    
    // Clean up
    let deleted = try await conversationService.deleteConversation(id: conversationId)
    XCTAssertTrue(deleted)
}
```

## 5. Error Handling

### 5.1 Socket.IO Error Handling

```swift
// Example Socket.IO error handling
func handleSocketError(error: Error) {
    switch error {
    case let socketError as SocketIOError:
        switch socketError {
        case .connectionError:
            // Handle connection error
            showConnectionErrorAlert()
        case .disconnected:
            // Handle disconnection
            attemptReconnection()
        default:
            // Handle other socket errors
            logError(error)
        }
    default:
        // Handle unknown errors
        logError(error)
    }
}
```

### 5.2 API Error Handling

```swift
// Example API error handling
func handleAPIError(_ error: Error) {
    switch error {
    case let apiError as APIError:
        switch apiError {
        case .httpError(let statusCode, let data):
            // Handle HTTP errors
            switch statusCode {
            case 401:
                // Unauthorized - refresh token or prompt for login
                handleUnauthorized()
            case 404:
                // Not found
                showNotFoundError()
            case 429:
                // Rate limited
                showRateLimitError()
            case 500...599:
                // Server error
                showServerError()
            default:
                // Other HTTP errors
                showGenericError("HTTP Error \(statusCode)")
            }
        case .invalidURL:
            showGenericError("Invalid URL")
        case .invalidResponse:
            showGenericError("Invalid Response")
        case .decodingError(let decodingError):
            logError(decodingError)
            showGenericError("Data Parsing Error")
        }
    default:
        // Handle unknown errors
        logError(error)
        showGenericError("Unknown Error")
    }
}
```

## 6. Security Considerations

### 6.1 Token Storage

```swift
// Example secure token storage using Keychain
class TokenManager {
    private let keychainService = "com.openhands.macclient"
    private let tokenKey = "auth_token"
    
    func saveToken(_ token: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailure(status: status)
        }
    }
    
    func getToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecItemNotFound else {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.readFailure(status: status)
        }
        
        guard let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailure(status: status)
        }
    }
}

enum KeychainError: Error {
    case saveFailure(status: OSStatus)
    case readFailure(status: OSStatus)
    case deleteFailure(status: OSStatus)
}
```

### 6.2 Secure Communication

```swift
// Example secure URL session configuration
func configureSecureURLSession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    
    // Set TLS minimum version
    configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
    
    // Add security headers
    configuration.httpAdditionalHeaders = [
        "X-Content-Type-Options": "nosniff"
    ]
    
    // Configure cache policy
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    
    return URLSession(configuration: configuration)
}
```

## 7. Performance Optimization

### 7.1 Efficient Socket.IO Usage

```swift
// Example efficient Socket.IO event handling
func optimizeSocketIOUsage() {
    // 1. Use binary transport for efficiency
    let config: SocketIOClientConfiguration = [
        .compress,
        .forceWebsockets(true),
        .extraHeaders(["Accept": "application/msgpack"]),
        .connectParams(["transport": "websocket"])
    ]
    
    // 2. Implement selective event handling
    socket.on("oh_event") { [weak self] data, ack in
        guard let self = self,
              let eventData = data[0] as? [String: Any],
              let source = eventData["source"] as? String else {
            return
        }
        
        // Only process events we're interested in
        switch source {
        case "AGENT":
            self.handleAgentEvent(eventData)
        case "SYSTEM":
            self.handleSystemEvent(eventData)
        default:
            break
        }
    }
    
    // 3. Implement event batching for sending multiple actions
    func sendBatchedActions(_ actions: [[String: Any]]) {
        socket.emit("oh_action_batch", actions)
    }
}
```

### 7.2 Efficient API Usage

```swift
// Example efficient API usage
func optimizeAPIUsage() {
    // 1. Implement request throttling
    let requestThrottler = RequestThrottler(maxRequestsPerSecond: 10)
    
    // 2. Implement response caching
    let cache = NSCache<NSString, CachedResponse>()
    
    // 3. Implement conditional requests
    func conditionalFetch<T: Decodable>(endpoint: String, etag: String?) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        
        if let etag = etag {
            request.addValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 304 {
            // Use cached data
            guard let cachedResponse = cache.object(forKey: endpoint as NSString) else {
                throw APIError.cacheError
            }
            
            return try JSONDecoder().decode(T.self, from: cachedResponse.data)
        } else {
            // Use new data
            let newEtag = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")
            
            if let newEtag = newEtag {
                cache.setObject(CachedResponse(data: data, etag: newEtag), forKey: endpoint as NSString)
            }
            
            return try JSONDecoder().decode(T.self, from: data)
        }
    }
}

class CachedResponse {
    let data: Data
    let etag: String
    let timestamp: Date
    
    init(data: Data, etag: String, timestamp: Date = Date()) {
        self.data = data
        self.etag = etag
        self.timestamp = timestamp
    }
}

class RequestThrottler {
    private let maxRequestsPerSecond: Int
    private var requestTimestamps: [Date] = []
    private let queue = DispatchQueue(label: "com.openhands.requestThrottler")
    
    init(maxRequestsPerSecond: Int) {
        self.maxRequestsPerSecond = maxRequestsPerSecond
    }
    
    func waitForSlot() async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                let now = Date()
                
                // Remove timestamps older than 1 second
                self.requestTimestamps = self.requestTimestamps.filter {
                    now.timeIntervalSince($0) < 1.0
                }
                
                // If we have capacity, add timestamp and continue
                if self.requestTimestamps.count < self.maxRequestsPerSecond {
                    self.requestTimestamps.append(now)
                    continuation.resume()
                    return
                }
                
                // Otherwise, wait until we have capacity
                let oldestTimestamp = self.requestTimestamps[0]
                let timeToWait = 1.0 - now.timeIntervalSince(oldestTimestamp)
                
                if timeToWait > 0 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeToWait) {
                        self.queue.async {
                            self.requestTimestamps.removeFirst()
                            self.requestTimestamps.append(Date())
                            continuation.resume()
                        }
                    }
                } else {
                    self.requestTimestamps.removeFirst()
                    self.requestTimestamps.append(now)
                    continuation.resume()
                }
            }
        }
    }
}
```

## 8. Compatibility Considerations

### 8.1 API Version Handling

```swift
// Example API version handling
class VersionedAPIClient {
    private let baseURL: URL
    private let apiVersion: String
    
    init(baseURL: URL, apiVersion: String = "v1") {
        self.baseURL = baseURL
        self.apiVersion = apiVersion
    }
    
    func createRequest(endpoint: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("\(apiVersion)/\(endpoint)"))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
    
    // Check API compatibility
    func checkAPICompatibility() async throws -> Bool {
        struct VersionInfo: Codable {
            let version: String
            let minClientVersion: String?
            
            enum CodingKeys: String, CodingKey {
                case version
                case minClientVersion = "min_client_version"
            }
        }
        
        let versionInfo: VersionInfo = try await get(endpoint: "version")
        
        // Compare versions to ensure compatibility
        let clientVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        
        if let minClientVersion = versionInfo.minClientVersion {
            return compareVersions(clientVersion, minClientVersion) >= 0
        }
        
        return true
    }
    
    private func compareVersions(_ version1: String, _ version2: String) -> Int {
        let components1 = version1.split(separator: ".").compactMap { Int($0) }
        let components2 = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(components1.count, components2.count)
        
        for i in 0..<maxLength {
            let v1 = i < components1.count ? components1[i] : 0
            let v2 = i < components2.count ? components2[i] : 0
            
            if v1 > v2 {
                return 1
            } else if v1 < v2 {
                return -1
            }
        }
        
        return 0
    }
}
```

### 8.2 Feature Detection

```swift
// Example feature detection
class FeatureDetector {
    private let apiClient: APIClient
    private var supportedFeatures: [String] = []
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func detectFeatures() async throws {
        struct ServerConfig: Codable {
            let features: [String]
        }
        
        let config: ServerConfig = try await apiClient.get(endpoint: "api/options/config")
        self.supportedFeatures = config.features
    }
    
    func isFeatureSupported(_ feature: String) -> Bool {
        return supportedFeatures.contains(feature)
    }
    
    // Example usage
    func configureUI() {
        if isFeatureSupported("file_editing") {
            enableFileEditingUI()
        } else {
            disableFileEditingUI()
        }
        
        if isFeatureSupported("image_upload") {
            enableImageUploadUI()
        } else {
            disableImageUploadUI()
        }
    }
}
```

This comprehensive API integration specification provides the detailed technical guidance needed to implement the OpenHands Mac client, ensuring compatibility with the existing backend and covering all the necessary communication patterns for a functional MVP.