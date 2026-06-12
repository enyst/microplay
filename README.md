# Files-to-Prompt GitHub Interface

This repository provides a GitHub Pages interface for [simonw/files-to-prompt](https://github.com/simonw/files-to-prompt), a tool that concatenates a directory full of files into a single prompt for use with LLMs.

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

## GitHub Workflow

The repository includes a GitHub workflow file (`.github/workflows/files-to-prompt.yml`) that can be triggered manually to process files from a repository and generate a prompt.

### Workflow Inputs

- `repository`: GitHub repository (format: owner/repo)
- `branch`: Branch name
- `paths`: Comma-separated list of file/directory paths to include
- `include_hidden`: Include hidden files
- `line_numbers`: Include line numbers
- `output_format`: Output format (default, markdown, cxml)
- `ignore_patterns`: Comma-separated list of patterns to ignore
- `ignore_gitignore`: Ignore .gitignore files

### Workflow Outputs

The workflow produces an artifact containing:
- `prompt.txt`: The generated prompt
- `metadata.json`: Metadata about the generation process

## Security Considerations

- GitHub tokens are stored only in your browser's local storage and are never sent to any server other than GitHub's API
- When using the GitHub workflow option, no token is required for public repositories
- The workflow runs in the context of the repository, so it can only access files that are part of the repository

## Development

To contribute to this project:

1. Clone the repository
2. Make your changes
3. Test locally using a web server (e.g., `python -m http.server`)
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.