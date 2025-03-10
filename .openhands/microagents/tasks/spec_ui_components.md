---
name  :  mac_client_ui_components
type  :  task
agent  :  CodeActAgent
---

# OpenHands Mac Client UI Components Specification

This document provides detailed specifications for the UI components of the OpenHands Mac client, including layout, behavior, and implementation details.

## 1. Main Window Layout

The main window of the OpenHands Mac client will use a split view layout with resizable panels:

```
+-----------------------------------------------+
| Toolbar (Control Buttons, Settings)           |
+-----------------------------------------------+
| +----------+                                  |
| |          |                                  |
| |  File    |                                  |
| |  Explorer|     Agent Output Display         |
| |          |                                  |
| |          |                                  |
| |          |                                  |
| +----------+                                  |
|                                               |
+-----------------------------------------------+
|                                               |
|           Task Input Area                     |
|                                               |
+-----------------------------------------------+
```

### 1.1 SwiftUI Implementation

```swift
struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main content area with split view
                HSplitView {
                    // File Explorer
                    FileExplorerView(viewModel: viewModel.fileExplorerViewModel)
                        .frame(minWidth: 200, idealWidth: 250, maxWidth: 400)
                    
                    // Agent Output Display
                    AgentOutputView(viewModel: viewModel.outputViewModel)
                        .frame(minWidth: 400)
                }
                
                Divider()
                
                // Task Input Area
                TaskInputView(viewModel: viewModel.inputViewModel)
                    .frame(height: 100)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Control Buttons
                    AgentControlButtons(viewModel: viewModel.controlViewModel)
                    
                    Spacer()
                    
                    // Settings Button
                    Button(action: { viewModel.showSettings() }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $viewModel.isSettingsPresented) {
                SettingsView(viewModel: viewModel.settingsViewModel)
            }
        }
    }
}
```

## 2. File Explorer Component

The File Explorer provides a hierarchical view of files and directories in the workspace.

### 2.1 Design and Behavior

- Tree view with expandable/collapsible folders
- Icons to indicate file types
- Selection highlighting for the current file
- Context menu for file operations (optional for MVP)
- Double-click to open files

### 2.2 SwiftUI Implementation

```swift
struct FileExplorerView: View {
    @ObservedObject var viewModel: FileExplorerViewModel
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Files")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { viewModel.refreshFiles() }) {
                    Image(systemName: "arrow.clockwise")
                        .imageScale(.small)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            Divider()
            
            // File tree
            if viewModel.isLoading && viewModel.rootNodes.isEmpty {
                ProgressView("Loading files...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.rootNodes.isEmpty {
                VStack {
                    Text("Error loading files")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        viewModel.refreshFiles()
                    }
                    .padding(.top)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.rootNodes, children: \.children) { node in
                    FileNodeView(node: node, selectedPath: viewModel.selectedPath) { path in
                        viewModel.selectFile(path: path)
                    }
                }
                .listStyle(SidebarListStyle())
            }
        }
    }
}

struct FileNodeView: View {
    let node: FileNode
    let selectedPath: String?
    let onSelect: (String) -> Void
    
    var body: some View {
        HStack {
            // Icon based on file type
            if node.isDirectory {
                Image(systemName: "folder")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: fileTypeIcon(for: node.name))
                    .foregroundColor(.gray)
            }
            
            // File name
            Text(node.name)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(node.path)
        }
        .background(
            selectedPath == node.path ? Color.accentColor.opacity(0.2) : Color.clear
        )
    }
    
    private func fileTypeIcon(for fileName: String) -> String {
        let fileExtension = fileName.components(separatedBy: ".").last?.lowercased() ?? ""
        
        switch fileExtension {
        case "swift", "java", "kt", "cpp", "c", "h", "cs", "js", "ts", "py", "rb":
            return "doc.plaintext"
        case "json", "xml", "yaml", "yml":
            return "curlybraces"
        case "md", "txt", "rtf":
            return "doc.text"
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff":
            return "photo"
        case "mp4", "mov", "avi", "wmv":
            return "film"
        case "mp3", "wav", "aac", "flac":
            return "music.note"
        case "zip", "tar", "gz", "7z", "rar":
            return "archivebox"
        default:
            return "doc"
        }
    }
}
```

### 2.3 View Model

```swift
class FileExplorerViewModel: ObservableObject {
    @Published var rootNodes: [FileNode] = []
    @Published var selectedPath: String?
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let fileService: FileService
    private let conversationId: String
    
    init(fileService: FileService, conversationId: String) {
        self.fileService = fileService
        self.conversationId = conversationId
    }
    
    func refreshFiles() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let files = try await fileService.listFiles(
                    conversationId: conversationId
                )
                
                await MainActor.run {
                    self.rootNodes = files
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func selectFile(path: String) {
        selectedPath = path
        
        // Notify parent view model or handle file selection
        // This could trigger a file content fetch if needed
    }
}
```

## 3. Agent Output Display Component

The Agent Output Display shows the step-by-step actions and outputs from the agent in real-time.

### 3.1 Design and Behavior

- Scrollable list of messages and outputs
- Support for different content types:
  - Text messages
  - Markdown content
  - Code blocks with syntax highlighting
  - Terminal command outputs
  - File changes
  - Error messages
- Auto-scrolling to latest content with manual override
- Chunked processing for large outputs

### 3.2 SwiftUI Implementation

```swift
struct AgentOutputView: View {
    @ObservedObject var viewModel: AgentOutputViewModel
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var autoScroll: Bool = true
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Agent Output")
                    .font(.headline)
                
                Spacer()
                
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            Divider()
            
            // Output content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.outputs) { output in
                            OutputItemView(output: output)
                                .id(output.id)
                        }
                        
                        // Bottom anchor for auto-scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding()
                }
                .onChange(of: viewModel.outputs) { _ in
                    if autoScroll {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    scrollViewProxy = proxy
                    if autoScroll {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct OutputItemView: View {
    let output: AgentOutput
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Output header
            HStack {
                Text(output.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let source = output.source {
                    Text(source)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sourceColor(source).opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            // Output content based on type
            switch output.type {
            case .text:
                Text(output.content)
                    .textSelection(.enabled)
            
            case .markdown:
                MarkdownView(markdown: output.content)
                    .textSelection(.enabled)
            
            case .code:
                CodeBlockView(
                    code: output.content,
                    language: output.metadata?["language"] as? String ?? ""
                )
            
            case .terminal:
                TerminalOutputView(
                    command: output.metadata?["command"] as? String,
                    output: output.content,
                    exitCode: output.metadata?["exitCode"] as? Int ?? 0
                )
            
            case .error:
                ErrorOutputView(
                    message: output.content,
                    details: output.metadata?["details"] as? String
                )
            
            case .fileChange:
                FileChangeView(
                    path: output.metadata?["path"] as? String ?? "",
                    changeType: output.metadata?["changeType"] as? String ?? ""
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func sourceColor(_ source: String) -> Color {
        switch source.uppercased() {
        case "AGENT":
            return .blue
        case "SYSTEM":
            return .gray
        case "USER":
            return .green
        default:
            return .gray
        }
    }
}

// Specialized views for different output types

struct MarkdownView: View {
    let markdown: String
    
    var body: some View {
        // Use a markdown rendering library or WebKit
        Text(markdown)
    }
}

struct CodeBlockView: View {
    let code: String
    let language: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !language.isEmpty {
                Text(language)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            }
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .textSelection(.enabled)
            }
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(4)
        }
    }
}

struct TerminalOutputView: View {
    let command: String?
    let output: String
    let exitCode: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let command = command {
                HStack {
                    Text("$")
                        .foregroundColor(.secondary)
                    Text(command)
                        .bold()
                        .textSelection(.enabled)
                }
                .font(.system(.body, design: .monospaced))
                .padding(.bottom, 2)
            }
            
            Text(output)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
            
            if exitCode != 0 {
                Text("Exit code: \(exitCode)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 2)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(4)
    }
}

struct ErrorOutputView: View {
    let message: String
    let details: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message)
                .foregroundColor(.red)
                .bold()
                .textSelection(.enabled)
            
            if let details = details {
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .padding(.top, 2)
            }
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(4)
    }
}

struct FileChangeView: View {
    let path: String
    let changeType: String
    
    var body: some View {
        HStack {
            Image(systemName: iconForChangeType(changeType))
                .foregroundColor(colorForChangeType(changeType))
            
            VStack(alignment: .leading) {
                Text(changeTypeDescription(changeType))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(path)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .padding(8)
        .background(colorForChangeType(changeType).opacity(0.1))
        .cornerRadius(4)
    }
    
    private func iconForChangeType(_ type: String) -> String {
        switch type.lowercased() {
        case "create":
            return "plus.circle"
        case "modify", "edit":
            return "pencil.circle"
        case "delete":
            return "minus.circle"
        case "read":
            return "eye.circle"
        default:
            return "doc.circle"
        }
    }
    
    private func colorForChangeType(_ type: String) -> Color {
        switch type.lowercased() {
        case "create":
            return .green
        case "modify", "edit":
            return .blue
        case "delete":
            return .red
        case "read":
            return .gray
        default:
            return .gray
        }
    }
    
    private func changeTypeDescription(_ type: String) -> String {
        switch type.lowercased() {
        case "create":
            return "Created file"
        case "modify", "edit":
            return "Modified file"
        case "delete":
            return "Deleted file"
        case "read":
            return "Read file"
        default:
            return "File operation"
        }
    }
}
```

### 3.3 View Model

```swift
class AgentOutputViewModel: ObservableObject {
    @Published var outputs: [AgentOutput] = []
    
    private let socketManager: SocketIOManager
    
    init(socketManager: SocketIOManager) {
        self.socketManager = socketManager
        setupEventHandlers()
    }
    
    private func setupEventHandlers() {
        socketManager.onEvent = { [weak self] eventData in
            self?.processEvent(eventData)
        }
    }
    
    private func processEvent(_ eventData: [String: Any]) {
        // Extract common fields
        let timestamp = Date()
        let source = eventData["source"] as? String
        let message = eventData["message"] as? String ?? ""
        
        // Determine output type and content
        if let observation = eventData["observation"] as? [String: Any],
           let observationType = observation["observation"] as? String {
            
            switch observationType {
            case "CmdOutputObservation":
                if let content = eventData["content"] as? String,
                   let extras = eventData["extras"] as? [String: Any],
                   let command = extras["command"] as? String,
                   let exitCode = extras["exit_code"] as? Int {
                    
                    addOutput(
                        content: content,
                        type: .terminal,
                        source: source,
                        metadata: [
                            "command": command,
                            "exitCode": exitCode
                        ]
                    )
                }
                
            case "FileObservation":
                if let content = eventData["content"] as? String,
                   let path = eventData["path"] as? String {
                    
                    addOutput(
                        content: content,
                        type: .code,
                        source: source,
                        metadata: [
                            "path": path,
                            "language": pathToLanguage(path)
                        ]
                    )
                } else if let path = eventData["path"] as? String,
                          let success = eventData["success"] as? Bool {
                    
                    let operation = eventData["operation"] as? String ?? "file_operation"
                    
                    addOutput(
                        content: "\(operation.capitalized) \(success ? "succeeded" : "failed"): \(path)",
                        type: .fileChange,
                        source: source,
                        metadata: [
                            "path": path,
                            "changeType": operation,
                            "success": success
                        ]
                    )
                }
                
            default:
                // Handle other observation types or generic messages
                addOutput(
                    content: message,
                    type: .text,
                    source: source
                )
            }
        } else if let error = eventData["error"] as? [String: Any],
                  let errorMessage = error["message"] as? String {
            
            addOutput(
                content: errorMessage,
                type: .error,
                source: source,
                metadata: [
                    "details": error["details"] as? String ?? ""
                ]
            )
        } else {
            // Generic message
            addOutput(
                content: message,
                type: .text,
                source: source
            )
        }
    }
    
    private func addOutput(
        content: String,
        type: AgentOutputType,
        source: String?,
        metadata: [String: Any]? = nil
    ) {
        let output = AgentOutput(
            id: UUID(),
            content: content,
            type: type,
            source: source,
            timestamp: Date(),
            metadata: metadata
        )
        
        DispatchQueue.main.async {
            self.outputs.append(output)
            
            // Limit the number of outputs to prevent memory issues
            if self.outputs.count > 1000 {
                self.outputs.removeFirst(100)
            }
        }
    }
    
    private func pathToLanguage(_ path: String) -> String {
        let fileExtension = path.components(separatedBy: ".").last?.lowercased() ?? ""
        
        switch fileExtension {
        case "swift": return "Swift"
        case "java": return "Java"
        case "kt": return "Kotlin"
        case "js": return "JavaScript"
        case "ts": return "TypeScript"
        case "py": return "Python"
        case "rb": return "Ruby"
        case "go": return "Go"
        case "rs": return "Rust"
        case "c", "cpp", "h", "hpp": return "C/C++"
        case "cs": return "C#"
        case "php": return "PHP"
        case "html": return "HTML"
        case "css": return "CSS"
        case "json": return "JSON"
        case "xml": return "XML"
        case "yaml", "yml": return "YAML"
        case "md": return "Markdown"
        case "sh", "bash": return "Shell"
        default: return ""
        }
    }
}

struct AgentOutput: Identifiable {
    let id: UUID
    let content: String
    let type: AgentOutputType
    let source: String?
    let timestamp: Date
    let metadata: [String: Any]?
}

enum AgentOutputType {
    case text
    case markdown
    case code
    case terminal
    case error
    case fileChange
}
```

## 4. Task Input Area Component

The Task Input Area allows users to input instructions and tasks for the agent.

### 4.1 Design and Behavior

- Multi-line text input field
- Submit button
- Optional support for text formatting
- Optional support for image attachments
- Command history (optional for MVP)

### 4.2 SwiftUI Implementation

```swift
struct TaskInputView: View {
    @ObservedObject var viewModel: TaskInputViewModel
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 8) {
                // Text input field
                ZStack(alignment: .topLeading) {
                    if viewModel.inputText.isEmpty {
                        Text("Type your instructions here...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $viewModel.inputText)
                        .focused($isInputFocused)
                        .padding(4)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(8)
                        .frame(minHeight: 40, maxHeight: 200)
                }
                
                // Submit button
                Button(action: {
                    viewModel.submitInput()
                    isInputFocused = true
                }) {
                    Text("Submit")
                        .frame(minWidth: 80)
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSubmitting)
            }
            .padding(8)
        }
        .background(Color(.systemBackground))
    }
}
```

### 4.3 View Model

```swift
class TaskInputViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var isSubmitting: Bool = false
    
    private let socketManager: SocketIOManager
    
    init(socketManager: SocketIOManager) {
        self.socketManager = socketManager
    }
    
    func submitInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else { return }
        
        isSubmitting = true
        
        // Send message to backend
        socketManager.sendAction(
            action: "message",
            args: [
                "content": text,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
        
        // Clear input after sending
        inputText = ""
        isSubmitting = false
    }
}
```

## 5. Agent Control Buttons Component

The Agent Control Buttons allow users to control the agent's execution state.

### 5.1 Design and Behavior

- Start/Resume button
- Pause button
- Stop button
- Visual indication of current agent state
- Confirmation for potentially destructive actions

### 5.2 SwiftUI Implementation

```swift
struct AgentControlButtons: View {
    @ObservedObject var viewModel: AgentControlViewModel
    @State private var showStopConfirmation = false
    
    var body: some View {
        HStack {
            // Start/Resume button
            Button(action: {
                viewModel.startOrResumeAgent()
            }) {
                Label("Start", systemImage: "play.fill")
            }
            .disabled(!viewModel.canStartOrResume)
            
            // Pause button
            Button(action: {
                viewModel.pauseAgent()
            }) {
                Label("Pause", systemImage: "pause.fill")
            }
            .disabled(!viewModel.canPause)
            
            // Stop button
            Button(action: {
                if viewModel.requiresStopConfirmation {
                    showStopConfirmation = true
                } else {
                    viewModel.stopAgent()
                }
            }) {
                Label("Stop", systemImage: "stop.fill")
            }
            .disabled(!viewModel.canStop)
            .confirmationDialog(
                "Stop Agent",
                isPresented: $showStopConfirmation,
                actions: {
                    Button("Stop Agent", role: .destructive) {
                        viewModel.stopAgent()
                    }
                    Button("Cancel", role: .cancel) {}
                },
                message: {
                    Text("Are you sure you want to stop the agent? This will terminate the current task.")
                }
            )
            
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor(viewModel.agentState))
                    .frame(width: 8, height: 8)
                
                Text(statusText(viewModel.agentState))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
        }
    }
    
    private func statusColor(_ state: AgentState) -> Color {
        switch state {
        case .running:
            return .green
        case .paused:
            return .yellow
        case .stopped, .finished:
            return .gray
        case .error:
            return .red
        case .awaitingUserInput:
            return .blue
        default:
            return .gray
        }
    }
    
    private func statusText(_ state: AgentState) -> String {
        switch state {
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        case .stopped:
            return "Stopped"
        case .finished:
            return "Finished"
        case .error:
            return "Error"
        case .awaitingUserInput:
            return "Waiting for input"
        default:
            return "Unknown"
        }
    }
}
```

### 5.3 View Model

```swift
class AgentControlViewModel: ObservableObject {
    @Published var agentState: AgentState = .stopped
    
    private let socketManager: SocketIOManager
    
    init(socketManager: SocketIOManager) {
        self.socketManager = socketManager
        setupEventHandlers()
    }
    
    private func setupEventHandlers() {
        socketManager.onEvent = { [weak self] eventData in
            if let stateString = eventData["agent_state"] as? String {
                self?.updateAgentState(stateString)
            }
        }
    }
    
    private func updateAgentState(_ stateString: String) {
        let newState: AgentState
        
        switch stateString.uppercased() {
        case "RUNNING":
            newState = .running
        case "PAUSED":
            newState = .paused
        case "STOPPED":
            newState = .stopped
        case "FINISHED":
            newState = .finished
        case "ERROR":
            newState = .error
        case "AWAITING_USER_INPUT":
            newState = .awaitingUserInput
        default:
            newState = .unknown
        }
        
        DispatchQueue.main.async {
            self.agentState = newState
        }
    }
    
    func startOrResumeAgent() {
        let newState: String
        
        if agentState == .stopped {
            newState = "RUNNING"
        } else if agentState == .paused {
            newState = "RUNNING"
        } else {
            return
        }
        
        socketManager.sendAction(
            action: "change_agent_state",
            args: ["agent_state": newState]
        )
    }
    
    func pauseAgent() {
        guard agentState == .running else { return }
        
        socketManager.sendAction(
            action: "change_agent_state",
            args: ["agent_state": "PAUSED"]
        )
    }
    
    func stopAgent() {
        guard agentState == .running || agentState == .paused else { return }
        
        socketManager.sendAction(
            action: "change_agent_state",
            args: ["agent_state": "STOPPED"]
        )
    }
    
    // Computed properties for button states
    
    var canStartOrResume: Bool {
        agentState == .stopped || agentState == .paused || agentState == .error
    }
    
    var canPause: Bool {
        agentState == .running
    }
    
    var canStop: Bool {
        agentState == .running || agentState == .paused
    }
    
    var requiresStopConfirmation: Bool {
        agentState == .running
    }
}

enum AgentState {
    case unknown
    case running
    case paused
    case stopped
    case finished
    case error
    case awaitingUserInput
}
```

## 6. Settings Panel Component

The Settings Panel allows users to configure the Mac client and backend connection.

### 6.1 Design and Behavior

- Modal dialog or separate window
- Categorized settings
- Save/cancel buttons
- Validation of inputs
- Persistent storage of settings

### 6.2 SwiftUI Implementation

```swift
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Backend Connection")) {
                    TextField("Backend URL", text: $viewModel.backendURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle("Use TLS (HTTPS)", isOn: $viewModel.useTLS)
                }
                
                Section(header: Text("API Keys")) {
                    SecureField("OpenAI API Key", text: $viewModel.openAIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    // Additional API keys as needed
                }
                
                Section(header: Text("UI Preferences")) {
                    Picker("Theme", selection: $viewModel.theme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Stepper("Font Size: \(viewModel.fontSize)", value: $viewModel.fontSize, in: 10...24)
                    
                    Toggle("Show Line Numbers", isOn: $viewModel.showLineNumbers)
                }
            }
            .padding()
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Save") {
                    viewModel.saveSettings()
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!viewModel.isValid)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .onAppear {
            viewModel.loadSettings()
        }
    }
}
```

### 6.3 View Model

```swift
class SettingsViewModel: ObservableObject {
    // Backend Connection
    @Published var backendURL: String = "http://localhost:8000"
    @Published var useTLS: Bool = false
    
    // API Keys
    @Published var openAIKey: String = ""
    
    // UI Preferences
    @Published var theme: String = "system"
    @Published var fontSize: Int = 14
    @Published var showLineNumbers: Bool = true
    
    // Validation state
    @Published var isValid: Bool = true
    
    private let settingsService: SettingsService
    
    init(settingsService: SettingsService) {
        self.settingsService = settingsService
    }
    
    func loadSettings() {
        Task {
            do {
                if let settings = try await settingsService.getSettings() {
                    await MainActor.run {
                        self.backendURL = settings.backendURL.absoluteString
                        self.useTLS = settings.backendURL.scheme == "https"
                        
                        if let openAIKey = settings.apiKeys["openai"] {
                            self.openAIKey = openAIKey
                        }
                        
                        self.theme = settings.uiPreferences.theme
                        self.fontSize = settings.uiPreferences.fontSize
                        self.showLineNumbers = settings.uiPreferences.showLineNumbers
                        
                        self.validateSettings()
                    }
                }
            } catch {
                print("Error loading settings: \(error)")
            }
        }
    }
    
    func saveSettings() {
        guard isValid else { return }
        
        // Construct URL with appropriate scheme
        var urlString = backendURL
        if !urlString.lowercased().hasPrefix("http") {
            urlString = (useTLS ? "https://" : "http://") + urlString
        }
        
        guard let url = URL(string: urlString) else {
            isValid = false
            return
        }
        
        let settings = Settings(
            backendURL: url,
            apiKeys: ["openai": openAIKey],
            uiPreferences: Settings.UIPreferences(
                theme: theme,
                fontSize: fontSize,
                showLineNumbers: showLineNumbers
            )
        )
        
        Task {
            do {
                let success = try await settingsService.saveSettings(settings: settings)
                if success {
                    print("Settings saved successfully")
                }
            } catch {
                print("Error saving settings: \(error)")
            }
        }
    }
    
    func validateSettings() {
        // Validate backend URL
        let urlString = backendURL
        if !urlString.isEmpty {
            var fullURL = urlString
            if !fullURL.lowercased().hasPrefix("http") {
                fullURL = (useTLS ? "https://" : "http://") + fullURL
            }
            
            isValid = URL(string: fullURL) != nil
        } else {
            isValid = false
        }
    }
}
```

## 7. Error Notification Component

The Error Notification component displays error messages and provides recovery options.

### 7.1 Design and Behavior

- Non-intrusive notifications for minor errors
- Modal dialogs for critical errors
- Recovery options where applicable

### 7.2 SwiftUI Implementation

```swift
struct ErrorNotificationView: View {
    let error: AppError
    let onDismiss: () -> Void
    let onRecovery: (ErrorRecoveryOption) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForSeverity(error.severity))
                    .foregroundColor(colorForSeverity(error.severity))
                    .font(.title)
                
                Text(error.title)
                    .font(.headline)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            
            Text(error.message)
                .font(.body)
            
            if !error.recoveryOptions.isEmpty {
                HStack {
                    Spacer()
                    
                    ForEach(error.recoveryOptions, id: \.title) { option in
                        Button(option.title) {
                            onRecovery(option)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
        .background(backgroundForSeverity(error.severity))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    private func iconForSeverity(_ severity: ErrorSeverity) -> String {
        switch severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "exclamationmark.circle"
        case .critical:
            return "xmark.octagon"
        }
    }
    
    private func colorForSeverity(_ severity: ErrorSeverity) -> Color {
        switch severity {
        case .info:
            return .blue
        case .warning:
            return .yellow
        case .error:
            return .red
        case .critical:
            return .red
        }
    }
    
    private func backgroundForSeverity(_ severity: ErrorSeverity) -> Color {
        switch severity {
        case .info:
            return Color.blue.opacity(0.1)
        case .warning:
            return Color.yellow.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        case .critical:
            return Color.red.opacity(0.2)
        }
    }
}
```

### 7.3 Error Manager

```swift
class ErrorManager: ObservableObject {
    @Published var currentErrors: [UUID: AppError] = [:]
    
    func showError(_ error: AppError) {
        let id = UUID()
        
        DispatchQueue.main.async {
            self.currentErrors[id] = error
            
            // Auto-dismiss non-critical errors after a delay
            if error.severity != .critical {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.dismissError(id: id)
                }
            }
        }
    }
    
    func dismissError(id: UUID) {
        DispatchQueue.main.async {
            self.currentErrors.removeValue(forKey: id)
        }
    }
    
    func handleRecovery(for error: AppError, option: ErrorRecoveryOption) {
        // Implement recovery actions based on the error and option
        switch (error.code, option.title) {
        case (1001, "Retry"):
            // Retry connection
            retryConnection()
        case (1002, "Reset"):
            // Reset settings
            resetSettings()
        default:
            // Default recovery action
            print("Unhandled recovery action: \(option.title) for error code \(error.code)")
        }
    }
    
    private func retryConnection() {
        // Implement connection retry logic
    }
    
    private func resetSettings() {
        // Implement settings reset logic
    }
}
```

## 8. Main View Model

The Main View Model coordinates between the different components and manages the overall application state.

### 8.1 Implementation

```swift
class MainViewModel: ObservableObject {
    // Child view models
    let fileExplorerViewModel: FileExplorerViewModel
    let outputViewModel: AgentOutputViewModel
    let inputViewModel: TaskInputViewModel
    let controlViewModel: AgentControlViewModel
    let settingsViewModel: SettingsViewModel
    
    // Settings sheet state
    @Published var isSettingsPresented: Bool = false
    
    // Services
    private let socketManager: SocketIOManager
    private let apiClient: APIClient
    private let fileService: FileService
    private let conversationService: ConversationService
    private let settingsService: SettingsService
    
    // Current conversation
    private var conversationId: String
    
    init() {
        // Initialize with default values, will be updated when settings are loaded
        let baseURL = URL(string: "http://localhost:8000")!
        
        // Initialize services
        apiClient = APIClient(baseURL: baseURL)
        fileService = FileService(apiClient: apiClient)
        conversationService = ConversationService(apiClient: apiClient)
        settingsService = SettingsService(apiClient: apiClient)
        
        // Default conversation ID (will be updated)
        conversationId = ""
        
        // Initialize socket manager
        socketManager = SocketIOManager(
            serverURL: baseURL,
            conversationId: conversationId
        )
        
        // Initialize child view models
        fileExplorerViewModel = FileExplorerViewModel(
            fileService: fileService,
            conversationId: conversationId
        )
        
        outputViewModel = AgentOutputViewModel(
            socketManager: socketManager
        )
        
        inputViewModel = TaskInputViewModel(
            socketManager: socketManager
        )
        
        controlViewModel = AgentControlViewModel(
            socketManager: socketManager
        )
        
        settingsViewModel = SettingsViewModel(
            settingsService: settingsService
        )
        
        // Load settings and initialize
        loadSettingsAndConnect()
    }
    
    private func loadSettingsAndConnect() {
        Task {
            do {
                if let settings = try await settingsService.getSettings() {
                    // Update services with new settings
                    updateBackendConnection(url: settings.backendURL)
                    
                    // Create or load conversation
                    await createOrLoadConversation()
                }
            } catch {
                print("Error loading settings: \(error)")
            }
        }
    }
    
    private func updateBackendConnection(url: URL) {
        apiClient.updateBaseURL(url)
        socketManager.updateServerURL(url)
    }
    
    private func createOrLoadConversation() async {
        do {
            // Get recent conversations
            let conversations = try await conversationService.listConversations(limit: 1)
            
            if let mostRecent = conversations.first {
                // Use most recent conversation
                conversationId = mostRecent.id
            } else {
                // Create new conversation
                conversationId = try await conversationService.createConversation(
                    initialUserMessage: "Hello, I'm using the Mac client."
                )
            }
            
            // Update child view models with new conversation ID
            await MainActor.run {
                fileExplorerViewModel.updateConversationId(conversationId)
                socketManager.updateConversationId(conversationId)
                
                // Connect to socket
                socketManager.connect()
                
                // Load initial data
                fileExplorerViewModel.refreshFiles()
            }
        } catch {
            print("Error creating/loading conversation: \(error)")
        }
    }
    
    func showSettings() {
        isSettingsPresented = true
    }
}
```

## 9. Accessibility Considerations

### 9.1 VoiceOver Support

```swift
// Example of enhancing VoiceOver accessibility
struct AccessibleFileNodeView: View {
    let node: FileNode
    let selectedPath: String?
    let onSelect: (String) -> Void
    
    var body: some View {
        HStack {
            if node.isDirectory {
                Image(systemName: "folder")
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: fileTypeIcon(for: node.name))
                    .foregroundColor(.gray)
                    .accessibilityHidden(true)
            }
            
            Text(node.name)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(node.path)
        }
        .background(
            selectedPath == node.path ? Color.accentColor.opacity(0.2) : Color.clear
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(selectedPath == node.path ? .isSelected : [])
        .accessibilityAddTraits(node.isDirectory ? .isButton : [])
    }
    
    private var accessibilityLabel: String {
        let type = node.isDirectory ? "Folder" : "File"
        return "\(type): \(node.name)"
    }
    
    private var accessibilityHint: String {
        if node.isDirectory {
            return "Double tap to expand or collapse folder"
        } else {
            return "Double tap to view file contents"
        }
    }
    
    private func fileTypeIcon(for fileName: String) -> String {
        // Implementation as before
        return "doc"
    }
}
```

### 9.2 Keyboard Navigation

```swift
// Example of enhancing keyboard navigation
struct KeyboardNavigableFileExplorer: View {
    @ObservedObject var viewModel: FileExplorerViewModel
    @FocusState private var isFocused: Bool
    @State private var selectedIndex: Int = 0
    
    var body: some View {
        VStack {
            // Header as before
            
            List(Array(viewModel.rootNodes.enumerated()), id: \.element.id) { index, node in
                FileNodeView(node: node, selectedPath: viewModel.selectedPath) { path in
                    viewModel.selectFile(path: path)
                }
                .background(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
                .onTapGesture {
                    selectedIndex = index
                }
            }
            .focused($isFocused)
            .onKeyPress(.upArrow) {
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
                return .handled
            }
            .onKeyPress(.downArrow) {
                if selectedIndex < viewModel.rootNodes.count - 1 {
                    selectedIndex += 1
                }
                return .handled
            }
            .onKeyPress(.return) {
                if selectedIndex >= 0 && selectedIndex < viewModel.rootNodes.count {
                    let node = viewModel.rootNodes[selectedIndex]
                    viewModel.selectFile(path: node.path)
                }
                return .handled
            }
        }
    }
}
```

## 10. Localization Support

### 10.1 Localized Strings

```swift
// Example of localization support
struct LocalizedFileExplorerView: View {
    @ObservedObject var viewModel: FileExplorerViewModel
    
    var body: some View {
        VStack {
            HStack {
                Text("files_header", bundle: .main, comment: "Header for file explorer")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { viewModel.refreshFiles() }) {
                    Image(systemName: "arrow.clockwise")
                        .imageScale(.small)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("refresh_files", bundle: .main, comment: "Refresh files button"))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            Divider()
            
            if viewModel.isLoading && viewModel.rootNodes.isEmpty {
                ProgressView(Text("loading_files", bundle: .main, comment: "Loading files progress indicator"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.rootNodes.isEmpty {
                VStack {
                    Text("error_loading_files", bundle: .main, comment: "Error loading files message")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button(Text("retry", bundle: .main, comment: "Retry button")) {
                        viewModel.refreshFiles()
                    }
                    .padding(.top)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // List as before
            }
        }
    }
}
```

### 10.2 Localized Date and Number Formatting

```swift
// Example of localized date and number formatting
struct LocalizedOutputItemView: View {
    let output: AgentOutput
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(output.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .environment(\.locale, Locale.current)
                
                if let source = output.source {
                    Text(localizedSource(source))
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sourceColor(source).opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            // Output content as before
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func localizedSource(_ source: String) -> String {
        switch source.uppercased() {
        case "AGENT":
            return NSLocalizedString("source_agent", comment: "Agent source label")
        case "SYSTEM":
            return NSLocalizedString("source_system", comment: "System source label")
        case "USER":
            return NSLocalizedString("source_user", comment: "User source label")
        default:
            return source
        }
    }
    
    private func sourceColor(_ source: String) -> Color {
        // Implementation as before
        return .gray
    }
}
```

This comprehensive UI components specification provides the detailed technical guidance needed to implement the OpenHands Mac client, covering all the necessary UI components for a functional MVP.