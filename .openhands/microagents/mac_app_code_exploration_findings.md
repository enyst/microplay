# Mac App Code Exploration Findings

This document contains findings from exploring the OpenHands codebase to inform the Mac client implementation.

## 1. Overview

The OpenHands platform consists of a web frontend and backend server that communicate via Socket.IO. The Mac client will need to implement similar communication patterns while adapting to native macOS UI paradigms.

## 2. Key Components

- **Socket.IO Communication**: The primary method for real-time communication between client and server
- **File Explorer**: Provides access to the file system with operations like viewing, editing, and creating files
- **Agent Output Display**: Renders various types of agent outputs including text, code, and images
- **Terminal Interface**: Allows execution and interaction with terminal commands

## 3. Backend Communication

### 3.1. Socket.IO Events

The backend server communicates with clients using the following primary Socket.IO events:

- `oh_action`: Sent from client to server to initiate actions
- `oh_event`: Sent from server to client to deliver agent outputs and system events

### 3.2. Event Structure

Events follow a consistent structure:

```json
{
  "type": "message",
  "args": {
    "content": "Hello, world!"
  },
  "timestamp": "2023-04-01T12:34:56Z"
}
```

### 3.3. Internal API Naming Convention

For clarity within the Mac app codebase, we'll use more descriptive internal terminology while maintaining compatibility with backend events:

| API Event Name | Internal Term    | Description                               |
|----------------|------------------|-------------------------------------------|
| `oh_action`    | `userAction`     | User-initiated commands sent to backend   |
| `oh_event`     | `oh_event`       | All events received from backend          |

Implementation example:
```swift
// Public methods with clear naming
func sendUserAction(type: String, args: [String: Any])

// Internally mapped to compatible API event
socketManager.emit("oh_action", payload)
```

This maintains API compatibility while providing more intuitive naming in the codebase.

## 4. UI Components

### 4.1. File Explorer

The file explorer provides a hierarchical view of files and directories with the following features:

- Tree view of directories and files
- Context menus for file operations
- File content preview with syntax highlighting
- Search functionality

### 4.2. Agent Output Display

Agent outputs are displayed in a conversation-like interface with support for:

- Markdown rendering
- Code blocks with syntax highlighting
- Terminal output display
- Image rendering
- Interactive elements

### 4.3. Terminal Interface

The terminal interface provides:

- Command input field
- Output display with proper formatting
- Support for interactive commands
- History navigation

## 5. Performance Considerations

- **Lazy Loading**: Large file directories and conversation histories should be lazy-loaded
- **Caching**: Frequently accessed files and outputs should be cached
- **Background Processing**: Heavy operations should be performed in background threads

## 6. Security Considerations

- **Authentication**: Secure storage of authentication tokens
- **File Access**: Proper sandboxing and permission handling for file system access
- **Network Security**: Secure Socket.IO connections with proper error handling