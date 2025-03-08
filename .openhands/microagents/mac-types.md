---
 name: mac-types
 type: knowledge
 agent: CodeActAgent
 version: 1.0.0
 triggers:
 - mac-types
---

# Types for the Mac Client functionality

This document catalogs the data types needed for implementing the OpenHands Mac client specific functionality.

For types representing openhands' events, which are set in stone since they are implemented on backend/server side, see: events.md

IMPORTANT: unlike the specs dependent on backend definitions, this document is open to change while we are writing the spec!

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

# BackendSettings

Configuration for connecting to the backend.

```json
{
  "backend_host": "localhost",
  "backend_port": 8000,
  "use_tls": false
}
```
