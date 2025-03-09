# Performance Considerations for Mac Client

This document outlines implementation details for optimizing performance in the Mac client, including handling large outputs, maintaining UI responsiveness, and managing memory for long-running sessions.

## 1. Handling Large Agent Outputs

### 1.1 Chunked Message Processing

```swift
class ChunkedMessageProcessor {
    // Maximum size of a single chunk to process at once
    private let maxChunkSize = 10_000 // characters
    
    // Process large message in chunks
    func processLargeMessage(_ message: Message, handler: @escaping (MessageChunk) -> Void, completion: @escaping () -> Void) {
        let content = message.content
        
        // If content is small enough, process it directly
        if content.count <= maxChunkSize {
            let chunk = MessageChunk(
                id: message.id,
                content: content,
                isComplete: true,
                index: 0,
                totalChunks: 1
            )
            handler(chunk)
            completion()
            return
        }
        
        // Split content into chunks
        let chunks = splitIntoChunks(content: content)
        
        // Process chunks with a delay to allow UI to update
        processChunks(chunks, messageId: message.id, handler: handler, completion: completion)
    }
    
    // Split content into manageable chunks
    private func splitIntoChunks(content: String) -> [String] {
        var chunks: [String] = []
        var remainingContent = content
        
        while !remainingContent.isEmpty {
            let chunkEndIndex = remainingContent.index(
                remainingContent.startIndex,
                offsetBy: min(maxChunkSize, remainingContent.count)
            )
            
            // Try to find a natural break point (newline, space, punctuation)
            var actualEndIndex = chunkEndIndex
            if chunkEndIndex < remainingContent.endIndex {
                let searchRange = remainingContent.index(chunkEndIndex, offsetBy: -100, limitedBy: remainingContent.startIndex) ?? remainingContent.startIndex
                ..<chunkEndIndex
                
                if let newlineIndex = remainingContent.lastIndex(of: "\n", in: searchRange) {
                    actualEndIndex = remainingContent.index(after: newlineIndex)
                } else if let spaceIndex = remainingContent.lastIndex(of: " ", in: searchRange) {
                    actualEndIndex = remainingContent.index(after: spaceIndex)
                } else if let periodIndex = remainingContent.lastIndex(of: ".", in: searchRange) {
                    actualEndIndex = remainingContent.index(after: periodIndex)
                }
            }
            
            let chunk = String(remainingContent[..<actualEndIndex])
            chunks.append(chunk)
            
            remainingContent = String(remainingContent[actualEndIndex...])
        }
        
        return chunks
    }
    
    // Process chunks with a delay to allow UI to update
    private func processChunks(_ chunks: [String], messageId: String, handler: @escaping (MessageChunk) -> Void, completion: @escaping () -> Void) {
        let totalChunks = chunks.count
        
        func processNextChunk(index: Int) {
            guard index < totalChunks else {
                completion()
                return
            }
            
            let chunk = MessageChunk(
                id: messageId,
                content: chunks[index],
                isComplete: index == totalChunks - 1,
                index: index,
                totalChunks: totalChunks
            )
            
            handler(chunk)
            
            // Schedule next chunk with a small delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                processNextChunk(index: index + 1)
            }
        }
        
        // Start processing chunks
        processNextChunk(index: 0)
    }
}

// Message chunk model
struct MessageChunk {
    let id: String
    let content: String
    let isComplete: Bool
    let index: Int
    let totalChunks: Int
}
```

### 1.2 Virtualized Text Display

```swift
struct VirtualizedTextView: NSViewRepresentable {
    let text: NSAttributedString
    let maxHeight: CGFloat
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsUndo = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }
        
        // Update text content
        textView.textStorage?.setAttributedString(text)
        
        // Adjust height based on content
        let contentHeight = min(textView.contentSize.height, maxHeight)
        scrollView.frame.size.height = contentHeight
    }
}

// Extension to get content size of NSTextView
extension NSTextView {
    var contentSize: CGSize {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else {
            return .zero
        }
        
        layoutManager.ensureLayout(for: textContainer)
        return layoutManager.usedRect(for: textContainer).size
    }
}
```

### 1.3 Lazy Loading for Code Blocks

```swift
class CodeBlockManager {
    private var loadedBlocks: [String: NSAttributedString] = [:]
    private let syntaxHighlighter: SyntaxHighlighter
    private let processingQueue = DispatchQueue(label: "com.openhands.mac.codeblocks", qos: .userInitiated)
    
    init(syntaxHighlighter: SyntaxHighlighter) {
        self.syntaxHighlighter = syntaxHighlighter
    }
    
    // Get or load code block
    func getCodeBlock(id: String, code: String, language: String, completion: @escaping (NSAttributedString) -> Void) {
        // Check if already loaded
        if let loadedBlock = loadedBlocks[id] {
            completion(loadedBlock)
            return
        }
        
        // Process on background queue
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Apply syntax highlighting
            let highlightedCode = self.syntaxHighlighter.highlight(code: code, language: language)
            
            // Cache result
            self.loadedBlocks[id] = highlightedCode
            
            // Return on main queue
            DispatchQueue.main.async {
                completion(highlightedCode)
            }
        }
    }
    
    // Preload code blocks
    func preloadCodeBlocks(codeBlocks: [(id: String, code: String, language: String)]) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (id, code, language) in codeBlocks {
                if self.loadedBlocks[id] == nil {
                    let highlightedCode = self.syntaxHighlighter.highlight(code: code, language: language)
                    self.loadedBlocks[id] = highlightedCode
                }
            }
        }
    }
    
    // Clear cache for blocks no longer needed
    func clearUnusedBlocks(activeBlockIds: Set<String>) {
        let keysToRemove = Set(loadedBlocks.keys).subtracting(activeBlockIds)
        
        for key in keysToRemove {
            loadedBlocks.removeValue(forKey: key)
        }
    }
}

// Lazy loading code block view
struct LazyCodeBlockView: View {
    let id: String
    let code: String
    let language: String
    
    @ObservedObject private var viewModel: CodeBlockViewModel
    
    init(id: String, code: String, language: String, codeBlockManager: CodeBlockManager) {
        self.id = id
        self.code = code
        self.language = language
        self.viewModel = CodeBlockViewModel(
            id: id,
            code: code,
            language: language,
            codeBlockManager: codeBlockManager
        )
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                CodeBlockView(attributedCode: viewModel.highlightedCode)
            }
        }
        .onAppear {
            viewModel.loadCodeBlock()
        }
    }
}

class CodeBlockViewModel: ObservableObject {
    let id: String
    let code: String
    let language: String
    
    @Published var highlightedCode: NSAttributedString = NSAttributedString()
    @Published var isLoading = true
    
    private let codeBlockManager: CodeBlockManager
    
    init(id: String, code: String, language: String, codeBlockManager: CodeBlockManager) {
        self.id = id
        self.code = code
        self.language = language
        self.codeBlockManager = codeBlockManager
    }
    
    func loadCodeBlock() {
        isLoading = true
        
        codeBlockManager.getCodeBlock(id: id, code: code, language: language) { [weak self] attributedCode in
            guard let self = self else { return }
            
            self.highlightedCode = attributedCode
            self.isLoading = false
        }
    }
}

struct CodeBlockView: NSViewRepresentable {
    let attributedCode: NSAttributedString
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsUndo = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }
        
        textView.textStorage?.setAttributedString(attributedCode)
    }
}
```

### 1.4 Image Optimization

```swift
class ImageOptimizer {
    // Maximum dimensions for displayed images
    private let maxImageDimension: CGFloat = 1200
    
    // Optimize image for display
    func optimizeImage(_ image: NSImage) -> NSImage {
        let originalSize = image.size
        
        // Check if image needs resizing
        if originalSize.width <= maxImageDimension && originalSize.height <= maxImageDimension {
            return image
        }
        
        // Calculate new size while maintaining aspect ratio
        let newSize: NSSize
        if originalSize.width > originalSize.height {
            let ratio = maxImageDimension / originalSize.width
            newSize = NSSize(width: maxImageDimension, height: originalSize.height * ratio)
        } else {
            let ratio = maxImageDimension / originalSize.height
            newSize = NSSize(width: originalSize.width * ratio, height: maxImageDimension)
        }
        
        // Create resized image
        let resizedImage = NSImage(size: newSize)
        
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        
        return resizedImage
    }
    
    // Load and optimize image from URL
    func loadAndOptimizeImage(from url: URL, completion: @escaping (NSImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let image = NSImage(contentsOf: url) {
                let optimizedImage = self.optimizeImage(image)
                
                DispatchQueue.main.async {
                    completion(optimizedImage)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // Load and optimize image from data
    func loadAndOptimizeImage(from data: Data, completion: @escaping (NSImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let image = NSImage(data: data) {
                let optimizedImage = self.optimizeImage(image)
                
                DispatchQueue.main.async {
                    completion(optimizedImage)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}

// Lazy loading image view
struct LazyImageView: View {
    let url: URL
    
    @StateObject private var viewModel = LazyImageViewModel()
    
    var body: some View {
        Group {
            if let image = viewModel.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .frame(width: 200, height: 150)
            }
        }
        .onAppear {
            viewModel.loadImage(from: url)
        }
    }
}

class LazyImageViewModel: ObservableObject {
    @Published var image: NSImage?
    
    private let imageOptimizer = ImageOptimizer()
    
    func loadImage(from url: URL) {
        imageOptimizer.loadAndOptimizeImage(from: url) { [weak self] image in
            self?.image = image
        }
    }
}
```

## 2. UI Responsiveness During Heavy Operations

### 2.1 Background Processing Manager

```swift
class BackgroundProcessingManager {
    private let processingQueue = DispatchQueue(label: "com.openhands.mac.backgroundProcessing", qos: .userInitiated, attributes: .concurrent)
    private let serialQueue = DispatchQueue(label: "com.openhands.mac.serialProcessing", qos: .userInitiated)
    
    // Run task in background
    func runInBackground<T>(task: @escaping () -> T, completion: @escaping (T) -> Void) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let result = task()
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    // Run tasks in sequence
    func runSequentially<T>(tasks: [() -> T], completion: @escaping ([T]) -> Void) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            let results = tasks.map { $0() }
            
            DispatchQueue.main.async {
                completion(results)
            }
        }
    }
    
    // Run task with progress reporting
    func runWithProgress<T>(
        task: @escaping (@escaping (Double) -> Void) -> T,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (T) -> Void
    ) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let result = task { progress in
                DispatchQueue.main.async {
                    progressHandler(progress)
                }
            }
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    // Cancel all operations
    func cancelAllOperations() {
        // Not directly possible with GCD, but we can use a flag
        // to signal cancellation to long-running operations
        NotificationCenter.default.post(name: .cancelBackgroundOperations, object: nil)
    }
}

extension Notification.Name {
    static let cancelBackgroundOperations = Notification.Name("com.openhands.mac.cancelBackgroundOperations")
}
```

### 2.2 UI Throttling

```swift
class UIUpdateThrottler {
    private var lastUpdateTime: Date = Date.distantPast
    private var pendingUpdate: (() -> Void)?
    private var updateTimer: Timer?
    private let minimumInterval: TimeInterval
    
    init(minimumInterval: TimeInterval = 0.1) {
        self.minimumInterval = minimumInterval
    }
    
    // Schedule UI update with throttling
    func scheduleUpdate(_ update: @escaping () -> Void) {
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        
        // Cancel any pending update
        pendingUpdate = update
        updateTimer?.invalidate()
        
        if timeSinceLastUpdate >= minimumInterval {
            // Update immediately
            performUpdate()
        } else {
            // Schedule update after delay
            let delay = minimumInterval - timeSinceLastUpdate
            updateTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.performUpdate()
            }
        }
    }
    
    private func performUpdate() {
        guard let update = pendingUpdate else {
            return
        }
        
        // Perform the update
        update()
        
        // Update timestamp
        lastUpdateTime = Date()
        pendingUpdate = nil
    }
    
    // Cancel pending update
    func cancelPendingUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
        pendingUpdate = nil
    }
}

// Example usage in a view model
class ThrottledViewModel: ObservableObject {
    @Published var data: [String] = []
    
    private let throttler = UIUpdateThrottler(minimumInterval: 0.1)
    private var internalData: [String] = []
    
    // Add items with throttled UI updates
    func addItems(_ newItems: [String]) {
        // Update internal data immediately
        internalData.append(contentsOf: newItems)
        
        // Schedule throttled UI update
        throttler.scheduleUpdate { [weak self] in
            guard let self = self else { return }
            
            // Update published property on main thread
            DispatchQueue.main.async {
                self.data = self.internalData
            }
        }
    }
}
```

### 2.3 Progressive Loading Indicators

```swift
struct ProgressiveLoadingView<Content: View>: View {
    let isLoading: Bool
    let progress: Double
    let content: () -> Content
    
    @State private var showingProgress = false
    
    var body: some View {
        ZStack {
            // Content
            content()
                .opacity(isLoading ? 0.5 : 1.0)
                .disabled(isLoading)
            
            // Loading indicator
            if isLoading {
                VStack {
                    if progress > 0 && progress < 1.0 {
                        // Show progress bar for known progress
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 200)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if showingProgress {
                        // Show indeterminate spinner for unknown progress
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                .cornerRadius(10)
                .shadow(radius: 5)
            }
        }
        .onAppear {
            // Delay showing progress indicator for quick operations
            if isLoading {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if isLoading {
                        showingProgress = true
                    }
                }
            }
        }
        .onChange(of: isLoading) { newValue in
            if !newValue {
                showingProgress = false
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if isLoading {
                        showingProgress = true
                    }
                }
            }
        }
    }
}

// Example usage
struct ContentLoadingView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        ProgressiveLoadingView(
            isLoading: viewModel.isLoading,
            progress: viewModel.loadingProgress
        ) {
            List(viewModel.items, id: \.id) { item in
                Text(item.title)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }
}

class ContentViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var loadingProgress = 0.0
    
    func loadData() {
        isLoading = true
        loadingProgress = 0.0
        
        // Simulate progressive loading
        let totalItems = 100
        var loadedItems = 0
        
        func loadNextBatch() {
            guard loadedItems < totalItems else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadingProgress = 1.0
                }
                return
            }
            
            // Load a batch of items
            let batchSize = 10
            let newItems = (0..<batchSize).map { i in
                Item(id: UUID().uuidString, title: "Item \(loadedItems + i)")
            }
            
            loadedItems += batchSize
            
            // Update progress
            let progress = Double(loadedItems) / Double(totalItems)
            
            DispatchQueue.main.async {
                self.items.append(contentsOf: newItems)
                self.loadingProgress = progress
                
                // Schedule next batch
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    loadNextBatch()
                }
            }
        }
        
        // Start loading
        loadNextBatch()
    }
}

struct Item {
    let id: String
    let title: String
}
```

### 2.4 Operation Cancellation

```swift
class CancellableOperation<T> {
    private var isCancelled = false
    private var isExecuting = false
    private var task: ((@escaping (Double) -> Void, _ isCancelled: () -> Bool) -> T)?
    private var progressHandler: ((Double) -> Void)?
    private var completionHandler: ((Result<T, Error>) -> Void)?
    
    init(task: @escaping (@escaping (Double) -> Void, _ isCancelled: () -> Bool) -> T) {
        self.task = task
    }
    
    // Set progress handler
    func onProgress(_ handler: @escaping (Double) -> Void) -> CancellableOperation<T> {
        progressHandler = handler
        return self
    }
    
    // Set completion handler
    func onCompletion(_ handler: @escaping (Result<T, Error>) -> Void) -> CancellableOperation<T> {
        completionHandler = handler
        return self
    }
    
    // Start the operation
    func start() {
        guard !isExecuting && !isCancelled else {
            return
        }
        
        isExecuting = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let task = self.task else {
                return
            }
            
            do {
                // Execute task with progress reporting and cancellation check
                let result = task(
                    { [weak self] progress in
                        guard let self = self else { return }
                        
                        DispatchQueue.main.async {
                            self.progressHandler?(progress)
                        }
                    },
                    { [weak self] in
                        return self?.isCancelled ?? true
                    }
                )
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !self.isCancelled else { return }
                    
                    self.completionHandler?(.success(result))
                    self.isExecuting = false
                    self.task = nil
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.completionHandler?(.failure(error))
                    self.isExecuting = false
                    self.task = nil
                }
            }
        }
    }
    
    // Cancel the operation
    func cancel() {
        isCancelled = true
        
        if !isExecuting {
            task = nil
            completionHandler?(.failure(NSError(domain: "CancellableOperation", code: -999, userInfo: [
                NSLocalizedDescriptionKey: "Operation was cancelled"
            ])))
        }
    }
}

// Example usage
class SearchViewModel: ObservableObject {
    @Published var results: [SearchResult] = []
    @Published var isSearching = false
    @Published var progress = 0.0
    
    private var currentOperation: CancellableOperation<[SearchResult]>?
    
    func search(query: String) {
        // Cancel any ongoing search
        cancelSearch()
        
        // Start new search
        isSearching = true
        progress = 0.0
        
        currentOperation = CancellableOperation<[SearchResult]> { progressHandler, isCancelled in
            // Simulate search operation
            var searchResults: [SearchResult] = []
            
            for i in 0..<100 {
                // Check for cancellation
                if isCancelled() {
                    throw NSError(domain: "SearchViewModel", code: -999, userInfo: [
                        NSLocalizedDescriptionKey: "Search was cancelled"
                    ])
                }
                
                // Simulate work
                Thread.sleep(forTimeInterval: 0.02)
                
                // Add result
                searchResults.append(SearchResult(id: UUID().uuidString, title: "Result \(i) for \(query)"))
                
                // Report progress
                let progress = Double(i + 1) / 100.0
                progressHandler(progress)
            }
            
            return searchResults
        }
        .onProgress { [weak self] progress in
            self?.progress = progress
        }
        .onCompletion { [weak self] result in
            guard let self = self else { return }
            
            self.isSearching = false
            
            switch result {
            case .success(let results):
                self.results = results
            case .failure(let error):
                print("Search failed: \(error)")
                self.results = []
            }
            
            self.currentOperation = nil
        }
        
        currentOperation?.start()
    }
    
    func cancelSearch() {
        currentOperation?.cancel()
        currentOperation = nil
        isSearching = false
    }
}

struct SearchResult {
    let id: String
    let title: String
}
```

## 3. Memory Management for Long-Running Sessions

### 3.1 Memory Monitor

```swift
class MemoryMonitor {
    // Memory usage thresholds
    private let warningThreshold: Double = 0.7 // 70% of available memory
    private let criticalThreshold: Double = 0.85 // 85% of available memory
    
    private var timer: Timer?
    private var observers: [UUID: (MemoryStatus) -> Void] = [:]
    
    init() {
        // Start monitoring
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // Start periodic memory monitoring
    func startMonitoring(interval: TimeInterval = 5.0) {
        stopMonitoring()
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkMemoryUsage()
        }
    }
    
    // Stop monitoring
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    // Add observer for memory status changes
    func addObserver(_ observer: @escaping (MemoryStatus) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        
        // Immediately notify with current status
        let status = currentMemoryStatus()
        observer(status)
        
        return id
    }
    
    // Remove observer
    func removeObserver(id: UUID) {
        observers.removeValue(forKey: id)
    }
    
    // Check memory usage and notify observers if needed
    private func checkMemoryUsage() {
        let status = currentMemoryStatus()
        
        // Notify all observers
        for observer in observers.values {
            observer(status)
        }
        
        // Take action based on memory status
        switch status.level {
        case .critical:
            NotificationCenter.default.post(name: .memoryStatusCritical, object: status)
        case .warning:
            NotificationCenter.default.post(name: .memoryStatusWarning, object: status)
        case .normal:
            break
        }
    }
    
    // Get current memory status
    func currentMemoryStatus() -> MemoryStatus {
        let memoryUsage = getMemoryUsage()
        
        let level: MemoryLevel
        if memoryUsage.usedPercentage >= criticalThreshold {
            level = .critical
        } else if memoryUsage.usedPercentage >= warningThreshold {
            level = .warning
        } else {
            level = .normal
        }
        
        return MemoryStatus(
            level: level,
            usedMemory: memoryUsage.used,
            totalMemory: memoryUsage.total,
            usedPercentage: memoryUsage.usedPercentage
        )
    }
    
    // Get memory usage information
    private func getMemoryUsage() -> (used: UInt64, total: UInt64, usedPercentage: Double) {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        var used: UInt64 = 0
        if result == KERN_SUCCESS {
            used = UInt64(taskInfo.phys_footprint)
        }
        
        // Get total physical memory
        let total = ProcessInfo.processInfo.physicalMemory
        
        // Calculate percentage
        let percentage = Double(used) / Double(total)
        
        return (used, total, percentage)
    }
}

// Memory status model
struct MemoryStatus {
    let level: MemoryLevel
    let usedMemory: UInt64
    let totalMemory: UInt64
    let usedPercentage: Double
    
    var formattedUsedMemory: String {
        return formatBytes(usedMemory)
    }
    
    var formattedTotalMemory: String {
        return formatBytes(totalMemory)
    }
    
    var formattedPercentage: String {
        return String(format: "%.1f%%", usedPercentage * 100)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

enum MemoryLevel {
    case normal
    case warning
    case critical
}

extension Notification.Name {
    static let memoryStatusWarning = Notification.Name("com.openhands.mac.memoryStatusWarning")
    static let memoryStatusCritical = Notification.Name("com.openhands.mac.memoryStatusCritical")
}
```

### 3.2 Cache Manager

```swift
class CacheManager {
    // Singleton instance
    static let shared = CacheManager()
    
    // Memory cache
    private let memoryCache = NSCache<NSString, AnyObject>()
    
    // Disk cache
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // Memory monitor
    private let memoryMonitor = MemoryMonitor()
    private var memoryMonitorId: UUID?
    
    private init() {
        // Set up cache directory
        if let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            cacheDirectory = cachesDirectory.appendingPathComponent("com.openhands.mac.cache")
            
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: cacheDirectory.path) {
                try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            }
        } else {
            // Fallback to temporary directory
            cacheDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.openhands.mac.cache")
        }
        
        // Configure memory cache
        memoryCache.name = "com.openhands.mac.memoryCache"
        memoryCache.countLimit = 100
        
        // Set up memory monitoring
        setupMemoryMonitoring()
    }
    
    // Set up memory monitoring
    private func setupMemoryMonitoring() {
        memoryMonitorId = memoryMonitor.addObserver { [weak self] status in
            guard let self = self else { return }
            
            // Adjust cache size based on memory pressure
            switch status.level {
            case .normal:
                self.memoryCache.countLimit = 100
            case .warning:
                self.memoryCache.countLimit = 50
                self.trimMemoryCache()
            case .critical:
                self.memoryCache.countLimit = 20
                self.clearMemoryCache()
            }
        }
    }
    
    // MARK: - Memory Cache
    
    // Store item in memory cache
    func storeInMemory<T: AnyObject>(object: T, forKey key: String) {
        memoryCache.setObject(object, forKey: key as NSString)
    }
    
    // Retrieve item from memory cache
    func retrieveFromMemory<T: AnyObject>(forKey key: String) -> T? {
        return memoryCache.object(forKey: key as NSString) as? T
    }
    
    // Remove item from memory cache
    func removeFromMemory(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
    }
    
    // Clear memory cache
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    // Trim memory cache to reduce size
    func trimMemoryCache() {
        // This is a simple implementation that just removes half the objects
        // A more sophisticated approach would use access time or priority
        let allKeys = getAllMemoryCacheKeys()
        let keysToRemove = Array(allKeys.prefix(allKeys.count / 2))
        
        for key in keysToRemove {
            memoryCache.removeObject(forKey: key as NSString)
        }
    }
    
    // Get all keys in memory cache
    private func getAllMemoryCacheKeys() -> [String] {
        // NSCache doesn't provide a way to enumerate keys
        // This is a workaround using associated objects
        var keys: [String] = []
        
        // This is a placeholder - in a real implementation,
        // you would need to track keys separately
        return keys
    }
    
    // MARK: - Disk Cache
    
    // Store data in disk cache
    func storeOnDisk(data: Data, forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        do {
            try data.write(to: fileURL)
        } catch {
            print("Failed to write to disk cache: \(error)")
        }
    }
    
    // Retrieve data from disk cache
    func retrieveFromDisk(forKey key: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            print("Failed to read from disk cache: \(error)")
            return nil
        }
    }
    
    // Remove item from disk cache
    func removeFromDisk(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            print("Failed to remove from disk cache: \(error)")
        }
    }
    
    // Clear disk cache
    func clearDiskCache() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("Failed to clear disk cache: \(error)")
        }
    }
    
    // Get disk cache size
    func getDiskCacheSize() -> UInt64 {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            return contents.reduce(0) { total, fileURL in
                guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                      let size = attributes[.size] as? UInt64 else {
                    return total
                }
                
                return total + size
            }
        } catch {
            print("Failed to get disk cache size: \(error)")
            return 0
        }
    }
    
    // Trim disk cache to target size
    func trimDiskCache(toSize targetSize: UInt64) {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
            )
            
            // Sort by creation date (oldest first)
            let sortedContents = try contents.sorted { fileURL1, fileURL2 in
                let attributes1 = try fileURL1.resourceValues(forKeys: [.creationDateKey])
                let attributes2 = try fileURL2.resourceValues(forKeys: [.creationDateKey])
                
                guard let date1 = attributes1.creationDate,
                      let date2 = attributes2.creationDate else {
                    return false
                }
                
                return date1 < date2
            }
            
            var currentSize = getDiskCacheSize()
            var index = 0
            
            // Remove oldest files until we're under target size
            while currentSize > targetSize && index < sortedContents.count {
                let fileURL = sortedContents[index]
                
                guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                      let size = attributes[.size] as? UInt64 else {
                    index += 1
                    continue
                }
                
                try fileManager.removeItem(at: fileURL)
                currentSize -= size
                index += 1
            }
        } catch {
            print("Failed to trim disk cache: \(error)")
        }
    }
}
```

### 3.3 Conversation History Manager

```swift
class ConversationHistoryManager {
    private let stateStore: StateStore
    private let cacheManager: CacheManager
    
    // Maximum number of conversations to keep in memory
    private let maxActiveConversations = 5
    
    init(stateStore: StateStore, cacheManager: CacheManager = CacheManager.shared) {
        self.stateStore = stateStore
        self.cacheManager = cacheManager
        
        // Set up memory pressure handling
        setupMemoryPressureHandling()
    }
    
    // Set up memory pressure handling
    private func setupMemoryPressureHandling() {
        NotificationCenter.default.addObserver(
            forName: .memoryStatusWarning,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        
        NotificationCenter.default.addObserver(
            forName: .memoryStatusCritical,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryCritical()
        }
    }
    
    // Handle memory warning
    private func handleMemoryWarning() {
        // Archive older conversations
        archiveOlderConversations()
    }
    
    // Handle critical memory situation
    private func handleMemoryCritical() {
        // Archive all but current conversation
        archiveAllButCurrentConversation()
    }
    
    // Archive older conversations to disk
    func archiveOlderConversations() {
        stateStore.updateState { state in
            // Keep track of current conversation
            let currentId = state.currentConversationId
            
            // Sort conversations by last updated (newest first)
            let sortedConversations = state.conversations.sorted { $0.lastUpdated > $1.lastUpdated }
            
            // Keep the most recent conversations and current conversation in memory
            var conversationsToKeep: [Conversation] = []
            var conversationsToArchive: [Conversation] = []
            
            var keptCount = 0
            
            for conversation in sortedConversations {
                if keptCount < maxActiveConversations || conversation.id == currentId {
                    conversationsToKeep.append(conversation)
                    keptCount += 1
                } else {
                    conversationsToArchive.append(conversation)
                }
            }
            
            // Archive conversations
            for conversation in conversationsToArchive {
                archiveConversation(conversation)
            }
            
            // Update state with kept conversations
            state.conversations = conversationsToKeep
        }
    }
    
    // Archive all but current conversation
    func archiveAllButCurrentConversation() {
        stateStore.updateState { state in
            // Keep only current conversation in memory
            guard let currentId = state.currentConversationId else {
                return
            }
            
            let conversationsToKeep = state.conversations.filter { $0.id == currentId }
            let conversationsToArchive = state.conversations.filter { $0.id != currentId }
            
            // Archive conversations
            for conversation in conversationsToArchive {
                archiveConversation(conversation)
            }
            
            // Update state with kept conversations
            state.conversations = conversationsToKeep
        }
    }
    
    // Archive a conversation to disk
    private func archiveConversation(_ conversation: Conversation) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(conversation)
            
            // Store in disk cache
            cacheManager.storeOnDisk(data: data, forKey: "conversation_\(conversation.id)")
        } catch {
            print("Failed to archive conversation: \(error)")
        }
    }
    
    // Load a conversation from disk
    func loadConversation(id: String, completion: @escaping (Conversation?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let data = self.cacheManager.retrieveFromDisk(forKey: "conversation_\(id)") {
                do {
                    let decoder = JSONDecoder()
                    let conversation = try decoder.decode(Conversation.self, from: data)
                    
                    DispatchQueue.main.async {
                        completion(conversation)
                    }
                } catch {
                    print("Failed to decode conversation: \(error)")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // Restore a conversation to memory
    func restoreConversation(id: String, completion: @escaping (Bool) -> Void) {
        loadConversation(id: id) { [weak self] conversation in
            guard let self = self, let conversation = conversation else {
                completion(false)
                return
            }
            
            // Add conversation to state
            self.stateStore.updateState { state in
                // Check if conversation already exists
                if !state.conversations.contains(where: { $0.id == id }) {
                    state.conversations.append(conversation)
                }
            }
            
            completion(true)
        }
    }
    
    // Purge old conversations from disk
    func purgeOldConversations(olderThan date: Date) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            // Get all conversation IDs from disk
            let conversationKeys = self.getAllConversationKeysFromDisk()
            
            for key in conversationKeys {
                if let data = self.cacheManager.retrieveFromDisk(forKey: key) {
                    do {
                        let decoder = JSONDecoder()
                        let conversation = try decoder.decode(Conversation.self, from: data)
                        
                        // Check if conversation is older than specified date
                        if conversation.lastUpdated < date {
                            self.cacheManager.removeFromDisk(forKey: key)
                        }
                    } catch {
                        print("Failed to decode conversation for purging: \(error)")
                    }
                }
            }
        }
    }
    
    // Get all conversation keys from disk
    private func getAllConversationKeysFromDisk() -> [String] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheManager.cacheDirectory, includingPropertiesForKeys: nil)
            
            return contents
                .map { $0.lastPathComponent }
                .filter { $0.hasPrefix("conversation_") }
        } catch {
            print("Failed to get conversation keys: \(error)")
            return []
        }
    }
}

// Extension to access cache directory
extension CacheManager {
    var cacheDirectory: URL {
        if let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            return cachesDirectory.appendingPathComponent("com.openhands.mac.cache")
        } else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.openhands.mac.cache")
        }
    }
}
```

### 3.4 Memory-Efficient Collection Views

```swift
// Memory-efficient list for large datasets
struct LazyLoadingList<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Identifiable, Content: View {
    let data: Data
    let content: (Data.Element) -> Content
    
    // Pagination settings
    private let pageSize: Int
    @State private var loadedPages: Set<Int> = [0] // Start with first page
    
    init(data: Data, pageSize: Int = 20, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.pageSize = pageSize
        self.content = content
    }
    
    var body: some View {
        List {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, element in
                content(element)
                    .onAppear {
                        // Calculate page and load if needed
                        let page = index / pageSize
                        if !loadedPages.contains(page) {
                            loadedPages.insert(page)
                        }
                        
                        // Preload next page
                        let nextPage = page + 1
                        if index % pageSize == pageSize - 3 && !loadedPages.contains(nextPage) {
                            loadedPages.insert(nextPage)
                        }
                    }
                    .id(element.id) // Ensure view is recreated when element changes
            }
        }
        .onDisappear {
            // Keep only current and adjacent pages in memory
            let currentPages = loadedPages
            loadedPages = Set()
            
            if let minPage = currentPages.min(), let maxPage = currentPages.max() {
                // Keep only a window of pages
                let pagesToKeep = max(3, min(5, maxPage - minPage + 1))
                let startPage = max(0, maxPage - pagesToKeep + 1)
                
                for page in startPage...maxPage {
                    loadedPages.insert(page)
                }
            }
        }
    }
}

// Memory-efficient grid for large datasets
struct LazyLoadingGrid<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Identifiable, Content: View {
    let data: Data
    let columns: Int
    let content: (Data.Element) -> Content
    
    // Pagination settings
    private let pageSize: Int
    @State private var loadedPages: Set<Int> = [0] // Start with first page
    
    init(data: Data, columns: Int, pageSize: Int = 50, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.columns = columns
        self.pageSize = pageSize
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns)) {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, element in
                    content(element)
                        .onAppear {
                            // Calculate page and load if needed
                            let page = index / pageSize
                            if !loadedPages.contains(page) {
                                loadedPages.insert(page)
                            }
                            
                            // Preload next page
                            let nextPage = page + 1
                            if index % pageSize == pageSize - 5 && !loadedPages.contains(nextPage) {
                                loadedPages.insert(nextPage)
                            }
                        }
                        .id(element.id) // Ensure view is recreated when element changes
                }
            }
            .padding()
        }
        .onDisappear {
            // Keep only current and adjacent pages in memory
            let currentPages = loadedPages
            loadedPages = Set()
            
            if let minPage = currentPages.min(), let maxPage = currentPages.max() {
                // Keep only a window of pages
                let pagesToKeep = max(3, min(5, maxPage - minPage + 1))
                let startPage = max(0, maxPage - pagesToKeep + 1)
                
                for page in startPage...maxPage {
                    loadedPages.insert(page)
                }
            }
        }
    }
}

// Example usage
struct GalleryView: View {
    @StateObject private var viewModel = GalleryViewModel()
    
    var body: some View {
        LazyLoadingGrid(data: viewModel.images, columns: 3) { image in
            AsyncImage(url: image.url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                case .failure:
                    Image(systemName: "photo")
                        .frame(width: 100, height: 100)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 100, height: 100)
        }
    }
}

class GalleryViewModel: ObservableObject {
    @Published var images: [ImageItem] = []
    
    init() {
        // Generate sample data
        images = (0..<1000).map { i in
            ImageItem(
                id: UUID().uuidString,
                url: URL(string: "https://picsum.photos/id/\(i % 100)/100")!
            )
        }
    }
}

struct ImageItem: Identifiable {
    let id: String
    let url: URL
}
```

This implementation guide provides a comprehensive approach to performance optimization in the Mac client, covering large output handling, UI responsiveness, and memory management for long-running sessions.