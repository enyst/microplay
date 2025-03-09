# Error States and Recovery for Mac Client

This document outlines the implementation details for handling error states and recovery procedures in the Mac client, including error definitions, user feedback mechanisms, and recovery strategies.

## 1. Error State Definitions

### 1.1 Error Type Hierarchy

```swift
// Base error protocol for app-wide error handling
protocol AppError: Error {
    var title: String { get }
    var message: String { get }
    var code: Int { get }
    var recoveryOptions: [ErrorRecoveryOption] { get }
    var severity: ErrorSeverity { get }
    var isUserVisible: Bool { get }
}

// Error severity levels
enum ErrorSeverity {
    case info      // Informational, doesn't affect functionality
    case warning   // Potential issue, limited functionality impact
    case error     // Significant issue, major functionality affected
    case critical  // Fatal error, application cannot function
}

// Recovery options for errors
struct ErrorRecoveryOption {
    let title: String
    let action: () -> Void
    let isDestructive: Bool
}

// Network-related errors
struct NetworkError: AppError {
    let title: String
    let message: String
    let code: Int
    let recoveryOptions: [ErrorRecoveryOption]
    let severity: ErrorSeverity
    let isUserVisible: Bool
    let underlyingError: Error?
    
    // Common network errors
    static func connectionFailed(error: Error? = nil) -> NetworkError {
        NetworkError(
            title: "Connection Failed",
            message: "Unable to connect to the server. Please check your internet connection and try again.",
            code: 1001,
            recoveryOptions: [
                ErrorRecoveryOption(
                    title: "Retry Connection",
                    action: { NotificationCenter.default.post(name: .retryConnection, object: nil) },
                    isDestructive: false
                ),
                ErrorRecoveryOption(
                    title: "Work Offline",
                    action: { NotificationCenter.default.post(name: .enableOfflineMode, object: nil) },
                    isDestructive: false
                )
            ],
            severity: .error,
            isUserVisible: true,
            underlyingError: error
        )
    }
    
    static func requestTimeout() -> NetworkError {
        NetworkError(
            title: "Request Timeout",
            message: "The server took too long to respond. Please try again later.",
            code: 1002,
            recoveryOptions: [
                ErrorRecoveryOption(
                    title: "Retry",
                    action: { NotificationCenter.default.post(name: .retryLastRequest, object: nil) },
                    isDestructive: false
                )
            ],
            severity: .warning,
            isUserVisible: true,
            underlyingError: nil
        )
    }
    
    static func serverError(statusCode: Int, message: String? = nil) -> NetworkError {
        NetworkError(
            title: "Server Error",
            message: message ?? "The server encountered an error (Status \(statusCode)). Please try again later.",
            code: 1003,
            recoveryOptions: [
                ErrorRecoveryOption(
                    title: "Retry",
                    action: { NotificationCenter.default.post(name: .retryLastRequest, object: nil) },
                    isDestructive: false
                )
            ],
            severity: .error,
            isUserVisible: true,
            underlyingError: nil
        )
    }
}

// File system errors
struct FileSystemError: AppError {
    let title: String
    let message: String
    let code: Int
    let recoveryOptions: [ErrorRecoveryOption]
    let severity: ErrorSeverity
    let isUserVisible: Bool
    let filePath: String?
    
    static func accessDenied(path: String) -> FileSystemError {
        FileSystemError(
            title: "Access Denied",
            message: "You don't have permission to access this file or directory: \(path)",
            code: 2001,
            recoveryOptions: [
                ErrorRecoveryOption(
                    title: "Request Permission",
                    action: { NotificationCenter.default.post(name: .requestFilePermission, object: path) },
                    isDestructive: false
                )
            ],
            severity: .error,
            isUserVisible: true,
            filePath: path
        )
    }
    
    static func fileNotFound(path: String) -> FileSystemError {
        FileSystemError(
            title: "File Not Found",
            message: "The file or directory could not be found: \(path)",
            code: 2002,
            recoveryOptions: [
                ErrorRecoveryOption(
                    title: "Refresh",
                    action: { NotificationCenter.default.post(name: .refreshFileExplorer, object: nil) },
                    isDestructive: false
                )
            ],
            severity: .warning,
            isUserVisible: true,
            filePath: path
        )
    }
    
    static func fileSaveError(path: String, error: Error? = nil) -> FileSystemError {
        FileSystemError(
            title: "Save Failed",
            message: "Failed to save file: \(path)",
            code: 2003,
            recoveryOptions: [
                ErrorRecoveryOption(
                    title: "Retry Save",
                    action: { NotificationCenter.default.post(name: .retrySaveFile, object: path) },
                    isDestructive: false
                ),
                ErrorRecoveryOption(
                    title: "Save As...",
                    action: { NotificationCenter.default.post(name: .showSaveAsDialog, object: path) },
                    isDestructive: false
                )
            ],
            severity: .error,
            isUserVisible: true,
            filePath: path
        )
    }
}

// State management errors
struct StateError: AppError {
    let title: String
    let message: String
    let code: Int
    let recoveryOptions: [ErrorRecoveryOption]
    let severity: ErrorSeverity
    let isUserVisible: Bool
    
    static func syncFailed() -> StateError {
        StateError(
            title: "Sync Failed",
            message: "Failed to synchronize with the server. Some changes may not be saved.",
            code: 3001,
            recoveryOptions: [
                ErrorRecoveryOption(
                    title: "Retry Sync",
                    action: { NotificationCenter.default.post(name: .retryStateSync, object: nil) },
                    isDestructive: false
                ),
                ErrorRecoveryOption(
                    title: "Work Offline",
                    action: { NotificationCenter.default.post(name: .enableOfflineMode, object: nil) },
                    isDestructive: false
                )
            ],
            severity: .warning,
            isUserVisible: true
        )
    }
    
    static func stateCorrupted() -> StateError {
        StateError(
            title: "State Corrupted",
            message: "The application state is corrupted. The application needs to be reset.",
            code: 3002,
            recoveryOptions: [
                ErrorRecoveryOption(
                    title: "Reset Application",
                    action: { NotificationCenter.default.post(name: .resetApplicationState, object: nil) },
                    isDestructive: true
                )
            ],
            severity: .critical,
            isUserVisible: true
        )
    }
    
    static func conflictDetected() -> StateError {
        StateError(
            title: "Sync Conflict",
            message: "There is a conflict between your local changes and the server. Please choose how to resolve it.",
            code: 3003,
            recoveryOptions: [
                ErrorRecoveryOption(
                    title: "Use Server Version",
                    action: { NotificationCenter.default.post(name: .resolveConflictWithServer, object: nil) },
                    isDestructive: false
                ),
                ErrorRecoveryOption(
                    title: "Keep My Changes",
                    action: { NotificationCenter.default.post(name: .resolveConflictWithLocal, object: nil) },
                    isDestructive: false
                ),
                ErrorRecoveryOption(
                    title: "Merge Changes",
                    action: { NotificationCenter.default.post(name: .resolveConflictWithMerge, object: nil) },
                    isDestructive: false
                )
            ],
            severity: .warning,
            isUserVisible: true
        )
    }
}

// Authentication errors
struct AuthError: AppError {
    let title: String
    let message: String
    let code: Int
    let recoveryOptions: [ErrorRecoveryOption]
    let severity: ErrorSeverity
    let isUserVisible: Bool
    
    static func unauthorized() -> AuthError {
        AuthError(
            title: "Authentication Required",
            message: "Your session has expired. Please sign in again.",
            code: 4001,
            recoveryOptions: [
                ErrorRecoveryOption(
                    title: "Sign In",
                    action: { NotificationCenter.default.post(name: .showSignInPrompt, object: nil) },
                    isDestructive: false
                )
            ],
            severity: .error,
            isUserVisible: true
        )
    }
    
    static func tokenExpired() -> AuthError {
        AuthError(
            title: "Session Expired",
            message: "Your session has expired. Please sign in again to continue.",
            code: 4002,
            recoveryOptions: [
                ErrorRecoveryOption(
                    title: "Sign In",
                    action: { NotificationCenter.default.post(name: .showSignInPrompt, object: nil) },
                    isDestructive: false
                )
            ],
            severity: .warning,
            isUserVisible: true
        )
    }
}

// Application errors
struct ApplicationError: AppError {
    let title: String
    let message: String
    let code: Int
    let recoveryOptions: [ErrorRecoveryOption]
    let severity: ErrorSeverity
    let isUserVisible: Bool
    
    static func unexpectedError(error: Error? = nil) -> ApplicationError {
        ApplicationError(
            title: "Unexpected Error",
            message: "An unexpected error occurred. Please try again or restart the application.",
            code: 5001,
            recoveryOptions: [
                ErrorRecoveryOption(
                    title: "Restart Application",
                    action: { NotificationCenter.default.post(name: .restartApplication, object: nil) },
                    isDestructive: false
                )
            ],
            severity: .error,
            isUserVisible: true
        )
    }
    
    static func outOfMemory() -> ApplicationError {
        ApplicationError(
            title: "Out of Memory",
            message: "The application is running low on memory. Please save your work and restart the application.",
            code: 5002,
            recoveryOptions: [
                ErrorRecoveryOption(
                    title: "Save and Restart",
                    action: { NotificationCenter.default.post(name: .saveAndRestart, object: nil) },
                    isDestructive: false
                )
            ],
            severity: .critical,
            isUserVisible: true
        )
    }
}
```

### 1.2 Error Manager

```swift
class ErrorManager {
    static let shared = ErrorManager()
    
    private init() {}
    
    // Current active errors
    private var activeErrors: [UUID: AppError] = [:]
    
    // Error handlers by type
    private var errorHandlers: [String: (AppError) -> Void] = [:]
    
    // Report an error
    @discardableResult
    func reportError(_ error: AppError) -> UUID {
        let errorId = UUID()
        activeErrors[errorId] = error
        
        // Log the error
        logError(error)
        
        // Handle based on error type
        let errorType = String(describing: type(of: error))
        if let handler = errorHandlers[errorType] {
            handler(error)
        }
        
        // Show user-visible errors
        if error.isUserVisible {
            showErrorToUser(error, id: errorId)
        }
        
        return errorId
    }
    
    // Resolve an error
    func resolveError(id: UUID) {
        activeErrors.removeValue(forKey: id)
        
        // Dismiss error UI if needed
        NotificationCenter.default.post(name: .dismissError, object: id)
    }
    
    // Register error handler
    func registerHandler(for errorType: AppError.Type, handler: @escaping (AppError) -> Void) {
        let typeName = String(describing: errorType)
        errorHandlers[typeName] = handler
    }
    
    // Log error
    private func logError(_ error: AppError) {
        // Log to system log
        os_log(
            "Error [%{public}d]: %{public}@ - %{public}@",
            log: OSLog(subsystem: "com.openhands.mac", category: "Errors"),
            type: osLogType(for: error.severity),
            error.code,
            error.title,
            error.message
        )
        
        // Additional logging for critical errors
        if error.severity == .critical {
            // Could send to crash reporting service
        }
    }
    
    // Map severity to OSLogType
    private func osLogType(for severity: ErrorSeverity) -> OSLogType {
        switch severity {
        case .info:
            return .info
        case .warning:
            return .debug
        case .error:
            return .error
        case .critical:
            return .fault
        }
    }
    
    // Show error to user
    private func showErrorToUser(_ error: AppError, id: UUID) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .showError,
                object: ErrorDisplay(error: error, id: id)
            )
        }
    }
    
    // Get all active errors
    func getActiveErrors() -> [UUID: AppError] {
        return activeErrors
    }
}

// Error display model for UI
struct ErrorDisplay {
    let error: AppError
    let id: UUID
}

// Notification names
extension Notification.Name {
    static let showError = Notification.Name("com.openhands.mac.showError")
    static let dismissError = Notification.Name("com.openhands.mac.dismissError")
    static let retryConnection = Notification.Name("com.openhands.mac.retryConnection")
    static let enableOfflineMode = Notification.Name("com.openhands.mac.enableOfflineMode")
    static let retryLastRequest = Notification.Name("com.openhands.mac.retryLastRequest")
    static let requestFilePermission = Notification.Name("com.openhands.mac.requestFilePermission")
    static let refreshFileExplorer = Notification.Name("com.openhands.mac.refreshFileExplorer")
    static let retrySaveFile = Notification.Name("com.openhands.mac.retrySaveFile")
    static let showSaveAsDialog = Notification.Name("com.openhands.mac.showSaveAsDialog")
    static let retryStateSync = Notification.Name("com.openhands.mac.retryStateSync")
    static let resetApplicationState = Notification.Name("com.openhands.mac.resetApplicationState")
    static let resolveConflictWithServer = Notification.Name("com.openhands.mac.resolveConflictWithServer")
    static let resolveConflictWithLocal = Notification.Name("com.openhands.mac.resolveConflictWithLocal")
    static let resolveConflictWithMerge = Notification.Name("com.openhands.mac.resolveConflictWithMerge")
    static let showSignInPrompt = Notification.Name("com.openhands.mac.showSignInPrompt")
    static let restartApplication = Notification.Name("com.openhands.mac.restartApplication")
    static let saveAndRestart = Notification.Name("com.openhands.mac.saveAndRestart")
}
```

## 2. User Feedback Mechanisms

### 2.1 Error Alert View

```swift
struct ErrorAlertView: View {
    let errorDisplay: ErrorDisplay
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                    .font(.title)
                
                Text(errorDisplay.error.title)
                    .font(.headline)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Message
            Text(errorDisplay.error.message)
                .font(.body)
                .foregroundColor(.secondary)
            
            // Recovery options
            if !errorDisplay.error.recoveryOptions.isEmpty {
                HStack {
                    ForEach(errorDisplay.error.recoveryOptions, id: \.title) { option in
                        Button(action: {
                            option.action()
                            onDismiss()
                        }) {
                            Text(option.title)
                                .foregroundColor(option.isDestructive ? .red : .accentColor)
                        }
                        .buttonStyle(.bordered)
                        
                        if option != errorDisplay.error.recoveryOptions.last {
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private var severityIcon: String {
        switch errorDisplay.error.severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error, .critical:
            return "exclamationmark.circle"
        }
    }
    
    private var severityColor: Color {
        switch errorDisplay.error.severity {
        case .info:
            return .blue
        case .warning:
            return .yellow
        case .error:
            return .orange
        case .critical:
            return .red
        }
    }
}
```

### 2.2 Error Toast View

```swift
struct ErrorToastView: View {
    let errorDisplay: ErrorDisplay
    let onDismiss: () -> Void
    
    @State private var isShowing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: severityIcon)
                .foregroundColor(severityColor)
                .font(.title3)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(errorDisplay.error.title)
                    .font(.headline)
                
                Text(errorDisplay.error.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .opacity(isShowing ? 1 : 0)
        .offset(y: isShowing ? 0 : -20)
        .onAppear {
            withAnimation(.spring()) {
                isShowing = true
            }
            
            // Auto-dismiss non-critical errors after a delay
            if errorDisplay.error.severity != .critical {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation(.spring()) {
                        isShowing = false
                    }
                    
                    // Dismiss after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private var severityIcon: String {
        switch errorDisplay.error.severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error, .critical:
            return "exclamationmark.circle"
        }
    }
    
    private var severityColor: Color {
        switch errorDisplay.error.severity {
        case .info:
            return .blue
        case .warning:
            return .yellow
        case .error:
            return .orange
        case .critical:
            return .red
        }
    }
}
```

### 2.3 Error Manager View

```swift
struct ErrorManagerView: View {
    @StateObject private var viewModel = ErrorManagerViewModel()
    
    var body: some View {
        ZStack {
            // Main content
            Color.clear
            
            // Error toasts
            VStack {
                ForEach(viewModel.toastErrors, id: \.id) { errorDisplay in
                    ErrorToastView(errorDisplay: errorDisplay) {
                        viewModel.dismissError(id: errorDisplay.id)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }
                
                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal)
            
            // Modal error alerts
            if let modalError = viewModel.modalError {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        // Don't dismiss critical errors on outside tap
                        if modalError.error.severity != .critical {
                            viewModel.dismissModalError()
                        }
                    }
                
                ErrorAlertView(errorDisplay: modalError) {
                    viewModel.dismissModalError()
                }
                .frame(width: 400)
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.spring(), value: viewModel.toastErrors.count)
        .animation(.spring(), value: viewModel.modalError != nil)
    }
}

class ErrorManagerViewModel: ObservableObject {
    @Published private(set) var toastErrors: [ErrorDisplay] = []
    @Published private(set) var modalError: ErrorDisplay?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to error notifications
        NotificationCenter.default.publisher(for: .showError)
            .compactMap { $0.object as? ErrorDisplay }
            .receive(on: RunLoop.main)
            .sink { [weak self] errorDisplay in
                self?.handleNewError(errorDisplay)
            }
            .store(in: &cancellables)
        
        // Subscribe to dismiss notifications
        NotificationCenter.default.publisher(for: .dismissError)
            .compactMap { $0.object as? UUID }
            .receive(on: RunLoop.main)
            .sink { [weak self] errorId in
                self?.dismissError(id: errorId)
            }
            .store(in: &cancellables)
    }
    
    private func handleNewError(_ errorDisplay: ErrorDisplay) {
        // Critical and error severity errors show as modal alerts
        if errorDisplay.error.severity == .critical || errorDisplay.error.severity == .error {
            modalError = errorDisplay
        } else {
            // Info and warning severity errors show as toasts
            toastErrors.append(errorDisplay)
            
            // Limit number of toast errors
            if toastErrors.count > 3 {
                toastErrors.removeFirst()
            }
        }
    }
    
    func dismissError(id: UUID) {
        // Remove from toast errors
        toastErrors.removeAll { $0.id == id }
        
        // Clear modal error if it matches
        if modalError?.id == id {
            modalError = nil
        }
        
        // Resolve in error manager
        ErrorManager.shared.resolveError(id: id)
    }
    
    func dismissModalError() {
        if let id = modalError?.id {
            dismissError(id: id)
        }
    }
}
```

### 2.4 Status Bar Error Indicator

```swift
struct StatusBarErrorIndicator: View {
    @ObservedObject private var viewModel = StatusBarErrorViewModel()
    
    var body: some View {
        HStack(spacing: 4) {
            if viewModel.hasActiveErrors {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(viewModel.severityColor)
                    .font(.caption)
                
                Text("\(viewModel.errorCount)")
                    .font(.caption)
                    .foregroundColor(viewModel.severityColor)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(viewModel.hasActiveErrors ? viewModel.severityColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onTapGesture {
            viewModel.showErrorList()
        }
    }
}

class StatusBarErrorViewModel: ObservableObject {
    @Published private(set) var hasActiveErrors = false
    @Published private(set) var errorCount = 0
    @Published private(set) var highestSeverity: ErrorSeverity = .info
    
    private var timer: Timer?
    
    init() {
        // Start periodic check for errors
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateErrorStatus()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func updateErrorStatus() {
        let activeErrors = ErrorManager.shared.getActiveErrors()
        
        DispatchQueue.main.async {
            self.errorCount = activeErrors.count
            self.hasActiveErrors = self.errorCount > 0
            
            // Determine highest severity
            if self.hasActiveErrors {
                self.highestSeverity = activeErrors.values.map { $0.severity }.max(by: { a, b in
                    self.severityRank(a) < self.severityRank(b)
                }) ?? .info
            }
        }
    }
    
    private func severityRank(_ severity: ErrorSeverity) -> Int {
        switch severity {
        case .info: return 0
        case .warning: return 1
        case .error: return 2
        case .critical: return 3
        }
    }
    
    var severityColor: Color {
        switch highestSeverity {
        case .info: return .blue
        case .warning: return .yellow
        case .error: return .orange
        case .critical: return .red
        }
    }
    
    func showErrorList() {
        NotificationCenter.default.post(name: .showErrorList, object: nil)
    }
}

extension Notification.Name {
    static let showErrorList = Notification.Name("com.openhands.mac.showErrorList")
}
```

### 2.5 Error List View

```swift
struct ErrorListView: View {
    @ObservedObject private var viewModel = ErrorListViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Error Log")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            
            // Error list
            if viewModel.errors.isEmpty {
                VStack {
                    Spacer()
                    
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    
                    Text("No Active Errors")
                        .font(.headline)
                        .padding(.top)
                    
                    Spacer()
                }
            } else {
                List {
                    ForEach(viewModel.errors, id: \.id) { errorItem in
                        ErrorListItemView(errorItem: errorItem) {
                            viewModel.dismissError(id: errorItem.id)
                        }
                    }
                }
            }
            
            // Footer
            HStack {
                Button(action: {
                    viewModel.clearAllErrors()
                }) {
                    Text("Clear All")
                }
                .disabled(viewModel.errors.isEmpty)
                
                Spacer()
                
                Button(action: {
                    viewModel.exportErrorLog()
                }) {
                    Text("Export Log")
                }
                .disabled(viewModel.errors.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

struct ErrorListItemView: View {
    let errorItem: ErrorListItem
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                
                Text(errorItem.error.title)
                    .font(.headline)
                
                Spacer()
                
                Text(errorItem.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Text(errorItem.error.message)
                .font(.body)
                .foregroundColor(.secondary)
            
            if !errorItem.error.recoveryOptions.isEmpty {
                HStack {
                    ForEach(errorItem.error.recoveryOptions, id: \.title) { option in
                        Button(action: {
                            option.action()
                            onDismiss()
                        }) {
                            Text(option.title)
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        
                        if option != errorItem.error.recoveryOptions.last {
                            Spacer()
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var severityIcon: String {
        switch errorItem.error.severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "exclamationmark.circle"
        case .critical:
            return "exclamationmark.octagon"
        }
    }
    
    private var severityColor: Color {
        switch errorItem.error.severity {
        case .info:
            return .blue
        case .warning:
            return .yellow
        case .error:
            return .orange
        case .critical:
            return .red
        }
    }
}

struct ErrorListItem {
    let id: UUID
    let error: AppError
    let timestamp: Date
}

class ErrorListViewModel: ObservableObject {
    @Published private(set) var errors: [ErrorListItem] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load initial errors
        loadActiveErrors()
        
        // Subscribe to error notifications
        NotificationCenter.default.publisher(for: .showError)
            .compactMap { $0.object as? ErrorDisplay }
            .receive(on: RunLoop.main)
            .sink { [weak self] errorDisplay in
                self?.addError(errorDisplay)
            }
            .store(in: &cancellables)
        
        // Subscribe to dismiss notifications
        NotificationCenter.default.publisher(for: .dismissError)
            .compactMap { $0.object as? UUID }
            .receive(on: RunLoop.main)
            .sink { [weak self] errorId in
                self?.dismissError(id: errorId)
            }
            .store(in: &cancellables)
    }
    
    private func loadActiveErrors() {
        let activeErrors = ErrorManager.shared.getActiveErrors()
        
        errors = activeErrors.map { (id, error) in
            ErrorListItem(id: id, error: error, timestamp: Date())
        }
    }
    
    private func addError(_ errorDisplay: ErrorDisplay) {
        let errorItem = ErrorListItem(
            id: errorDisplay.id,
            error: errorDisplay.error,
            timestamp: Date()
        )
        
        errors.append(errorItem)
        
        // Sort by severity and timestamp
        errors.sort { first, second in
            if first.error.severity != second.error.severity {
                return severityRank(first.error.severity) > severityRank(second.error.severity)
            }
            return first.timestamp > second.timestamp
        }
    }
    
    func dismissError(id: UUID) {
        errors.removeAll { $0.id == id }
        ErrorManager.shared.resolveError(id: id)
    }
    
    func clearAllErrors() {
        let errorIds = errors.map { $0.id }
        for id in errorIds {
            ErrorManager.shared.resolveError(id: id)
        }
        errors.removeAll()
    }
    
    func exportErrorLog() {
        // Create error log content
        var logContent = "OpenHands Mac Client Error Log\n"
        logContent += "Generated: \(Date())\n\n"
        
        for errorItem in errors {
            logContent += "[\(errorItem.timestamp)] [\(errorItem.error.severity)] \(errorItem.error.title)\n"
            logContent += "Message: \(errorItem.error.message)\n"
            logContent += "Code: \(errorItem.error.code)\n"
            logContent += "Recovery Options: \(errorItem.error.recoveryOptions.map { $0.title }.joined(separator: ", "))\n"
            logContent += "\n"
        }
        
        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "OpenHandsErrorLog_\(Date().timeIntervalSince1970).txt"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try logContent.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    // Ironically, report an error about failing to save the error log
                    ErrorManager.shared.reportError(
                        FileSystemError.fileSaveError(path: url.path, error: error)
                    )
                }
            }
        }
    }
    
    private func severityRank(_ severity: ErrorSeverity) -> Int {
        switch severity {
        case .info: return 0
        case .warning: return 1
        case .error: return 2
        case .critical: return 3
        }
    }
}
```

## 3. Recovery Procedures

### 3.1 Network Recovery

```swift
class NetworkRecoveryManager {
    private let socketManager: SocketManager
    private let retryManager: RetryManager
    
    init(socketManager: SocketManager) {
        self.socketManager = socketManager
        self.retryManager = RetryManager()
        
        setupNotificationHandlers()
    }
    
    private func setupNotificationHandlers() {
        // Handle retry connection requests
        NotificationCenter.default.addObserver(
            forName: .retryConnection,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.retryConnection()
        }
        
        // Handle retry last request
        NotificationCenter.default.addObserver(
            forName: .retryLastRequest,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.retryLastRequest()
        }
        
        // Handle enable offline mode
        NotificationCenter.default.addObserver(
            forName: .enableOfflineMode,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.enableOfflineMode()
        }
    }
    
    // Retry connection with exponential backoff
    func retryConnection() {
        retryManager.startRetrying { [weak self] in
            self?.socketManager.connect()
        }
    }
    
    // Retry last request
    func retryLastRequest() {
        socketManager.retryLastRequest()
    }
    
    // Enable offline mode
    func enableOfflineMode() {
        NotificationCenter.default.post(name: .offlineModeEnabled, object: nil)
    }
    
    // Run network diagnostics
    func runDiagnostics(completion: @escaping (NetworkDiagnosticResult) -> Void) {
        let diagnostics = NetworkDiagnostics(socketManager: socketManager)
        diagnostics.runDiagnostics(completion: completion)
    }
}

// Network diagnostics
class NetworkDiagnostics {
    private let socketManager: SocketManager
    
    init(socketManager: SocketManager) {
        self.socketManager = socketManager
    }
    
    func runDiagnostics(completion: @escaping (NetworkDiagnosticResult) -> Void) {
        var result = NetworkDiagnosticResult()
        
        // Check internet connectivity
        checkInternetConnectivity { isConnected in
            result.internetConnected = isConnected
            
            // If no internet, return early
            guard isConnected else {
                completion(result)
                return
            }
            
            // Check server reachability
            self.checkServerReachability { isReachable in
                result.serverReachable = isReachable
                
                // If server not reachable, return early
                guard isReachable else {
                    completion(result)
                    return
                }
                
                // Check WebSocket connectivity
                self.checkWebSocketConnectivity { canConnect in
                    result.webSocketConnectable = canConnect
                    
                    // If WebSocket can't connect, return early
                    guard canConnect else {
                        completion(result)
                        return
                    }
                    
                    // Check authentication
                    self.checkAuthentication { isAuthenticated in
                        result.authenticated = isAuthenticated
                        completion(result)
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
}

struct NetworkDiagnosticResult {
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

extension Notification.Name {
    static let offlineModeEnabled = Notification.Name("com.openhands.mac.offlineModeEnabled")
}
```

### 3.2 File System Recovery

```swift
class FileSystemRecoveryManager {
    private let fileManager = FileManager.default
    
    init() {
        setupNotificationHandlers()
    }
    
    private func setupNotificationHandlers() {
        // Handle request file permission
        NotificationCenter.default.addObserver(
            forName: .requestFilePermission,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let path = notification.object as? String {
                self?.requestFilePermission(path: path)
            }
        }
        
        // Handle refresh file explorer
        NotificationCenter.default.addObserver(
            forName: .refreshFileExplorer,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshFileExplorer()
        }
        
        // Handle retry save file
        NotificationCenter.default.addObserver(
            forName: .retrySaveFile,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let path = notification.object as? String {
                self?.retrySaveFile(path: path)
            }
        }
        
        // Handle show save as dialog
        NotificationCenter.default.addObserver(
            forName: .showSaveAsDialog,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let path = notification.object as? String {
                self?.showSaveAsDialog(path: path)
            }
        }
    }
    
    // Request file permission
    func requestFilePermission(path: String) {
        // For macOS, we need to use the open panel to get permission
        let openPanel = NSOpenPanel()
        openPanel.message = "Please grant access to this file or directory"
        openPanel.prompt = "Grant Access"
        
        // Try to set the initial directory to the parent folder
        let url = URL(fileURLWithPath: path)
        openPanel.directoryURL = url.deletingLastPathComponent()
        
        openPanel.begin { result in
            if result == .OK {
                // Permission granted, notify file explorer to refresh
                NotificationCenter.default.post(name: .refreshFileExplorer, object: nil)
            }
        }
    }
    
    // Refresh file explorer
    func refreshFileExplorer() {
        NotificationCenter.default.post(name: .fileExplorerRefresh, object: nil)
    }
    
    // Retry save file
    func retrySaveFile(path: String) {
        NotificationCenter.default.post(name: .retrySaveFileContent, object: path)
    }
    
    // Show save as dialog
    func showSaveAsDialog(path: String) {
        let savePanel = NSSavePanel()
        
        // Set initial directory and filename
        let url = URL(fileURLWithPath: path)
        savePanel.directoryURL = url.deletingLastPathComponent()
        savePanel.nameFieldStringValue = url.lastPathComponent
        
        savePanel.begin { result in
            if result == .OK, let newURL = savePanel.url {
                // Notify with new path
                NotificationCenter.default.post(
                    name: .saveFileAs,
                    object: [
                        "originalPath": path,
                        "newPath": newURL.path
                    ]
                )
            }
        }
    }
    
    // Check if file exists
    func fileExists(at path: String) -> Bool {
        return fileManager.fileExists(atPath: path)
    }
    
    // Create backup of file
    func createBackup(of path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).backup")
        
        do {
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            
            try fileManager.copyItem(at: url, to: backupURL)
            return backupURL.path
        } catch {
            print("Failed to create backup: \(error)")
            return nil
        }
    }
    
    // Restore from backup
    func restoreFromBackup(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).backup")
        
        guard fileManager.fileExists(atPath: backupURL.path) else {
            return false
        }
        
        do {
            if fileManager.fileExists(atPath: path) {
                try fileManager.removeItem(at: url)
            }
            
            try fileManager.copyItem(at: backupURL, to: url)
            return true
        } catch {
            print("Failed to restore from backup: \(error)")
            return false
        }
    }
}

extension Notification.Name {
    static let fileExplorerRefresh = Notification.Name("com.openhands.mac.fileExplorerRefresh")
    static let retrySaveFileContent = Notification.Name("com.openhands.mac.retrySaveFileContent")
    static let saveFileAs = Notification.Name("com.openhands.mac.saveFileAs")
}
```

### 3.3 State Recovery

```swift
class StateRecoveryManager {
    private let stateStore: StateStore
    private let statePersistenceManager: StatePersistenceManager
    
    init(stateStore: StateStore, statePersistenceManager: StatePersistenceManager) {
        self.stateStore = stateStore
        self.statePersistenceManager = statePersistenceManager
        
        setupNotificationHandlers()
    }
    
    private func setupNotificationHandlers() {
        // Handle retry state sync
        NotificationCenter.default.addObserver(
            forName: .retryStateSync,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.retryStateSync()
        }
        
        // Handle reset application state
        NotificationCenter.default.addObserver(
            forName: .resetApplicationState,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetApplicationState()
        }
        
        // Handle conflict resolution
        NotificationCenter.default.addObserver(
            forName: .resolveConflictWithServer,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resolveConflict(strategy: .serverWins)
        }
        
        NotificationCenter.default.addObserver(
            forName: .resolveConflictWithLocal,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resolveConflict(strategy: .clientWins)
        }
        
        NotificationCenter.default.addObserver(
            forName: .resolveConflictWithMerge,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resolveConflict(strategy: .merge)
        }
    }
    
    // Retry state sync
    func retryStateSync() {
        NotificationCenter.default.post(name: .forceSyncState, object: nil)
    }
    
    // Reset application state
    func resetApplicationState() {
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Reset Application State"
        alert.informativeText = "This will reset the application to its default state. All unsaved data will be lost. Are you sure you want to continue?"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Create backup before resetting
            createStateBackup()
            
            // Clear state
            statePersistenceManager.clearState()
            
            // Restart application
            restartApplication()
        }
    }
    
    // Create backup of current state
    func createStateBackup() {
        guard let state = statePersistenceManager.loadState() else {
            return
        }
        
        // Save backup with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        statePersistenceManager.saveStateBackup(state, name: "backup_\(timestamp)")
    }
    
    // Restore from backup
    func restoreFromBackup(name: String) {
        guard let backupState = statePersistenceManager.loadStateBackup(name: name) else {
            return
        }
        
        // Apply backup state
        stateStore.updateState { _ in
            return backupState
        }
        
        // Save restored state
        statePersistenceManager.saveState(backupState)
    }
    
    // Resolve conflict
    func resolveConflict(strategy: ConflictResolutionStrategy) {
        NotificationCenter.default.post(name: .resolveStateConflict, object: strategy)
    }
    
    // Restart application
    private func restartApplication() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", Bundle.main.bundlePath]
        
        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            print("Failed to restart application: \(error)")
        }
    }
}

extension Notification.Name {
    static let forceSyncState = Notification.Name("com.openhands.mac.forceSyncState")
    static let resolveStateConflict = Notification.Name("com.openhands.mac.resolveStateConflict")
}

// Extended StatePersistenceManager for backups
extension StatePersistenceManager {
    func saveStateBackup(_ state: AppState, name: String) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let backupsDirectory = documentsDirectory.appendingPathComponent("backups")
        
        // Create backups directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: backupsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create backups directory: \(error)")
                return
            }
        }
        
        let backupURL = backupsDirectory.appendingPathComponent("\(name).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(state)
            try data.write(to: backupURL)
        } catch {
            print("Error saving state backup: \(error)")
        }
    }
    
    func loadStateBackup(name: String) -> AppState? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let backupURL = documentsDirectory
            .appendingPathComponent("backups")
            .appendingPathComponent("\(name).json")
        
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: backupURL)
            let decoder = JSONDecoder()
            return try decoder.decode(AppState.self, from: data)
        } catch {
            print("Error loading state backup: \(error)")
            return nil
        }
    }
    
    func listStateBackups() -> [String] {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        
        let backupsDirectory = documentsDirectory.appendingPathComponent("backups")
        
        guard FileManager.default.fileExists(atPath: backupsDirectory.path) else {
            return []
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: nil)
            return fileURLs
                .filter { $0.pathExtension == "json" }
                .map { $0.deletingPathExtension().lastPathComponent }
        } catch {
            print("Error listing state backups: \(error)")
            return []
        }
    }
}
```

### 3.4 Authentication Recovery

```swift
class AuthRecoveryManager {
    private let authManager: AuthManager
    
    init(authManager: AuthManager) {
        self.authManager = authManager
        
        setupNotificationHandlers()
    }
    
    private func setupNotificationHandlers() {
        // Handle show sign in prompt
        NotificationCenter.default.addObserver(
            forName: .showSignInPrompt,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showSignInPrompt()
        }
    }
    
    // Show sign in prompt
    func showSignInPrompt() {
        // Create sign in view controller
        let signInViewController = SignInViewController(authManager: authManager)
        
        // Present as sheet
        if let window = NSApp.keyWindow {
            window.contentViewController?.presentAsSheet(signInViewController)
        }
    }
    
    // Refresh authentication token
    func refreshAuthToken(completion: @escaping (Bool) -> Void) {
        authManager.refreshToken { result in
            switch result {
            case .success:
                completion(true)
            case .failure:
                // Token refresh failed, show sign in prompt
                self.showSignInPrompt()
                completion(false)
            }
        }
    }
}

// Sign In View Controller
class SignInViewController: NSViewController {
    private let authManager: AuthManager
    
    private let emailTextField = NSTextField()
    private let passwordTextField = NSSecureTextField()
    private let signInButton = NSButton(title: "Sign In", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private let errorLabel = NSTextField(labelWithString: "")
    
    init(authManager: AuthManager) {
        self.authManager = authManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSView()
        view.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        
        setupUI()
    }
    
    private func setupUI() {
        // Email field
        emailTextField.placeholderString = "Email"
        emailTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emailTextField)
        
        // Password field
        passwordTextField.placeholderString = "Password"
        passwordTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(passwordTextField)
        
        // Error label
        errorLabel.textColor = .systemRed
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorLabel)
        
        // Sign in button
        signInButton.bezelStyle = .rounded
        signInButton.keyEquivalent = "\r"
        signInButton.target = self
        signInButton.action = #selector(signInTapped)
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(signInButton)
        
        // Cancel button
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            emailTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            emailTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            emailTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 10),
            passwordTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            passwordTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            errorLabel.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 10),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.widthAnchor.constraint(equalToConstant: 100),
            
            signInButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            signInButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            signInButton.widthAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    @objc private func signInTapped() {
        guard let email = emailTextField.stringValue.nilIfEmpty,
              let password = passwordTextField.stringValue.nilIfEmpty else {
            showError("Please enter email and password")
            return
        }
        
        // Disable UI during sign in
        setUIEnabled(false)
        
        // Attempt sign in
        authManager.signIn(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.setUIEnabled(true)
                
                switch result {
                case .success:
                    // Sign in successful, dismiss
                    self?.dismiss(nil)
                    
                    // Notify that authentication is restored
                    NotificationCenter.default.post(name: .authenticationRestored, object: nil)
                    
                case .failure(let error):
                    // Show error
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func cancelTapped() {
        dismiss(nil)
    }
    
    private func showError(_ message: String) {
        errorLabel.stringValue = message
        errorLabel.isHidden = false
    }
    
    private func setUIEnabled(_ enabled: Bool) {
        emailTextField.isEnabled = enabled
        passwordTextField.isEnabled = enabled
        signInButton.isEnabled = enabled
        cancelButton.isEnabled = enabled
    }
}

extension String {
    var nilIfEmpty: String? {
        return self.isEmpty ? nil : self
    }
}

extension Notification.Name {
    static let authenticationRestored = Notification.Name("com.openhands.mac.authenticationRestored")
}
```

### 3.5 Application Recovery

```swift
class ApplicationRecoveryManager {
    init() {
        setupNotificationHandlers()
    }
    
    private func setupNotificationHandlers() {
        // Handle restart application
        NotificationCenter.default.addObserver(
            forName: .restartApplication,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartApplication()
        }
        
        // Handle save and restart
        NotificationCenter.default.addObserver(
            forName: .saveAndRestart,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveAndRestart()
        }
    }
    
    // Restart application
    func restartApplication() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", Bundle.main.bundlePath]
        
        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            print("Failed to restart application: \(error)")
        }
    }
    
    // Save and restart
    func saveAndRestart() {
        // Notify all components to save their state
        NotificationCenter.default.post(name: .saveAllState, object: nil)
        
        // Wait a moment for saves to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.restartApplication()
        }
    }
    
    // Check for application updates
    func checkForUpdates(completion: @escaping (Bool) -> Void) {
        // Implementation would depend on update mechanism
        // For example, using Sparkle framework
        
        // Placeholder implementation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(false)
        }
    }
    
    // Install update
    func installUpdate() {
        // Implementation would depend on update mechanism
    }
    
    // Check system requirements
    func checkSystemRequirements() -> Bool {
        // Check macOS version
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let isSupported = osVersion.majorVersion >= 11
        
        // Check available disk space
        let availableDiskSpace = getAvailableDiskSpace()
        let hasEnoughSpace = availableDiskSpace > 100_000_000 // 100 MB
        
        return isSupported && hasEnoughSpace
    }
    
    // Get available disk space
    private func getAvailableDiskSpace() -> Int64 {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let capacity = values.volumeAvailableCapacity {
                return Int64(capacity)
            }
        } catch {
            print("Error getting disk space: \(error)")
        }
        return 0
    }
}

extension Notification.Name {
    static let saveAllState = Notification.Name("com.openhands.mac.saveAllState")
}
```

This implementation guide provides a comprehensive approach to error handling and recovery in the Mac client, covering error definitions, user feedback mechanisms, and recovery procedures for various failure scenarios.