---
name  :  mac_app_mvp
type  :  task
agent  :  CodeActAgent
---

# OpenHands Mac App MVP Definition

This document defines the MVP features for the OpenHands Mac App.

## MVP Configuration Defaults

- **Backend Connection**: Local by default (localhost)
- **Target macOS Version**: Current stable release (no backward compatibility required for MVP)
- **Architecture Role**: The Mac App functions purely as a frontend client connecting to the existing OpenHands backend, which handles all data persistence, file operations, and business logic.

## Core MVP Features

For the initial MVP release of the OpenHands Mac application, we will focus on the following core features:

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

5. **Backend Connection Settings:**
   - Description: Basic settings to connect to the OpenHands backend.
   - Functionality: Option to specify the backend host (assume local backend for MVP initially).

## Excluded from MVP

The following features will be excluded from the MVP to expedite the initial release:

- Advanced File Management (create, delete, rename)
- Extended Settings Panel (beyond basic backend connection)
- Prompt Configuration Area (MicroAgent management)
- Memory Area visualization
- Pause/Resume and Step control buttons
- Dedicated Terminal/Command Output section (agent output display suffices)

## MVP Focus

The primary focus of the MVP is to enable the following functionalities:

- Input tasks for the OpenHands agent.
- View the agent's execution and outputs in real-time.
- Navigate and view files within the workspace.
- Start and stop agent execution.
- Connect to a local OpenHands backend.
