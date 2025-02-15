# Git Pitch Generator Tool
==========================

## Introduction
---------------

The `git-pitch-gen` tool is a CLI application that integrates with Ollama to generate meaningful commit messages and pull request descriptions using AI.

## Installation
--------------

To install the tool, run:
```bash
npm install -g git-pitch-gen
```
Or use the provided installation script:
```bash
curl -fsSL https://raw.githubusercontent.com/guilhermehbueno/ollama-git-pitch-gen/master/install.sh | bash
```
## Usage
-----

### Commands

* `pitch install`: Installs Ollama, starts the Ollama server, registers symlink, and creates default models.
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

### Configuration

The following configurations can be added as needed:

| Configuration | Default Value |
| --- | --- |
| OLLAMA_MODEL | "DeepSeek" |
| UNIFIED_LINES | 50 |
| ALLOW_COMMIT_OVERRIDE | true |

## Functions
-------------

### `pitch install`

Installs Ollama, starts the Ollama server, registers symlink, and creates default models.

### `pitch uninstall`

Removes `pitch` models, stops Ollama, and performs full uninstallation.

### `pitch delete`

Deletes only the models while keeping the installation intact.

### `pitch start`

Starts the Ollama server.

### `pitch stop`

Stops the Ollama server.

### `pitch info`

Displays system information, including installed models, symlinks, and updates.

### `pitch apply`

Installs the Git hook to automate commit message generation.

### `pitch model`

Allows the user to switch AI models used for commit messages.

### `pitch update`

Updates `pitch` to the latest version from the repository.

### `pitch create_model <model-name>`

Creates a new AI model with the given name.

### `pitch pr <base_branch>`

Generates a Pull Request title and description using AI, comparing the current branch to `<base_branch>`.

## Git Hook
------------

The tool includes a Git hook that generates a commit message using Ollama based on the staged changes in the repository. The hook checks if Ollama is running, retrieves the diff of the staged changes, and uses this information to generate a meaningful commit message.

### Functions

* `get_git_diff`: Retrieves the diff of the staged changes.
* `is_ollama_running`: Checks if Ollama is running on the specified port.
* `generate_commit_message(diff)`: Generates a commit message using Ollama based on the provided diff.
* `process_commit_message(raw_message)`: Processes the output from Ollama to convert <think> blocks into comments.

### Configurations

The following configurations can be added as needed:

| Configuration | Default Value |
| --- | --- |
| OLLAMA_MODEL | "DeepSeek" |
| OLLAMA_PROMPT | "" |
| OLLAMA_PROMPT_EXTRA | "" |
| MAX_DIFF_LINES | 50 |
| MIN_DIFF_LINES | not specified |
| ALLOW_COMMIT_OVERRIDE | true |

## Troubleshooting
-----------------

If you encounter any issues during installation or usage, please refer to the [Troubleshooting](#troubleshooting) section.

## Contributing
--------------

Contributions are welcome! Please see the [Contributing](#contributing) section for more information.

## License
---------

The `git-pitch-gen` tool is licensed under the MIT License. See the [License](#license) section for details.
