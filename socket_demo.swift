#!/usr/bin/env swift

import Foundation

// This is a simple demo script that shows how to use the SocketExample class
// Note: This script requires a Socket.IO server running at the specified URL

// First, we need to import the necessary modules
print("Importing modules...")

// Import the MacClient module which contains our SocketExample class
import MacClient

// Create a URL for the Socket.IO server
let serverURL = URL(string: "http://localhost:8080")!
print("Connecting to Socket.IO server at \(serverURL.absoluteString)...")

// Create a SocketExample instance
let socketExample = SocketExample(url: serverURL)

// Connect to the server
socketExample.connect()

// Send a message
print("Sending message to server...")
socketExample.sendMessage("Hello from Swift on Linux!")

// Keep the script running for a few seconds to allow for connections and messages
print("Waiting for 5 seconds...")
Thread.sleep(forTimeInterval: 5)

// Disconnect from the server
print("Disconnecting from server...")
socketExample.disconnect()

print("Demo completed!")