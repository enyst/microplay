import Foundation

/// Protocol for handling socket events
protocol SocketServiceDelegate: AnyObject {
    /// Called when a socket event is received
    /// - Parameters:
    ///   - service: The socket service that received the event
    ///   - event: The event that was received
    func socketService(_ service: SocketService, didReceiveEvent event: Event)
    
    /// Called when a socket event is processed and the app state is updated
    /// - Parameters:
    ///   - service: The socket service that processed the event
    ///   - event: The event that was processed
    func socketService(_ service: SocketService, didProcessEvent event: Event)
    
    /// Called when the socket connects
    /// - Parameter service: The socket service that connected
    func socketServiceDidConnect(_ service: SocketService)
    
    /// Called when the socket disconnects
    /// - Parameter service: The socket service that disconnected
    func socketServiceDidDisconnect(_ service: SocketService)
    
    /// Called when a socket error occurs
    /// - Parameters:
    ///   - service: The socket service that encountered the error
    ///   - error: The error that occurred
    func socketService(_ service: SocketService, didEncounterError error: Error)
}