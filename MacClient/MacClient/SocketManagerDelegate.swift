import Foundation

/// Protocol for handling socket events
protocol SocketManagerDelegate: AnyObject {
    /// Called when a socket event is received
    /// - Parameters:
    ///   - manager: The socket manager that received the event
    ///   - event: The event that was received
    func socketManager(_ manager: SocketManager, didReceiveEvent event: Event)
    
    /// Called when the socket connects
    /// - Parameter manager: The socket manager that connected
    func socketManagerDidConnect(_ manager: SocketManager)
    
    /// Called when the socket disconnects
    /// - Parameter manager: The socket manager that disconnected
    func socketManagerDidDisconnect(_ manager: SocketManager)
    
    /// Called when a socket error occurs
    /// - Parameters:
    ///   - manager: The socket manager that encountered the error
    ///   - error: The error that occurred
    func socketManager(_ manager: SocketManager, didEncounterError error: Error)
}