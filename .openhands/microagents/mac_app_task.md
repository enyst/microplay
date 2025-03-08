---
name  :  mac_app_task
type  :  task
agent  :  CodeActAgent
---

# OpenHands Mac App UI Design Plan

This document provides a technical overview and development guide for the OpenHands Mac application.

## 1. Core App Features

The Mac app will include the following core features:

1. **Task Input Area:**
   - Description: A text area where users can input instructions and tasks for OpenHands.

2. **Agent Output Display:**
   - Description: Displays conversation history, agent actions, and logs.

3. **Basic File Explorer:**
   - Description: Enables navigation and viewing of the workspace files.

## 2. App Structure

The application is conceptually divided into two main columns:

- **Left Column (Main Interaction Area):**
  - Task Input Area
  - User Input Area
  - Agent Output Display

- **Right Column (Context and Tools):**
  - Workspace (File Explorer)
  - Variable Context Area
  - Memory (switchable)
  - Settings Panel
  - Prompt Configuration Area

## 3. Backend Connection

The application communicates with the backend via SocketIO using:

- `oh_event`: For receiving events from the backend.
- `oh_action`: For sending actions such as running commands, changing agent state, and sending messages.

This document outlines the technical design and integration points for the Mac application.