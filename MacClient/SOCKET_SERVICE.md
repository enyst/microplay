# SocketService Event Emission Methods

This document outlines the methods available in the `SocketService` class for sending events to the OpenHands server.

## Overview

The `SocketService` class provides methods for sending various types of events to the OpenHands server. These events are sent using the Socket.IO protocol and follow the structure defined in the server API documentation.

## Event Emission Methods

### Generic Action Method

```swift
func sendAction(action: String, args: [String: Any])
```

This is the base method used by all other event emission methods. It sends an `oh_action` event to the server with the specified action type and arguments.

### User Message

```swift
func sendMessage(content: String, imageUrls: [String]? = nil)
```

Sends a user message to the server. The message can include optional image URLs.

### Command Execution

```swift
func executeCommand(command: String, securityRisk: Bool = false, confirmationState: String? = nil, thought: String? = nil)
```

Executes a command on the server. You can specify whether the command poses a security risk, the confirmation state, and the thought process behind the command.

### File Operations

```swift
func readFile(path: String)
```

Reads a file from the server.

```swift
func writeFile(path: String, content: String)
```

Writes content to a file on the server.

```swift
func editFile(path: String, oldContent: String, newContent: String)
```

Edits a file on the server by replacing the old content with new content.

### Browser Operations

```swift
func browseUrl(url: String)
```

Navigates to a URL in the browser.

```swift
func browseInteractive(code: String)
```

Interacts with the browser by executing the specified code.

## Usage Examples

### Sending a User Message

```swift
socketService.sendMessage(content: "Hello, OpenHands!")
```

### Executing a Command

```swift
socketService.executeCommand(command: "ls -la", securityRisk: false)
```

### Reading a File

```swift
socketService.readFile(path: "/path/to/file.txt")
```

### Writing to a File

```swift
socketService.writeFile(path: "/path/to/file.txt", content: "Hello, world!")
```

### Editing a File

```swift
socketService.editFile(
    path: "/path/to/file.txt",
    oldContent: "Hello, world!",
    newContent: "Hello, OpenHands!"
)
```

### Navigating to a URL

```swift
socketService.browseUrl(url: "https://example.com")
```

### Interacting with the Browser

```swift
socketService.browseInteractive(code: "document.querySelector('button').click()")
```