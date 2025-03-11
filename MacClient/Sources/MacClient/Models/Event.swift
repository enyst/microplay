import Foundation

/// Represents an event received from the OpenHands server
struct Event: Identifiable {
    /// The unique identifier of the event
    let id: Int
    
    /// The timestamp of the event in ISO 8601 format
    let timestamp: String
    
    /// The source of the event (agent or user)
    let source: String
    
    /// A human-readable message describing the event
    let message: String
    
    /// The ID of the event that caused this event (for observations)
    let cause: Int?
    
    // For actions
    
    /// The type of action (e.g., "message", "run", etc.)
    let action: String?
    
    /// Action-specific arguments
    let args: [String: Any]?
    
    // For observations
    
    /// The type of observation
    let observation: String?
    
    /// The content of the observation
    let content: String?
    
    /// Observation-specific extra data
    let extras: [String: Any]?
    
    /// Creates an Event from a dictionary
    /// - Parameter dict: The dictionary containing the event data
    /// - Returns: An Event if the dictionary contains valid data, nil otherwise
    static func from(dict: [String: Any]) -> Event? {
        guard let id = dict["id"] as? Int,
              let timestamp = dict["timestamp"] as? String,
              let source = dict["source"] as? String,
              let message = dict["message"] as? String else {
            return nil
        }
        
        return Event(
            id: id,
            timestamp: timestamp,
            source: source,
            message: message,
            cause: dict["cause"] as? Int,
            action: dict["action"] as? String,
            args: dict["args"] as? [String: Any],
            observation: dict["observation"] as? String,
            content: dict["content"] as? String,
            extras: dict["extras"] as? [String: Any]
        )
    }
    
    /// Returns a formatted date from the timestamp
    var formattedDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: timestamp)
    }
    
    /// Returns true if the event is an action
    var isAction: Bool {
        return action != nil
    }
    
    /// Returns true if the event is an observation
    var isObservation: Bool {
        return observation != nil
    }
    
    /// Returns true if the event is a message
    var isMessage: Bool {
        return action == "message"
    }
    
    /// Returns true if the event is an error
    var isError: Bool {
        return observation == "error"
    }
    
    /// Returns the thought from a message action, if available
    var thought: String? {
        guard isMessage, let args = args else { return nil }
        return args["thought"] as? String
    }
    
    /// Returns the image URLs from a message action, if available
    var imageUrls: [String]? {
        guard isMessage, let args = args else { return nil }
        return args["image_urls"] as? [String]
    }
    
    /// Returns true if the agent is waiting for a response
    var waitForResponse: Bool? {
        guard isMessage, let args = args else { return nil }
        return args["wait_for_response"] as? Bool
    }
    
    /// Returns the command from a run observation, if available
    var command: String? {
        guard observation == "run", let extras = extras else { return nil }
        return extras["command"] as? String
    }
    
    /// Returns the exit code from a run observation, if available
    var exitCode: Int? {
        guard observation == "run", let extras = extras,
              let metadata = extras["metadata"] as? [String: Any] else { return nil }
        return metadata["exit_code"] as? Int
    }
    
    /// Returns the path from a file operation observation, if available
    var path: String? {
        guard let extras = extras, ["read", "write", "edit"].contains(observation ?? "") else { return nil }
        return extras["path"] as? String
    }
    
    /// Returns the URL from a browse observation, if available
    var url: String? {
        guard observation == "browse", let extras = extras else { return nil }
        return extras["url"] as? String
    }
    
    /// Returns the agent state from an agent_state_changed observation, if available
    var agentState: String? {
        guard observation == "agent_state_changed", let extras = extras else { return nil }
        return extras["agent_state"] as? String
    }
    
    /// Returns the error ID from an error observation, if available
    var errorId: String? {
        guard observation == "error", let extras = extras else { return nil }
        return extras["error_id"] as? String
    }
}