## MVVM with SwiftUI: Technical Explanation

MVVM (Model-View-ViewModel) in SwiftUI leverages the framework's reactive programming model to create a clean separation of concerns:

```
Model → ViewModel → View
  ↑        ↓
  └────────┘
```

### Components
1. **Model**: Raw data structures representing business logic and backend communication
   - Example: `AgentEvent`, `FileData`, `BackendConnection`
   - Pure data without UI logic or state management

2. **ViewModel**: Observable objects that transform model data for views
   - Implements `ObservableObject` protocol with `@Published` properties
   - Handles business logic, backend calls, data transformation
   - Decouples views from direct model dependencies

3. **View**: Declarative UI that observes and reacts to ViewModel changes
   - Contains minimal logic (primarily UI-related)
   - Automatically updates when ViewModel's `@Published` properties change

### Implementation in OpenHands Mac Client

For the Agent Output component:
```swift
// Model
struct AgentEvent {
    let timestamp: String
    let source: String
    let message: String
    let observation: AgentObservation?
}

// ViewModel
class AgentOutputViewModel: ObservableObject {
    @Published var events: [AgentEvent] = []
    private let socketManager: SocketIOManager
    
    init(socketManager: SocketIOManager) {
        self.socketManager = socketManager
        setupEventHandlers()
    }
    
    private func setupEventHandlers() {
        socketManager.onEvent { [weak self] event in
            DispatchQueue.main.async {
                self?.events.append(event)
            }
        }
    }
}

// View
struct AgentOutputView: View {
    @ObservedObject var viewModel: AgentOutputViewModel
    
    var body: some View {
        List(viewModel.events, id: \.timestamp) { event in
            AgentEventRow(event: event)
        }
    }
}
```

## State Objects Explanation

In SwiftUI, "state objects" refers to objects managed by property wrappers that trigger UI updates when changed:

### Key Property Wrappers

1. **@StateObject**
   - Creates and owns a reference to an observable object
   - Persists through view lifecycle (unlike `@State`)
   - Used for view-owned ViewModels
   ```swift
   struct FileExplorerView: View {
       @StateObject private var viewModel = FileExplorerViewModel()
       // View will be recreated when viewModel publishes changes
   }
   ```

2. **@ObservedObject**
   - References an observable object owned elsewhere
   - Used for ViewModels passed to child views
   ```swift
   struct AgentEventRow: View {
       @ObservedObject var viewModel: AgentEventViewModel
       // This view will update when viewModel changes
   }
   ```

3. **@EnvironmentObject**
   - Dependency injection for deeply nested view hierarchies
   - Used for app-wide shared state
   ```swift
   struct ContentView: View {
       @EnvironmentObject var appState: AppState
       // Accessible to ContentView and all its child views
   }
   ```

### Communication Pattern

The communication flow between components is reactive and unidirectional:

1. User interacts with **View**
2. View calls methods on **ViewModel**
3. ViewModel updates its `@Published` properties
4. SwiftUI automatically refreshes **View** in response

For cross-component communication, options include:
- Parent-child ViewModel references
- Combine framework for advanced reactive scenarios
- Environment objects for shared global state (e.g., SocketIOManager)

This architecture provides clear separation of concerns, testability, and a reactive UI that automatically updates in response to data changes—ideal for real-time agent outputs.
