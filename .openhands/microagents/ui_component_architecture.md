# UI Component Architecture for Mac Client

This document outlines the UI component architecture for the Mac client, including component breakdown, view hierarchy, navigation flow, and MVVM implementation for each feature.

## 1. UI Component Breakdown

### 1.1 Core Components

```swift
// MARK: - Core UI Components

// Base text field with common styling and behavior
struct OHTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var onSubmit: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        onSubmit?()
                    }
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(keyboardType)
                    .onSubmit {
                        onSubmit?()
                    }
            }
        }
        .padding(.vertical, 4)
    }
}

// Primary button with consistent styling
struct OHPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: {
            if !isLoading && !isDisabled {
                action()
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                        .padding(.trailing, 5)
                }
                
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isDisabled || isLoading)
    }
}

// Secondary button with consistent styling
struct OHSecondaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: {
            if !isLoading && !isDisabled {
                action()
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                        .padding(.trailing, 5)
                }
                
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .disabled(isDisabled || isLoading)
    }
}

// Card container with consistent styling
struct OHCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 12
    
    init(padding: CGFloat = 16, cornerRadius: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// Section header with consistent styling
struct OHSectionHeader: View {
    let title: String
    var showDivider: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            if showDivider {
                Divider()
            }
        }
        .padding(.vertical, 8)
    }
}

// Empty state view
struct OHEmptyStateView: View {
    let title: String
    let message: String
    var icon: String = "doc.text"
    var action: (() -> Void)?
    var actionTitle: String?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if let action = action, let actionTitle = actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Loading overlay
struct OHLoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .opacity(0.7)
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                
                Text(message)
                    .font(.headline)
            }
            .padding(24)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// Toast notification
struct OHToast: View {
    let message: String
    let type: ToastType
    let onDismiss: () -> Void
    
    enum ToastType {
        case success
        case error
        case info
        case warning
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
            
            Text(message)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var iconName: String {
        switch type {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .success:
            return .green
        case .error:
            return .red
        case .info:
            return .blue
        case .warning:
            return .yellow
        }
    }
}

// Sidebar item
struct OHSidebarItem: View {
    let title: String
    let icon: String
    var badge: Int? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Spacer()
                
                if let badge = badge, badge > 0 {
                    Text("\(badge)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Code block view
struct OHCodeBlockView: View {
    let code: String
    let language: String
    
    @State private var isExpanded = false
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(language.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                }) {
                    Label(isCopied ? "Copied" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    isExpanded.toggle()
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Code content
            ScrollView([.horizontal, .vertical]) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: isExpanded ? nil : 200)
        }
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// Markdown content view
struct OHMarkdownView: View {
    let content: String
    
    var body: some View {
        ScrollView {
            Text(LocalizedStringKey(content))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}
```

### 1.2 Conversation Components

```swift
// MARK: - Conversation Components

// Message bubble
struct OHMessageBubble: View {
    let message: Message
    var onCodeBlockTap: ((String, String) -> Void)?
    
    var body: some View {
        HStack(alignment: .top) {
            if message.source == .user {
                Spacer()
            }
            
            VStack(alignment: message.source == .user ? .trailing : .leading, spacing: 4) {
                // Message content
                MessageContentView(message: message, onCodeBlockTap: onCodeBlockTap)
                
                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(backgroundColor)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            
            if message.source == .agent {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private var backgroundColor: Color {
        switch message.source {
        case .user:
            return Color.accentColor.opacity(0.1)
        case .agent:
            return Color(NSColor.controlBackgroundColor)
        case .system:
            return Color.gray.opacity(0.1)
        }
    }
}

// Message content view
struct MessageContentView: View {
    let message: Message
    var onCodeBlockTap: ((String, String) -> Void)?
    
    @State private var parsedContent: [MessageContentBlock] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parsedContent, id: \.id) { block in
                switch block.type {
                case .text:
                    Text(block.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                
                case .code:
                    OHCodeBlockView(code: block.content, language: block.language ?? "text")
                        .onTapGesture {
                            onCodeBlockTap?(block.content, block.language ?? "text")
                        }
                
                case .image:
                    if let url = URL(string: block.content) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(8)
                            case .failure:
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(maxWidth: 300, maxHeight: 300)
                    }
                }
            }
        }
        .onAppear {
            parsedContent = parseMessageContent(message.content)
        }
    }
    
    // Parse message content into blocks
    private func parseMessageContent(_ content: String) -> [MessageContentBlock] {
        var blocks: [MessageContentBlock] = []
        
        // Simple parser for demonstration
        // In a real implementation, use a proper Markdown parser
        
        let codeBlockRegex = try! NSRegularExpression(pattern: "```([a-zA-Z0-9]*)\\s*\\n([\\s\\S]*?)\\n```", options: [])
        let imageRegex = try! NSRegularExpression(pattern: "!\\[(.*?)\\]\\((.*?)\\)", options: [])
        
        let nsContent = content as NSString
        var lastIndex = 0
        
        // Find code blocks
        let codeMatches = codeBlockRegex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))
        
        for match in codeMatches {
            // Add text before code block
            if match.range.location > lastIndex {
                let textRange = NSRange(location: lastIndex, length: match.range.location - lastIndex)
                let textContent = nsContent.substring(with: textRange)
                
                if !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(MessageContentBlock(type: .text, content: textContent))
                }
            }
            
            // Add code block
            let languageRange = match.range(at: 1)
            let codeRange = match.range(at: 2)
            
            let language = languageRange.location != NSNotFound ? nsContent.substring(with: languageRange) : "text"
            let code = codeRange.location != NSNotFound ? nsContent.substring(with: codeRange) : ""
            
            blocks.append(MessageContentBlock(type: .code, content: code, language: language))
            
            lastIndex = match.range.location + match.range.length
        }
        
        // Add remaining text
        if lastIndex < nsContent.length {
            let textRange = NSRange(location: lastIndex, length: nsContent.length - lastIndex)
            let textContent = nsContent.substring(with: textRange)
            
            // Find images in the remaining text
            let imageMatches = imageRegex.matches(in: textContent, options: [], range: NSRange(location: 0, length: textContent.count))
            
            if imageMatches.isEmpty {
                blocks.append(MessageContentBlock(type: .text, content: textContent))
            } else {
                var textLastIndex = 0
                
                for match in imageMatches {
                    // Add text before image
                    if match.range.location > textLastIndex {
                        let subTextRange = NSRange(location: textLastIndex, length: match.range.location - textLastIndex)
                        let subTextContent = (textContent as NSString).substring(with: subTextRange)
                        
                        if !subTextContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            blocks.append(MessageContentBlock(type: .text, content: subTextContent))
                        }
                    }
                    
                    // Add image
                    let urlRange = match.range(at: 2)
                    let url = urlRange.location != NSNotFound ? (textContent as NSString).substring(with: urlRange) : ""
                    
                    blocks.append(MessageContentBlock(type: .image, content: url))
                    
                    textLastIndex = match.range.location + match.range.length
                }
                
                // Add remaining text
                if textLastIndex < textContent.count {
                    let subTextRange = NSRange(location: textLastIndex, length: textContent.count - textLastIndex)
                    let subTextContent = (textContent as NSString).substring(with: subTextRange)
                    
                    if !subTextContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        blocks.append(MessageContentBlock(type: .text, content: subTextContent))
                    }
                }
            }
        }
        
        return blocks
    }
}

// Message content block
struct MessageContentBlock {
    let id = UUID()
    let type: MessageContentType
    let content: String
    var language: String?
    
    enum MessageContentType {
        case text
        case code
        case image
    }
}

// Message input view
struct OHMessageInputView: View {
    @Binding var message: String
    let onSend: () -> Void
    var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Text input
                TextField("Type a message...", text: $message, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .lineLimit(1...5)
                
                // Send button
                Button(action: {
                    if !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading {
                        onSend()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor)
                            .cornerRadius(18)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// Conversation header
struct OHConversationHeader: View {
    let title: String
    var status: ConversationStatus = .active
    var onTitleEdit: ((String) -> Void)?
    var onClose: (() -> Void)?
    
    @State private var isEditing = false
    @State private var editedTitle = ""
    
    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            // Title
            if isEditing {
                TextField("Conversation title", text: $editedTitle, onCommit: {
                    isEditing = false
                    if !editedTitle.isEmpty {
                        onTitleEdit?(editedTitle)
                    } else {
                        editedTitle = title
                    }
                })
                .textFieldStyle(PlainTextFieldStyle())
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)
            } else {
                Text(title)
                    .fontWeight(.semibold)
                    .onTapGesture(count: 2) {
                        if onTitleEdit != nil {
                            isEditing = true
                            editedTitle = title
                        }
                    }
            }
            
            Spacer()
            
            // Close button
            if let onClose = onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var statusColor: Color {
        switch status {
        case .active:
            return .green
        case .completed:
            return .blue
        case .error:
            return .red
        }
    }
}

// Conversation list item
struct OHConversationListItem: View {
    let conversation: Conversation
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)
                    
                    Text(conversationPreview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(conversation.lastUpdated, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var conversationPreview: String {
        if let lastMessage = conversation.messages.last {
            return lastMessage.content.prefix(50).replacingOccurrences(of: "\n", with: " ")
        } else if let draft = conversation.localDraft, !draft.isEmpty {
            return "Draft: \(draft.prefix(40))"
        } else {
            return "No messages"
        }
    }
}
```

### 1.3 File Explorer Components

```swift
// MARK: - File Explorer Components

// File item view
struct OHFileItemView: View {
    let file: FileItem
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                // File icon
                Image(systemName: file.isDirectory ? "folder.fill" : fileIcon)
                    .foregroundColor(file.isDirectory ? .blue : iconColor)
                    .frame(width: 24)
                
                // File name
                Text(file.name)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Spacer()
                
                // File size or item count
                if file.isDirectory {
                    if let itemCount = file.itemCount {
                        Text("\(itemCount) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    if let size = file.size {
                        Text(formatFileSize(size))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var fileIcon: String {
        switch file.extension?.lowercased() {
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "gif":
            return "photo.fill"
        case "mp4", "mov", "avi":
            return "film.fill"
        case "mp3", "wav", "aac":
            return "music.note"
        case "zip", "rar", "tar", "gz":
            return "archivebox.fill"
        case "swift", "java", "cpp", "c", "h", "py", "js", "html", "css":
            return "doc.plaintext.fill"
        case "md", "txt":
            return "doc.text.fill"
        case "json", "xml", "yaml", "yml":
            return "curlybraces"
        default:
            return "doc.fill"
        }
    }
    
    private var iconColor: Color {
        switch file.extension?.lowercased() {
        case "pdf":
            return .red
        case "jpg", "jpeg", "png", "gif":
            return .green
        case "mp4", "mov", "avi":
            return .purple
        case "mp3", "wav", "aac":
            return .pink
        case "zip", "rar", "tar", "gz":
            return .orange
        case "swift", "java", "cpp", "c", "h", "py", "js", "html", "css":
            return .blue
        case "md", "txt":
            return .gray
        case "json", "xml", "yaml", "yml":
            return .yellow
        default:
            return .gray
        }
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// File path breadcrumb
struct OHFileBreadcrumbView: View {
    let path: String
    let onNavigate: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(pathComponents.indices, id: \.self) { index in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        let path = pathComponents[0...index].joined(separator: "/")
                        onNavigate(path)
                    }) {
                        Text(pathComponents[index])
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var pathComponents: [String] {
        var components = path.split(separator: "/").map(String.init)
        if components.isEmpty {
            components = ["/"]
        } else {
            components.insert("/", at: 0)
        }
        return components
    }
}

// File explorer toolbar
struct OHFileExplorerToolbar: View {
    let onNewFolder: () -> Void
    let onRefresh: () -> Void
    let onUpload: () -> Void
    let onSearch: (String) -> Void
    
    @State private var searchText = ""
    
    var body: some View {
        HStack {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search files", text: $searchText, onCommit: {
                    onSearch(searchText)
                })
                .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        onSearch("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(6)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            
            Spacer()
            
            // Action buttons
            Button(action: onNewFolder) {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(PlainButtonStyle())
            .help("New Folder")
            
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(PlainButtonStyle())
            .help("Refresh")
            
            Button(action: onUpload) {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(PlainButtonStyle())
            .help("Upload")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// File preview
struct OHFilePreviewView: View {
    let file: FileItem
    let content: String?
    var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: fileIcon)
                    .foregroundColor(iconColor)
                
                Text(file.name)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let size = file.size {
                    Text(formatFileSize(size))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let content = content {
                if isImageFile {
                    if let image = NSImage(contentsOfFile: file.path) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding()
                    } else {
                        Text("Unable to load image")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if isPDFFile {
                    if let url = URL(string: "file://\(file.path)") {
                        PDFKitView(url: url)
                    } else {
                        Text("Unable to load PDF")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ScrollView {
                        if isCodeFile {
                            OHCodeBlockView(code: content, language: file.extension ?? "text")
                                .padding()
                        } else if isMarkdownFile {
                            OHMarkdownView(content: content)
                        } else {
                            Text(content)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            } else {
                Text("No preview available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private var fileIcon: String {
        switch file.extension?.lowercased() {
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "gif":
            return "photo.fill"
        case "mp4", "mov", "avi":
            return "film.fill"
        case "mp3", "wav", "aac":
            return "music.note"
        case "zip", "rar", "tar", "gz":
            return "archivebox.fill"
        case "swift", "java", "cpp", "c", "h", "py", "js", "html", "css":
            return "doc.plaintext.fill"
        case "md", "txt":
            return "doc.text.fill"
        case "json", "xml", "yaml", "yml":
            return "curlybraces"
        default:
            return "doc.fill"
        }
    }
    
    private var iconColor: Color {
        switch file.extension?.lowercased() {
        case "pdf":
            return .red
        case "jpg", "jpeg", "png", "gif":
            return .green
        case "mp4", "mov", "avi":
            return .purple
        case "mp3", "wav", "aac":
            return .pink
        case "zip", "rar", "tar", "gz":
            return .orange
        case "swift", "java", "cpp", "c", "h", "py", "js", "html", "css":
            return .blue
        case "md", "txt":
            return .gray
        case "json", "xml", "yaml", "yml":
            return .yellow
        default:
            return .gray
        }
    }
    
    private var isImageFile: Bool {
        ["jpg", "jpeg", "png", "gif"].contains(file.extension?.lowercased())
    }
    
    private var isPDFFile: Bool {
        file.extension?.lowercased() == "pdf"
    }
    
    private var isCodeFile: Bool {
        ["swift", "java", "cpp", "c", "h", "py", "js", "html", "css", "json", "xml", "yaml", "yml"].contains(file.extension?.lowercased())
    }
    
    private var isMarkdownFile: Bool {
        file.extension?.lowercased() == "md"
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// PDF view wrapper
struct PDFKitView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
    }
}
```

## 2. View Hierarchy and Navigation Flow

### 2.1 Main Window Structure

```swift
// MARK: - Main Window Structure

// Main window content view
struct MainContentView: View {
    @StateObject private var navigationViewModel = NavigationViewModel()
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(navigationViewModel: navigationViewModel)
        } content: {
            // Content list
            ContentListView(navigationViewModel: navigationViewModel)
        } detail: {
            // Detail view
            DetailView(navigationViewModel: navigationViewModel)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// Navigation view model
class NavigationViewModel: ObservableObject {
    @Published var selectedSidebarItem: SidebarItem = .conversations
    @Published var selectedConversationId: String?
    @Published var selectedFilePath: String?
    
    enum SidebarItem {
        case conversations
        case files
        case settings
    }
    
    // Select conversation
    func selectConversation(_ id: String) {
        selectedSidebarItem = .conversations
        selectedConversationId = id
        selectedFilePath = nil
    }
    
    // Select file
    func selectFile(_ path: String) {
        selectedSidebarItem = .files
        selectedFilePath = path
        selectedConversationId = nil
    }
    
    // Select settings
    func selectSettings() {
        selectedSidebarItem = .settings
        selectedConversationId = nil
        selectedFilePath = nil
    }
}

// Sidebar view
struct SidebarView: View {
    @ObservedObject var navigationViewModel: NavigationViewModel
    
    var body: some View {
        List {
            Section(header: Text("OpenHands")) {
                OHSidebarItem(
                    title: "Conversations",
                    icon: "bubble.left.and.bubble.right",
                    isSelected: navigationViewModel.selectedSidebarItem == .conversations,
                    action: {
                        navigationViewModel.selectedSidebarItem = .conversations
                    }
                )
                
                OHSidebarItem(
                    title: "Files",
                    icon: "folder",
                    isSelected: navigationViewModel.selectedSidebarItem == .files,
                    action: {
                        navigationViewModel.selectedSidebarItem = .files
                    }
                )
            }
            
            Section(header: Text("App")) {
                OHSidebarItem(
                    title: "Settings",
                    icon: "gear",
                    isSelected: navigationViewModel.selectedSidebarItem == .settings,
                    action: {
                        navigationViewModel.selectSettings()
                    }
                )
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
}

// Content list view
struct ContentListView: View {
    @ObservedObject var navigationViewModel: NavigationViewModel
    
    var body: some View {
        Group {
            switch navigationViewModel.selectedSidebarItem {
            case .conversations:
                ConversationListView(navigationViewModel: navigationViewModel)
            case .files:
                FileExplorerListView(navigationViewModel: navigationViewModel)
            case .settings:
                EmptyView()
            }
        }
        .frame(minWidth: 250)
    }
}

// Detail view
struct DetailView: View {
    @ObservedObject var navigationViewModel: NavigationViewModel
    
    var body: some View {
        Group {
            switch navigationViewModel.selectedSidebarItem {
            case .conversations:
                if let conversationId = navigationViewModel.selectedConversationId {
                    ConversationDetailView(conversationId: conversationId)
                } else {
                    OHEmptyStateView(
                        title: "No Conversation Selected",
                        message: "Select a conversation from the list or create a new one.",
                        icon: "bubble.left.and.bubble.right"
                    )
                }
            case .files:
                if let filePath = navigationViewModel.selectedFilePath {
                    FileDetailView(filePath: filePath)
                } else {
                    OHEmptyStateView(
                        title: "No File Selected",
                        message: "Select a file from the explorer to view its contents.",
                        icon: "doc.text"
                    )
                }
            case .settings:
                SettingsView()
            }
        }
    }
}
```

### 2.2 Conversation Flow

```swift
// MARK: - Conversation Flow

// Conversation list view
struct ConversationListView: View {
    @ObservedObject var navigationViewModel: NavigationViewModel
    @StateObject private var viewModel = ConversationListViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Conversations")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    viewModel.createNewConversation()
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(PlainButtonStyle())
                .help("New Conversation")
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Conversation list
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.conversations.isEmpty {
                OHEmptyStateView(
                    title: "No Conversations",
                    message: "Start a new conversation to chat with the agent.",
                    icon: "bubble.left.and.bubble.right",
                    action: {
                        viewModel.createNewConversation()
                    },
                    actionTitle: "New Conversation"
                )
            } else {
                List {
                    ForEach(viewModel.conversations) { conversation in
                        OHConversationListItem(
                            conversation: conversation,
                            isSelected: navigationViewModel.selectedConversationId == conversation.id,
                            onSelect: {
                                navigationViewModel.selectConversation(conversation.id)
                            }
                        )
                        .contextMenu {
                            Button("Rename") {
                                viewModel.startRenaming(conversation)
                            }
                            
                            Button("Delete") {
                                viewModel.deleteConversation(conversation)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(item: $viewModel.conversationToRename) { conversation in
            RenameConversationView(
                conversation: conversation,
                onRename: { newTitle in
                    viewModel.renameConversation(conversation, newTitle: newTitle)
                },
                onCancel: {
                    viewModel.conversationToRename = nil
                }
            )
        }
        .alert(item: $viewModel.error) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// Rename conversation view
struct RenameConversationView: View {
    let conversation: Conversation
    let onRename: (String) -> Void
    let onCancel: () -> Void
    
    @State private var title: String
    @Environment(\.presentationMode) var presentationMode
    
    init(conversation: Conversation, onRename: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.conversation = conversation
        self.onRename = onRename
        self.onCancel = onCancel
        _title = State(initialValue: conversation.title)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Conversation")
                .font(.headline)
            
            TextField("Conversation title", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            HStack {
                Button("Cancel") {
                    onCancel()
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("Rename") {
                    if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onRename(title)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .padding()
        .frame(width: 300)
    }
}

// Conversation detail view
struct ConversationDetailView: View {
    let conversationId: String
    @StateObject private var viewModel: ConversationViewModel
    
    init(conversationId: String) {
        self.conversationId = conversationId
        _viewModel = StateObject(wrappedValue: ConversationViewModel(conversationId: conversationId))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Conversation header
            OHConversationHeader(
                title: viewModel.conversation?.title ?? "Loading...",
                status: viewModel.conversation?.status ?? .active,
                onTitleEdit: { newTitle in
                    viewModel.updateTitle(newTitle)
                }
            )
            
            Divider()
            
            // Messages
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let conversation = viewModel.conversation {
                if conversation.messages.isEmpty {
                    OHEmptyStateView(
                        title: "No Messages",
                        message: "Start the conversation by sending a message.",
                        icon: "bubble.left.and.bubble.right"
                    )
                } else {
                    ScrollViewReader { scrollView in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(conversation.messages) { message in
                                    OHMessageBubble(
                                        message: message,
                                        onCodeBlockTap: { code, language in
                                            viewModel.handleCodeBlockTap(code: code, language: language)
                                        }
                                    )
                                    .id(message.id)
                                }
                                
                                if viewModel.isAgentResponding {
                                    HStack {
                                        OHMessageBubble(
                                            message: Message(
                                                id: "typing",
                                                source: .agent,
                                                content: "Thinking...",
                                                timestamp: Date(),
                                                metadata: nil,
                                                sequence: conversation.messages.count,
                                                isAcknowledged: true
                                            )
                                        )
                                        
                                        Spacer()
                                    }
                                    .id("typing")
                                }
                            }
                            .padding(.vertical)
                        }
                        .onChange(of: conversation.messages.count) { _ in
                            if let lastMessage = conversation.messages.last {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: viewModel.isAgentResponding) { isResponding in
                            if isResponding {
                                scrollView.scrollTo("typing", anchor: .bottom)
                            }
                        }
                        .onAppear {
                            if let lastMessage = conversation.messages.last {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            } else {
                OHEmptyStateView(
                    title: "Conversation Not Found",
                    message: "The conversation you're looking for doesn't exist or couldn't be loaded.",
                    icon: "exclamationmark.triangle"
                )
            }
            
            // Message input
            OHMessageInputView(
                message: $viewModel.messageText,
                onSend: {
                    viewModel.sendMessage()
                },
                isLoading: viewModel.isAgentResponding
            )
        }
        .sheet(item: $viewModel.codeBlockToShow) { codeBlock in
            CodeBlockDetailView(
                code: codeBlock.code,
                language: codeBlock.language
            )
        }
        .alert(item: $viewModel.error) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// Code block detail view
struct CodeBlockDetailView: View {
    let code: String
    let language: String
    
    @State private var isCopied = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(language.uppercased())
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                }) {
                    Label(isCopied ? "Copied" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Code content
            ScrollView([.horizontal, .vertical]) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 600, height: 400)
    }
}
```

### 2.3 File Explorer Flow

```swift
// MARK: - File Explorer Flow

// File explorer list view
struct FileExplorerListView: View {
    @ObservedObject var navigationViewModel: NavigationViewModel
    @StateObject private var viewModel = FileExplorerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            OHFileExplorerToolbar(
                onNewFolder: {
                    viewModel.showNewFolderDialog()
                },
                onRefresh: {
                    viewModel.refreshCurrentDirectory()
                },
                onUpload: {
                    viewModel.showUploadDialog()
                },
                onSearch: { query in
                    viewModel.searchFiles(query: query)
                }
            )
            
            Divider()
            
            // Breadcrumb
            OHFileBreadcrumbView(
                path: viewModel.currentPath,
                onNavigate: { path in
                    viewModel.navigateToPath(path)
                }
            )
            
            Divider()
            
            // File list
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.files.isEmpty {
                OHEmptyStateView(
                    title: "Empty Directory",
                    message: "This directory is empty.",
                    icon: "folder"
                )
            } else {
                List {
                    ForEach(viewModel.files) { file in
                        OHFileItemView(
                            file: file,
                            isSelected: navigationViewModel.selectedFilePath == file.path,
                            onSelect: {
                                if file.isDirectory {
                                    viewModel.navigateToPath(file.path)
                                } else {
                                    navigationViewModel.selectFile(file.path)
                                }
                            }
                        )
                        .contextMenu {
                            Button("Rename") {
                                viewModel.showRenameDialog(file: file)
                            }
                            
                            Button("Delete") {
                                viewModel.showDeleteConfirmation(file: file)
                            }
                            
                            if !file.isDirectory {
                                Button("Copy Path") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(file.path, forType: .string)
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(isPresented: $viewModel.showingNewFolderDialog) {
            NewFolderView(
                currentPath: viewModel.currentPath,
                onCreateFolder: { folderName in
                    viewModel.createFolder(name: folderName)
                },
                onCancel: {
                    viewModel.showingNewFolderDialog = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showingUploadDialog) {
            // This would typically use NSOpenPanel in a real implementation
            Text("Upload Dialog")
                .frame(width: 300, height: 200)
        }
        .sheet(item: $viewModel.fileToRename) { file in
            RenameFileView(
                file: file,
                onRename: { newName in
                    viewModel.renameFile(file: file, newName: newName)
                },
                onCancel: {
                    viewModel.fileToRename = nil
                }
            )
        }
        .alert(item: $viewModel.confirmationAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: .destructive(Text(alert.confirmButtonTitle)) {
                    alert.action()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(item: $viewModel.error) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// New folder view
struct NewFolderView: View {
    let currentPath: String
    let onCreateFolder: (String) -> Void
    let onCancel: () -> Void
    
    @State private var folderName = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Folder")
                .font(.headline)
            
            TextField("Folder name", text: $folderName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            HStack {
                Button("Cancel") {
                    onCancel()
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("Create") {
                    if !folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onCreateFolder(folderName)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .padding()
        .frame(width: 300)
    }
}

// Rename file view
struct RenameFileView: View {
    let file: FileItem
    let onRename: (String) -> Void
    let onCancel: () -> Void
    
    @State private var fileName: String
    @Environment(\.presentationMode) var presentationMode
    
    init(file: FileItem, onRename: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.file = file
        self.onRename = onRename
        self.onCancel = onCancel
        _fileName = State(initialValue: file.name)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rename \(file.isDirectory ? "Folder" : "File")")
                .font(.headline)
            
            TextField("Name", text: $fileName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            HStack {
                Button("Cancel") {
                    onCancel()
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("Rename") {
                    if !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onRename(fileName)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .disabled(fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .padding()
        .frame(width: 300)
    }
}

// File detail view
struct FileDetailView: View {
    let filePath: String
    @StateObject private var viewModel: FileDetailViewModel
    
    init(filePath: String) {
        self.filePath = filePath
        _viewModel = StateObject(wrappedValue: FileDetailViewModel(filePath: filePath))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let file = viewModel.file {
                OHFilePreviewView(
                    file: file,
                    content: viewModel.fileContent,
                    isLoading: viewModel.isLoadingContent
                )
            } else {
                OHEmptyStateView(
                    title: "File Not Found",
                    message: "The file you're looking for doesn't exist or couldn't be loaded.",
                    icon: "exclamationmark.triangle"
                )
            }
        }
        .alert(item: $viewModel.error) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
```

### 2.4 Settings Flow

```swift
// MARK: - Settings Flow

// Settings view
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // General settings
                OHCard {
                    VStack(alignment: .leading, spacing: 16) {
                        OHSectionHeader(title: "General")
                        
                        Picker("Theme", selection: $viewModel.theme) {
                            Text("System").tag(AppTheme.system)
                            Text("Light").tag(AppTheme.light)
                            Text("Dark").tag(AppTheme.dark)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Stepper("Font Size: \(viewModel.fontSize)", value: $viewModel.fontSize, in: 10...24)
                        
                        Toggle("Enable Notifications", isOn: $viewModel.enableNotifications)
                    }
                }
                
                // Account settings
                OHCard {
                    VStack(alignment: .leading, spacing: 16) {
                        OHSectionHeader(title: "Account")
                        
                        if viewModel.isSignedIn {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(viewModel.userEmail)
                                        .font(.headline)
                                    
                                    Text("Signed in")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Sign Out") {
                                    viewModel.signOut()
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            OHPrimaryButton(
                                title: "Sign In",
                                action: {
                                    viewModel.showSignInDialog()
                                }
                            )
                        }
                    }
                }
                
                // Storage settings
                OHCard {
                    VStack(alignment: .leading, spacing: 16) {
                        OHSectionHeader(title: "Storage")
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cache Size")
                                    .font(.headline)
                                
                                Text(viewModel.cacheSize)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Clear Cache") {
                                viewModel.clearCache()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // About
                OHCard {
                    VStack(alignment: .leading, spacing: 16) {
                        OHSectionHeader(title: "About")
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("OpenHands Mac Client")
                                    .font(.headline)
                                
                                Text("Version \(viewModel.appVersion)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Check for Updates") {
                                viewModel.checkForUpdates()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.showingSignInDialog) {
            SignInView(
                onSignIn: { email, password in
                    viewModel.signIn(email: email, password: password)
                },
                onCancel: {
                    viewModel.showingSignInDialog = false
                }
            )
        }
        .alert(item: $viewModel.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// Sign in view
struct SignInView: View {
    let onSignIn: (String, String) -> Void
    let onCancel: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: String?
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sign In")
                .font(.headline)
            
            OHTextField(
                title: "Email",
                text: $email,
                placeholder: "Enter your email",
                keyboardType: .emailAddress
            )
            
            OHTextField(
                title: "Password",
                text: $password,
                placeholder: "Enter your password",
                isSecure: true
            )
            
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                OHSecondaryButton(
                    title: "Cancel",
                    action: {
                        onCancel()
                        presentationMode.wrappedValue.dismiss()
                    }
                )
                
                OHPrimaryButton(
                    title: "Sign In",
                    action: {
                        isLoading = true
                        error = nil
                        
                        // Simulate sign in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isLoading = false
                            
                            if email.isEmpty || password.isEmpty {
                                error = "Please enter both email and password"
                            } else {
                                onSignIn(email, password)
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    },
                    isLoading: isLoading,
                    isDisabled: email.isEmpty || password.isEmpty
                )
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 350)
    }
}
```

## 3. MVVM Implementation for Features

### 3.1 Conversation Feature MVVM

```swift
// MARK: - Conversation List MVVM

// Conversation list view model
class ConversationListViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var error: NSError?
    @Published var conversationToRename: Conversation?
    
    private let conversationService: ConversationService
    private var cancellables = Set<AnyCancellable>()
    
    init(conversationService: ConversationService = ConversationService()) {
        self.conversationService = conversationService
        
        loadConversations()
        setupEventHandling()
    }
    
    // Load conversations
    func loadConversations() {
        isLoading = true
        error = nil
        
        conversationService.getConversations()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error as NSError
                    }
                },
                receiveValue: { [weak self] conversations in
                    self?.conversations = conversations
                }
            )
            .store(in: &cancellables)
    }
    
    // Create new conversation
    func createNewConversation() {
        isLoading = true
        error = nil
        
        conversationService.createConversation(title: "New Conversation")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error as NSError
                    }
                },
                receiveValue: { [weak self] conversation in
                    self?.conversations.insert(conversation, at: 0)
                }
            )
            .store(in: &cancellables)
    }
    
    // Start renaming conversation
    func startRenaming(_ conversation: Conversation) {
        conversationToRename = conversation
    }
    
    // Rename conversation
    func renameConversation(_ conversation: Conversation, newTitle: String) {
        isLoading = true
        error = nil
        
        conversationService.updateConversation(id: conversation.id, title: newTitle)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    self.conversationToRename = nil
                    
                    if case .failure(let error) = completion {
                        self.error = error as NSError
                    }
                },
                receiveValue: { [weak self] updatedConversation in
                    guard let self = self else { return }
                    
                    if let index = self.conversations.firstIndex(where: { $0.id == updatedConversation.id }) {
                        self.conversations[index] = updatedConversation
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // Delete conversation
    func deleteConversation(_ conversation: Conversation) {
        isLoading = true
        error = nil
        
        conversationService.deleteConversation(id: conversation.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error as NSError
                    }
                },
                receiveValue: { [weak self] success in
                    guard let self = self, success else { return }
                    
                    self.conversations.removeAll { $0.id == conversation.id }
                }
            )
            .store(in: &cancellables)
    }
    
    // Set up event handling
    private func setupEventHandling() {
        // Listen for conversation created events
        NotificationCenter.default.publisher(for: .conversationCreated)
            .compactMap { $0.object as? Conversation }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conversation in
                guard let self = self else { return }
                
                if !self.conversations.contains(where: { $0.id == conversation.id }) {
                    self.conversations.insert(conversation, at: 0)
                }
            }
            .store(in: &cancellables)
        
        // Listen for conversation updated events
        NotificationCenter.default.publisher(for: .conversationUpdated)
            .compactMap { $0.object as? Conversation }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conversation in
                guard let self = self else { return }
                
                if let index = self.conversations.firstIndex(where: { $0.id == conversation.id }) {
                    self.conversations[index] = conversation
                }
            }
            .store(in: &cancellables)
        
        // Listen for conversation deleted events
        NotificationCenter.default.publisher(for: .conversationDeleted)
            .compactMap { $0.object as? String }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conversationId in
                guard let self = self else { return }
                
                self.conversations.removeAll { $0.id == conversationId }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Conversation Detail MVVM

// Conversation view model
class ConversationViewModel: ObservableObject {
    @Published var conversation: Conversation?
    @Published var messageText = ""
    @Published var isLoading = false
    @Published var isAgentResponding = false
    @Published var error: NSError?
    @Published var codeBlockToShow: CodeBlock?
    
    private let conversationId: String
    private let conversationService: ConversationService
    private let messageService: MessageService
    private var cancellables = Set<AnyCancellable>()
    
    init(conversationId: String, conversationService: ConversationService = ConversationService(), messageService: MessageService = MessageService()) {
        self.conversationId = conversationId
        self.conversationService = conversationService
        self.messageService = messageService
        
        loadConversation()
        setupEventHandling()
    }
    
    // Load conversation
    func loadConversation() {
        isLoading = true
        error = nil
        
        conversationService.getConversation(id: conversationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error as NSError
                    }
                },
                receiveValue: { [weak self] conversation in
                    self?.conversation = conversation
                }
            )
            .store(in: &cancellables)
    }
    
    // Send message
    func sendMessage() {
        guard let conversation = conversation, !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let messageContent = messageText
        messageText = ""
        isAgentResponding = true
        
        messageService.sendMessage(conversationId: conversationId, content: messageContent)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error as NSError
                        self?.isAgentResponding = false
                    }
                },
                receiveValue: { [weak self] message in
                    guard let self = self else { return }
                    
                    // Add user message to conversation
                    var updatedConversation = conversation
                    updatedConversation.messages.append(message)
                    self.conversation = updatedConversation
                    
                    // Agent will respond via events
                }
            )
            .store(in: &cancellables)
    }
    
    // Update conversation title
    func updateTitle(_ newTitle: String) {
        guard let conversation = conversation else { return }
        
        conversationService.updateConversation(id: conversationId, title: newTitle)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error as NSError
                    }
                },
                receiveValue: { [weak self] updatedConversation in
                    self?.conversation = updatedConversation
                }
            )
            .store(in: &cancellables)
    }
    
    // Handle code block tap
    func handleCodeBlockTap(code: String, language: String) {
        codeBlockToShow = CodeBlock(code: code, language: language)
    }
    
    // Set up event handling
    private func setupEventHandling() {
        // Listen for message received events
        NotificationCenter.default.publisher(for: .messageReceived)
            .compactMap { $0.object as? MessageEvent }
            .filter { $0.conversationId == self.conversationId }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self, var conversation = self.conversation else { return }
                
                // Add message to conversation
                conversation.messages.append(event.message)
                self.conversation = conversation
            }
            .store(in: &cancellables)
        
        // Listen for agent thinking events
        NotificationCenter.default.publisher(for: .agentThinking)
            .compactMap { $0.object as? AgentEvent }
            .filter { $0.conversationId == self.conversationId }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isAgentResponding = true
            }
            .store(in: &cancellables)
        
        // Listen for agent response events
        NotificationCenter.default.publisher(for: .agentResponse)
            .compactMap { $0.object as? AgentResponseEvent }
            .filter { $0.conversationId == self.conversationId }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self, var conversation = self.conversation else { return }
                
                // Check if message already exists
                if let index = conversation.messages.firstIndex(where: { $0.id == event.messageId }) {
                    // Update existing message
                    conversation.messages[index].content = event.content
                } else {
                    // Add new message
                    let message = Message(
                        id: event.messageId,
                        source: .agent,
                        content: event.content,
                        timestamp: event.timestamp,
                        metadata: event.metadata?.mapValues { $0.value },
                        sequence: conversation.messages.count,
                        isAcknowledged: true
                    )
                    
                    conversation.messages.append(message)
                }
                
                self.conversation = conversation
                self.isAgentResponding = !event.isComplete
            }
            .store(in: &cancellables)
        
        // Listen for agent complete events
        NotificationCenter.default.publisher(for: .agentComplete)
            .compactMap { $0.object as? AgentEvent }
            .filter { $0.conversationId == self.conversationId }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isAgentResponding = false
            }
            .store(in: &cancellables)
    }
}

// Code block model
struct CodeBlock: Identifiable {
    let id = UUID()
    let code: String
    let language: String
}

// Message event model
struct MessageEvent {
    let conversationId: String
    let message: Message
}

// Agent event model
struct AgentEvent {
    let conversationId: String
}

// Agent response event model
struct AgentResponseEvent {
    let conversationId: String
    let messageId: String
    let content: String
    let isComplete: Bool
    let timestamp: Date
    let metadata: [String: AnyCodable]?
}

// Notification names
extension Notification.Name {
    static let conversationCreated = Notification.Name("com.openhands.mac.conversationCreated")
    static let conversationUpdated = Notification.Name("com.openhands.mac.conversationUpdated")
    static let conversationDeleted = Notification.Name("com.openhands.mac.conversationDeleted")
    static let messageReceived = Notification.Name("com.openhands.mac.messageReceived")
    static let agentThinking = Notification.Name("com.openhands.mac.agentThinking")
    static let agentResponse = Notification.Name("com.openhands.mac.agentResponse")
    static let agentComplete = Notification.Name("com.openhands.mac.agentComplete")
}
```

### 3.2 File Explorer Feature MVVM

```swift
// MARK: - File Explorer MVVM

// File explorer view model
class FileExplorerViewModel: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var currentPath = "/"
    @Published var isLoading = false
    @Published var error: NSError?
    @Published var showingNewFolderDialog = false
    @Published var showingUploadDialog = false
    @Published var fileToRename: FileItem?
    @Published var confirmationAlert: ConfirmationAlert?
    
    private let fileService: FileService
    private var cancellables = Set<AnyCancellable>()
    
    init(fileService: FileService = FileService()) {
        self.fileService = fileService
        
        loadFiles()
        setupEventHandling()
    }
    
    // Load files for current path
    func loadFiles() {
        isLoading = true
        error = nil
        
        fileService.getFiles(path: currentPath)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error as NSError
                    }
                },
                receiveValue: { [weak self] files in
                    self?.files = files
                }
            )
            .store(in: &cancellables)
    }
    
    // Navigate to path
    func navigateToPath(_ path: String) {
        currentPath = path
        loadFiles()
    }
    
    // Refresh current directory
    func refreshCurrentDirectory() {
        loadFiles()
    }
    
    // Show new folder dialog
    func showNewFolderDialog() {
        showingNewFolderDialog = true
    }
    
    // Create folder
    func createFolder(name: String) {
        isLoading = true
        error = nil
        
        let folderPath = currentPath.hasSuffix("/") ? "\(currentPath)\(name)" : "\(currentPath)/\(name)"
        
        fileService.createFolder(path: folderPath)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error as NSError
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        self?.loadFiles()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // Show upload dialog
    func showUploadDialog() {
        showingUploadDialog = true
    }
    
    // Upload file
    func uploadFile(url: URL) {
        isLoading = true
        error = nil
        
        fileService.uploadFile(sourceURL: url, destinationPath: currentPath)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error as NSError
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        self?.loadFiles()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // Show rename dialog
    func showRenameDialog(file: FileItem) {
        fileToRename = file
    }
    
    // Rename file
    func renameFile(file: FileItem, newName: String) {
        isLoading = true
        error = nil
        
        let directory = (file.path as NSString).deletingLastPathComponent
        let newPath = "\(directory)/\(newName)"
        
        fileService.renameFile(oldPath: file.path, newPath: newPath)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error as NSError
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        self?.loadFiles()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // Show delete confirmation
    func showDeleteConfirmation(file: FileItem) {
        confirmationAlert = ConfirmationAlert(
            title: "Delete \(file.isDirectory ? "Folder" : "File")",
            message: "Are you sure you want to delete \(file.name)? This action cannot be undone.",
            confirmButtonTitle: "Delete",
            action: { [weak self] in
                self?.deleteFile(file: file)
            }
        )
    }
    
    // Delete file
    func deleteFile(file: FileItem) {
        isLoading = true
        error = nil
        
        fileService.deleteFile(path: file.path)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error as NSError
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        self?.loadFiles()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // Search files
    func searchFiles(query: String) {
        if query.isEmpty {
            loadFiles()
            return
        }
        
        isLoading = true
        error = nil
        
        fileService.searchFiles(path: currentPath, query: query)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error as NSError
                    }
                },
                receiveValue: { [weak self] files in
                    self?.files = files
                }
            )
            .store(in: &cancellables)
    }
    
    // Set up event handling
    private func setupEventHandling() {
        // Listen for file created events
        NotificationCenter.default.publisher(for: .fileCreated)
            .compactMap { $0.object as? FileEvent }
            .filter { [weak self] event in
                guard let self = self else { return false }
                let directory = (event.path as NSString).deletingLastPathComponent
                return directory == self.currentPath
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadFiles()
            }
            .store(in: &cancellables)
        
        // Listen for file updated events
        NotificationCenter.default.publisher(for: .fileUpdated)
            .compactMap { $0.object as? FileEvent }
            .filter { [weak self] event in
                guard let self = self else { return false }
                let directory = (event.path as NSString).deletingLastPathComponent
                return directory == self.currentPath
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadFiles()
            }
            .store(in: &cancellables)
        
        // Listen for file deleted events
        NotificationCenter.default.publisher(for: .fileDeleted)
            .compactMap { $0.object as? FileEvent }
            .filter { [weak self] event in
                guard let self = self else { return false }
                let directory = (event.path as NSString).deletingLastPathComponent
                return directory == self.currentPath
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadFiles()
            }
            .store(in: &cancellables)
    }
}

// File detail view model
class FileDetailViewModel: ObservableObject {
    @Published var file: FileItem?
    @Published var fileContent: String?
    @Published var isLoading = false
    @Published var isLoadingContent = false
    @Published var error: NSError?
    
    private let filePath: String
    private let fileService: FileService
    private var cancellables = Set<AnyCancellable>()
    
    init(filePath: String, fileService: FileService = FileService()) {
        self.filePath = filePath
        self.fileService = fileService
        
        loadFile()
    }
    
    // Load file metadata
    func loadFile() {
        isLoading = true
        error = nil
        
        fileService.getFileInfo(path: filePath)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error as NSError
                    }
                },
                receiveValue: { [weak self] file in
                    guard let self = self else { return }
                    
                    self.file = file
                    
                    // Load content for text files
                    if !file.isDirectory && self.isTextFile(file) {
                        self.loadFileContent()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // Load file content
    func loadFileContent() {
        isLoadingContent = true
        
        fileService.getFileContent(path: filePath)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoadingContent = false
                    
                    if case .failure(let error) = completion {
                        self.error = error as NSError
                    }
                },
                receiveValue: { [weak self] content in
                    self?.fileContent = content
                }
            )
            .store(in: &cancellables)
    }
    
    // Check if file is a text file
    private func isTextFile(_ file: FileItem) -> Bool {
        let textExtensions = [
            "txt", "md", "markdown", "swift", "java", "cpp", "c", "h", "py", "js", "html", "css",
            "json", "xml", "yaml", "yml", "sh", "bash", "zsh", "properties", "config", "ini",
            "log", "csv", "tsv"
        ]
        
        return textExtensions.contains(file.extension?.lowercased() ?? "")
    }
}

// Confirmation alert model
struct ConfirmationAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let confirmButtonTitle: String
    let action: () -> Void
}

// File event model
struct FileEvent {
    let path: String
}

// Notification names
extension Notification.Name {
    static let fileCreated = Notification.Name("com.openhands.mac.fileCreated")
    static let fileUpdated = Notification.Name("com.openhands.mac.fileUpdated")
    static let fileDeleted = Notification.Name("com.openhands.mac.fileDeleted")
}
```

### 3.3 Settings Feature MVVM

```swift
// MARK: - Settings MVVM

// Settings view model
class SettingsViewModel: ObservableObject {
    @Published var theme: AppTheme {
        didSet {
            settingsService.updateSettings(key: "theme", value: theme.rawValue)
        }
    }
    
    @Published var fontSize: Int {
        didSet {
            settingsService.updateSettings(key: "fontSize", value: fontSize)
        }
    }
    
    @Published var enableNotifications: Bool {
        didSet {
            settingsService.updateSettings(key: "enableNotifications", value: enableNotifications)
        }
    }
    
    @Published var isSignedIn = false
    @Published var userEmail = ""
    @Published var cacheSize = "0 KB"
    @Published var appVersion = "1.0.0"
    
    @Published var showingSignInDialog = false
    @Published var alert: AlertItem?
    
    private let settingsService: SettingsService
    private let authService: AuthService
    private let cacheService: CacheService
    private var cancellables = Set<AnyCancellable>()
    
    init(settingsService: SettingsService = SettingsService(), authService: AuthService = AuthService(), cacheService: CacheService = CacheService()) {
        self.settingsService = settingsService
        self.authService = authService
        self.cacheService = cacheService
        
        // Initialize with default values
        self.theme = .system
        self.fontSize = 14
        self.enableNotifications = true
        
        loadSettings()
        loadAuthStatus()
        loadCacheSize()
        loadAppVersion()
    }
    
    // Load settings
    func loadSettings() {
        settingsService.getSettings()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] settings in
                    guard let self = self else { return }
                    
                    if let themeString = settings["theme"] as? String, let theme = AppTheme(rawValue: themeString) {
                        self.theme = theme
                    }
                    
                    if let fontSize = settings["fontSize"] as? Int {
                        self.fontSize = fontSize
                    }
                    
                    if let enableNotifications = settings["enableNotifications"] as? Bool {
                        self.enableNotifications = enableNotifications
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // Load authentication status
    func loadAuthStatus() {
        authService.getCurrentUser()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] user in
                    guard let self = self else { return }
                    
                    self.isSignedIn = user != nil
                    self.userEmail = user?.email ?? ""
                }
            )
            .store(in: &cancellables)
    }
    
    // Load cache size
    func loadCacheSize() {
        cacheService.getCacheSize()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] size in
                    self?.cacheSize = size
                }
            )
            .store(in: &cancellables)
    }
    
    // Load app version
    func loadAppVersion() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appVersion = version
        }
    }
    
    // Show sign in dialog
    func showSignInDialog() {
        showingSignInDialog = true
    }
    
    // Sign in
    func signIn(email: String, password: String) {
        authService.signIn(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.alert = AlertItem(
                            title: "Sign In Failed",
                            message: error.localizedDescription
                        )
                    }
                },
                receiveValue: { [weak self] user in
                    guard let self = self else { return }
                    
                    self.isSignedIn = true
                    self.userEmail = user.email
                    self.showingSignInDialog = false
                }
            )
            .store(in: &cancellables)
    }
    
    // Sign out
    func signOut() {
        authService.signOut()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.alert = AlertItem(
                            title: "Sign Out Failed",
                            message: error.localizedDescription
                        )
                    }
                },
                receiveValue: { [weak self] success in
                    guard let self = self, success else { return }
                    
                    self.isSignedIn = false
                    self.userEmail = ""
                }
            )
            .store(in: &cancellables)
    }
    
    // Clear cache
    func clearCache() {
        cacheService.clearCache()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.alert = AlertItem(
                            title: "Clear Cache Failed",
                            message: error.localizedDescription
                        )
                    }
                },
                receiveValue: { [weak self] success in
                    guard let self = self, success else { return }
                    
                    self.loadCacheSize()
                    
                    self.alert = AlertItem(
                        title: "Cache Cleared",
                        message: "Application cache has been cleared successfully."
                    )
                }
            )
            .store(in: &cancellables)
    }
    
    // Check for updates
    func checkForUpdates() {
        // Simulate update check
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.alert = AlertItem(
                title: "No Updates Available",
                message: "You are running the latest version of the application."
            )
        }
    }
}

// Alert item model
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
```

### 3.4 Service Layer

```swift
// MARK: - Service Layer

// Conversation service
class ConversationService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = APIClient.shared) {
        self.apiClient = apiClient
    }
    
    // Get all conversations
    func getConversations() -> AnyPublisher<[Conversation], Error> {
        return apiClient.request(endpoint: "conversations")
    }
    
    // Get conversation by ID
    func getConversation(id: String) -> AnyPublisher<Conversation, Error> {
        return apiClient.request(endpoint: "conversations/\(id)")
    }
    
    // Create new conversation
    func createConversation(title: String) -> AnyPublisher<Conversation, Error> {
        return apiClient.request(
            endpoint: "conversations",
            method: .post,
            parameters: ["title": title]
        )
    }
    
    // Update conversation
    func updateConversation(id: String, title: String) -> AnyPublisher<Conversation, Error> {
        return apiClient.request(
            endpoint: "conversations/\(id)",
            method: .put,
            parameters: ["title": title]
        )
    }
    
    // Delete conversation
    func deleteConversation(id: String) -> AnyPublisher<Bool, Error> {
        return apiClient.request(
            endpoint: "conversations/\(id)",
            method: .delete
        )
    }
}

// Message service
class MessageService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = APIClient.shared) {
        self.apiClient = apiClient
    }
    
    // Send message
    func sendMessage(conversationId: String, content: String) -> AnyPublisher<Message, Error> {
        return apiClient.request(
            endpoint: "conversations/\(conversationId)/messages",
            method: .post,
            parameters: ["content": content]
        )
    }
}

// File service
class FileService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = APIClient.shared) {
        self.apiClient = apiClient
    }
    
    // Get files in directory
    func getFiles(path: String) -> AnyPublisher<[FileItem], Error> {
        return apiClient.request(
            endpoint: "files",
            parameters: ["path": path]
        )
    }
    
    // Get file info
    func getFileInfo(path: String) -> AnyPublisher<FileItem, Error> {
        return apiClient.request(
            endpoint: "files/info",
            parameters: ["path": path]
        )
    }
    
    // Get file content
    func getFileContent(path: String) -> AnyPublisher<String, Error> {
        return apiClient.request(
            endpoint: "files/content",
            parameters: ["path": path]
        )
    }
    
    // Create folder
    func createFolder(path: String) -> AnyPublisher<Bool, Error> {
        return apiClient.request(
            endpoint: "files/folder",
            method: .post,
            parameters: ["path": path]
        )
    }
    
    // Upload file
    func uploadFile(sourceURL: URL, destinationPath: String) -> AnyPublisher<Bool, Error> {
        return apiClient.uploadFile(
            endpoint: "files/upload",
            fileURL: sourceURL,
            parameters: ["path": destinationPath]
        )
    }
    
    // Rename file
    func renameFile(oldPath: String, newPath: String) -> AnyPublisher<Bool, Error> {
        return apiClient.request(
            endpoint: "files/rename",
            method: .post,
            parameters: [
                "oldPath": oldPath,
                "newPath": newPath
            ]
        )
    }
    
    // Delete file
    func deleteFile(path: String) -> AnyPublisher<Bool, Error> {
        return apiClient.request(
            endpoint: "files/delete",
            method: .delete,
            parameters: ["path": path]
        )
    }
    
    // Search files
    func searchFiles(path: String, query: String) -> AnyPublisher<[FileItem], Error> {
        return apiClient.request(
            endpoint: "files/search",
            parameters: [
                "path": path,
                "query": query
            ]
        )
    }
}

// Settings service
class SettingsService {
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // Get all settings
    func getSettings() -> AnyPublisher<[String: Any], Error> {
        return Future<[String: Any], Error> { promise in
            let settings: [String: Any] = [
                "theme": self.userDefaults.string(forKey: "theme") ?? AppTheme.system.rawValue,
                "fontSize": self.userDefaults.integer(forKey: "fontSize") != 0 ? self.userDefaults.integer(forKey: "fontSize") : 14,
                "enableNotifications": self.userDefaults.bool(forKey: "enableNotifications")
            ]
            
            promise(.success(settings))
        }
        .eraseToAnyPublisher()
    }
    
    // Update setting
    func updateSettings(key: String, value: Any) {
        if let stringValue = value as? String {
            userDefaults.set(stringValue, forKey: key)
        } else if let intValue = value as? Int {
            userDefaults.set(intValue, forKey: key)
        } else if let boolValue = value as? Bool {
            userDefaults.set(boolValue, forKey: key)
        }
    }
}

// Auth service
class AuthService {
    private let apiClient: APIClient
    private let userDefaults: UserDefaults
    
    init(apiClient: APIClient = APIClient.shared, userDefaults: UserDefaults = .standard) {
        self.apiClient = apiClient
        self.userDefaults = userDefaults
    }
    
    // Get current user
    func getCurrentUser() -> AnyPublisher<User?, Error> {
        return Future<User?, Error> { promise in
            if let userData = self.userDefaults.data(forKey: "currentUser"),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                promise(.success(user))
            } else {
                promise(.success(nil))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // Sign in
    func signIn(email: String, password: String) -> AnyPublisher<User, Error> {
        // In a real app, this would call the API
        return Future<User, Error> { promise in
            // Simulate API call
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let user = User(id: UUID().uuidString, email: email, name: "Test User")
                
                // Save user to UserDefaults
                if let userData = try? JSONEncoder().encode(user) {
                    self.userDefaults.set(userData, forKey: "currentUser")
                }
                
                promise(.success(user))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // Sign out
    func signOut() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            // Clear user from UserDefaults
            self.userDefaults.removeObject(forKey: "currentUser")
            promise(.success(true))
        }
        .eraseToAnyPublisher()
    }
}

// Cache service
class CacheService {
    private let fileManager = FileManager.default
    
    // Get cache size
    func getCacheSize() -> AnyPublisher<String, Error> {
        return Future<String, Error> { promise in
            do {
                let cacheDirectory = try self.getCacheDirectory()
                let size = try self.directorySize(url: cacheDirectory)
                
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useAll]
                formatter.countStyle = .file
                let sizeString = formatter.string(fromByteCount: Int64(size))
                
                promise(.success(sizeString))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // Clear cache
    func clearCache() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            do {
                let cacheDirectory = try self.getCacheDirectory()
                let contents = try self.fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
                
                for fileURL in contents {
                    try self.fileManager.removeItem(at: fileURL)
                }
                
                promise(.success(true))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // Get cache directory
    private func getCacheDirectory() throws -> URL {
        return try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }
    
    // Calculate directory size
    private func directorySize(url: URL) throws -> UInt64 {
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        var size: UInt64 = 0
        
        for fileURL in contents {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if fileURL.hasDirectoryPath {
                size += try directorySize(url: fileURL)
            } else {
                size += attributes[.size] as? UInt64 ?? 0
            }
        }
        
        return size
    }
}

// User model
struct User: Codable {
    let id: String
    let email: String
    let name: String
}

// API client
class APIClient {
    static let shared = APIClient()
    
    private let baseURL: URL
    
    private init() {
        // In a real app, this would be configured from settings
        self.baseURL = URL(string: "https://api.openhands.dev")!
    }
    
    // Generic request method
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil
    ) -> AnyPublisher<T, Error> {
        // In a real app, this would make actual API requests
        return Future<T, Error> { promise in
            // Simulate API call
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // This is just a mock implementation
                // In a real app, this would make actual network requests
                
                // For demonstration purposes, return mock data based on endpoint
                if endpoint.contains("conversations") {
                    if let mockData = self.mockConversationData(endpoint: endpoint, method: method, parameters: parameters) as? T {
                        promise(.success(mockData))
                    } else {
                        promise(.failure(NSError(domain: "APIClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid mock data"])))
                    }
                } else if endpoint.contains("files") {
                    if let mockData = self.mockFileData(endpoint: endpoint, method: method, parameters: parameters) as? T {
                        promise(.success(mockData))
                    } else {
                        promise(.failure(NSError(domain: "APIClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid mock data"])))
                    }
                } else {
                    promise(.failure(NSError(domain: "APIClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown endpoint"])))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // Upload file
    func uploadFile(
        endpoint: String,
        fileURL: URL,
        parameters: [String: String]? = nil
    ) -> AnyPublisher<Bool, Error> {
        // In a real app, this would make actual API requests
        return Future<Bool, Error> { promise in
            // Simulate API call
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                promise(.success(true))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // Mock conversation data
    private func mockConversationData(endpoint: String, method: HTTPMethod, parameters: [String: Any]?) -> Any? {
        if endpoint == "conversations" {
            if method == .get {
                // Get all conversations
                return [
                    Conversation(
                        id: "1",
                        title: "First Conversation",
                        messages: [
                            Message(
                                id: "1",
                                source: .user,
                                content: "Hello, how can you help me?",
                                timestamp: Date().addingTimeInterval(-3600),
                                metadata: nil,
                                sequence: 0,
                                isAcknowledged: true
                            ),
                            Message(
                                id: "2",
                                source: .agent,
                                content: "I'm here to help you with any questions or tasks you have. What would you like assistance with today?",
                                timestamp: Date().addingTimeInterval(-3500),
                                metadata: nil,
                                sequence: 1,
                                isAcknowledged: true
                            )
                        ],
                        status: .active,
                        lastUpdated: Date().addingTimeInterval(-3500),
                        isArchived: false,
                        localDraft: nil,
                        unreadCount: 0,
                        version: 1
                    ),
                    Conversation(
                        id: "2",
                        title: "Second Conversation",
                        messages: [
                            Message(
                                id: "3",
                                source: .user,
                                content: "Can you help me with a coding problem?",
                                timestamp: Date().addingTimeInterval(-7200),
                                metadata: nil,
                                sequence: 0,
                                isAcknowledged: true
                            ),
                            Message(
                                id: "4",
                                source: .agent,
                                content: "Of course! Please describe the problem you're facing, and I'll do my best to help.",
                                timestamp: Date().addingTimeInterval(-7100),
                                metadata: nil,
                                sequence: 1,
                                isAcknowledged: true
                            )
                        ],
                        status: .active,
                        lastUpdated: Date().addingTimeInterval(-7100),
                        isArchived: false,
                        localDraft: nil,
                        unreadCount: 0,
                        version: 1
                    )
                ]
            } else if method == .post {
                // Create new conversation
                return Conversation(
                    id: UUID().uuidString,
                    title: parameters?["title"] as? String ?? "New Conversation",
                    messages: [],
                    status: .active,
                    lastUpdated: Date(),
                    isArchived: false,
                    localDraft: nil,
                    unreadCount: 0,
                    version: 1
                )
            }
        } else if endpoint.contains("conversations/") {
            let components = endpoint.split(separator: "/")
            if components.count >= 2 {
                let conversationId = String(components[1])
                
                if method == .get {
                    // Get conversation by ID
                    if conversationId == "1" {
                        return Conversation(
                            id: "1",
                            title: "First Conversation",
                            messages: [
                                Message(
                                    id: "1",
                                    source: .user,
                                    content: "Hello, how can you help me?",
                                    timestamp: Date().addingTimeInterval(-3600),
                                    metadata: nil,
                                    sequence: 0,
                                    isAcknowledged: true
                                ),
                                Message(
                                    id: "2",
                                    source: .agent,
                                    content: "I'm here to help you with any questions or tasks you have. What would you like assistance with today?",
                                    timestamp: Date().addingTimeInterval(-3500),
                                    metadata: nil,
                                    sequence: 1,
                                    isAcknowledged: true
                                )
                            ],
                            status: .active,
                            lastUpdated: Date().addingTimeInterval(-3500),
                            isArchived: false,
                            localDraft: nil,
                            unreadCount: 0,
                            version: 1
                        )
                    } else if conversationId == "2" {
                        return Conversation(
                            id: "2",
                            title: "Second Conversation",
                            messages: [
                                Message(
                                    id: "3",
                                    source: .user,
                                    content: "Can you help me with a coding problem?",
                                    timestamp: Date().addingTimeInterval(-7200),
                                    metadata: nil,
                                    sequence: 0,
                                    isAcknowledged: true
                                ),
                                Message(
                                    id: "4",
                                    source: .agent,
                                    content: "Of course! Please describe the problem you're facing, and I'll do my best to help.",
                                    timestamp: Date().addingTimeInterval(-7100),
                                    metadata: nil,
                                    sequence: 1,
                                    isAcknowledged: true
                                )
                            ],
                            status: .active,
                            lastUpdated: Date().addingTimeInterval(-7100),
                            isArchived: false,
                            localDraft: nil,
                            unreadCount: 0,
                            version: 1
                        )
                    }
                } else if method == .put {
                    // Update conversation
                    return Conversation(
                        id: conversationId,
                        title: parameters?["title"] as? String ?? "Updated Conversation",
                        messages: [],
                        status: .active,
                        lastUpdated: Date(),
                        isArchived: false,
                        localDraft: nil,
                        unreadCount: 0,
                        version: 2
                    )
                } else if method == .delete {
                    // Delete conversation
                    return true
                }
                
                // Handle messages
                if components.count >= 4 && components[2] == "messages" {
                    if method == .post {
                        // Send message
                        return Message(
                            id: UUID().uuidString,
                            source: .user,
                            content: parameters?["content"] as? String ?? "",
                            timestamp: Date(),
                            metadata: nil,
                            sequence: 2,
                            isAcknowledged: true
                        )
                    }
                }
            }
        }
        
        return nil
    }
    
    // Mock file data
    private func mockFileData(endpoint: String, method: HTTPMethod, parameters: [String: Any]?) -> Any? {
        if endpoint == "files" {
            // Get files in directory
            let path = parameters?["path"] as? String ?? "/"
            
            if path == "/" {
                return [
                    FileItem(
                        name: "Documents",
                        path: "/Documents",
                        isDirectory: true,
                        size: nil,
                        extension: nil,
                        itemCount: 5
                    ),
                    FileItem(
                        name: "Projects",
                        path: "/Projects",
                        isDirectory: true,
                        size: nil,
                        extension: nil,
                        itemCount: 3
                    ),
                    FileItem(
                        name: "README.md",
                        path: "/README.md",
                        isDirectory: false,
                        size: 1024,
                        extension: "md",
                        itemCount: nil
                    ),
                    FileItem(
                        name: "example.swift",
                        path: "/example.swift",
                        isDirectory: false,
                        size: 2048,
                        extension: "swift",
                        itemCount: nil
                    )
                ]
            } else if path == "/Documents" {
                return [
                    FileItem(
                        name: "Notes",
                        path: "/Documents/Notes",
                        isDirectory: true,
                        size: nil,
                        extension: nil,
                        itemCount: 2
                    ),
                    FileItem(
                        name: "report.pdf",
                        path: "/Documents/report.pdf",
                        isDirectory: false,
                        size: 5120,
                        extension: "pdf",
                        itemCount: nil
                    ),
                    FileItem(
                        name: "presentation.pptx",
                        path: "/Documents/presentation.pptx",
                        isDirectory: false,
                        size: 10240,
                        extension: "pptx",
                        itemCount: nil
                    )
                ]
            }
        } else if endpoint == "files/info" {
            // Get file info
            let path = parameters?["path"] as? String ?? "/"
            
            if path == "/README.md" {
                return FileItem(
                    name: "README.md",
                    path: "/README.md",
                    isDirectory: false,
                    size: 1024,
                    extension: "md",
                    itemCount: nil
                )
            } else if path == "/example.swift" {
                return FileItem(
                    name: "example.swift",
                    path: "/example.swift",
                    isDirectory: false,
                    size: 2048,
                    extension: "swift",
                    itemCount: nil
                )
            }
        } else if endpoint == "files/content" {
            // Get file content
            let path = parameters?["path"] as? String ?? "/"
            
            if path == "/README.md" {
                return "# OpenHands Project\n\nThis is a sample README file for the OpenHands project.\n\n## Features\n\n- Feature 1\n- Feature 2\n- Feature 3"
            } else if path == "/example.swift" {
                return "import Foundation\n\nclass Example {\n    func sayHello() {\n        print(\"Hello, world!\")\n    }\n}"
            }
        } else if endpoint == "files/folder" && method == .post {
            // Create folder
            return true
        } else if endpoint == "files/rename" && method == .post {
            // Rename file
            return true
        } else if endpoint == "files/delete" && method == .delete {
            // Delete file
            return true
        } else if endpoint == "files/search" {
            // Search files
            let query = parameters?["query"] as? String ?? ""
            
            if query.contains("swift") {
                return [
                    FileItem(
                        name: "example.swift",
                        path: "/example.swift",
                        isDirectory: false,
                        size: 2048,
                        extension: "swift",
                        itemCount: nil
                    ),
                    FileItem(
                        name: "main.swift",
                        path: "/Projects/SwiftProject/main.swift",
                        isDirectory: false,
                        size: 1536,
                        extension: "swift",
                        itemCount: nil
                    )
                ]
            }
        }
        
        return nil
    }
}

// HTTP method enum
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
```

This implementation guide provides a comprehensive approach to UI component architecture for the Mac client, covering component breakdown, view hierarchy, navigation flow, and MVVM implementation for each feature.