import Foundation

/// Represents a message in the chat interface
struct Message: Identifiable {
    /// The unique identifier of the message
    let id = UUID()
    
    /// The text content of the message
    let text: String
    
    /// The sender of the message (agent, user, or system)
    let sender: String
    
    /// The timestamp when the message was created
    let timestamp = Date()
    
    /// The URLs of images attached to the message, if any
    var imageUrls: [String]?
    
    /// The thought process behind the message, if any
    var thought: String?
    
    /// Whether the message is an error
    var isError: Bool {
        return sender == "system" && text.starts(with: "Error:")
    }
    
    /// Whether the message is from the agent
    var isFromAgent: Bool {
        return sender == "agent"
    }
    
    /// Whether the message is from the user
    var isFromUser: Bool {
        return sender == "user"
    }
    
    /// Whether the message is from the system
    var isFromSystem: Bool {
        return sender == "system"
    }
    
    /// Returns a formatted date string for the timestamp
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}