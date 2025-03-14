import SwiftUI

/// A simple demo application for testing the SocketService
struct SocketServiceDemo: View {
    /// The socket service view model
    @StateObject private var viewModel = SocketServiceDemoViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Connection status
            HStack {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                
                Text(viewModel.isConnected ? "Connected" : "Disconnected")
                    .font(.headline)
            }
            
            // Connection controls
            VStack(alignment: .leading) {
                Text("Connection")
                    .font(.headline)
                
                HStack {
                    TextField("Conversation ID", text: $viewModel.conversationId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Connect") {
                        viewModel.connect()
                    }
                    .disabled(viewModel.isConnected || viewModel.conversationId.isEmpty)
                    
                    Button("Disconnect") {
                        viewModel.disconnect()
                    }
                    .disabled(!viewModel.isConnected)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Message input
            VStack(alignment: .leading) {
                Text("Send Message")
                    .font(.headline)
                
                HStack {
                    TextField("Message", text: $viewModel.messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Send") {
                        viewModel.sendMessage()
                    }
                    .disabled(!viewModel.isConnected || viewModel.messageText.isEmpty)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Events list
            VStack(alignment: .leading) {
                Text("Events")
                    .font(.headline)
                
                List {
                    ForEach(viewModel.events) { event in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("#\(event.id)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(event.source)
                                    .font(.caption)
                                    .padding(4)
                                    .background(event.source == "agent" ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                                    .cornerRadius(4)
                                
                                Spacer()
                                
                                if let date = event.formattedDate {
                                    Text(date, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text(event.message)
                                .font(.body)
                            
                            if event.isAction, let action = event.action {
                                Text("Action: \(action)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            if event.isObservation, let observation = event.observation {
                                Text("Observation: \(observation)")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }
                            
                            if let content = event.content {
                                Text(content)
                                    .font(.body)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                .frame(minHeight: 200)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Error display
            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
        .navigationTitle("Socket.IO Demo")
    }
}

/// View model for the SocketServiceDemo
class SocketServiceDemoViewModel: ObservableObject, SocketServiceDelegate {
    /// The socket service instance
    private let socketService: SocketService
    
    /// Flag indicating whether the socket is connected
    @Published var isConnected = false
    
    /// The conversation ID to connect with
    @Published var conversationId = ""
    
    /// The message text to send
    @Published var messageText = ""
    
    /// The events received from the server
    @Published var events: [Event] = []
    
    /// The latest error message
    @Published var error: String?
    
    /// Initializes a new SocketServiceDemoViewModel
    init() {
        // Create the socket service with a default URL
        // In a real app, you would get this from configuration
        socketService = SocketService(serverUrl: URL(string: "http://openhands-server:3000")!)
        socketService.delegate = self
    }
    
    /// Connects to the server with the current conversation ID
    func connect() {
        guard !conversationId.isEmpty else { return }
        
        socketService.connect(conversationId: conversationId)
    }
    
    /// Disconnects from the server
    func disconnect() {
        socketService.disconnect()
    }
    
    /// Sends a message to the server
    func sendMessage() {
        guard !messageText.isEmpty, isConnected else { return }
        
        socketService.sendMessage(content: messageText)
        messageText = ""
    }
    
    // MARK: - SocketServiceDelegate
    
    func socketService(_ service: SocketService, didReceiveEvent event: Event) {
        DispatchQueue.main.async {
            self.events.insert(event, at: 0)
            self.error = nil
        }
    }
    
    func socketServiceDidConnect(_ service: SocketService) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.error = nil
        }
    }
    
    func socketServiceDidDisconnect(_ service: SocketService) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    func socketService(_ service: SocketService, didEncounterError error: Error) {
        DispatchQueue.main.async {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    SocketServiceDemo()
}