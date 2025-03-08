---
name: types
type: knowledge
agent: CodeActAgent
version: 1.0.0
triggers:
- openhands-types
---

# OpenHands Mac App Types

This document catalogs the data types needed for implementing the OpenHands Mac client.

## Communication Types

### Events (Backend to Frontend)

#### Base Event Structure
```json
{
  "timestamp": "2025-01-31T17:00:00.000Z",
  "source": "AGENT",
  "message": "Event message"
}
```

#### Event Types

##### CmdOutputObservation
Represents the output of a command execution.

```json
{
  "timestamp": "2025-01-31T17:00:00.000Z",
  "source": "AGENT",
  "message": "Executing command: ls -l /workspace",
  "observation": {
    "observation": "CmdOutputObservation"
  },
  "content": "total 4\ndrwxr-xr-x 1 openhands openhands 4096 Jan 31 16:00 workspace",
  "extras": {
    "command": "ls -l /workspace",
    "cwd": "/workspace",
    "exit_code": 0
  },
  "success": true
}
```

### User Actions (Frontend to Backend)

#### Base User Action Structure
```json
{
  "action": "action_type_string",
  "args": {
    // Action-specific arguments
  },
  "timeout": 60 // Optional
}
```

#### Action Types

##### CmdRunAction
Executes a shell command.

```json
{
  "action": "CmdRunAction",
  "args": {
    "command": "ls -l /workspace",
    "hidden": false
  }
}
```

##### ChangeAgentStateAction
Updates the state of the agent.

```json
{
  "action": "change_agent_state",
  "args": {
    "agent_state": "PAUSED"
  }
}
```

##### MessageAction
Sends a message to the agent.

```json
{
  "action": "message",
  "args": {
    "content": "Hello, agent!",
    "image_urls": [],
    "timestamp": "2025-01-31T21:00:00.000Z"
  }
}
```

##### ReadAction
Reads the content of a file.

```json
{
  "action": "read",
  "args": {
    "path": "/workspace/file.txt",
    "start": 0,
    "end": -1
  }
}
```

##### WriteAction
Writes content to a file.

```json
{
  "action": "write",
  "args": {
    "path": "/workspace/file.txt",
    "content": "New file content"
  }
}
```

## Enumerations

### AgentState
Represents the current state of the agent.

- `LOADING`: Agent is loading/initializing
- `INIT`: Agent is initialized
- `RUNNING`: Agent is currently running/executing tasks
- `AWAITING_USER_INPUT`: Agent is waiting for user input/message
- `PAUSED`: Agent execution is paused
- `STOPPED`: Agent execution is stopped
- `FINISHED`: Agent has finished the task successfully
- `REJECTED`: Agent rejected the task or request
- `ERROR`: Agent encountered an error during execution
- `RATE_LIMITED`: Agent is rate-limited by an external service
- `AWAITING_USER_CONFIRMATION`: Agent is waiting for user confirmation
- `USER_CONFIRMED`: User has confirmed agent's action
- `USER_REJECTED`: User has rejected agent's action

### EventSource
Indicates the source of an event.

- `AGENT`: Event originated from the agent
- `USER`: Event originated from the user
- `ENVIRONMENT`: Event originated from the environment

## File System Types

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

## Settings Types

### BackendSettings
Configuration for connecting to the backend.

```json
{
  "backend_host": "localhost",
  "backend_port": 8000,
  "use_tls": false
}
```
