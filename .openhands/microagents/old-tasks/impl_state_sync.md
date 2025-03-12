# State Synchronization for Mac Client

This document outlines the implementation details for state synchronization between the Mac client and backend server, including handling conflicts, divergent states, and stale data.

## 1. State Synchronization Architecture

### 1.1 State Model

```swift
// Core state model that represents the application state
struct AppState: Codable, Equatable {
    var conversations: [Conversation]
    var currentConversationId: String?
    var preferences: UserPreferences
    var fileSystem: FileSystemState
    var lastSyncTimestamp: Date
    
    // Version tracking for conflict resolution
    var stateVersion: Int
}

struct Conversation: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var messages: [Message]
    var status: ConversationStatus
    var lastUpdated: Date
    var isArchived: Bool
    
    // Local-only properties (not synchronized)
    var localDraft: String?
    var unreadCount: Int
    
    // Version tracking for conflict resolution
    var version: Int
}

enum ConversationStatus: String, Codable, Equatable {
    case active
    case completed
    case error
}

struct Message: Codable, Identifiable, Equatable {
    let id: String
    let source: MessageSource
    let content: String
    let timestamp: Date
    let metadata: [String: AnyCodable]?
    
    // Server-assigned sequence for ordering
    let sequence: Int
    
    // Flag to track if message has been acknowledged by server
    var isAcknowledged: Bool
}

enum MessageSource: String, Codable, Equatable {
    case user
    case agent
    case system
}

struct UserPreferences: Codable, Equatable {
    var theme: AppTheme
    var fontSize: Int
    var enableNotifications: Bool
    var autoSaveInterval: TimeInterval
    
    // Version tracking for conflict resolution
    var version: Int
}

enum AppTheme: String, Codable, Equatable {
    case system
    case light
    case dark
}

struct FileSystemState: Codable, Equatable {
    var recentFiles: [RecentFile]
    var expandedFolders: [String]
    var fileFilters: [String]
    
    // Version tracking for conflict resolution
    var version: Int
}

struct RecentFile: Codable, Identifiable, Equatable {
    let id: String
    let path: String
    let lastAccessed: Date
}
```

### 1.2 State Store

```swift
class StateStore: ObservableObject {
    @Published private(set) var state: AppState
    
    private let syncManager: StateSyncManager
    private let persistenceManager: StatePersistenceManager
    
    init(syncManager: StateSyncManager, persistenceManager: StatePersistenceManager) {
        self.syncManager = syncManager
        self.persistenceManager = persistenceManager
        
        // Load initial state from persistence
        if let savedState = persistenceManager.loadState() {
            self.state = savedState
        } else {
            self.state = AppState.default
        }
        
        // Set up sync manager
        syncManager.onStateReceived = { [weak self] serverState in
            self?.handleServerState(serverState)
        }
        
        // Set up state change observation
        setupStateObservation()
    }
    
    private func setupStateObservation() {
        // Observe state changes to trigger persistence and sync
        $state
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.persistenceManager.saveState(newState)
                self?.syncManager.queueStateForSync(newState)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Updates
    
    func updateState(_ update: (inout AppState) -> Void) {
        var newState = state
        update(&newState)
        
        // Update version
        newState.stateVersion += 1
        
        // Update timestamp
        newState.lastSyncTimestamp = Date()
        
        // Publish new state
        state = newState
    }
    
    // MARK: - Server State Handling
    
    private func handleServerState(_ serverState: AppState) {
        // Merge server state with local state
        let mergedState = mergeStates(local: state, server: serverState)
        
        // Update state if changes were made
        if mergedState != state {
            state = mergedState
        }
    }
    
    private func mergeStates(local: AppState, server: AppState) -> AppState {
        var result = local
        
        // Apply server-side conversation changes
        for serverConversation in server.conversations {
            if let localIndex = local.conversations.firstIndex(where: { $0.id == serverConversation.id }) {
                // Existing conversation - merge based on version
                let localConversation = local.conversations[localIndex]
                
                if serverConversation.version > localConversation.version {
                    // Server has newer version - use server data but preserve local-only properties
                    var updatedConversation = serverConversation
                    updatedConversation.localDraft = localConversation.localDraft
                    updatedConversation.unreadCount = localConversation.unreadCount
                    
                    result.conversations[localIndex] = updatedConversation
                } else if serverConversation.version == localConversation.version {
                    // Same version - merge messages
                    var updatedConversation = localConversation
                    updatedConversation.messages = mergeMessages(
                        local: localConversation.messages,
                        server: serverConversation.messages
                    )
                    
                    result.conversations[localIndex] = updatedConversation
                }
                // If local version is higher, keep local version
            } else {
                // New conversation from server - add it
                result.conversations.append(serverConversation)
            }
        }
        
        // Apply preference changes if server has newer version
        if server.preferences.version > local.preferences.version {
            result.preferences = server.preferences
        }
        
        // Apply file system state changes if server has newer version
        if server.fileSystem.version > local.fileSystem.version {
            result.fileSystem = server.fileSystem
        }
        
        // Update current conversation if needed
        if let serverCurrentId = server.currentConversationId,
           serverCurrentId != local.currentConversationId {
            result.currentConversationId = serverCurrentId
        }
        
        // Update last sync timestamp
        result.lastSyncTimestamp = Date()
        
        return result
    }
    
    private func mergeMessages(local: [Message], server: [Message]) -> [Message] {
        var result = local
        
        // Add any server messages not in local
        for serverMessage in server {
            if !local.contains(where: { $0.id == serverMessage.id }) {
                result.append(serverMessage)
            }
        }
        
        // Sort by sequence number
        result.sort { $0.sequence < $1.sequence }
        
        return result
    }
}
```

## 2. Synchronization Manager

### 2.1 Sync Manager Implementation

```swift
class StateSyncManager {
    // Callback for when state is received from server
    var onStateReceived: ((AppState) -> Void)?
    
    private let socketManager: SocketManager
    private var syncQueue: OperationQueue
    private var pendingStateUpdates: [AppState] = []
    private var isSyncing = false
    private var lastSyncedVersion: Int = 0
    
    init(socketManager: SocketManager) {
        self.socketManager = socketManager
        
        // Create a serial queue for sync operations
        syncQueue = OperationQueue()
        syncQueue.maxConcurrentOperationCount = 1
        
        // Set up socket event handlers
        setupSocketHandlers()
    }
    
    private func setupSocketHandlers() {
        // Listen for state updates from server
        socketManager.on("state_update") { [weak self] data in
            guard let self = self,
                  let stateData = data.first as? [String: Any] else {
                return
            }
            
            do {
                // Convert to JSON data
                let jsonData = try JSONSerialization.data(withJSONObject: stateData)
                
                // Decode server state
                let serverState = try JSONDecoder().decode(AppState.self, from: jsonData)
                
                // Notify state store
                DispatchQueue.main.async {
                    self.onStateReceived?(serverState)
                }
                
                // Update last synced version
                self.lastSyncedVersion = serverState.stateVersion
            } catch {
                print("Error decoding server state: \(error)")
            }
        }
        
        // Listen for sync acknowledgements
        socketManager.on("sync_ack") { [weak self] data in
            guard let self = self,
                  let ackData = data.first as? [String: Any],
                  let version = ackData["version"] as? Int else {
                return
            }
            
            // Update last synced version
            self.lastSyncedVersion = version
            
            // Remove acknowledged updates from pending queue
            self.pendingStateUpdates.removeAll { $0.stateVersion <= version }
            
            // Continue syncing if more updates are pending
            self.isSyncing = false
            self.processPendingUpdates()
        }
    }
    
    // Queue state for synchronization
    func queueStateForSync(_ state: AppState) {
        // Only queue if version is newer than last synced
        if state.stateVersion > lastSyncedVersion {
            pendingStateUpdates.append(state)
            processPendingUpdates()
        }
    }
    
    private func processPendingUpdates() {
        // Skip if already syncing or no updates
        guard !isSyncing, !pendingStateUpdates.isEmpty else {
            return
        }
        
        // Get latest state update
        guard let latestState = pendingStateUpdates.last else {
            return
        }
        
        // Mark as syncing
        isSyncing = true
        
        // Prepare state for sync (remove local-only properties)
        let syncState = prepareStateForSync(latestState)
        
        do {
            // Encode state to JSON
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(syncState)
            
            // Convert to dictionary
            if let stateDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                // Send to server
                socketManager.emit("state_sync", stateDict)
            }
        } catch {
            print("Error encoding state for sync: \(error)")
            isSyncing = false
        }
    }
    
    private func prepareStateForSync(_ state: AppState) -> AppState {
        var syncState = state
        
        // Remove local-only properties from conversations
        for i in 0..<syncState.conversations.count {
            syncState.conversations[i].localDraft = nil
            syncState.conversations[i].unreadCount = 0
        }
        
        return syncState
    }
    
    // Force immediate sync
    func forceSync() {
        if let currentState = pendingStateUpdates.last {
            pendingStateUpdates = [currentState]
            isSyncing = false
            processPendingUpdates()
        }
    }
}
```

### 2.2 State Persistence Manager

```swift
class StatePersistenceManager {
    private let fileManager = FileManager.default
    private let stateFileName = "app_state.json"
    
    // Get URL for state file
    private var stateFileURL: URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(stateFileName)
    }
    
    // Save state to disk
    func saveState(_ state: AppState) {
        guard let fileURL = stateFileURL else {
            print("Error: Could not determine state file URL")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(state)
            try data.write(to: fileURL)
        } catch {
            print("Error saving state: \(error)")
        }
    }
    
    // Load state from disk
    func loadState() -> AppState? {
        guard let fileURL = stateFileURL,
              fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            return try decoder.decode(AppState.self, from: data)
        } catch {
            print("Error loading state: \(error)")
            return nil
        }
    }
    
    // Clear saved state
    func clearState() {
        guard let fileURL = stateFileURL,
              fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            print("Error clearing state: \(error)")
        }
    }
}
```

## 3. Conflict Resolution

### 3.1 Version-Based Conflict Resolution

```swift
enum ConflictResolutionStrategy {
    case serverWins
    case clientWins
    case merge
    case manual
}

class ConflictResolver {
    // Resolve conflicts between local and server states
    static func resolveConflicts(
        local: AppState,
        server: AppState,
        strategy: ConflictResolutionStrategy = .merge
    ) -> AppState {
        switch strategy {
        case .serverWins:
            return resolveServerWins(local: local, server: server)
            
        case .clientWins:
            return resolveClientWins(local: local, server: server)
            
        case .merge:
            return resolveMerge(local: local, server: server)
            
        case .manual:
            // Return both states for manual resolution
            // This would typically show a UI for the user to choose
            return local
        }
    }
    
    // Server wins strategy - use server state but preserve local-only data
    private static func resolveServerWins(local: AppState, server: AppState) -> AppState {
        var result = server
        
        // Preserve local-only data in conversations
        for i in 0..<result.conversations.count {
            let serverId = result.conversations[i].id
            
            if let localConversation = local.conversations.first(where: { $0.id == serverId }) {
                result.conversations[i].localDraft = localConversation.localDraft
                result.conversations[i].unreadCount = localConversation.unreadCount
            }
        }
        
        return result
    }
    
    // Client wins strategy - use local state but incorporate new server data
    private static func resolveClientWins(local: AppState, server: AppState) -> AppState {
        var result = local
        
        // Add new conversations from server
        for serverConversation in server.conversations {
            if !local.conversations.contains(where: { $0.id == serverConversation.id }) {
                result.conversations.append(serverConversation)
            }
        }
        
        return result
    }
    
    // Merge strategy - intelligently merge based on entity versions
    private static func resolveMerge(local: AppState, server: AppState) -> AppState {
        var result = local
        
        // Merge conversations
        var mergedConversations: [Conversation] = []
        
        // Process all conversations from both states
        let allConversationIds = Set(
            local.conversations.map { $0.id } + 
            server.conversations.map { $0.id }
        )
        
        for conversationId in allConversationIds {
            let localConversation = local.conversations.first(where: { $0.id == conversationId })
            let serverConversation = server.conversations.first(where: { $0.id == conversationId })
            
            if let local = localConversation, let server = serverConversation {
                // Both exist - resolve based on version
                if local.version > server.version {
                    mergedConversations.append(local)
                } else if server.version > local.version {
                    var merged = server
                    merged.localDraft = local.localDraft
                    merged.unreadCount = local.unreadCount
                    mergedConversations.append(merged)
                } else {
                    // Same version - merge messages
                    var merged = local
                    merged.messages = mergeMessages(local: local.messages, server: server.messages)
                    mergedConversations.append(merged)
                }
            } else if let local = localConversation {
                // Only in local
                mergedConversations.append(local)
            } else if let server = serverConversation {
                // Only in server
                mergedConversations.append(server)
            }
        }
        
        result.conversations = mergedConversations
        
        // Merge preferences based on version
        if server.preferences.version > local.preferences.version {
            result.preferences = server.preferences
        }
        
        // Merge file system state based on version
        if server.fileSystem.version > local.fileSystem.version {
            result.fileSystem = server.fileSystem
        }
        
        // Use higher state version
        result.stateVersion = max(local.stateVersion, server.stateVersion)
        
        return result
    }
    
    // Merge messages from local and server
    private static func mergeMessages(local: [Message], server: [Message]) -> [Message] {
        var result: [Message] = []
        
        // Combine all messages
        let allMessages = local + server.filter { serverMsg in
            !local.contains { $0.id == serverMsg.id }
        }
        
        // Sort by sequence and timestamp
        result = allMessages.sorted { first, second in
            if first.sequence != second.sequence {
                return first.sequence < second.sequence
            }
            return first.timestamp < second.timestamp
        }
        
        return result
    }
}
```

### 3.2 Conflict Detection

```swift
class ConflictDetector {
    // Detect conflicts between local and server states
    static func detectConflicts(local: AppState, server: AppState) -> [StateConflict] {
        var conflicts: [StateConflict] = []
        
        // Check for conversation conflicts
        for localConversation in local.conversations {
            if let serverConversation = server.conversations.first(where: { $0.id == localConversation.id }) {
                // Both have the same conversation - check for conflicts
                if localConversation.version != serverConversation.version {
                    conflicts.append(
                        .conversationConflict(
                            id: localConversation.id,
                            localVersion: localConversation.version,
                            serverVersion: serverConversation.version
                        )
                    )
                }
                
                // Check for message conflicts
                let messageConflicts = detectMessageConflicts(
                    local: localConversation.messages,
                    server: serverConversation.messages
                )
                
                conflicts.append(contentsOf: messageConflicts.map {
                    .messageConflict(conversationId: localConversation.id, conflict: $0)
                })
            }
        }
        
        // Check for preference conflicts
        if local.preferences.version != server.preferences.version {
            conflicts.append(
                .preferencesConflict(
                    localVersion: local.preferences.version,
                    serverVersion: server.preferences.version
                )
            )
        }
        
        // Check for file system state conflicts
        if local.fileSystem.version != server.fileSystem.version {
            conflicts.append(
                .fileSystemConflict(
                    localVersion: local.fileSystem.version,
                    serverVersion: server.fileSystem.version
                )
            )
        }
        
        return conflicts
    }
    
    // Detect conflicts between message sets
    private static func detectMessageConflicts(local: [Message], server: [Message]) -> [MessageConflict] {
        var conflicts: [MessageConflict] = []
        
        // Check for messages with same ID but different content
        for localMessage in local {
            if let serverMessage = server.first(where: { $0.id == localMessage.id }) {
                if localMessage.content != serverMessage.content {
                    conflicts.append(
                        .contentMismatch(
                            messageId: localMessage.id,
                            localContent: localMessage.content,
                            serverContent: serverMessage.content
                        )
                    )
                }
                
                if localMessage.sequence != serverMessage.sequence {
                    conflicts.append(
                        .sequenceMismatch(
                            messageId: localMessage.id,
                            localSequence: localMessage.sequence,
                            serverSequence: serverMessage.sequence
                        )
                    )
                }
            }
        }
        
        return conflicts
    }
}

// Conflict types
enum StateConflict {
    case conversationConflict(id: String, localVersion: Int, serverVersion: Int)
    case messageConflict(conversationId: String, conflict: MessageConflict)
    case preferencesConflict(localVersion: Int, serverVersion: Int)
    case fileSystemConflict(localVersion: Int, serverVersion: Int)
}

enum MessageConflict {
    case contentMismatch(messageId: String, localContent: String, serverContent: String)
    case sequenceMismatch(messageId: String, localSequence: Int, serverSequence: Int)
}
```

## 4. Handling Stale State

### 4.1 Stale State Detection

```swift
class StaleStateDetector {
    // Check if state is stale based on timestamp
    static func isStateStale(state: AppState, threshold: TimeInterval = 300) -> Bool {
        let now = Date()
        return now.timeIntervalSince(state.lastSyncTimestamp) > threshold
    }
    
    // Check if specific conversation is stale
    static func isConversationStale(conversation: Conversation, threshold: TimeInterval = 300) -> Bool {
        let now = Date()
        return now.timeIntervalSince(conversation.lastUpdated) > threshold
    }
    
    // Get stale conversations
    static func getStaleConversations(in state: AppState, threshold: TimeInterval = 300) -> [Conversation] {
        let now = Date()
        return state.conversations.filter {
            now.timeIntervalSince($0.lastUpdated) > threshold
        }
    }
}
```

### 4.2 Stale State Refresh

```swift
class StateRefresher {
    private let socketManager: SocketManager
    
    init(socketManager: SocketManager) {
        self.socketManager = socketManager
    }
    
    // Request full state refresh from server
    func requestFullStateRefresh(completion: @escaping (Result<AppState, Error>) -> Void) {
        socketManager.emit("request_full_state") { [weak self] response in
            guard let self = self else { return }
            
            if let error = response.error {
                completion(.failure(error))
                return
            }
            
            guard let stateData = response.data as? [String: Any] else {
                completion(.failure(NSError(domain: "StateRefresher", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid state data received"
                ])))
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: stateData)
                let state = try JSONDecoder().decode(AppState.self, from: jsonData)
                completion(.success(state))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // Request refresh for specific conversation
    func refreshConversation(id: String, completion: @escaping (Result<Conversation, Error>) -> Void) {
        socketManager.emit("request_conversation", ["id": id]) { response in
            if let error = response.error {
                completion(.failure(error))
                return
            }
            
            guard let conversationData = response.data as? [String: Any] else {
                completion(.failure(NSError(domain: "StateRefresher", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid conversation data received"
                ])))
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: conversationData)
                let conversation = try JSONDecoder().decode(Conversation.self, from: jsonData)
                completion(.success(conversation))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
```

### 4.3 Automatic Refresh Policy

```swift
class AutoRefreshPolicy {
    private let stateStore: StateStore
    private let stateRefresher: StateRefresher
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval
    
    init(stateStore: StateStore, stateRefresher: StateRefresher, refreshInterval: TimeInterval = 300) {
        self.stateStore = stateStore
        self.stateRefresher = stateRefresher
        self.refreshInterval = refreshInterval
        
        startRefreshTimer()
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            timeInterval: refreshInterval,
            target: self,
            selector: #selector(checkForStaleState),
            userInfo: nil,
            repeats: true
        )
    }
    
    @objc private func checkForStaleState() {
        let state = stateStore.state
        
        // Check if overall state is stale
        if StaleStateDetector.isStateStale(state: state) {
            refreshFullState()
            return
        }
        
        // Check for stale conversations
        let staleConversations = StaleStateDetector.getStaleConversations(in: state)
        for conversation in staleConversations {
            refreshConversation(id: conversation.id)
        }
    }
    
    private func refreshFullState() {
        stateRefresher.requestFullStateRefresh { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let refreshedState):
                self.stateStore.updateState { state in
                    // Apply refreshed state
                    state = refreshedState
                }
                
            case .failure(let error):
                print("Failed to refresh state: \(error)")
                // Could implement retry logic here
            }
        }
    }
    
    private func refreshConversation(id: String) {
        stateRefresher.refreshConversation(id: id) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let refreshedConversation):
                self.stateStore.updateState { state in
                    // Find and update the conversation
                    if let index = state.conversations.firstIndex(where: { $0.id == id }) {
                        state.conversations[index] = refreshedConversation
                    }
                }
                
            case .failure(let error):
                print("Failed to refresh conversation \(id): \(error)")
            }
        }
    }
}
```

## 5. Offline Mode and Reconnection Syncing

### 5.1 Offline Queue Manager

```swift
class OfflineQueueManager {
    private let persistenceManager: StatePersistenceManager
    private var offlineActions: [OfflineAction] = []
    private let offlineActionsFileName = "offline_actions.json"
    
    init(persistenceManager: StatePersistenceManager) {
        self.persistenceManager = persistenceManager
        loadOfflineActions()
    }
    
    // Add action to offline queue
    func queueAction(_ action: OfflineAction) {
        offlineActions.append(action)
        saveOfflineActions()
    }
    
    // Get all queued actions
    func getQueuedActions() -> [OfflineAction] {
        return offlineActions
    }
    
    // Clear specific actions
    func clearActions(_ actionIds: [String]) {
        offlineActions.removeAll { actionIds.contains($0.id) }
        saveOfflineActions()
    }
    
    // Clear all actions
    func clearAllActions() {
        offlineActions.removeAll()
        saveOfflineActions()
    }
    
    // Save offline actions to disk
    private func saveOfflineActions() {
        guard let fileURL = getOfflineActionsFileURL() else {
            print("Error: Could not determine offline actions file URL")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(offlineActions)
            try data.write(to: fileURL)
        } catch {
            print("Error saving offline actions: \(error)")
        }
    }
    
    // Load offline actions from disk
    private func loadOfflineActions() {
        guard let fileURL = getOfflineActionsFileURL(),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            offlineActions = try decoder.decode([OfflineAction].self, from: data)
        } catch {
            print("Error loading offline actions: \(error)")
        }
    }
    
    // Get URL for offline actions file
    private func getOfflineActionsFileURL() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(offlineActionsFileName)
    }
}

// Offline action model
struct OfflineAction: Codable, Identifiable {
    let id: String
    let type: String
    let payload: [String: AnyCodable]
    let timestamp: Date
    let conversationId: String?
    var retryCount: Int
    
    init(type: String, payload: [String: Any], conversationId: String? = nil) {
        self.id = UUID().uuidString
        self.type = type
        self.payload = payload.mapValues { AnyCodable($0) }
        self.timestamp = Date()
        self.conversationId = conversationId
        self.retryCount = 0
    }
}

// Helper for encoding/decoding Any values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable value cannot be encoded"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}
```

### 5.2 Offline Mode Manager

```swift
class OfflineModeManager: ObservableObject {
    @Published private(set) var isOffline = false
    @Published private(set) var pendingActionCount = 0
    
    private let socketManager: SocketManager
    private let offlineQueueManager: OfflineQueueManager
    private let stateStore: StateStore
    
    init(socketManager: SocketManager, offlineQueueManager: OfflineQueueManager, stateStore: StateStore) {
        self.socketManager = socketManager
        self.offlineQueueManager = offlineQueueManager
        self.stateStore = stateStore
        
        // Set up connection status monitoring
        setupConnectionMonitoring()
        
        // Update pending action count
        updatePendingActionCount()
    }
    
    private func setupConnectionMonitoring() {
        // Monitor socket connection status
        socketManager.onStatusChange = { [weak self] status in
            guard let self = self else { return }
            
            let wasOffline = self.isOffline
            
            // Update offline status
            switch status {
            case .connected:
                self.isOffline = false
            case .disconnected, .error:
                self.isOffline = true
            case .connecting, .reconnecting:
                // Keep current offline status during connection attempts
                break
            }
            
            // If transitioning from offline to online, sync queued actions
            if wasOffline && !self.isOffline {
                self.syncOfflineActions()
            }
        }
    }
    
    // Perform action with offline support
    func performAction(type: String, payload: [String: Any], conversationId: String? = nil) {
        if !isOffline {
            // Online - send directly
            socketManager.emit(type, payload)
        } else {
            // Offline - queue for later
            let action = OfflineAction(type: type, payload: payload, conversationId: conversationId)
            offlineQueueManager.queueAction(action)
            updatePendingActionCount()
            
            // Also update local state to reflect the action
            applyOfflineActionToLocalState(action)
        }
    }
    
    // Apply offline action to local state for immediate feedback
    private func applyOfflineActionToLocalState(_ action: OfflineAction) {
        stateStore.updateState { state in
            switch action.type {
            case "send_message":
                if let conversationId = action.conversationId,
                   let content = action.payload["content"]?.value as? String,
                   let conversationIndex = state.conversations.firstIndex(where: { $0.id == conversationId }) {
                    
                    // Create a temporary message
                    let tempMessage = Message(
                        id: action.id,
                        source: .user,
                        content: content,
                        timestamp: action.timestamp,
                        metadata: nil,
                        sequence: state.conversations[conversationIndex].messages.count,
                        isAcknowledged: false
                    )
                    
                    // Add to conversation
                    state.conversations[conversationIndex].messages.append(tempMessage)
                    state.conversations[conversationIndex].lastUpdated = action.timestamp
                }
                
            case "update_conversation":
                if let conversationId = action.conversationId,
                   let title = action.payload["title"]?.value as? String,
                   let conversationIndex = state.conversations.firstIndex(where: { $0.id == conversationId }) {
                    
                    // Update conversation title
                    state.conversations[conversationIndex].title = title
                    state.conversations[conversationIndex].lastUpdated = action.timestamp
                }
                
            case "update_preferences":
                if let theme = action.payload["theme"]?.value as? String {
                    if let appTheme = AppTheme(rawValue: theme) {
                        state.preferences.theme = appTheme
                    }
                }
                
                if let fontSize = action.payload["fontSize"]?.value as? Int {
                    state.preferences.fontSize = fontSize
                }
                
                if let enableNotifications = action.payload["enableNotifications"]?.value as? Bool {
                    state.preferences.enableNotifications = enableNotifications
                }
                
                // Increment version
                state.preferences.version += 1
                
            default:
                // Other action types not handled for local state updates
                break
            }
        }
    }
    
    // Sync offline actions when back online
    private func syncOfflineActions() {
        let actions = offlineQueueManager.getQueuedActions()
        
        if actions.isEmpty {
            return
        }
        
        // Process actions in order
        var processedActionIds: [String] = []
        
        for action in actions {
            // Convert AnyCodable payload back to regular dictionary
            let payload = action.payload.mapValues { $0.value }
            
            // Send to server
            socketManager.emit(action.type, payload)
            
            // Add to processed list
            processedActionIds.append(action.id)
        }
        
        // Clear processed actions
        offlineQueueManager.clearActions(processedActionIds)
        updatePendingActionCount()
    }
    
    // Update pending action count
    private func updatePendingActionCount() {
        let count = offlineQueueManager.getQueuedActions().count
        
        DispatchQueue.main.async {
            self.pendingActionCount = count
        }
    }
    
    // Force sync of offline actions
    func forceSyncOfflineActions() {
        if !isOffline {
            syncOfflineActions()
        }
    }
}
```

### 5.3 Offline Indicator UI

```swift
struct OfflineIndicatorView: View {
    @ObservedObject var offlineModeManager: OfflineModeManager
    
    var body: some View {
        if offlineModeManager.isOffline || offlineModeManager.pendingActionCount > 0 {
            HStack(spacing: 8) {
                // Offline icon
                Image(systemName: offlineModeManager.isOffline ? "wifi.slash" : "arrow.up.arrow.down")
                    .foregroundColor(offlineModeManager.isOffline ? .red : .orange)
                
                // Status text
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(offlineModeManager.isOffline ? .red : .orange)
                
                // Sync button if needed
                if !offlineModeManager.isOffline && offlineModeManager.pendingActionCount > 0 {
                    Button(action: {
                        offlineModeManager.forceSyncOfflineActions()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }
    
    private var statusText: String {
        if offlineModeManager.isOffline {
            return "Offline Mode"
        } else if offlineModeManager.pendingActionCount > 0 {
            return "Syncing (\(offlineModeManager.pendingActionCount) pending)"
        } else {
            return ""
        }
    }
    
    private var backgroundColor: Color {
        offlineModeManager.isOffline ? Color.red.opacity(0.1) : Color.orange.opacity(0.1)
    }
}
```

This implementation guide provides a comprehensive approach to state synchronization in the Mac client, covering state models, synchronization, conflict resolution, stale state handling, and offline mode support.