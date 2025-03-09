# Agent Output Display Implementation

This document provides detailed technical guidance for implementing the Agent Output Display component of the OpenHands Mac client. It breaks down the feature into specific technical components, providing actionable details for developers.

## Table of Contents

1. [Overview](#1-overview)
2. [Data Models](#2-data-models)
3. [View Models](#3-view-models)
4. [UI Components](#4-ui-components)
5. [Output Formatting](#5-output-formatting)
6. [Syntax Highlighting](#6-syntax-highlighting)
7. [Performance Considerations](#7-performance-considerations)
8. [Integration with Backend](#8-integration-with-backend)

## 1. Overview

The Agent Output Display component is responsible for rendering various types of output from the agent, including:
- Plain text messages
- Code blocks with syntax highlighting
- Command execution results
- Tool outputs (including potential image rendering)
- Error messages and warnings

The implementation should handle real-time updates, proper formatting, and efficient rendering of potentially large outputs.

## 2. Data Models

```swift
// Model representing a message from the agent
struct AgentMessage: Identifiable, Codable {
    let id: String
    let content: String
    let timestamp: Date
    let messageType: MessageType
    let metadata: MessageMetadata?
    
    enum MessageType: String, Codable {
        case text
        case code
        case commandResult
        case toolOutput
        case error
        case warning
    }
    
    struct MessageMetadata: Codable {
        let language: String?
        let mimeType: String?
        let isComplete: Bool
        let executionTime: TimeInterval?
    }
}

// Model for tracking conversation state
struct Conversation: Identifiable, Codable {
    let id: String
    var messages: [AgentMessage]
    let createdAt: Date
    var updatedAt: Date
    var title: String
}
```

## 3. View Models

```swift
class AgentOutputViewModel: ObservableObject {
    @Published var messages: [AgentMessage] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private let conversationService: ConversationService
    private let conversationId: String
    
    init(conversationService: ConversationService, conversationId: String) {
        self.conversationService = conversationService
        self.conversationId = conversationId
        
        // Load initial messages
        loadMessages()
        
        // Subscribe to real-time updates
        subscribeToUpdates()
    }
    
    func loadMessages() {
        isLoading = true
        
        Task {
            do {
                let conversation = try await conversationService.getConversation(id: conversationId)
                
                await MainActor.run {
                    self.messages = conversation.messages
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func subscribeToUpdates() {
        conversationService.subscribeToMessages(conversationId: conversationId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                DispatchQueue.main.async {
                    // Check if this is an update to an existing message
                    if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                        self.messages[index] = message
                    } else {
                        self.messages.append(message)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.error = error
                }
            }
        }
    }
    
    func clearMessages() {
        Task {
            do {
                try await conversationService.clearConversation(id: conversationId)
                
                await MainActor.run {
                    self.messages = []
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
}
```

## 4. UI Components

```swift
struct AgentOutputView: View {
    @ObservedObject var viewModel: AgentOutputViewModel
    @State private var scrollProxy: ScrollViewProxy?
    @State private var shouldAutoScroll = true
    
    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                ProgressView("Loading conversation...")
            } else if let error = viewModel.error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
                Button("Retry") {
                    viewModel.loadMessages()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                            
                            // Invisible view at the bottom for auto-scrolling
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages) { _ in
                        if shouldAutoScroll {
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        scrollProxy = proxy
                        
                        // Scroll to bottom on initial load
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Auto-scroll toggle
                Toggle("Auto-scroll", isOn: $shouldAutoScroll)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }
}

struct MessageView: View {
    let message: AgentMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Message header
            HStack {
                Text(message.messageType.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Message content
            Group {
                switch message.messageType {
                case .text:
                    Text(message.content)
                        .textSelection(.enabled)
                
                case .code:
                    CodeBlockView(
                        code: message.content,
                        language: message.metadata?.language ?? "swift"
                    )
                
                case .commandResult:
                    TerminalOutputView(output: message.content)
                
                case .toolOutput:
                    ToolOutputView(
                        content: message.content,
                        mimeType: message.metadata?.mimeType
                    )
                
                case .error:
                    Text(message.content)
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                
                case .warning:
                    Text(message.content)
                        .foregroundColor(.orange)
                        .textSelection(.enabled)
                }
            }
            .padding(8)
            .background(backgroundForMessageType)
            .cornerRadius(8)
        }
    }
    
    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
    
    private var backgroundForMessageType: Color {
        switch message.messageType {
        case .text:
            return Color(.textBackgroundColor).opacity(0.3)
        case .code:
            return Color(.textBackgroundColor).opacity(0.5)
        case .commandResult:
            return Color.black.opacity(0.7)
        case .toolOutput:
            return Color.blue.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        case .warning:
            return Color.orange.opacity(0.1)
        }
    }
}
```

## 5. Output Formatting

For proper formatting of different output types, implement specialized views:

```swift
struct CodeBlockView: View {
    let code: String
    let language: String
    
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Code header with language and copy button
            HStack {
                Text(language)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                Button(action: {
                    copyToClipboard()
                }) {
                    Label(
                        isCopied ? "Copied!" : "Copy",
                        systemImage: isCopied ? "checkmark" : "doc.on.doc"
                    )
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
            }
            
            // Code content with syntax highlighting
            SyntaxHighlightedText(code: code, language: language)
                .padding(8)
                .background(Color(.textBackgroundColor))
                .cornerRadius(4)
                .textSelection(.enabled)
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        
        isCopied = true
        
        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}

struct TerminalOutputView: View {
    let output: String
    
    var body: some View {
        Text(output)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.white)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black)
            .cornerRadius(4)
            .textSelection(.enabled)
    }
}

struct ToolOutputView: View {
    let content: String
    let mimeType: String?
    
    var body: some View {
        Group {
            if let mimeType = mimeType, mimeType.starts(with: "image/") {
                if let data = Data(base64Encoded: content),
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                } else {
                    Text("Invalid image data")
                        .foregroundColor(.red)
                }
            } else {
                Text(content)
                    .textSelection(.enabled)
            }
        }
    }
}
```

## 6. Syntax Highlighting

Implement syntax highlighting for code blocks:

```swift
struct SyntaxHighlightedText: NSViewRepresentable {
    let code: String
    let language: String
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 0, height: 0)
        
        return textView
    }
    
    func updateNSView(_ textView: NSTextView, context: Context) {
        // Apply syntax highlighting
        let attributedString = highlightSyntax(code: code, language: language)
        textView.textStorage?.setAttributedString(attributedString)
    }
    
    private func highlightSyntax(code: String, language: String) -> NSAttributedString {
        // For a production app, use a proper syntax highlighting library
        // This is a simplified example
        
        let attributedString = NSMutableAttributedString(string: code)
        
        // Apply base font
        attributedString.addAttribute(
            .font,
            value: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            range: NSRange(location: 0, length: code.count)
        )
        
        // Simple syntax highlighting for Swift
        if language.lowercased() == "swift" {
            // Keywords
            let keywords = ["func", "var", "let", "if", "else", "guard", "return", "class", "struct", "enum", "protocol", "extension", "import", "for", "while", "switch", "case", "default", "break", "continue", "self", "super", "init", "deinit", "get", "set", "willSet", "didSet", "throws", "throw", "do", "try", "catch"]
            
            for keyword in keywords {
                let pattern = "\\b\(keyword)\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let matches = regex.matches(in: code, options: [], range: NSRange(location: 0, length: code.count))
                    for match in matches {
                        attributedString.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: match.range)
                        attributedString.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold), range: match.range)
                    }
                }
            }
            
            // String literals
            if let regex = try? NSRegularExpression(pattern: "\"[^\"]*\"", options: []) {
                let matches = regex.matches(in: code, options: [], range: NSRange(location: 0, length: code.count))
                for match in matches {
                    attributedString.addAttribute(.foregroundColor, value: NSColor.systemRed, range: match.range)
                }
            }
            
            // Comments
            if let regex = try? NSRegularExpression(pattern: "//.*$|/\\*[\\s\\S]*?\\*/", options: [.anchorsMatchLines]) {
                let matches = regex.matches(in: code, options: [], range: NSRange(location: 0, length: code.count))
                for match in matches {
                    attributedString.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: match.range)
                    attributedString.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular), range: match.range)
                }
            }
        }
        
        return attributedString
    }
}
```

## 7. Performance Considerations

For handling large outputs efficiently:

```swift
// Lazy loading for large outputs
class LazyLoadedOutputViewModel: ObservableObject {
    @Published var visibleContent: String = ""
    @Published var isFullyLoaded: Bool = false
    
    private let fullContent: String
    private let chunkSize: Int
    private var loadedChunks: Int = 0
    
    init(content: String, chunkSize: Int = 5000) {
        self.fullContent = content
        self.chunkSize = chunkSize
        
        // Load first chunk immediately
        loadNextChunk()
    }
    
    func loadNextChunk() {
        guard !isFullyLoaded else { return }
        
        let startIndex = loadedChunks * chunkSize
        let endIndex = min(startIndex + chunkSize, fullContent.count)
        
        guard startIndex < fullContent.count else {
            isFullyLoaded = true
            return
        }
        
        let start = fullContent.index(fullContent.startIndex, offsetBy: startIndex)
        let end = fullContent.index(fullContent.startIndex, offsetBy: endIndex)
        let chunk = String(fullContent[start..<end])
        
        visibleContent += chunk
        loadedChunks += 1
        
        isFullyLoaded = endIndex >= fullContent.count
    }
    
    func loadAllContent() {
        visibleContent = fullContent
        isFullyLoaded = true
    }
}

struct LazyLoadedOutputView: View {
    @ObservedObject var viewModel: LazyLoadedOutputViewModel
    
    var body: some View {
        VStack {
            Text(viewModel.visibleContent)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            
            if !viewModel.isFullyLoaded {
                Button("Load more...") {
                    viewModel.loadNextChunk()
                }
                .padding(.vertical, 4)
                
                Button("Load all") {
                    viewModel.loadAllContent()
                }
                .padding(.vertical, 4)
            }
        }
    }
}
```

## 8. Integration with Backend

The Agent Output Display component integrates with the backend through:

1. **REST API calls** for loading conversation history
2. **SocketIO events** for real-time updates to messages

```swift
// Example of handling message update events from SocketIO
func setupMessageUpdateListeners() {
    socketManager.on("oh_event") { [weak self] data in
        guard let self = self,
              let eventData = data as? [String: Any],
              let observation = eventData["observation"] as? [String: Any],
              let observationType = observation["observation"] as? String,
              observationType == "MessageObservation" else {
            return
        }
        
        // Parse the message data
        if let messageData = try? JSONSerialization.data(withJSONObject: observation["message"] as Any),
           let message = try? JSONDecoder().decode(AgentMessage.self, from: messageData) {
            
            // Update the view model
            DispatchQueue.main.async {
                if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                    self.messages[index] = message
                } else {
                    self.messages.append(message)
                }
            }
        }
    }
}
```