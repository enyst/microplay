# Files to Prompt GitHub Interface

This repository provides a GitHub Pages interface for [simonw/files-to-prompt](https://github.com/simonw/files-to-prompt), a tool that concatenates files from a repository into a single prompt for use with LLMs.

## Features

- Browse public GitHub repositories and select files/directories
- Generate prompts in different formats (plain text, Markdown, Claude XML)
- Process files locally in the browser or via GitHub Actions workflow
- No GitHub token required for public repositories when using the GitHub workflow

## How to Use

### Option 1: GitHub Pages Interface with Local Processing

1. Visit the GitHub Pages site
2. Enter the repository owner and name
3. Provide a GitHub token (required for local processing)
4. Browse the repository and select files/directories
5. Configure output options
6. Click "Generate Prompt"
7. Copy the generated prompt to your clipboard

### Option 2: GitHub Pages Interface with GitHub Workflow

1. Visit the GitHub Pages site
2. Enter the repository owner and name
3. Browse the repository and select files/directories
4. Configure output options
5. Click "Generate Prompt"
6. Follow the instructions to trigger the GitHub workflow
7. Download the generated prompt from the workflow artifacts

## GitHub Workflow

The repository includes a GitHub workflow that can be triggered manually to generate prompts. The workflow:

1. Checks out the specified repository
2. Installs the files-to-prompt tool
3. Runs the tool with the specified options
4. Uploads the generated prompt as a workflow artifact

## Setup

To set up this interface for your own use:

1. Fork this repository
2. Enable GitHub Pages for the repository
3. The interface will be available at `https://[your-username].github.io/[repo-name]/`

## Local Development

To run the interface locally:

```bash
# Clone the repository
git clone https://github.com/[your-username]/[repo-name].git
cd [repo-name]

# Serve the files using a local web server
python -m http.server
```

Then visit `http://localhost:8000` in your browser.

## License

This project is licensed under the MIT License - see the LICENSE file for details.