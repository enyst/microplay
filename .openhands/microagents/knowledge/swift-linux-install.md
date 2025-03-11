---
 name: swift-linux-install
 type: knowledge
 agent: CodeActAgent
 version: 1.0.0
 triggers:
 - swift-linux
 - swift-debian
 - swift-installation
---

# Swift Installation Guide for Debian Linux

This document provides instructions for installing Swift on Debian 12 (Bookworm) for the microplay project.

> This setup is intended for non-UI development tasks on Swift on Linux.

## Prerequisites

Before installing Swift, you need to install the required dependencies:

```bash
sudo apt-get update
sudo apt-get install -y \
  binutils-gold \
  gcc \
  git \
  libcurl4-openssl-dev \
  libedit-dev \
  libicu-dev \
  libncurses-dev \
  libpython3-dev \
  libsqlite3-dev \
  libxml2-dev \
  pkg-config \
  tzdata \
  uuid-dev
```

## Download and Install Swift

1. Find the latest Swift version for Debian:

   Go to the [Swift.org download page](https://www.swift.org/download/) to find the latest Swift version compatible with Debian 12 (Bookworm).
   
   Look for a tarball named something like `swift-<VERSION>-RELEASE-debian12.tar.gz` (e.g., `swift-6.0.3-RELEASE-debian12.tar.gz`).
   
   The URL pattern is typically:
   ```
   https://download.swift.org/swift-<VERSION>-release/debian12/swift-<VERSION>-RELEASE/swift-<VERSION>-RELEASE-debian12.tar.gz
   ```
   
   Where `<VERSION>` is the Swift version number (e.g., `6.0.3`).

2. Download the Swift binary for Debian 12:

```bash
cd /workspace
wget https://download.swift.org/swift-6.0.3-release/debian12/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-debian12.tar.gz
```

> **Note**: Check the Swift.org page for the latest version and update the version number in the URL if necessary (e.g., replace `6.0.3` with the current version).

3. Extract the archive:

```bash
tar xzf swift-6.0.3-RELEASE-debian12.tar.gz
```

4. Add Swift to your PATH by adding the following line to your `~/.bashrc` file:

```bash
echo 'export PATH=/workspace/swift-6.0.3-RELEASE-debian12/usr/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

> **Note**: Make sure to update the version number in the PATH to match the version you downloaded.

> **Note**: Make sure to install Swift in the `/workspace` directory, but outside the git repository to avoid committing the Swift binaries.

## Verify Installation

Verify that Swift is correctly installed by running:

```bash
swift --version
```

You should see output similar to:

```
Swift version 6.0.3 (swift-6.0.3-RELEASE)
Target: x86_64-unknown-linux-gnu
```

## Running Swift

You can now run Swift commands and build Swift projects:

```bash
# Run the Swift REPL
swift

# Build a Swift package
cd /path/to/swift/package
swift build

# Run Swift tests
swift test
```

## Troubleshooting

If you encounter any issues with the Swift installation:

1. Ensure all dependencies are installed
2. Verify the PATH is correctly set
3. Check that the Swift binary is executable

For more information, visit the [Swift website](https://swift.org/getting-started/).