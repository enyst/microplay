# Backend Connection Management for Mac Client

This document outlines the implementation details for managing backend connections in the Mac client, including connection persistence, status indicators, and retry mechanisms.

## 1. Connection Persistence Across App Launches

### 1.1 Connection Configuration Storage

```swift
struct ConnectionConfiguration: Codable {
    let serverURL: URL
    let conversationId: String
    let lastEventId: String?
    let authToken: String?
    let connectionParams: [String: String]
    
    // Default configuration
    static let `default` = ConnectionConfiguration(
        serverURL: URL(string: "https://api.openhands.dev")!,
        conversationId: "",
        lastEventId: nil,
        authToken: nil,
        connectionParams: [:]
    )
}

class ConnectionConfigurationStore {
    private let userDefaults = UserDefaults.standard
    private let configKey = "connection_configuration"
    
    func saveConfiguration(_ config: ConnectionConfiguration) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(config)
            userDefaults.set(data, forKey: configKey)
        } catch {
            print("Failed to save connection configuration: \(error)")
        }
    }
    
    func loadConfiguration() -> ConnectionConfiguration {
        guard let data = userDefaults.data(forKey: configKey) else {
            return .default
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(ConnectionConfiguration.self, from: data)
        } catch {
            print("Failed to load connection configuration: \(error)")
            return .default
        }
    }
    
    func updateLastEventId(_ eventId: String) {
        var config = loadConfiguration()
        config.lastEventId = eventId
        saveConfiguration(config)
    }
    
    func clearConfiguration() {
        userDefaults.removeObject(forKey: configKey)
    }
}
```

### 1.2 Connection Manager with Persistence

```swift
class ConnectionManager: ObservableObject {
    @Published private(set) var status: ConnectionStatus = .disconnected
    @Published private(set) var currentConversationId: String?
    
    private let configStore = ConnectionConfigurationStore()
    private var socketManager: SocketManager?
    
    init() {
        // Restore previous connection on app launch if available
        let savedConfig = configStore.loadConfiguration()
        if !savedConfig.conversationId.isEmpty {
            currentConversationId = savedConfig.conversationId
            
            // Don't automatically connect, but prepare the connection
            prepareConnection(with: savedConfig)
        }
    }
    
    func connect(to conversationId: String, serverURL: URL? = nil) {
        // Update current conversation ID
        currentConversationId = conversationId
        
        // Create or update configuration
        var config = configStore.loadConfiguration()
        config.conversationId = conversationId
        if let serverURL = serverURL {
            config.serverURL = serverURL
        }
        
        // Save the configuration
        configStore.saveConfiguration(config)
        
        // Prepare and establish connection
        prepareConnection(with: config)
        socketManager?.connect()
    }
    
    func disconnect() {
        socketManager?.disconnect()
        status = .disconnected
    }
    
    private func prepareConnection(with config: ConnectionConfiguration) {
        // Create socket manager with the saved configuration
        socketManager = SocketManager(
            serverURL: config.serverURL,
            conversationId: config.conversationId,
            lastEventId: config.lastEventId,
            authToken: config.authToken,
            additionalParams: config.connectionParams
        )
        
        // Set up status change handler
        socketManager?.onStatusChange = { [weak self] newStatus in
            DispatchQueue.main.async {
                self?.status = newStatus
            }
        }
        
        // Set up event ID tracking for persistence
        socketManager?.onEventReceived = { [weak self] eventId in
            if let eventId = eventId {
                self?.configStore.updateLastEventId(eventId)
            }
        }
    }
    
    func updateServerURL(_ url: URL) {
        var config = configStore.loadConfiguration()
        config.serverURL = url
        configStore.saveConfiguration(config)
        
        // Reconnect with new URL if currently connected
        if status == .connected, let conversationId = currentConversationId {
            disconnect()
            connect(to: conversationId, serverURL: url)
        }
    }
}
```

### 1.3 App Delegate Integration

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    let connectionManager = ConnectionManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Restore connection if needed
        if let conversationId = connectionManager.currentConversationId {
            // Optionally auto-connect or just prepare the connection
            // connectionManager.connect(to: conversationId)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Gracefully disconnect
        connectionManager.disconnect()
    }
}
```

## 2. Connection Status Indicators

### 2.1 Connection Status Enum

```swift
enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int, maxAttempts: Int)
    case error(message: String)
    
    var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .reconnecting(let attempt, let maxAttempts):
            return "Reconnecting (\(attempt)/\(maxAttempts))..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
    
    var isConnecting: Bool {
        if case .connecting = self {
            return true
        }
        if case .reconnecting = self {
            return true
        }
        return false
    }
}
```

### 2.2 Status Indicator View

```swift
struct ConnectionStatusIndicatorView: View {
    @ObservedObject var connectionManager: ConnectionManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            // Status text
            Text(connectionManager.status.description)
                .font(.caption)
                .foregroundColor(textColor)
            
            // Reconnect button if needed
            if case .error = connectionManager.status, 
               let conversationId = connectionManager.currentConversationId {
                Button(action: {
                    connectionManager.connect(to: conversationId)
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
    
    private var statusColor: Color {
        switch connectionManager.status {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .yellow
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
    
    private var textColor: Color {
        switch connectionManager.status {
        case .error:
            return .red
        default:
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        switch connectionManager.status {
        case .error:
            return Color.red.opacity(0.1)
        case .connecting, .reconnecting:
            return Color.yellow.opacity(0.1)
        case .connected:
            return Color.green.opacity(0.1)
        default:
            return Color.gray.opacity(0.1)
        }
    }
}
```

### 2.3 Menu Bar Status Indicator

```swift
class StatusBarController {
    private var statusItem: NSStatusItem
    private var connectionManager: ConnectionManager
    
    init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Connection Status")
            updateStatusItemAppearance()
        }
        
        // Observe connection status changes
        connectionManager.$status.sink { [weak self] newStatus in
            self?.updateStatusItemAppearance()
        }
        .store(in: &cancellables)
    }
    
    private func updateStatusItemAppearance() {
        guard let button = statusItem.button else { return }
        
        // Update icon based on connection status
        switch connectionManager.status {
        case .connected:
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Connected")
            button.contentTintColor = .systemGreen
            
        case .connecting:
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Connecting")
            button.contentTintColor = .systemYellow
            
        case .reconnecting:
            button.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reconnecting")
            button.contentTintColor = .systemYellow
            
        case .disconnected:
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Disconnected")
            button.contentTintColor = .systemGray
            
        case .error:
            button.image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: "Connection Error")
            button.contentTintColor = .systemRed
        }
        
        // Update tooltip
        button.toolTip = "OpenHands: \(connectionManager.status.description)"
    }
}
```

## 3. Retry Mechanism

### 3.1 Advanced Retry Configuration

```swift
struct RetryConfiguration: Codable {
    let initialDelay: TimeInterval
    let maxDelay: TimeInterval
    let maxAttempts: Int
    let jitter: Bool
    let backoffFactor: Double
    
    // Default configuration
    static let `default` = RetryConfiguration(
        initialDelay: 1.0,
        maxDelay: 30.0,
        maxAttempts: 10,
        jitter: true,
        backoffFactor: 1.5
    )
}
```

### 3.2 Retry Manager Implementation

```swift
class RetryManager {
    private let configuration: RetryConfiguration
    private var currentAttempt = 0
    private var timer: Timer?
    private var onRetry: (() -> Void)?
    
    init(configuration: RetryConfiguration = .default) {
        self.configuration = configuration
    }
    
    func startRetrying(onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
        currentAttempt = 0
        scheduleNextRetry()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        currentAttempt = 0
    }
    
    func retry() {
        timer?.invalidate()
        timer = nil
        
        if currentAttempt < configuration.maxAttempts {
            onRetry?()
            currentAttempt += 1
        }
    }
    
    private func scheduleNextRetry() {
        guard currentAttempt < configuration.maxAttempts else {
            // Max attempts reached
            return
        }
        
        // Calculate delay with exponential backoff
        let baseDelay = configuration.initialDelay * pow(configuration.backoffFactor, Double(currentAttempt))
        let delay = min(baseDelay, configuration.maxDelay)
        
        // Add jitter if configured
        let actualDelay = configuration.jitter ? addJitter(to: delay) : delay
        
        timer = Timer.scheduledTimer(withTimeInterval: actualDelay, repeats: false) { [weak self] _ in
            self?.retry()
        }
    }
    
    private func addJitter(to delay: TimeInterval) -> TimeInterval {
        // Add random jitter of ±30%
        let jitterFactor = 0.7 + (Double.random(in: 0...0.6))
        return delay * jitterFactor
    }
    
    var currentStatus: ConnectionStatus {
        if currentAttempt > 0 {
            return .reconnecting(attempt: currentAttempt, maxAttempts: configuration.maxAttempts)
        } else {
            return .disconnected
        }
    }
}
```

### 3.3 Integration with Socket Manager

```swift
class SocketManager {
    // ... other properties ...
    
    private let retryManager: RetryManager
    private var isManuallyDisconnected = false
    
    init(serverURL: URL, conversationId: String, lastEventId: String? = nil, 
         authToken: String? = nil, additionalParams: [String: String] = [:],
         retryConfiguration: RetryConfiguration = .default) {
        
        self.retryManager = RetryManager(configuration: retryConfiguration)
        
        // ... other initialization ...
        
        setupSocketHandlers()
    }
    
    private func setupSocketHandlers() {
        // ... other handlers ...
        
        socket.on(clientEvent: .disconnect) { [weak self] data, _ in
            guard let self = self else { return }
            
            // Update status
            self.updateStatus(.disconnected)
            
            // Start retry process if not manually disconnected
            if !self.isManuallyDisconnected {
                self.retryManager.startRetrying { [weak self] in
                    self?.updateStatus(self?.retryManager.currentStatus ?? .reconnecting(attempt: 0, maxAttempts: 0))
                    self?.connect()
                }
            }
        }
    }
    
    func connect() {
        isManuallyDisconnected = false
        retryManager.stop()
        updateStatus(.connecting)
        socket.connect()
    }
    
    func disconnect() {
        isManuallyDisconnected = true
        retryManager.stop()
        socket.disconnect()
        updateStatus(.disconnected)
    }
    
    private func updateStatus(_ newStatus: ConnectionStatus) {
        DispatchQueue.main.async {
            self.status = newStatus
            self.onStatusChange?(newStatus)
        }
    }
}
```

## 4. Connection Health Monitoring

### 4.1 Heartbeat Mechanism

```swift
class HeartbeatMonitor {
    private let heartbeatInterval: TimeInterval
    private let timeoutInterval: TimeInterval
    private var timer: Timer?
    private var lastHeartbeatResponse: Date?
    private var onTimeout: (() -> Void)?
    
    init(heartbeatInterval: TimeInterval = 30.0, timeoutInterval: TimeInterval = 10.0) {
        self.heartbeatInterval = heartbeatInterval
        self.timeoutInterval = timeoutInterval
    }
    
    func start(onTimeout: @escaping () -> Void) {
        self.onTimeout = onTimeout
        lastHeartbeatResponse = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func receivedHeartbeat() {
        lastHeartbeatResponse = Date()
    }
    
    private func sendHeartbeat() {
        // Send heartbeat to server
        // This would typically emit a socket event
        
        // Check if previous heartbeat timed out
        if let lastResponse = lastHeartbeatResponse,
           Date().timeIntervalSince(lastResponse) > heartbeatInterval + timeoutInterval {
            // Connection is considered dead
            onTimeout?()
        }
    }
}
```

### 4.2 Integration with Socket Manager

```swift
class SocketManager {
    // ... other properties ...
    
    private let heartbeatMonitor: HeartbeatMonitor
    
    init(/* ... */) {
        // ... other initialization ...
        
        self.heartbeatMonitor = HeartbeatMonitor()
        
        setupSocketHandlers()
    }
    
    private func setupSocketHandlers() {
        // ... other handlers ...
        
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self = self else { return }
            
            self.updateStatus(.connected)
            
            // Start heartbeat monitoring
            self.heartbeatMonitor.start { [weak self] in
                // Connection timed out
                self?.socket.disconnect()
                self?.updateStatus(.error(message: "Connection timed out"))
            }
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            // Stop heartbeat monitoring
            self?.heartbeatMonitor.stop()
            
            // ... other disconnect handling ...
        }
        
        // Listen for heartbeat responses
        socket.on("pong") { [weak self] _, _ in
            self?.heartbeatMonitor.receivedHeartbeat()
        }
    }
    
    // Send periodic ping to keep connection alive
    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.socket.emit("ping")
        }
    }
}
```

## 5. Connection Diagnostics

### 5.1 Connection Quality Monitoring

```swift
class ConnectionQualityMonitor {
    enum ConnectionQuality {
        case excellent
        case good
        case fair
        case poor
        case unusable
        
        var description: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            case .unusable: return "Unusable"
            }
        }
    }
    
    private var latencyMeasurements: [TimeInterval] = []
    private var pingTimer: Timer?
    private var onQualityChange: ((ConnectionQuality) -> Void)?
    
    func start(socket: SocketIOClient, onQualityChange: @escaping (ConnectionQuality) -> Void) {
        self.onQualityChange = onQualityChange
        
        // Set up ping-pong for latency measurement
        socket.on("pong") { [weak self] data, _ in
            guard let self = self,
                  let pingData = data.first as? [String: Any],
                  let sentTime = pingData["sent"] as? TimeInterval else {
                return
            }
            
            let latency = Date().timeIntervalSince1970 - sentTime
            self.recordLatency(latency)
        }
        
        // Send pings every 5 seconds
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self, weak socket] _ in
            let pingData: [String: Any] = ["sent": Date().timeIntervalSince1970]
            socket?.emit("ping", pingData)
        }
    }
    
    func stop() {
        pingTimer?.invalidate()
        pingTimer = nil
        latencyMeasurements.removeAll()
    }
    
    private func recordLatency(_ latency: TimeInterval) {
        // Keep last 10 measurements
        latencyMeasurements.append(latency)
        if latencyMeasurements.count > 10 {
            latencyMeasurements.removeFirst()
        }
        
        // Calculate average latency
        let averageLatency = latencyMeasurements.reduce(0, +) / Double(latencyMeasurements.count)
        
        // Determine connection quality
        let quality = determineQuality(from: averageLatency)
        onQualityChange?(quality)
    }
    
    private func determineQuality(from latency: TimeInterval) -> ConnectionQuality {
        switch latency {
        case 0..<0.1:
            return .excellent
        case 0.1..<0.3:
            return .good
        case 0.3..<0.5:
            return .fair
        case 0.5..<1.0:
            return .poor
        default:
            return .unusable
        }
    }
}
```

### 5.2 Diagnostic Tools

```swift
class ConnectionDiagnostics {
    private let socketManager: SocketManager
    
    init(socketManager: SocketManager) {
        self.socketManager = socketManager
    }
    
    func runDiagnostics(completion: @escaping (DiagnosticResult) -> Void) {
        var results = DiagnosticResult()
        
        // Check internet connectivity
        checkInternetConnectivity { isConnected in
            results.internetConnected = isConnected
            
            // Check server reachability
            self.checkServerReachability { isReachable in
                results.serverReachable = isReachable
                
                // Check WebSocket connectivity
                self.checkWebSocketConnectivity { canConnect in
                    results.webSocketConnectable = canConnect
                    
                    // Check authentication
                    self.checkAuthentication { isAuthenticated in
                        results.authenticated = isAuthenticated
                        
                        // Return complete results
                        completion(results)
                    }
                }
            }
        }
    }
    
    private func checkInternetConnectivity(completion: @escaping (Bool) -> Void) {
        // Simple check by trying to reach a reliable host
        let url = URL(string: "https://www.apple.com")!
        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            let isConnected = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
            completion(isConnected)
        }
        task.resume()
    }
    
    private func checkServerReachability(completion: @escaping (Bool) -> Void) {
        // Try to reach the server's health endpoint
        guard let serverURL = socketManager.serverURL else {
            completion(false)
            return
        }
        
        var healthURL = serverURL
        healthURL.appendPathComponent("health")
        
        let task = URLSession.shared.dataTask(with: healthURL) { _, response, error in
            let isReachable = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
            completion(isReachable)
        }
        task.resume()
    }
    
    private func checkWebSocketConnectivity(completion: @escaping (Bool) -> Void) {
        // Try to establish a temporary WebSocket connection
        let tempSocket = socketManager.createTemporarySocket()
        
        var didComplete = false
        
        tempSocket.on(clientEvent: .connect) { _, _ in
            if !didComplete {
                didComplete = true
                tempSocket.disconnect()
                completion(true)
            }
        }
        
        tempSocket.on(clientEvent: .error) { _, _ in
            if !didComplete {
                didComplete = true
                tempSocket.disconnect()
                completion(false)
            }
        }
        
        // Set timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if !didComplete {
                didComplete = true
                tempSocket.disconnect()
                completion(false)
            }
        }
        
        tempSocket.connect()
    }
    
    private func checkAuthentication(completion: @escaping (Bool) -> Void) {
        // Try to access an authenticated endpoint
        socketManager.checkAuthentication(completion: completion)
    }
    
    struct DiagnosticResult {
        var internetConnected = false
        var serverReachable = false
        var webSocketConnectable = false
        var authenticated = false
        
        var summary: String {
            var issues: [String] = []
            
            if !internetConnected {
                issues.append("No internet connection")
            }
            
            if internetConnected && !serverReachable {
                issues.append("Server is unreachable")
            }
            
            if serverReachable && !webSocketConnectable {
                issues.append("WebSocket connection failed")
            }
            
            if webSocketConnectable && !authenticated {
                issues.append("Authentication failed")
            }
            
            if issues.isEmpty {
                return "All systems operational"
            } else {
                return "Issues detected: " + issues.joined(separator: ", ")
            }
        }
    }
}
```

### 5.3 Diagnostic UI

```swift
struct ConnectionDiagnosticsView: View {
    @StateObject private var viewModel = ConnectionDiagnosticsViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connection Diagnostics")
                .font(.headline)
            
            if viewModel.isRunningDiagnostics {
                ProgressView("Running diagnostics...")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    DiagnosticItemView(
                        title: "Internet Connection",
                        status: viewModel.result?.internetConnected ?? false
                    )
                    
                    DiagnosticItemView(
                        title: "Server Reachable",
                        status: viewModel.result?.serverReachable ?? false
                    )
                    
                    DiagnosticItemView(
                        title: "WebSocket Connection",
                        status: viewModel.result?.webSocketConnectable ?? false
                    )
                    
                    DiagnosticItemView(
                        title: "Authentication",
                        status: viewModel.result?.authenticated ?? false
                    )
                }
                
                if let result = viewModel.result {
                    Text(result.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
            
            Button(action: {
                viewModel.runDiagnostics()
            }) {
                Text("Run Diagnostics")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isRunningDiagnostics)
        }
        .padding()
        .frame(width: 300)
    }
}

struct DiagnosticItemView: View {
    let title: String
    let status: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(status ? .green : .red)
        }
    }
}

class ConnectionDiagnosticsViewModel: ObservableObject {
    @Published private(set) var isRunningDiagnostics = false
    @Published private(set) var result: ConnectionDiagnostics.DiagnosticResult?
    
    private let diagnostics: ConnectionDiagnostics
    
    init() {
        // Get socket manager from app delegate or dependency injection
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        self.diagnostics = ConnectionDiagnostics(socketManager: appDelegate.connectionManager.socketManager)
    }
    
    func runDiagnostics() {
        isRunningDiagnostics = true
        result = nil
        
        diagnostics.runDiagnostics { [weak self] result in
            DispatchQueue.main.async {
                self?.result = result
                self?.isRunningDiagnostics = false
            }
        }
    }
}
```

This implementation guide provides a comprehensive approach to backend connection management in the Mac client, covering connection persistence, status indicators, retry mechanisms, and connection diagnostics.