---
name  :  mac_app_code_exploration_findings
type  :  task
agent  :  CodeActAgent
---

# OpenHands Mac App Code Exploration Findings

This document provides detailed findings from an exploration of the codebase relevant to the Mac Application. It serves as a technical reference that outlines the functions, event structures, and system integrations discovered during the investigation.

## Overview

Our exploration focused on the integration between the UI components and backend actions through SocketIO. In particular, we reviewed the following aspects:

- **Event Communication:** Implementation details of the `oh_event` and `oh_action` event types.
- **Backend Actions:** Detailed payloads and behavior for actions such as `run` (command execution), `change_agent_state`, and `message`.
- **UI Function Calls:** How UI components trigger backend events using functions available in the code, including terminal command execution and file management.

## Key Functions and Event Structures

### oh_event

- **Purpose:** Receive asynchronous messages from the backend server.
- **Payload Structure:**
  - `timestamp`: ISO timestamp string.
  - `source`: Event source enumeration (e.g., AGENT).
  - `message`: A textual message, e.g., "Executing command: ls -l".
  - `observation`: A nested payload including details like command output and additional metadata.

**Example Payload:**

```json
{
  "timestamp": "2025-01-31T17:00:00.000Z",
  "source": "AGENT",
  "message": "Executing command: ls -l /workspace",
  "observation": { "observation": "CmdOutputObservation" },
  "content": "total 4\ndrwxr-xr-x 1 openhands openhands 4096 Jan 31 16:00 workspace",
  "extras": { "command": "ls -l /workspace", "cwd": "/workspace", "exit_code": 0 },
  "success": true
}
```

### oh_action

- **Purpose:** Send actions from the frontend UI to the backend.
- **Common Actions:**
  - **Run Command (`run`)**: Executes a bash command on the backend.
  - **Change Agent State (`change_agent_state`)**: Updates the state of the agent (e.g., PAUSED, RUNNING).
  - **Send Message (`message`)**: Sends text messages; typically used in the chat interface.

**Run Command Action Example:**

```json
{
  "action": "CmdRunAction",
  "args": { "command": "ls -l /workspace", "hidden": false }
}
```

### File Actions

The codebase also defines actions for file operations, such as:

- **READ:** Retrieve file contents from the workspace.
- **WRITE:** Create or modify file content.

Parameters typically include the file path and optional start/end line numbers.

## UI and Backend Integration

The UI components communicate with backend services using SocketIO. Key integration points include:

- **Terminal Integration:** Commands (e.g., `ls -l`) are executed, and their output is captured via `oh_event` callbacks.
- **Agent State Management:** UI control buttons trigger `change_agent_state` actions that modify the agent's behavior.
- **File Browsing:** The file explorer component retrieves file content via READ actions and can trigger WRITE actions for file modifications.

## Additional Technical Insights

- The backend leverages Python modules (such as `openhands/server/shared.py` and `openhands/server/listen_socket.py`) to manage SocketIO communications.
- Payloads are serialized in JSON, facilitating debugging and extendability.
- Asynchronous event handling ensures a responsive UI during long-running operations.

# Details from Code Exploration Findings

## 1. Frontend Code Findings (React)

The web frontend is built using React and provides valuable UI components and logic that can be used as a reference for the Mac app development.

### 1.1. UI Components (frontend/src/components/features/)

* **Chat Feature (chat/):**
    * `chat/chat-input.tsx`: User input area component using `TextareaAutosize`. Handles text input, submission, image pasting/drag-and-drop. Key prop: `onSubmit(message: string)`.
    * `chat/interactive-chat-box.tsx`: Wraps `ChatInput` and adds image upload/display functionality. Prop: `onSubmit(message: string, images: File[])`.
    * `chat/messages.tsx`: Renders a list of chat messages.
    * `chat/chat-message.tsx`: Displays individual chat messages (agent outputs).
    * **File Explorer Feature (file-explorer/):**
    * `file-explorer/file-explorer.tsx`: Main file explorer component, uses `useListFiles` hook to fetch file list and renders `ExplorerTree`.
    * `file-explorer/explorer-tree.tsx`: Renders the file tree structure recursively using `TreeNode` components.
    * `file-explorer/tree-node.tsx`: Renders individual file/folder nodes, uses `useListFiles` (for folders) and `useListFile` (for file content/metadata).
    * **Controls Feature (controls/):**
    * `controls/agent-control-bar.tsx`: Contains Pause/Resume button using `ActionButton`. Sends `CHANGE_AGENT_STATE` actions.
    * `controls/agent-status-bar.tsx`: Displays agent status using `AGENT_STATUS_MAP` and Redux state.
    * **Terminal Feature (terminal/):**
    * `terminal/terminal.tsx`: Renders a terminal UI using `xterm.js` and `useTerminal` hook.
    * `hooks/use-terminal.ts`: Custom hook for integrating `xterm.js`, handling input, output, and commands.

### 1.2. Shared Components (frontend/src/components/shared/)

* `buttons/action-button.tsx`: Reusable button component for triggering agent actions, with tooltip and styling.
* `modals/settings/settings-modal.tsx`: Modal for displaying and editing application settings, uses `SettingsForm`.
* `modals/settings/settings-form.tsx`: Form component within `SettingsModal`, contains various input fields for settings.

### 1.3. Hooks (frontend/src/hooks/query/)

* `hooks/query/use-list-files.ts`: Fetches file list from backend API endpoint `/api/conversations/{conversation_id}/list-files`.
* `hooks/query/use-list-file.ts`: (Misnamed, should be `useFileContent`) Fetches file content from backend API endpoint `/api/conversations/{conversation_id}/select-file`.
* `hooks/use-terminal.ts`: Integrates `xterm.js` terminal emulator, handles input, output, and commands.

### 1.4. Contexts (frontend/src/context/)

* `context/ws-client-provider.tsx`: Provides WebSocket context (`WsClientContext`, `useWsClient`) for SocketIO communication. Manages connection and `send` function.
* `context/conversation-context.tsx`: Provides conversation ID context (`ConversationContext`, `useConversation`) from route parameters.
* `context/files.tsx`: Provides file-related state management context (`FilesContext`, `useFiles`) for file explorer.
* `context/settings-context.tsx`: Provides settings management context.

### 1.5. API Client (frontend/src/api/)

* `api/open-hands.ts`: Defines `OpenHands` API client class with methods for interacting with backend REST API endpoints (e.g., `getFiles`, `getFile`, `saveFile`, `getSettings`, `saveSettings`, `createConversation`, `getModels`, `getAgents`).
* `api/open-hands-axios.ts`: Configures Axios instance for API requests, handles authorization headers.

### 1.6. Types and Enums (frontend/src/types/)

* `types/action-type.tsx`: Defines `ActionType` enum listing all possible action types sent to the backend (e.g., `MESSAGE`, `RUN`, `READ`, `WRITE`, `CHANGE_AGENT_STATE`).
* `types/agent-state.tsx`: Defines `AgentState` enum listing all possible agent states (e.g., `RUNNING`, `AWAITING_USER_INPUT`, `STOPPED`).
* `components/agent-status-map.constant.ts`: Defines `AGENT_STATUS_MAP` constant, mapping `AgentState` to status messages and indicator styles.

## 2. Backend Code Findings (Python FastAPI)

The backend is built using FastAPI and provides REST API endpoints and a SocketIO server for communication.

### 2.1. SocketIO Server (openhands/server/listen_socket.py)

* Sets up SocketIO server using `socketio.AsyncServer`.
* Handles `connect`, `oh_action`, and `disconnect` events.
* Implements authentication and authorization for Saas mode using JWT cookies.
* Manages conversations and agent sessions using `conversation_manager`.
* Streams agent events to clients via `oh_event` events.

### 2.2. API Endpoints (openhands/server/routes/)

* **File Management (files.py):**
    * `GET /api/conversations/{conversation_id}/list-files`: Lists files in workspace.
    * `GET /api/conversations/{conversation_id}/select-file`: Retrieves file content.
    * `POST /api/conversations/{conversation_id}/save-file`: Saves file content.
    * `POST /api/conversations/{conversation_id}/upload-files`: Uploads files to workspace.
    * `GET /api/conversations/{conversation_id}/zip-directory`: Downloads workspace as zip.
    * **Conversation Management (manage_conversations.py):**
    * `POST /api/conversations`: Creates a new conversation.
    * `GET /api/conversations`: Lists/searches conversations.
    * `GET /api/conversations/{conversation_id}`: Retrieves conversation details.
    * `PATCH /api/conversations/{conversation_id}`: Updates conversation (e.g., title).
    * `DELETE /api/conversations/{conversation_id}`: Deletes conversation.
    * **Settings (settings.py):**
    * `GET /api/settings`: Loads application settings.
    * `POST /api/settings`: Stores application settings.
    * **Options (public.py):**
    * `GET /api/options/models`: Gets available AI models.
    * `GET /api/options/agents`: Gets available agents.
    * `GET /api/options/security-analyzers`: Gets available security analyzers.
    * `GET /api/options/config`: Gets server configuration.

### 2.3. Shared Resources (openhands/server/shared.py)

* Initializes and provides shared instances of `sio` (SocketIO server), `conversation_manager`, `config`, `server_config`, `file_store`, `SettingsStoreImpl`, `ConversationStoreImpl`.

### 2.4. Core Agent Logic (openhands/core/)

* `core/main.py`: CLI entry point, contains `run_controller` function for agent execution loop.
* `core/loop.py`: Defines `run_agent_until_done` function, the agent's main execution loop (simple polling loop).
* `core/config/`: Contains configuration loading logic.
* `core/exceptions.py`: Defines core exceptions.


## 3.  Backend Communication

The Mac app UI will communicate with the Python backend using **SocketIO**.

### 3.1. SocketIO Interface

The Mac app will interact with the backend server using SocketIO events. The key events are `oh_event` (for receiving events from the backend) and `oh_action` (for sending actions to the backend).

#### 3.1.1. Receiving Events (`oh_event`)

The backend server sends events to the Mac app using the `oh_event` event. Events are serialized as dictionaries in JSON format.

**`oh_event` Data Structure:**

```json
{
    "timestamp": "ISO timestamp string",
    "source": "event source enum value (string)",
    "message": "event message (string)",
    // ... other top-level keys ...

    // Action Event:
    "action": {
        // Action-specific data
    },
    "args": {
        // Action arguments
    },
    "timeout": (optional) timeout value (number)

    // Observation Event:
    "observation": {
        // Observation-specific data
    },
    "content": "observation content (string)",
    "extras": {
        // Extra observation details (dictionary)
    },
    "success": (optional) boolean indicating command success
}
```

**Example `oh_event`:**

```json
{
  "timestamp": "2025-01-31T17:00:00.000Z",
  "source": "AGENT",
  "message": "Executing command: ls -l /workspace",
  "observation": {
    "observation": "CmdOutputObservation"
  },
  "content": "total 4\\ndrwxr-xr-x 1 openhands openhands 4096 Jan 31 16:00 workspace\\n",
  "extras": {
    "command": "ls -l /workspace",
    "cwd": "/workspace",
    "exit_code": 0
  },
  "success": true
}
```

#### 3.1.2. Sending Actions (`oh_action`)

### 3.2. Examples of `oh_action` subtypes (from Web UI)

Here are some examples of `oh_action` subtypes that are currently sent by the web UI, based on our code exploration:

#### 3.2.1. Run Command (`"run"`)

*   **Action Type String:** `"run"`
*   **Backend Action Class:** `CmdRunAction`
*   **Example `oh_action` Payload (JSON):**
    ```json
    {
      "action": "run",
      "args": {
        "command": "ls -l /workspace",
        "hidden": false
      }
    }
    ```
*   **Source (Frontend):** `/workspace/playground/frontend/src/hooks/use-terminal.ts` (`getTerminalCommand` function)
*   **Description:** This action is sent when a user executes a command in the terminal within the web UI. It instructs the backend to run a bash command.

#### 3.2.2. Change Agent State (`"change_agent_state"`)

*   **Action Type String:** `"change_agent_state"`
*   **Backend Action Class:** `ChangeAgentStateAction`
*   **Example `oh_action` Payload (JSON):**
    ```json
    {
      "action": "change_agent_state",
      "args": {
        "agent_state": "PAUSED"
      }
    }
    ```
*   **Source (Frontend):** `/workspace/playground/frontend/src/components/features/controls/agent-control-bar.tsx` and other files using `generateAgentStateChangeEvent` function.
*   **Description:** This action is sent when the user interacts with UI controls to change the agent's state, such as pausing, resuming, or stopping the agent's execution.

#### 3.2.3. Send Message (`"message"`)

*   **Action Type String:** `"message"`
*   **Backend Action Class:** `MessageAction`
*   **Example `oh_action` Payload (JSON):**
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
*   **Source (Frontend):** `/workspace/playground/frontend/src/components/features/chat/chat-interface.tsx` (`createChatMessage` function)
*   **Description:** This action is sent when the user sends a message in the chat interface. It delivers the user's message content, image URLs (if any), and timestamp to the backend agent.

*   **Action Type String:** `"change_agent_state"`
*   **Backend Action Class:** `ChangeAgentStateAction`
*   **Example `oh_action` Payload (JSON):**
    ```json
    {
      "action": "change_agent_state",
      "args": {
        "agent_state": "PAUSED"
      }
    }
    ```
*   **Source (Frontend):** `/workspace/playground/frontend/src/components/features/controls/agent-control-bar.tsx` and other files using `generateAgentStateChangeEvent` function.
*   **Description:** This action is sent when the user interacts with UI controls to change the agent's state, such as pausing, resuming, or stopping the agent's execution.

The Mac app will need to be able to send similar `oh_action` events to interact with the OpenHands backend.

The Mac app sends actions to the backend server using the `oh_action` event. These actions are triggered by **user interactions within the Mac app**, and in the backend processing, they are associated with `EventSource.USER`. Actions are also sent as dictionaries in JSON format.

**`oh_action` Data Structure:**

```json
{
    "action": "action_type_string",  // e.g., "CmdRunAction", "BrowseURLAction", "FileEditAction"
    "args": {
        // Action-specific arguments (key-value pairs)
    },
    "timeout": (optional) timeout value in seconds (number)
}
```

**Example `oh_action` (Run Bash Command):**

To run the command `ls -l /workspace`, send the following `oh_action` message:

```json
{
  "action": "CmdRunAction",
  "args": {
    "command": "ls -l /workspace"
  }
}
```

**Available Actions:**

Here is a list of available actions that can be sent to the backend via the `oh_action` event, along with their action type strings and arguments:

*   **Agent Actions:** (Defined in `agent.py`)
    *   `CHANGE_AGENT_STATE` (`"change_agent_state"`):
        *   `agent_state` (str, required): The new agent state.
        *   `thought` (str, optional): Agent's thought about the state change.
    *   `SUMMARIZE` (`"summarize"`):
        *   `summary` (str, required): The summary text.
    *   `FINISH` (`"finish"`):
        *   `outputs` (dict, optional): Agent outputs (e.g., `{"content": "final result"}`).
        *   `thought` (str, optional): Agent's final thought/explanation.
    *   `REJECT` (`"reject"`):
        *   `outputs` (dict, optional): Rejection details (e.g., `{"reason": "cannot fulfill request"}`).
        *   `thought` (str, optional): Agent's thought about rejection.
    *   `DELEGATE` (`"delegate"`):
        *   `agent` (str, required): Name of the agent to delegate to.
        *   `inputs` (dict, required): Inputs for the delegated agent.
        *   `thought` (str, optional): Agent's thought about delegation.

*   **Browse Actions:** (Defined in `browse.py`)
    *   `BROWSE` (`"browse"`):
        *   `url` (str, required): The URL to browse.
        *   `thought` (str, optional): Agent's thought about browsing.
    *   `BROWSE_INTERACTIVE` (`"browse_interactive"`):
        *   `browser_actions` (str, required): String containing browser actions (Python code).
        *   `thought` (str, optional): Agent's thought about interactive browsing.
        *   `browsergym_send_msg_to_user` (str, optional): Internal field (ignore).

*   **Command Actions:** (Defined in `commands.py`)
    *   `RUN` (`"run"`):
        *   `command` (str, required): The bash command to run.
        *   `is_input` (bool, optional, default: `False`): Input to running process.
        *   `thought` (str, optional): Agent's thought about command.
        *   `blocking` (bool, optional, default: `False`): Blocking command.
        *   `hidden` (bool, optional, default: `False`): Hide command output.
        *   `confirmation_state` (optional): Ignore for basic use.
        *   `security_risk` (optional): Ignore for basic use.
    *   `RUN_IPYTHON` (`"run_ipython"`):
        *   `code` (str, required): Python code to run in IPython.
        *   `thought` (str, optional): Agent's thought about code.
        *   `include_extra` (bool, optional, default: `True`): Include extra output info.
        *   `confirmation_state` (optional): Ignore for basic use.
        *   `security_risk` (optional): Ignore for basic use.
        *   `kernel_init_code` (optional): Internal field (ignore).

*   **File Actions:** (Defined in `files.py`)
    *   `READ` (`"read"`):
        *   `path` (str, required): Path to file to read.
        *   `start` (int, optional, default: `0`): Start line (0-indexed).
        *   `end` (int, optional, default: `-1`): End line (-1 for EOF).
        *   `thought` (str, optional): Agent's thought about reading.
        *   `impl_source` (optional): Internal field (ignore).
        *   `translated_ipython_code` (optional): Internal field (ignore).
    *   `WRITE` (`"write"`):
        *   `path` (str, required): Path to file to write.
        *   `content` (str, required): Content to write.
        *   `start` (int, optional, default: `0`): Start line (ignore).
        *   `end` (int, optional, default: `-1`): End line (ignore).
        *   `thought` (str, optional): Agent's thought about writing.
    *   `EDIT` (`"edit"`):
        *   `path` (str, required): Path to file to edit.
        *   `content` (str, required): Content to edit/replace.
        *   `start` (int, optional, default: `1`): Start line (1-indexed, inclusive).
        *   `end` (int, optional, default: `-1`): End line (1-indexed, inclusive, -1 for EOF).
        *   `thought` (str, optional): Agent's thought about editing.
        *   `impl_source` (optional): Internal field (ignore).
        *   `translated_ipython_code` (optional): Internal field (ignore).

*   **Empty Action:** (Defined in `empty.py`)
    *   `NULL` (`"null"`):
        *   No arguments. No-operation action.

*   **Message Action:** (Defined in `message.py`)
    *   `MESSAGE` (`"message"`):
        *   `content` (str, required): Message content to display.
        *   `image_urls` (list[str] | None, optional): Image URLs in message.
        *   `wait_for_response` (bool, optional): Wait for user response (ignore for basic use).
        *   `security_risk` (optional): Ignore for basic use.

The backend server is already configured to use SocketIO for real-time communication with the web UI.  The SocketIO server is initialized in `openhands/server/shared.py` and event handlers are defined in `openhands/server/listen_socket.py`.

The existing SocketIO setup is configured to allow Cross-Origin Requests from any origin (`cors_allowed_origins='*'`), which will allow the Mac app to connect to the backend server.

The Mac app will need to implement a SocketIO client to connect to the backend server and communicate using the same event names (`oh_action`, `oh_event`, etc.) as the web UI.

---

# Key Takeaways for Mac App Development (Swift/Cocoa)

This approach reuses the existing communication infrastructure and avoids the need to design a new communication protocol.

* **Technology Stack:** Swift/Cocoa is chosen for native Mac app development.
* **MVP Feature Prioritization:** Confirmed focus on MVP features: Task Input Area, Agent Output Display, Basic File Explorer, Start/Stop Control Buttons, Backend Connection Settings.
* **Backend Communication:** Mac app needs to implement:
    * **SocketIO Client:** To connect to backend, send `oh_action` events, and receive `oh_event` events. Use `WsClientProvider` and `useWsClient` in frontend code as reference.
    * **REST API Client:** To call backend REST API endpoints for file management, settings, and conversation creation. Use `OpenHands` API client in frontend code as reference.
* **UI Components:** Consider adapting or reimplementing relevant React components in Swift/Cocoa:
    * Chat input area (similar to `ChatInput`).
    * Agent output display (similar to `Messages` / `chat-message.tsx`, potentially using `xterm.js` or native terminal view for command output).
    * File explorer (similar to `FileExplorer`, `ExplorerTree`, `TreeNode`, using file management APIs).
    * Control buttons (Start/Stop/Pause/Resume, similar to `ActionButton`).
    * Settings panel (similar to `SettingsModal` / `SettingsForm`, using settings APIs).
    * **State Management:** Implement state management in the Mac app, potentially inspired by Redux or React Context patterns used in the frontend. Consider managing agent state, conversation state, file explorer state, and settings state.
    * **Authentication (if needed for Saas mode):** Implement JWT cookie-based authentication similar to the backend and web frontend if targeting Saas mode. For OSS mode, authentication might be skipped.
    * **Configuration:** Allow users to configure backend connection settings (host, TLS) in the Mac app's settings panel, similar to `VITE_BACKEND_HOST` and `VITE_USE_TLS` environment variables in the frontend.
    * **Conversation Management:** Implement conversation creation using the `POST /api/conversations` endpoint.
    121 
    122 This documentation provides a technical foundation for starting the Swift/Cocoa Mac app development, focusing on precise details and actionable information derived from the existing codebase.
    123 
    124 ## 4. Glossary of Technical Details
    125 
    126 ### 4.1. REST API Endpoints
    127 
    128 | Endpoint                                                 | Method   | Description                                                                 | Request Parameters                                                                                                | Response Format                                  |
    129 | :------------------------------------------------------- | :------- | :-------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------- |
    130 | `/api/conversations/{conversation_id}/list-files`        | GET      | Lists files in the specified path within the agent's workspace.             | `conversation_id` (path), `path` (query, optional)                                                               | JSON list of file paths                        |
    131 | `/api/conversations/{conversation_id}/select-file`      | GET      | Retrieves the content of a specified file.                               | `conversation_id` (path), `file` (query, required - absolute path in runtime)                                     | JSON: `{'code': file_content}`                   |
    132 | `/api/conversations/{conversation_id}/save-file`        | POST     | Saves (writes/updates) the content of a file in the agent's workspace.      | `conversation_id` (path), Request Body (JSON): `{'filePath': relative_path, 'content': file_content}`             | JSON: `{'message': 'File saved successfully'}`   |
    133 | `/api/conversations/{conversation_id}/upload-files`      | POST     | Uploads one or more files to the agent's workspace.                         | `conversation_id` (path), Request Body (multipart/form-data): `files` (list of files)                             | JSON: `{'message': ..., 'uploaded_files': [], 'skipped_files': []}` |\n| `/api/conversations/{conversation_id}/zip-directory`    | GET      | Downloads the entire workspace as a zip file.                               | `conversation_id` (path)                                                                                           | File response (workspace.zip)                    |\n| `/api/conversations`                                    | POST     | Creates a new conversation.                                               | Request Body (JSON): `InitSessionRequest` (`selected_repository`, `initial_user_msg`, `image_urls`)               | JSON: `{'conversation_id': conversation_id}`      |\n| `/api/conversations`                                    | GET      | Searches and retrieves a list of conversations (paginated).                | `page_id` (query, optional), `limit` (query, optional)                                                            | `ConversationInfoResultSet` JSON                 |\n| `/api/conversations/{conversation_id}`                  | GET      | Retrieves details of a specific conversation.                              | `conversation_id` (path)                                                                                           | `ConversationInfo` JSON or `null`               |\n| `/api/conversations/{conversation_id}`                  | PATCH    | Updates a conversation (currently only title).                             | `conversation_id` (path), Request Body (body parameter): `title`                                                | `True` or `False` JSON                             |\n| `/api/conversations/{conversation_id}`                  | DELETE   | Deletes a conversation.                                                     | `conversation_id` (path)                                                                                           | `True` or `False` JSON                             |\n| `/api/settings`                                          | GET      | Loads application settings.                                                 | None                                                                                                               | `SettingsWithTokenMeta` JSON or `null`           |\n| `/api/settings`                                          | POST     | Stores (saves/updates) application settings.                                | Request Body (JSON): `SettingsWithTokenMeta`                                                                       | JSON: `{'message': 'Settings stored'}`           |\n| `/api/options/models`                                     | GET      | Gets available AI models.                                                    | None                                                                                                               | JSON list of model names                         |\n| `/api/options/agents`                                     | GET      | Gets available agents.                                                       | None                                                                                                               | JSON list of agent names                         |\n| `/api/options/security-analyzers`                         | GET      | Gets available security analyzers.                                           | None                                                                                                               | JSON list of security analyzer names             |\n| `/api/options/config`                                      | GET      | Gets server configuration.                                                    | None                                                                                                               | Server configuration JSON                        |\n| `/api/conversations/{conversation_id}/config`            | GET      | Retrieves runtime configuration (runtime_id, session_id).                  | `conversation_id` (path)                                                                                           | JSON: `{'runtime_id': runtime_id, 'session_id': session_id}` |\n| `/api/conversations/{conversation_id}/vscode-url`        | GET      | Retrieves VS Code URL for the conversation's workspace.                     | `conversation_id` (path)                                                                                           | JSON: `{'vscode_url': vscode_url}`               |\n| `/api/conversations/{conversation_id}/web-hosts`        | GET      | Retrieves web hosts used by the runtime.                                     | `conversation_id` (path)                                                                                           | JSON: `{'hosts': list_of_hosts}`                  |\n\n### 4.2. `ActionType` Enum Values\n\n*   `INIT`: Agent initialization. Only sent by client.\n*   `MESSAGE`: Sending a chat message.\n*   `READ`: Reading a file.\n*   `WRITE`: Writing to a file.\n*   `RUN`: Running a bash command.\n*   `RUN_IPYTHON`: Running IPython code.\n*   `BROWSE`: Browsing a web page.\n*   `BROWSE_INTERACTIVE`: Interactive browser interaction.\n*   `DELEGATE`: Delegating a task to another agent.\n*   `FINISH`: Finishing the task.\n*   `REJECT`: Rejecting a request.\n*   `CHANGE_AGENT_STATE`: Changes the state of the agent, e.g. to paused or running\n\n### 4.3. `AgentState` Enum Values\n\n*   `LOADING`: Agent is loading/initializing.\n*   `INIT`: Agent is initialized.\n*   `RUNNING`: Agent is currently running/executing tasks.\n*   `AWAITING_USER_INPUT`: Agent is waiting for user input/message.\n*   `PAUSED`: Agent execution is paused.\n*   `STOPPED`: Agent execution is stopped.\n*   `FINISHED`: Agent has finished the task successfully.\n*   `REJECTED`: Agent rejected the task or request.\n*   `ERROR`: Agent encountered an error during execution.\n*   `RATE_LIMITED`: Agent is rate-limited by an external service (e.g., LLM API).\n*   `AWAITING_USER_CONFIRMATION`: Agent is waiting for user confirmation before proceeding with an action.\n*   `USER_CONFIRMED`: User has confirmed agent's action.\n*   `USER_REJECTED`: User has rejected agent's action.\n\n---\n
