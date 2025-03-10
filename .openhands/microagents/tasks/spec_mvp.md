---
name  :  mac_client_mvp
type  :  task
agent  :  CodeActAgent
---

# OpenHands Mac Client MVP Definition

This document defines the MVP features for the OpenHands Mac Client, which serves as a native macOS alternative to the existing web UI. Both the Mac Client and web UI connect to the same OpenHands backend service, with this client providing a native desktop experience while maintaining full compatibility with the backend API.

## MVP Configuration Defaults

- **Backend Connection**: Local by default (localhost)
- **Target macOS Version**: Current stable release (no backward compatibility required for MVP)
- **Architecture Role**: The Mac Client functions purely as a frontend client connecting to the existing OpenHands backend, which handles all data persistence, file operations, and business logic.

## Core MVP Features

For the initial MVP release of the OpenHands Mac client application, we will focus on the following core features:

1. **Task Input Area:**
   - Description: A text area for users to input tasks.
   - Functionality: Accepts natural language task instructions.

2. **Agent Output Display:**
   - Description: Display area for agent's step-by-step actions and outputs.
   - Functionality: Real-time display of agent's progress, including command executions and code changes.

3. **Basic File Explorer:**
   - Description: A simplified file tree view.
   - Functionality: Enables file system navigation and file viewing (no creation, deletion, or renaming in MVP).

4. **Start/Stop Control Buttons:**
   - Description: Buttons to control agent execution.
   - Functionality: Start the agent and stop it when needed.

5. **Comprehensive Settings Panel:**
   - Description: Tabbed interface for configuring all client and backend settings.
   - Functionality: Complete settings management matching all backend config.template.toml options, organized in logical tabs.

6. **Backend Connection Settings:**
   - Description: Settings to connect to the OpenHands backend.
   - Functionality: Options to specify the backend host, port, authentication, and connection parameters.

7. **Multiple Conversation Management:**
   - Description: Interface to create, switch between, and manage multiple conversations.
   - Functionality: Create new conversations, switch between existing ones, view conversation history.

## MVP Technical Architecture

- **UI Framework**: SwiftUI
- **Architecture Pattern**: MVVM (Model-View-ViewModel)
- **State Management**: Observable state objects with SwiftUI's property wrappers
- **Communication**: Centralized SocketIO manager class for backend integration

## Excluded from MVP

The following features will be excluded from the MVP to expedite the initial release:

- Advanced File Management (create, delete, rename)
- Prompt Configuration Area (MicroAgent management)
- Memory Area visualization
- Pause/Resume and Step control buttons
- Dedicated Terminal/Command Output section (agent output display suffices)
- Advanced conversation grouping and tagging
- Settings import/export functionality
- Offline support

## MVP Focus

The primary focus of the MVP is to enable the following functionalities:

- Input tasks for the OpenHands agent.
- View the agent's execution and outputs in real-time.
- Navigate and view files within the workspace.
- Start and stop agent execution.
- Connect to a local or remote OpenHands backend.
- Configure all client and backend settings through a comprehensive tabbed interface.
- Create, switch between, and manage multiple conversations.
- View and search conversation history.

## Technical Architecture

### Data Models

The Mac client will implement Swift models that directly map to the JSON structures defined in the backend communication protocol. These include:

- Communication models (Events, UserActions)
- Agent state model
- File system representations
- Configuration models

All models will implement Swift's `Codable` protocol for JSON serialization/deserialization.

