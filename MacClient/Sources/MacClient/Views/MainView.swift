import SwiftUI

/// The main view of the application
struct MainView: View {
    /// The application state
    @StateObject private var appState = AppState()
    
    /// The conversation ID input
    @State private var conversationIdInput = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Connection status
                HStack {
                    Circle()
                        .fill(appState.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    
                    Text(appState.isConnected ? "Connected" : "Disconnected")
                        .font(.headline)
                    
                    Spacer()
                    
                    if appState.isAgentThinking {
                        Label("Thinking...", systemImage: "brain")
                            .foregroundColor(.blue)
                    } else if appState.isAgentExecuting {
                        Label("Executing...", systemImage: "terminal")
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                
                // Connection controls
                if !appState.isConnected {
                    VStack {
                        TextField("Conversation ID", text: $conversationIdInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                        
                        Button("Connect") {
                            appState.connect(conversationId: conversationIdInput)
                        }
                        .disabled(conversationIdInput.isEmpty)
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                } else {
                    // Chat view
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(appState.events) { event in
                                EventView(event: event)
                            }
                        }
                        .padding()
                    }
                    
                    // Message input
                    HStack {
                        TextField("Message", text: $appState.userMessage)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: {
                            appState.sendMessage(content: appState.userMessage)
                        }) {
                            Image(systemName: "paperplane.fill")
                        }
                        .disabled(appState.userMessage.isEmpty)
                    }
                    .padding()
                }
                
                // Error display
                if let error = appState.error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding()
                }
                
                // Disconnect button
                if appState.isConnected {
                    Button("Disconnect") {
                        appState.disconnect()
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
            }
            .navigationTitle("OpenHands Client")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        // Open settings
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
}

/// A view for displaying an event
struct EventView: View {
    /// The event to display
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Event header
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
            
            // Event message
            Text(event.message)
                .font(.body)
            
            // Event details
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
            
            // Event content
            if let content = event.content {
                Text(content)
                    .font(.body)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Event thought
            if let thought = event.thought {
                Text("Thought: \(thought)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(event.source == "agent" ? Color.blue.opacity(0.05) : Color.green.opacity(0.05))
        )
    }
}

#Preview {
    MainView()
}