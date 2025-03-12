# OpenHands Mac Client Implementation Guide

This document provides a comprehensive guide for implementing the OpenHands Mac client, summarizing the key components, architecture, and implementation approach.

## 1. Project Overview

The OpenHands Mac client is a native macOS application built with SwiftUI that provides an alternative to the web UI for interacting with the OpenHands backend. The client connects to the same backend service as the web UI, providing a native desktop experience while maintaining full compatibility with the backend API.

### 1.1 Key Features

1. **Task Input Area**: Text input for submitting tasks to the agent
2. **Agent Output Display**: Real-time display of agent actions and outputs
3. **File Explorer**: Browse and view files in the workspace
4. **Control Buttons**: Start, pause, and stop agent execution
5. **Conversation Management**: Create, switch between, and manage multiple conversations
6. **Comprehensive Settings Panel**: Tabbed interface for all client and backend settings

### 1.2 Architecture

The Mac client follows the MVVM (Model-View-ViewModel) architecture pattern:

- **Models**: Data structures representing backend entities (conversations, files, etc.)
- **Views**: SwiftUI components for the user interface
- **ViewModels**: Business logic and state management for views
- **Services**: Communication with the backend API

## 2. Implementation Roadmap

### 2.1 Phase 1: Foundation

1. **Project Setup**
   - Create a new SwiftUI macOS application
   - Set up project structure (Models, Views, ViewModels, Services)
   - Configure build settings and dependencies

2. **Backend Communication**
   - Implement Socket.IO client for real-time communication
   - Implement REST API client for backend operations
   - Create models for API requests and responses

3. **Core Services**
   - Implement `SocketIOManager` for WebSocket communication
   - Implement `APIClient` for REST API calls
   - Implement `SettingsService` for managing application settings

### 2.2 Phase 2: Core UI Components

1. **Main Window Layout**
   - Implement split view layout with resizable panels
   - Set up navigation and toolbar

2. **File Explorer**
   - Implement file tree view with expandable folders
   - Implement file selection and content display
   - Connect to backend file operations

3. **Agent Output Display**
   - Implement scrollable output display
   - Support different content types (text, code, terminal)
   - Implement auto-scrolling with manual override

4. **Task Input Area**
   - Implement multi-line text input
   - Connect to message sending functionality
   - Implement submit button and keyboard shortcuts

5. **Control Buttons**
   - Implement start/pause/stop buttons
   - Connect to agent state management
   - Implement visual state indicators

### 2.3 Phase 3: Integration and Polish

1. **Comprehensive Settings Panel**
   - Implement tabbed settings UI matching all backend config.template.toml options
   - Create separate tabs for different setting categories:
     * **General**: Application preferences, UI settings, theme options
     * **Backend**: Connection URL, authentication, proxy settings
     * **Model**: LLM selection, parameters, context window settings
     * **API Keys**: Secure storage for OpenAI, Anthropic, and other API keys
     * **Execution**: Runtime settings, timeout values, execution preferences
     * **File System**: Workspace paths, file handling preferences
     * **Advanced**: Debug options, experimental features, logging settings
   - Implement validation and persistence for all settings
   - Support backend connection configuration and authentication
   - Add search functionality for quickly finding specific settings
   - Implement secure storage for sensitive information (API keys)
   - Add import/export functionality for settings backup
   - Include inline documentation and tooltips for each setting

2. **Error Handling**
   - Implement error notification system
   - Add recovery options for common errors
   - Improve error reporting and logging

3. **State Synchronization**
   - Ensure consistent state between client and server
   - Handle reconnection and state recovery
   - Implement conflict resolution

4. **Performance Optimization**
   - Optimize large output handling
   - Implement efficient caching strategies
   - Improve UI responsiveness

5. **Accessibility and Localization**
   - Add VoiceOver support
   - Implement keyboard navigation
   - Add localization support (optional for MVP)

## 3. Technical Implementation Details

### 3.1 Backend Communication

The Mac client communicates with the backend through two primary channels:

1. **Socket.IO**: For real-time events and actions
   - Connect to the backend WebSocket server
   - Send `oh_action` events for user actions
   - Receive `oh_event` events for agent outputs
   - Handle reconnection and authentication

2. **REST API**: For configuration and setup
   - Create and manage conversations
   - List and retrieve files
   - Manage settings
   - Handle authentication (if needed)

### 3.1.1 Component-Specific Implementation Details

For detailed implementation guidance on specific components, refer to the dedicated implementation files:

1. **File Explorer**: See [impl_file_explorer.md](impl_file_explorer.md) for comprehensive implementation details of the file tree view, file content display, and backend integration.

2. **Socket.IO Communication**: See [impl_socket_io.md](impl_socket_io.md) for details on real-time communication with the backend.

3. **Backend Connection**: See [impl_backend_connection.md](impl_backend_connection.md) for implementation of the connection management.

4. **State Synchronization**: See [impl_state_sync.md](impl_state_sync.md) for details on maintaining consistent state.

5. **Error Handling**: See [impl_error_handling.md](impl_error_handling.md) for comprehensive error management.

Each component-specific implementation file contains detailed code examples, architecture decisions, and integration guidance.

### 3.2 Data Flow

The data flow in the application follows this pattern:

1. User interacts with the UI (inputs task, clicks button)
2. View calls ViewModel method
3. ViewModel processes the action and calls appropriate service
4. Service sends request to backend (via Socket.IO or REST)
5. Backend processes the request and sends response
6. Service receives response and notifies ViewModel
7. ViewModel updates its state
8. UI automatically updates due to SwiftUI's reactive nature

### 3.3 State Management

The application state is managed through:

1. **ObservableObject ViewModels**: Each major component has a ViewModel that manages its state
2. **Published Properties**: State changes trigger UI updates
3. **Centralized MainViewModel**: Coordinates between components
4. **Persistent Settings**: Stored using UserDefaults or similar mechanism

### 3.4 Error Handling

The error handling strategy includes:

1. **Typed Error Hierarchy**: Structured error types with severity levels
2. **User-Visible Notifications**: Non-intrusive notifications for minor errors
3. **Recovery Options**: Actionable recovery for critical errors
4. **Graceful Degradation**: Maintain functionality when possible

## 4. Key Components and Classes

### 4.1 Services

- **SocketIOManager**: Manages Socket.IO connection and events
- **APIClient**: Handles REST API requests
- **FileService**: Manages file operations
- **ConversationService**: Manages multiple conversations, history, and metadata
- **SettingsService**: Manages comprehensive application settings with tabbed interface
- **ErrorManager**: Handles error reporting and recovery

### 4.2 ViewModels

- **MainViewModel**: Coordinates between components
- **FileExplorerViewModel**: Manages file explorer state
- **AgentOutputViewModel**: Manages agent output display
- **TaskInputViewModel**: Manages task input area
- **AgentControlViewModel**: Manages agent control buttons
- **ConversationViewModel**: Manages multiple conversations and switching
- **SettingsViewModel**: Manages comprehensive tabbed settings panel

### 4.3 Views

- **MainView**: Main application window
- **FileExplorerView**: File tree view
- **AgentOutputView**: Agent output display
- **TaskInputView**: Task input area
- **AgentControlButtons**: Control buttons
- **ConversationListView**: Multiple conversation management interface
- **ConversationTabView**: Tabbed interface for switching conversations
- **SettingsView**: Comprehensive tabbed settings panel
- **ErrorNotificationView**: Error notifications

### 4.4 Models

- **ConversationInfo**: Conversation metadata and status
- **ConversationGroup**: Group of related conversations
- **FileNode**: File or directory in workspace
- **AgentOutput**: Agent output message
- **Settings**: Comprehensive application settings
- **SettingsCategory**: Category of related settings
- **AppError**: Error information

## 5. Implementation Approach

### 5.1 Technology Stack

- **Language**: Swift 5.5+
- **UI Framework**: SwiftUI
- **Concurrency**: Swift async/await
- **Networking**: URLSession, Socket.IO client
- **Persistence**: UserDefaults, Keychain

### 5.2 Development Practices

- **MVVM Architecture**: Clear separation of concerns
- **Protocol-Oriented Design**: Interfaces for testability
- **Dependency Injection**: Services injected into ViewModels
- **Reactive Programming**: SwiftUI's reactive nature
- **Error Handling**: Structured error handling with recovery

### 5.3 Testing Strategy

- **Unit Tests**: Test individual components in isolation
- **Integration Tests**: Test communication with backend
- **UI Tests**: Test user interactions
- **Mock Services**: Use mock services for testing

## 6. MVP Scope and Priorities

### 6.1 Must-Have Features (MVP)

1. **Basic Task Input**: Text input for submitting tasks
2. **Agent Output Display**: Display agent outputs with basic formatting
3. **Read-Only File Explorer**: Browse and view files
4. **Basic Control Buttons**: Start, pause, stop agent
5. **Comprehensive Settings Panel**: Tabbed interface matching all backend config.template.toml options
6. **Backend Connection Settings**: Configure backend connection
7. **Multiple Conversation Management**: Create, switch between, and manage multiple conversations
8. **Conversation History**: View and search conversation history

### 6.2 Nice-to-Have Features (Post-MVP)

1. **Rich Text Input**: Support for formatting and images
2. **Advanced Output Formatting**: Better syntax highlighting and rendering
3. **File Editing**: Edit files directly in the client
4. **Command History**: Browse and reuse previous commands
5. **Offline Support**: Queue actions when offline
6. **Advanced Keyboard Shortcuts**: Comprehensive keyboard navigation and shortcuts
7. **Settings Import/Export**: Export and import settings configurations
8. **Conversation Grouping**: Group conversations by project or topic
9. **Conversation Export**: Export conversation logs for sharing

## 7. Resources and References

### 7.1 Backend API Documentation

- Socket.IO Events: `oh_event` and `oh_action`
- REST API Endpoints for conversations, files, and settings
- Authentication mechanisms

### 7.2 SwiftUI Resources

- Apple's SwiftUI Documentation
- WWDC Sessions on SwiftUI
- SwiftUI Layout and Navigation

### 7.3 Socket.IO Resources

- Socket.IO Swift Client
- Socket.IO Event Handling
- Reconnection Strategies

## 8. Getting Started

1. **Clone the Repository**: Set up the development environment
2. **Install Dependencies**: Socket.IO client, other libraries
3. **Run the Backend**: Start the OpenHands backend locally
4. **Build the Foundation**: Implement core services
5. **Implement UI Components**: Build the user interface
6. **Connect to Backend**: Integrate with backend services
7. **Test and Refine**: Iterate on the implementation

By following this implementation guide, developers can build a functional OpenHands Mac client that provides a native alternative to the web UI while maintaining full compatibility with the backend API.