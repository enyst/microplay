---
name: types
type: knowledge
agent: CodeActAgent
version: 1.0.0
triggers:
- openhands-events
---

# OpenHands Events JSON Specification

This document defines the complete JSON specification for all events that the OpenHands backend supports and emits to frontends. This specification will serve as a reference for implementing Swift counterparts in the Mac client.


## Table of Contents

- [Event Architecture Overview](#event-architecture-overview)
- [Base Event Structure](#base-event-structure)
- [Action Events](#action-events)
  - [Agent Actions](#agent-actions)
  - [Command Actions](#command-actions)
  - [File Actions](#file-actions)
  - [Browse Actions](#browse-actions)
  - [Message Actions](#message-actions)
  - [System Actions](#system-actions)
- [Observation Events](#observation-events)
  - [Command Observations](#command-observations)
  - [File Observations](#file-observations)
  - [Browser Observations](#browser-observations)
  - [Agent Observations](#agent-observations)
  - [Status Observations](#status-observations)
- [Enumerations](#enumerations)
  - [AgentState](#agentstate)
  - [EventSource](#eventsource)
  - [ActionConfirmationStatus](#actionconfirmationstatus)
  - [ActionSecurityRisk](#actionsecurityrisk)
  - [RecallType](#recalltype)
  - [FileEditSource](#fileEditsource)
  - [FileReadSource](#fileReadsource)
  - [ActionType](#actiontype)
  - [ObservationType](#observationtype)

## Event Architecture Overview

The OpenHands event system follows a hierarchical structure:

- **Event** (base class): Common properties for all events
  - **Action**: Events representing commands/operations to perform
  - **Observation**: Events representing results or responses

Events flow between the backend and frontend:
- **Backend → Frontend**: ALL events (both actions and observations) are streamed via `oh_event` socket event. The Mac Client needs to read and display every one.
- **Frontend → Backend**: User actions on the user interface are sent via `oh_action` socket event. The Mac Client needs to implement methods to generate these action payloads based on UI interactions.

## Base Event Structure

All events share a common structure with these basic properties:

```json
{
  "id": 123,                              // Optional: Unique identifier
  "timestamp": "2023-01-01T12:00:00Z",    // ISO timestamp
  "source": "AGENT",                      // Event source (AGENT, USER, ENVIRONMENT)
  "message": "Human-readable description", // Optional: User-friendly message to be displayed in the frontend
  "cause": 456                            // Optional: ID of the event that caused this event
}
```

When serialized, events are formatted differently based on their type:

- **Actions** have this structure:
```json
{
  // Base event properties
  "action": "action_type_string",         // The type of action
  "args": {                               // Action-specific properties
    // Properties specific to this action type
  },
  "timeout": 60                           // Optional: Timeout in seconds
}
```

- **Observations** have this structure:
```json
{
  // Base event properties
  "observation": "observation_type_string", // The type of observation
  "content": "Observation content text",    // Primary content of the observation
  "extras": {                               // Observation-specific properties
    // Properties specific to this observation type
  },
  "success": true                           // Optional: For some observation types
}
```

## Action Events

### Agent Actions

#### ChangeAgentStateAction

Changes the state of the agent (e.g., paused, running).

```json
{
  "action": "change_agent_state",
  "args": {
    "agent_state": "PAUSED",    // New agent state
    "thought": "Optional explanation for the state change"
  }
}
```

#### AgentSummarizeAction

Provides a summary of results.

```json
{
  "action": "summarize",
  "args": {
    "summary": "Summary text of the agent's work or findings"
  }
}
```

#### AgentFinishAction

Indicates the agent has completed a task.

```json
{
  "action": "finish",
  "args": {
    "final_thought": "The agent's final thought about the completed task",
    "task_completed": "true",  // "true", "partial", "false"
    "outputs": {
      "content": "Final result content",
      // Other key-value outputs
    },
    "thought": "Agent's reasoning about completing the task"
  }
}
```

#### AgentThinkAction

Logs an agent's thought process.

```json
{
  "action": "think",
  "args": {
    "thought": "The agent's detailed thought process"
  }
}
```

#### AgentRejectAction

Indicates the agent is rejecting a task.

```json
{
  "action": "reject",
  "args": {
    "outputs": {
      "reason": "Reason for the rejection"
      // Other key-value outputs
    },
    "thought": "Agent's reasoning for the rejection"
  }
}
```

#### AgentDelegateAction

Delegates a task to another agent.

```json
{
  "action": "delegate",
  "args": {
    "agent": "target_agent_name",
    "inputs": {
      // Key-value inputs for the delegated agent
      "task": "Specific task for the delegated agent"
    },
    "thought": "Reasoning for delegating this task"
  }
}
```

#### AgentRecallAction

Retrieves data from memory or knowledge base.

```json
{
  "action": "recall",
  "args": {
    "query": "The search query to retrieve data",
    "thought": "Reasoning for recalling this information"
  }
}
```

### Command Actions

#### CmdRunAction

Executes a shell command.

```json
{
  "action": "run",
  "args": {
    "command": "ls -la",                  // Command to execute
    "is_input": false,                    // Whether this is input to a running process
    "thought": "Optional explanation",    // Agent's thought about this command
    "blocking": false,                    // Whether to block until completion
    "hidden": false,                      // Whether to hide command output from user
    "confirmation_state": "confirmed",    // confirmation status
    "security_risk": null                 // Optional security risk assessment
  }
}
```

#### IPythonRunCellAction

Executes Python code in an IPython environment.

```json
{
  "action": "run_ipython",
  "args": {
    "code": "import pandas as pd\ndf = pd.DataFrame()",  // Python code to execute
    "thought": "Optional explanation",                   // Agent's thought about this code
    "include_extra": true,                               // Whether to include extra info in output
    "confirmation_state": "confirmed",                   // confirmation status
    "security_risk": null,                               // Optional security risk assessment
    "kernel_init_code": ""                               // Code to run if kernel is restarted
  }
}
```

### File Actions

#### FileReadAction

Reads content from a file.

```json
{
  "action": "read",
  "args": {
    "path": "/path/to/file.txt",          // Path to the file
    "start": 0,                           // Starting line (0-indexed)
    "end": -1,                            // Ending line (-1 for EOF)
    "thought": "Optional explanation",    // Agent's thought about reading this file
    "impl_source": "default",             // Implementation source
    "view_range": null                    // Optional view range (used in OH_ACI mode)
  }
}
```

#### FileWriteAction

Writes content to a file.

```json
{
  "action": "write",
  "args": {
    "path": "/path/to/file.txt",          // Path to the file
    "content": "File content to write",   // Content to write
    "start": 0,                           // Starting line (0-indexed)
    "end": -1,                            // Ending line (-1 for EOF)
    "thought": "Optional explanation",    // Agent's thought about writing this file
    "security_risk": null                 // Optional security risk assessment
  }
}
```

#### FileEditAction

Performs more complex file edits.

```json
{
  "action": "edit",
  "args": {
    "path": "/path/to/file.txt",          // Path to the file
    
    // For OH_ACI mode
    "command": "str_replace",             // Edit command (view, create, str_replace, insert, undo_edit, write)
    "file_text": null,                    // File content for 'create' command
    "old_str": "text to replace",         // String to replace for 'str_replace' command
    "new_str": "replacement text",        // Replacement string for 'str_replace' or 'insert' commands
    "insert_line": null,                  // Line number for 'insert' command
    
    // For LLM-based editing
    "content": "",                        // Content to write or edit
    "start": 1,                           // Starting line (1-indexed, inclusive)
    "end": -1,                            // Ending line (1-indexed, inclusive, -1 for EOF)
    
    "thought": "Optional explanation",    // Agent's thought about editing this file
    "security_risk": null,                // Optional security risk assessment
    "impl_source": "oh_aci"               // Implementation source (oh_aci or llm_based_edit)
  }
}
```

### Browse Actions

#### BrowseURLAction

Browses a URL.

```json
{
  "action": "browse",
  "args": {
    "url": "https://example.com",         // URL to browse
    "thought": "Optional explanation",    // Agent's thought about browsing this URL
    "security_risk": null                 // Optional security risk assessment
  }
}
```

#### BrowseInteractiveAction

Performs interactive browser actions.

```json
{
  "action": "browse_interactive",
  "args": {
    "browser_actions": "browser.click('#button')",   // Browser action code 
    "thought": "Optional explanation",               // Agent's thought about these actions
    "browsergym_send_msg_to_user": "",               // Message to send to user
    "security_risk": null                            // Optional security risk assessment
  }
}
```

### Message Actions

#### MessageAction

Sends a message between agent and user.

```json
{
  "action": "message",
  "args": {
    "content": "Message content",         // Content of the message
    "image_urls": [                       // Optional list of image URLs
      "https://example.com/image.jpg"
    ],
    "wait_for_response": false,           // Whether to wait for response
    "security_risk": null                 // Optional security risk assessment
  }
}
```

### System Actions

#### NullAction

A placeholder action that does nothing.

```json
{
  "action": "null"
}
```

## Observation Events

### Command Observations

#### CmdOutputObservation

Represents the output of a command execution.

```json
{
  "observation": "run",
  "content": "Command output text",
  "extras": {
    "command": "ls -la",                  // The command that was executed
    "metadata": {                         // Metadata about the command
      "exit_code": 0,                     // Exit code of the command
      "pid": 12345,                       // Process ID
      "username": "user",                 // Username
      "hostname": "host",                 // Hostname
      "working_dir": "/current/dir",      // Working directory
      "py_interpreter_path": "/path/to/python", // Python interpreter path
      "prefix": "",                       // Prefix to add to command output
      "suffix": ""                        // Suffix to add to command output
    },
    "hidden": false                       // Whether command output is hidden from user
  },
  "success": true                         // Whether command executed successfully
}
```

#### IPythonRunCellObservation

Represents the output of a Python code execution in IPython.

```json
{
  "observation": "run_ipython",
  "content": "Python code execution output",
  "extras": {
    "code": "import pandas as pd\ndf = pd.DataFrame()"  // The code that was executed
  }
}
```

### File Observations

#### FileReadObservation

Represents the content read from a file.

```json
{
  "observation": "read",
  "content": "File content read from the file",
  "extras": {
    "path": "/path/to/file.txt",          // Path to the file that was read
    "impl_source": "default"              // Implementation source
  }
}
```

#### FileWriteObservation

Represents the result of writing to a file.

```json
{
  "observation": "write",
  "content": "Success message or details about write operation",
  "extras": {
    "path": "/path/to/file.txt"           // Path to the file that was written
  }
}
```

#### FileEditObservation

Represents the result of editing a file.

```json
{
  "observation": "edit",
  "content": "Edit results, often a diff or success message",
  "extras": {
    "path": "/path/to/file.txt",          // Path to the file that was edited
    "prev_exist": true,                   // Whether the file existed before the edit
    "old_content": "Previous content",    // File content before the edit
    "new_content": "New content",         // File content after the edit
    "impl_source": "llm_based_edit",      // Implementation source
    "diff": null                          // Raw diff between old and new content (OH_ACI mode)
  }
}
```

### Browser Observations

#### BrowserOutputObservation

Represents the output of a browser operation.

```json
{
  "observation": "browse",
  "content": "Browser content or operation result",
  "extras": {
    "url": "https://example.com",          // URL that was browsed
    "trigger_by_action": "browse",         // Action that triggered this observation
    "screenshot": "",                      // Base64-encoded screenshot (often empty in JSON)
    "set_of_marks": "",                    // Browser marks information
    "error": false,                        // Whether there was an error
    "goal_image_urls": [],                 // URLs of goal images
    "open_pages_urls": [                   // URLs of open browser pages
      "https://example.com"
    ],
    "active_page_index": 0,                // Index of the active page
    "last_browser_action": "",             // Last browser action performed
    "last_browser_action_error": "",       // Error message from last browser action
    "focused_element_bid": ""              // ID of the focused element
  }
}
```

### Agent Observations

#### AgentStateChangedObservation

Represents a change in the agent's state.

```json
{
  "observation": "agent_state_changed",
  "content": "",
  "extras": {
    "agent_state": "RUNNING"               // New agent state
  }
}
```

#### AgentCondensationObservation

Represents the result of memory condensation.

```json
{
  "observation": "condense",
  "content": "Condensed memory content"
}
```

#### AgentThinkObservation

Represents the agent's thought process.

```json
{
  "observation": "think",
  "content": "Agent's thought content"
}
```

#### RecallObservation

Represents data retrieved from memory or knowledge.

```json
{
  "observation": "recall",
  "content": "Recalled information",
  "extras": {
    "recall_type": "environment_info",     // Type of recall
    "repo_name": "openhands",              // Repository name
    "repo_directory": "/path/to/repo",     // Repository directory
    "repo_instructions": "Task instructions", // Repository instructions
    "runtime_hosts": {},                   // Runtime hosts information
    "additional_agent_instructions": "",   // Additional instructions
    "microagent_knowledge": [              // Knowledge from microagents
      {
        "agent_name": "python_best_practices",
        "trigger_word": "python",
        "content": "Use virtual environments"
      }
    ]
  }
}
```

#### AgentDelegateObservation

Represents the result of delegating to another agent.

```json
{
  "observation": "delegate",
  "content": "Delegation result content",
  "extras": {
    "outputs": {                           // Outputs from the delegated agent
      // Key-value outputs
    }
  }
}
```

### Status Observations

#### ErrorObservation

Represents an error encountered by the agent.

```json
{
  "observation": "error",
  "content": "Error message or details",
  "extras": {
    "error_id": "error_identifier"          // Optional error identifier
  }
}
```

#### SuccessObservation

Represents a successful operation.

```json
{
  "observation": "success",
  "content": "Success message or details"
}
```

#### UserRejectObservation

Represents a user rejection.

```json
{
  "observation": "user_rejected",
  "content": "User rejection message or details"
}
```

#### NullObservation

A placeholder observation that contains no meaningful information.

```json
{
  "observation": "null",
  "content": ""
}
```

## Enumerations

### AgentState

Represents the current state of the agent.

```json
// One of these string values:
"LOADING"                    // Agent is loading/initializing
"INIT"                       // Agent is initialized
"RUNNING"                    // Agent is currently running/executing tasks
"AWAITING_USER_INPUT"        // Agent is waiting for user input/message
"PAUSED"                     // Agent execution is paused
"STOPPED"                    // Agent execution is stopped
"FINISHED"                   // Agent has finished the task successfully
"REJECTED"                   // Agent rejected the task or request
"ERROR"                      // Agent encountered an error during execution
"RATE_LIMITED"               // Agent is rate-limited by an external service
"AWAITING_USER_CONFIRMATION" // Agent is waiting for user confirmation
"USER_CONFIRMED"             // User has confirmed agent's action
"USER_REJECTED"              // User has rejected agent's action
```

### EventSource

Indicates the source of an event.

```json
// One of these string values:
"agent"       // Event originated from the agent
"user"        // Event originated from the user
"environment" // Event originated from the environment
```

### ActionConfirmationStatus

Indicates the confirmation status of an action.

```json
// One of these string values:
"confirmed"            // Action is confirmed
"rejected"             // Action is rejected
"awaiting_confirmation" // Action is awaiting confirmation
```

### ActionSecurityRisk

Indicates the security risk level of an action.

```json
// One of these integer values:
-1  // UNKNOWN
0   // LOW
1   // MEDIUM
2   // HIGH
```

### RecallType

Indicates the type of information recalled.

```json
// One of these string values:
"environment_info"      // Environment information (repo instructions, runtime, etc.)
"knowledge_microagent"  // Knowledge from a microagent
"default"               // Default or other type of recall
```

### FileEditSource

Indicates the source of a file edit implementation.

```json
// One of these string values:
"llm_based_edit"  // LLM-based editing
"oh_aci"          // OpenHands ACI
```

### FileReadSource

Indicates the source of a file read implementation.

```json
// One of these string values:
"oh_aci"    // OpenHands ACI
"default"   // Default implementation
```

### ActionType

Defines the supported action types.

```json
// One of these string values:
"null"                // Empty action that does nothing
"run"                 // Run shell command
"run_ipython"         // Run Python code in IPython
"browse"              // Browse a URL
"browse_interactive"  // Interact with a browser
"read"                // Read file
"write"               // Write to file
"edit"                // Edit file
"message"             // Send message
"think"               // Log agent thought
"delegate"            // Delegate to another agent
"finish"              // Finish task
"reject"              // Reject task
"summarize"           // Summarize results
"recall"              // Recall information from memory
"change_agent_state"  // Change agent state
```

### ObservationType

Defines the supported observation types.

```json
// One of these string values:
"null"               // Empty observation
"run"                // Command output
"run_ipython"        // IPython execution result
"browse"             // Browser output
"read"               // File read result
"write"              // File write result
"edit"               // File edit result
"error"              // Error
"success"            // Success
"user_rejected"      // User rejection
"agent_state_changed" // Agent state changed
"delegate"           // Delegation result
"think"              // Agent thought result
"condense"           // Memory condensation result
"recall"             // Memory recall result
```

---

# ADDENDUM: File System Types for the Mac Client functionality

IMPORTANT: unlike the above, this is open to change!

### FileNode
Represents a file or directory in the workspace.

```json
{
  "path": "/workspace/dir",
  "name": "dir",
  "type": "directory",
  "children": [
    {
      "path": "/workspace/dir/file.txt",
      "name": "file.txt",
      "type": "file",
      "size": 1024
    }
  ]
}
```

### FileContent
Represents the content of a file.

```json
{
  "code": "File content as string"
}
```

### BackendSettings
Configuration for connecting to the backend.

```json
{
  "backend_host": "localhost",
  "backend_port": 8000,
  "use_tls": false
}
```
