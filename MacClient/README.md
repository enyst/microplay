# MacClient for OpenHands

A macOS client for the OpenHands AI assistant, built with Swift and SwiftUI.

## Features

- Socket.IO communication with the OpenHands server
- Real-time event handling
- Message sending and receiving
- Command execution
- File operations
- Browser integration
- Clean, native macOS interface built with SwiftUI
- Event history with detailed information
- Connection management and error handling

## Architecture

The Mac client follows the MVVM (Model-View-ViewModel) architecture pattern:

- **Models**: `Event` represents events received from the server.
- **Views**: `MainView` and `EventView` handle the UI presentation.
- **ViewModels**: `AppState` manages the application state and coordinates between the UI and the socket service.
- **Services**: `SocketService` handles the Socket.IO communication with the server.

## Socket.IO Implementation

The `SocketService` class provides a foundation for communication with the OpenHands server using socket.io. It handles:

- Connection and disconnection
- Event handling with delegate pattern
- Sending actions to the server
- Processing events from the server
- Error handling and reconnection

### Usage

```swift
// Initialize the socket service
let socketService = SocketService(serverUrl: URL(string: "http://openhands-server:3000")!)

// Set the delegate
socketService.delegate = self

// Connect to a conversation
socketService.connect(conversationId: "your-conversation-id")

// Send a message
socketService.sendMessage(content: "Hello, OpenHands!")

// Execute a command
socketService.executeCommand(command: "ls -la")

// Read a file
socketService.readFile(path: "/path/to/file.txt")

// Write to a file
socketService.writeFile(path: "/path/to/file.txt", content: "Hello, world!")

// Edit a file
socketService.editFile(path: "/path/to/file.txt", oldContent: "Hello, world!", newContent: "Hello, OpenHands!")

// Navigate to a URL
socketService.browseUrl(url: "https://example.com")

// Disconnect when done
socketService.disconnect()
```

### Event Handling with Delegate

The `SocketServiceDelegate` protocol is used to receive events from the socket service:

```swift
protocol SocketServiceDelegate: AnyObject {
    func socketService(_ service: SocketService, didReceiveEvent event: Event)
    func socketServiceDidConnect(_ service: SocketService)
    func socketServiceDidDisconnect(_ service: SocketService)
    func socketService(_ service: SocketService, didEncounterError error: Error)
}

// Implement the delegate methods
extension YourClass: SocketServiceDelegate {
    func socketService(_ service: SocketService, didReceiveEvent event: Event) {
        // Handle the event
    }
    
    func socketServiceDidConnect(_ service: SocketService) {
        // Handle connection
    }
    
    func socketServiceDidDisconnect(_ service: SocketService) {
        // Handle disconnection
    }
    
    func socketService(_ service: SocketService, didEncounterError error: Error) {
        // Handle error
    }
}
```

### Event Model

The `Event` model represents an event received from the OpenHands server:

```swift
// Access event properties
let id = event.id
let timestamp = event.timestamp
let source = event.source
let message = event.message

// Check event type
if event.isAction {
    // Handle action event
    if let action = event.action {
        // Handle specific action
    }
} else if event.isObservation {
    // Handle observation event
    if let observation = event.observation {
        // Handle specific observation
    }
}

// Access specific properties
if event.isMessage {
    if let thought = event.thought {
        // Handle thought
    }
    if let imageUrls = event.imageUrls {
        // Handle image URLs
    }
    if let waitForResponse = event.waitForResponse {
        // Handle wait for response
    }
}
```

## Demo Application

The `SocketServiceDemo` is a simple SwiftUI application that demonstrates how to use the `SocketService` class. It allows you to:

- Connect to the OpenHands server
- Send messages
- View events in real-time
- Handle errors

## Implementation Status

1. ✅ Implemented the `SocketService` class for Socket.IO communication
2. ✅ Created the `Event` model for representing server events
3. ✅ Implemented the `SocketServiceDelegate` protocol for event handling
4. ✅ Created the `AppState` class to manage application state
5. ✅ Built the basic UI components with SwiftUI
6. ✅ Implemented the demo application for testing

## Next Steps

1. Add more specific event handlers for different types of events
2. Implement file explorer and terminal components
3. Add support for image uploads and display
4. Implement settings and preferences
5. Add support for multiple conversations
6. Implement authentication

## Requirements

- Swift 5.5+
- macOS 12.0+
- SocketIO-Client-Swift library (via Swift Package Manager)

## Getting Started

1. Clone the repository
2. Open the project in Xcode
3. Build and run the application
4. Enter a conversation ID to connect to the OpenHands server
5. Start interacting with the OpenHands agent