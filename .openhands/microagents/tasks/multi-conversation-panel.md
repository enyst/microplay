# Multi-Conversation Panel Investigation

## Current Behavior

The current Conversation Panel in the web frontend displays a list of the user's conversations with the following characteristics:

### Data Source and API
- Conversations are fetched from the `/api/conversations` endpoint (defined in `manage_conversations.py`)
- Default limit is 20 conversations per page, with pagination support
- Each conversation has properties:
  - `conversation_id`: Unique identifier
  - `title`: Either custom or auto-generated from repository name + ID prefix
  - `selected_repository`: GitHub repository associated with the conversation (if any)
  - `last_updated_at`: Timestamp of last update
  - `created_at`: Timestamp when conversation was created
  - `status`: RUNNING or STOPPED

### Filtering Logic
- Conversations are filtered by the user's GitHub ID (using `get_github_user_id(request)`)
- Conversations older than a maximum age (`config.conversation_max_age_seconds`) are filtered out
- Only conversations that belong to the authenticated user are shown

### Display and Ordering
- Conversations appear to be displayed in chronological order with most recent first (based on the `last_updated_at` field)
- The frontend has a hardcoded limit of 9 conversations that are displayed in the panel (while the API supports up to 20 per page)
- Each conversation shows its title, status, and possibly other metadata

### Workspace Management
- Each conversation has its own workspace directory on the backend
- The workspace contains all files and state for that conversation
- When a user selects a conversation, they're effectively switching to that conversation's workspace

### User Interactions
- Users can create new conversations
- Users can select and continue existing conversations
- Users can delete conversations
- Users can rename conversations (by updating the title)

### Technical Implementation
- Backend uses FastAPI for the API endpoints
- Conversations are managed by a `ConversationManager` class
- Conversation metadata is stored and retrieved via `ConversationStoreImpl`

## Behavior for Mac Client

### Core Functionality
- Maintain the same conversation properties as the web client (ID, title, repository, timestamps, status)
- Add Mac-specific metadata (local workspace path, favorite status, tags, etc.)
- Unlike the web client, the Mac client will display all available conversations without the 9-conversation limit
- Implement pagination or infinite scroll to handle large numbers of conversations while maintaining performance

### UI/UX Improvements
- Support grouping conversations by repository, date, or custom tags
- Add search functionality for finding conversations by title, content, or repository
- Implement a "favorites" system for pinning important conversations
- Show additional metadata like conversation length, number of files, etc.

### Native Integration
- Integrate with macOS file system (Finder integration)
- Support drag-and-drop for files and folders
- Provide menu bar access for quick conversation switching
- Implement native macOS notifications for conversation updates