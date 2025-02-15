# Git Pitch Generator Tool
==========================

## Introduction
---------------

The `git-pitch-gen` tool is a CLI application that integrates with Ollama to generate meaningful commit messages and pull request descriptions using AI.

## Installation
--------------

To install the tool, run:
```bash
curl -fsSL https://raw.githubusercontent.com/guilhermehbueno/ollama-git-pitch-gen/master/install.sh | bash
```
## Usage
-----

### Commands

* `pitch install`: Installs Ollama, starts the Ollama server, registers symlink, and creates default models.
* `pitch readme`: Displays this README documentation in the terminal.
* `pitch uninstall`: Removes `pitch` models, stops Ollama, and performs full uninstallation.
* `pitch delete`: Deletes only the models while keeping the installation intact.
* `pitch start`: Starts the Ollama server.
* `pitch stop`: Stops the Ollama server.
* `pitch info`: Displays system information, including installed models, symlinks, and updates.
* `pitch apply`: Installs the Git hook to automate commit message generation.
* `pitch model`: Allows the user to switch AI models used for commit messages.
* `pitch update`: Updates `pitch` to the latest version from the repository.
* `pitch create_model <model-name>`: Creates a new AI model with the given name.
* `pitch pr <base_branch>`: Generates a Pull Request title and description using AI, comparing the current branch to `<base_branch>`.
* `pitch commit`: Generates a commit message using AI based on staged changes.

### Configuration

The following configurations can be added to `~/.ollama-git-pitch-gen/prepare-commit-msg.properties`:

| Configuration | Default Value | Description |
| --- | --- | --- |
| OLLAMA_MODEL | "DeepSeek" | The AI model to use for generating messages |
| UNIFIED_LINES | 50 | Maximum number of diff lines to process |
| ALLOW_COMMIT_OVERRIDE | true | If false, AI message is added as a comment |
| OLLAMA_PROMPT | "" | Custom prompt to use with the AI model |
| MAX_DIFF_LINES | 500 | Maximum number of diff lines to send to AI |

Example properties file:
```properties
# Use a different Ollama model
OLLAMA_MODEL=pitch_llama3.2:latest

# Custom AI prompt
OLLAMA_PROMPT=Generate a meaningful Git commit message for the following change:

# Increase max diff lines limit
MAX_DIFF_LINES=500

# Allow commit override (if false, AI-generated message is appended as a comment)
ALLOW_COMMIT_OVERRIDE=false
```

## Git Hook Integration
-------------------

The tool installs a Git hook (`prepare-commit-msg`) that automatically generates commit messages using AI when you make a commit. The hook:

1. Reads your configuration from the properties file
2. Checks if Ollama is running
3. Analyzes the staged changes
4. Generates an AI-powered commit message

You can install the Git hook using:
```bash
pitch apply
```

If `ALLOW_COMMIT_OVERRIDE=false`, the AI-generated message will be added as a comment in your commit message editor, allowing you to reference it while writing your own message.

## Functions
-------------

### `pitch install`

Installs Ollama, starts the Ollama server, registers symlink, and creates default models.

### `pitch readme`

Displays the README documentation directly in the terminal for quick reference of commands and configurations.

### `pitch uninstall`

Removes `pitch`