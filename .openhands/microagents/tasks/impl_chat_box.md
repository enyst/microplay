# Chat Box Implementation Guide for Mac Client

This document outlines the implementation details for the chat box in the Mac client, which displays both agent outputs and user messages, including handling different message types, formatting, styling, and scrolling management.

## 1. Message Types and Handling

### 1.1 Message Model

```swift
enum MessageType {
    case user
    case agent
}

struct ChatMessage: Identifiable {
    let id: UUID
    let type: MessageType
    let content: MessageContent
    let timestamp: Date
    let metadata: [String: Any]?
    
    // Convenience initializer for user messages
    static func userMessage(_ text: String) -> ChatMessage {
        return ChatMessage(
            id: UUID(),
            type: .user,
            content: .userMessage(text),
            timestamp: Date(),
            metadata: nil
        )
    }
    
    // Convenience initializer for agent outputs
    static func agentOutput(_ outputType: AgentOutputType, metadata: [String: Any]? = nil) -> ChatMessage {
        return ChatMessage(
            id: UUID(),
            type: .agent,
            content: .agentOutput(outputType),
            timestamp: Date(),
            metadata: metadata
        )
    }
}

enum MessageContent {
    case userMessage(String)
    case agentOutput(AgentOutputType)
}
```

## 2. Agent Output Types and Handling

### 2.1 Output Type Definitions

```swift
enum AgentOutputType {
    case text(String)
    case markdown(String)
    case code(String, language: String?)
    case image(URL)
    case terminal(String)
    case error(String, details: String?)
    case fileTree([FileItem])
    case custom(data: [String: Any])
}

struct AgentOutput {
    let id: UUID
    let type: AgentOutputType
    let timestamp: Date
    let isComplete: Bool
    let metadata: [String: Any]?
}
```

### 2.2 Output Type Detection

```swift
class OutputParser {
    static func parseOutput(from event: OpenHandsEvent) -> AgentOutput {
        let id = UUID()
        let timestamp = event.timestamp
        let isComplete = event.isComplete ?? true
        
        // Extract message content
        guard let message = event.message else {
            return AgentOutput(
                id: id,
                type: .error("Invalid message format", details: nil),
                timestamp: timestamp,
                isComplete: isComplete,
                metadata: nil
            )
        }
        
        // Detect output type based on message content and metadata
        if let outputType = event.metadata?["output_type"] as? String {
            switch outputType {
            case "markdown":
                return AgentOutput(
                    id: id,
                    type: .markdown(message),
                    timestamp: timestamp,
                    isComplete: isComplete,
                    metadata: event.metadata
                )
                
            case "code":
                let language = event.metadata?["language"] as? String
                return AgentOutput(
                    id: id,
                    type: .code(message, language: language),
                    timestamp: timestamp,
                    isComplete: isComplete,
                    metadata: event.metadata
                )
                
            case "terminal":
                return AgentOutput(
                    id: id,
                    type: .terminal(message),
                    timestamp: timestamp,
                    isComplete: isComplete,
                    metadata: event.metadata
                )
                
            case "image":
                if let urlString = event.metadata?["url"] as? String,
                   let url = URL(string: urlString) {
                    return AgentOutput(
                        id: id,
                        type: .image(url),
                        timestamp: timestamp,
                        isComplete: isComplete,
                        metadata: event.metadata
                    )
                }
                
            case "file_tree":
                if let fileItems = parseFileTree(from: message) {
                    return AgentOutput(
                        id: id,
                        type: .fileTree(fileItems),
                        timestamp: timestamp,
                        isComplete: isComplete,
                        metadata: event.metadata
                    )
                }
                
            case "custom":
                if let data = event.metadata?["data"] as? [String: Any] {
                    return AgentOutput(
                        id: id,
                        type: .custom(data: data),
                        timestamp: timestamp,
                        isComplete: isComplete,
                        metadata: event.metadata
                    )
                }
                
            default:
                break
            }
        }
        
        // Default to markdown if no specific type is detected
        return AgentOutput(
            id: id,
            type: .markdown(message),
            timestamp: timestamp,
            isComplete: isComplete,
            metadata: event.metadata
        )
    }
    
    private static func parseFileTree(from message: String) -> [FileItem]? {
        // Parse file tree JSON structure
        guard let data = message.data(using: .utf8) else { return nil }
        
        do {
            return try JSONDecoder().decode([FileItem].self, from: data)
        } catch {
            print("Error parsing file tree: \(error)")
            return nil
        }
    }
}
```

## 3. Output Formatting and Styling

### 3.1 Text and Markdown Rendering

```swift
struct MarkdownOutputView: View {
    let content: String
    
    var body: some View {
        ScrollView {
            MarkdownUI.Markdown(content)
                .markdownTheme(.gitHub)
                .padding()
        }
    }
}
```

### 3.2 User Message View

```swift
struct UserMessageView: View {
    let message: String
    
    var body: some View {
        HStack {
            Spacer()
            
            Text(message)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.primary)
                .cornerRadius(12)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = message
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

### 3.4 Code Block Rendering

```swift
struct CodeBlockView: View {
    let code: String
    let language: String?
    
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and copy button
            HStack {
                Text(language ?? "Code")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                
                Spacer()
                
                Button(action: {
                    UIPasteboard.general.string = code
                    isCopied = true
                    
                    // Reset copied state after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                }) {
                    Label(isCopied ? "Copied" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 8)
            }
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.05))
            
            // Code content with syntax highlighting
            CodeEditor(source: code, language: language ?? "swift", theme: .xcode)
                .frame(minHeight: 100)
                .padding(8)
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.vertical, 8)
    }
}
```

### 3.3 Terminal Output Rendering

```swift
struct TerminalOutputView: View {
    let output: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(output)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black)
        .cornerRadius(8)
    }
}
```

### 3.4 Image Rendering

```swift
struct AgentImageView: View {
    let imageURL: URL
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(8)
            } else if isLoading {
                ProgressView()
                    .frame(height: 200)
            } else if error != nil {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Failed to load image")
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        isLoading = true
        
        URLSession.shared.dataTask(with: imageURL) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    self.error = error
                    return
                }
                
                guard let data = data, let loadedImage = UIImage(data: data) else {
                    self.error = NSError(domain: "ImageLoadingError", code: 0, userInfo: nil)
                    return
                }
                
                self.image = loadedImage
            }
        }.resume()
    }
}
```

### 3.5 User Message Rendering

```swift
struct UserMessageView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
```

### 3.6 Output Container View

```swift
struct AgentOutputContainerView: View {
    let output: AgentOutput
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timestamp header
            HStack {
                Text(output.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !output.isComplete {
                    ProgressView()
                        .scaleEffect(0.5)
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            
            // Output content based on type
            Group {
                switch output.type {
                case .text(let content):
                    Text(content)
                        .padding(8)
                
                case .markdown(let content):
                    MarkdownOutputView(content: content)
                
                case .code(let code, let language):
                    CodeBlockView(code: code, language: language)
                
                case .terminal(let output):
                    TerminalOutputView(output: output)
                
                case .image(let url):
                    AgentImageView(imageURL: url)
                
                case .error(let message, let details):
                    ErrorView(message: message, details: details)
                
                case .fileTree(let items):
                    FileTreeView(items: items)
                
                case .custom(let data):
                    CustomOutputView(data: data)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
```

## 4. Scrolling and History Management

### 4.1 Conversation History View

```swift
struct ConversationHistoryView: View {
    @ObservedObject var viewModel: ConversationViewModel
    
    // Scroll position tracking
    @State private var scrollProxy: ScrollViewProxy?
    @State private var lastMessageId: UUID?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        Group {
                            switch message.type {
                            case .user:
                                if case .userMessage(let content) = message.content {
                                    UserMessageView(message: content)
                                }
                            case .agent:
                                if case .agentOutput(let outputType) = message.content {
                                    AgentOutputContainerView(output: AgentOutput(
                                        id: message.id,
                                        type: outputType,
                                        timestamp: message.timestamp,
                                        isComplete: true,
                                        metadata: message.metadata
                                    ))
                                }
                            }
                        }
                        .id(message.id)
                    }
                    
                    // Spacer at the bottom to allow scrolling past the last item
                    Color.clear
                        .frame(height: 20)
                        .id("bottom")
                }
                .padding()
            }
            .onAppear {
                scrollProxy = proxy
                scrollToBottom(animated: false)
            }
            .onChange(of: viewModel.messages) { newMessages in
                // If a new message was added, scroll to it
                if let lastMessage = newMessages.last, lastMessage.id != lastMessageId {
                    lastMessageId = lastMessage.id
                    scrollToBottom()
                }
            }
        }
    }
    
    private func scrollToBottom(animated: Bool = true) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(animated ? .easeOut : nil) {
                scrollProxy?.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}
```

### 4.2 Lazy Loading for Large Conversations

```swift
class ConversationViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoadingHistory = false
    
    private var conversationId: String
    private var socketManager: SocketManager
    private var historyManager: ConversationHistoryManager
    
    private var currentPage = 1
    private var hasMoreHistory = true
    
    init(conversationId: String) {
        self.conversationId = conversationId
        self.socketManager = SocketManager(conversationId: conversationId)
        self.historyManager = ConversationHistoryManager()
        
        // Load initial history
        loadInitialHistory()
        
        // Subscribe to new messages
        setupSocketSubscription()
    }
    
    func loadInitialHistory() {
        isLoadingHistory = true
        
        historyManager.fetchHistory(conversationId: conversationId, page: 1) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoadingHistory = false
                
                switch result {
                case .success(let messages):
                    self.messages = messages
                    self.currentPage = 1
                    self.hasMoreHistory = messages.count >= 20 // Assuming page size of 20
                    
                case .failure(let error):
                    print("Failed to load history: \(error)")
                    // Handle error
                }
            }
        }
    }
    
    // Send a new user message
    func sendMessage(_ message: String) {
        // Create and add user message to the conversation
        let userMessage = ChatMessage.userMessage(message)
        messages.append(userMessage)
        
        // Send message to backend
        socketManager.emit("oh_action", [
            "type": "user_message",
            "content": message,
            "conversation_id": conversationId
        ])
    }
    
    func loadMoreHistory() {
        guard hasMoreHistory && !isLoadingHistory else { return }
        
        isLoadingHistory = true
        let nextPage = currentPage + 1
        
        historyManager.fetchHistory(conversationId: conversationId, page: nextPage) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoadingHistory = false
                
                switch result {
                case .success(let messages):
                    if messages.isEmpty {
                        self.hasMoreHistory = false
                    } else {
                        self.messages.insert(contentsOf: messages, at: 0)
                        self.currentPage = nextPage
                        self.hasMoreHistory = messages.count >= 20
                    }
                    
                case .failure(let error):
                    print("Failed to load more history: \(error)")
                    // Handle error
                }
            }
        }
    }
    
    // Send a user message
    func sendUserMessage(_ text: String) {
        let userMessage = ChatMessage(
            id: UUID(),
            type: .user,
            content: .userMessage(text),
            timestamp: Date(),
            metadata: nil
        )
        
        // Add to local messages
        messages.append(userMessage)
        
        // Send to backend
        socketManager.sendUserMessage(text)
    }
    
    private func setupSocketSubscription() {
        socketManager.connect()
        
        // Subscribe to new agent outputs
        NotificationCenter.default.addObserver(
            forName: .newAgentOutput,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let event = notification.object as? OpenHandsEvent else {
                return
            }
            
            let output = OutputParser.parseOutput(from: event)
            
            // Create agent message
            let agentMessage = ChatMessage(
                id: UUID(),
                type: .agent,
                content: .agentOutput(output.type),
                timestamp: output.timestamp,
                metadata: output.metadata
            )
            
            // Update existing message if it's a continuation or add new message
            if let existingIndex = self.findIncompleteAgentMessageIndex() {
                self.messages[existingIndex] = agentMessage
            } else {
                self.messages.append(agentMessage)
            }
        }
    }
    
    // Find the index of the last incomplete agent message
    private func findIncompleteAgentMessageIndex() -> Int? {
        for (index, message) in messages.enumerated().reversed() {
            if message.type == .agent, 
               case .agentOutput(let outputType) = message.content,
               let metadata = message.metadata,
               let isComplete = metadata["isComplete"] as? Bool,
               !isComplete {
                return index
            }
        }
        return nil
    }
}
```

### 4.4 Pull to Refresh for History

```swift
struct ConversationView: View {
    @StateObject var viewModel: ConversationViewModel
    
    var body: some View {
        VStack {
            // History view with pull-to-refresh
            RefreshableScrollView(
                onRefresh: { done in
                    viewModel.loadMoreHistory()
                    // Simulate network delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        done()
                    }
                }
            ) {
                ConversationHistoryView(viewModel: viewModel)
            }
            
            // Input field at the bottom
            MessageInputView(onSend: { message in
                viewModel.sendMessage(message)
            })
        }
    }
}

// Custom refreshable scroll view implementation
struct RefreshableScrollView<Content: View>: View {
    @State private var isRefreshing = false
    let onRefresh: (@escaping () -> Void) -> Void
    let content: Content
    
    init(onRefresh: @escaping (@escaping () -> Void) -> Void, @ViewBuilder content: () -> Content) {
        self.onRefresh = onRefresh
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                // Pull to refresh indicator
                if isRefreshing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding(.top, 20)
                }
                
                // Main content
                VStack {
                    content
                }
                .offset(y: isRefreshing ? 50 : 0)
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.height > 50 && !isRefreshing {
                            isRefreshing = true
                            onRefresh {
                                isRefreshing = false
                            }
                        }
                    }
            )
        }
    }
}
```

## 4. Handling Streaming Outputs

### 4.1 Streaming Text Updates

```swift
class StreamingOutputManager {
    private var incompleteOutputs: [String: String] = [:]
    
    func handleStreamingUpdate(event: OpenHandsEvent) -> AgentOutput {
        guard let id = event.id else {
            return OutputParser.parseOutput(from: event)
        }
        
        // Check if this is a continuation of an existing output
        if var existingContent = incompleteOutputs[id] {
            // Append new content
            if let newContent = event.message {
                existingContent += newContent
                incompleteOutputs[id] = existingContent
            }
            
            // Create a modified event with the complete content so far
            var updatedEvent = event
            updatedEvent.message = existingContent
            
            // If this is the final chunk, remove from incomplete outputs
            if event.isComplete == true {
                incompleteOutputs.removeValue(forKey: id)
            }
            
            return OutputParser.parseOutput(from: updatedEvent)
        } else {
            // This is a new streaming output
            if event.isComplete == false, let content = event.message {
                incompleteOutputs[id] = content
            }
            
            return OutputParser.parseOutput(from: event)
        }
    }
}
```

### 4.2 Message Input View

```swift
struct MessageInputView: View {
    @State private var messageText = ""
    let onSend: (String) -> Void
    
    var body: some View {
        HStack {
            // Text input field
            TextField("Type a message...", text: $messageText)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }
            
            // Send button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -5)
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        onSend(trimmedMessage)
        messageText = ""
    }
}

### 4.3 Animated Typing Effect

```swift
struct TypingTextView: View {
    let text: String
    let isComplete: Bool
    
    @State private var displayedText: String = ""
    @State private var lastUpdatedText: String = ""
    
    var body: some View {
        Text(displayedText)
            .onChange(of: text) { newText in
                updateDisplayedText(newText)
            }
            .onAppear {
                updateDisplayedText(text)
            }
    }
    
    private func updateDisplayedText(_ newText: String) {
        // If this is a completely new message, reset the displayed text
        if !newText.hasPrefix(lastUpdatedText) {
            displayedText = ""
            lastUpdatedText = ""
        }
        
        // Calculate the new portion to animate
        let newPortion = String(newText.dropFirst(lastUpdatedText.count))
        lastUpdatedText = newText
        
        // Animate the new portion character by character
        var currentIndex = 0
        let characters = Array(newPortion)
        
        // Cancel any existing timers
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            if currentIndex < characters.count {
                displayedText += String(characters[currentIndex])
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}
```

## 5. Accessibility Considerations

### 5.1 VoiceOver Support

```swift
extension AgentOutputContainerView {
    var accessibilityLabel: String {
        switch output.type {
        case .text(let content), .markdown(let content):
            return "Agent message: \(content)"
            
        case .code(let code, let language):
            return "Code block in \(language ?? "unknown language"): \(code)"
            
        case .terminal(let output):
            return "Terminal output: \(output)"
            
        case .image:
            return "Image from agent"
            
        case .error(let message, _):
            return "Error: \(message)"
            
        case .fileTree:
            return "File tree display"
            
        case .custom:
            return "Custom agent output"
        }
    }
    
    var accessibilityHint: String {
        switch output.type {
        case .code:
            return "Double tap to copy code to clipboard"
            
        case .image:
            return "Double tap to view image in full screen"
            
        default:
            return ""
        }
    }
}
```

### 5.2 Dynamic Type Support

```swift
struct MarkdownOutputView: View {
    let content: String
    
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        ScrollView {
            MarkdownUI.Markdown(content)
                .markdownTheme(.gitHub)
                .environment(\.sizeCategory, sizeCategory)
                .padding()
        }
    }
}
```

This implementation guide provides a comprehensive approach to displaying agent outputs in the Mac client, covering different output types, formatting, styling, and scrolling management with accessibility considerations.