import Foundation
import SocketIO

/// A simple example class demonstrating Socket.IO functionality
public class SocketExample {
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    
    /// Initialize a Socket.IO connection
    /// - Parameter url: The URL of the Socket.IO server
    public init(url: URL) {
        manager = SocketManager(socketURL: url, config: [.log(true), .compress])
        socket = manager?.defaultSocket
        
        setupEventHandlers()
    }
    
    /// Set up event handlers for Socket.IO events
    private func setupEventHandlers() {
        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            print("Socket connected")
        }
        
        socket?.on(clientEvent: .disconnect) { [weak self] data, ack in
            print("Socket disconnected")
        }
        
        socket?.on("message") { [weak self] data, ack in
            if let message = data[0] as? String {
                print("Received message: \(message)")
            }
        }
    }
    
    /// Connect to the Socket.IO server
    public func connect() {
        socket?.connect()
    }
    
    /// Disconnect from the Socket.IO server
    public func disconnect() {
        socket?.disconnect()
    }
    
    /// Send a message to the Socket.IO server
    /// - Parameter message: The message to send
    public func sendMessage(_ message: String) {
        socket?.emit("message", message)
    }
    
    /// Send a message with acknowledgement
    /// - Parameters:
    ///   - message: The message to send
    ///   - completion: Callback for acknowledgement
    public func sendMessageWithAck(_ message: String, completion: @escaping ([Any]) -> Void) {
        socket?.emitWithAck("message", message).timingOut(after: 5) { data in
            completion(data)
        }
    }
}