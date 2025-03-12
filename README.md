# Files-to-Prompt GitHub Interface

This is the GitHub Pages interface for [simonw/files-to-prompt](https://github.com/simonw/files-to-prompt), a tool that concatenates a directory full of files into a single prompt for use with LLMs.

## Features

- Browse GitHub repositories and select files/directories to include in your prompt
- Process files locally in the browser or use a GitHub workflow
- Support for all files-to-prompt options:
  - Line numbers
  - Hidden files
  - Output formats (default, markdown, Claude XML)
  - Ignore patterns
  - .gitignore handling

## Usage

### Local Processing

1. Enter the repository owner and name
2. Enter a GitHub token with `repo` scope (required for accessing repository contents)
3. Click "Load Repository"
4. Browse the repository and select files/directories to include
5. Configure options (line numbers, output format, etc.)
6. Click "Generate Prompt"
7. Copy or download the generated prompt

### GitHub Workflow

For larger repositories or when you don't want to use a personal access token, you can use the GitHub workflow option:

1. Enter the repository owner and name
2. Click "Load Repository"
3. Browse the repository and select files/directories to include
4. Configure options (line numbers, output format, etc.)
5. Uncheck "Process files locally"
6. Click "Generate Prompt"
7. Follow the instructions to trigger the GitHub workflow
8. Download the generated prompt from the workflow artifacts

## Security Considerations

- GitHub tokens are stored only in your browser's local storage and are never sent to any server other than GitHub's API
- When using the GitHub workflow option, no token is required for public repositories
- The workflow runs in the context of the repository, so it can only access files that are part of the repository

## How It Works

This interface uses the GitHub API to:
1. Browse repository contents
2. Fetch file contents
3. Generate prompts locally in your browser

When using the GitHub workflow option, it provides instructions for triggering a workflow in your repository that will process the files and generate a prompt on GitHub's servers.